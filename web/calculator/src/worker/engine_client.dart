import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../engine/evaluator.dart';
import '../engine/rpn.dart';
import '../model/environment.dart';
import '../model/session.dart';
import '../model/stack.dart';
import '../model/value.dart';
import 'protocol.dart';

@JS(r'$dartLoader')
external JSAny? get _dartLoader;

/// Client that manages the dedicated symbolic computation `Worker` (`worker.dart.js`),
/// handling request correlation, busy timers, timeout cancellation (`terminate()`),
/// and seamless state replay on respawn.
///
/// Also maintains a synchronized local mirror of [Environment], [Session], and
/// [RpnStack] for instant synchronous UI rendering, autocomplete, and fallback
/// execution if Web Workers are unavailable.
final class EngineClient {
  new({
    this.workerScriptUrl = 'worker.dart.js',
    this.onBusyStateChanged,
    this.onStateUpdated,
  }) {
    _initLocalMirror();
    _spawnWorker();
  }

  final String workerScriptUrl;
  final void Function(bool isBusy, int elapsedMs)? onBusyStateChanged;
  final void Function()? onStateUpdated;

  late final Environment environment;
  late final Session session;
  late final RpnStack stack;
  late final CalcEvaluator localEvaluator;
  late final RpnInterpreter localRpn;

  final WorkerDispatcher _fallbackDispatcher = WorkerDispatcher();
  web.Worker? _worker;
  bool _workerAvailable = false;
  int _nextRequestId = 1;
  final Map<int, ({WorkerRequest request, Completer<WorkerResponse> completer})>
  _pending = {};

  Timer? _busyTicker;
  Stopwatch? _busyStopwatch;
  bool _isBusy = false;
  bool _canUndo = false;
  bool _canRedo = false;

  bool get isBusy => _isBusy;
  bool get canUndo => _workerAvailable ? _canUndo : _fallbackDispatcher.canUndo;
  bool get canRedo => _workerAvailable ? _canRedo : _fallbackDispatcher.canRedo;

  void _initLocalMirror() {
    environment = _fallbackDispatcher.environment;
    session = _fallbackDispatcher.session;
    stack = _fallbackDispatcher.stack;
    localEvaluator = _fallbackDispatcher.evaluator;
    localRpn = _fallbackDispatcher.rpn;
  }

  void _spawnWorker() {
    // In DDC edit-refresh mode (webdev serve), $dartLoader is defined on window
    // and entrypoints require DOM window bootstrap. Skip worker and use local mirror.
    if (_dartLoader != null) {
      _worker = null;
      _workerAvailable = false;
      return;
    }
    try {
      final w = web.Worker(workerScriptUrl.toJS);
      final handshakeId = _nextRequestId++;
      w.onmessage = ((web.MessageEvent event) {
        final raw = (event.data as JSString).toDart;
        final map = (jsonDecode(raw) as Map).cast<String, Object?>();
        final response = WorkerResponse.fromJson(map);
        if (response.id == handshakeId && response.ok) {
          _workerAvailable = true;
          // Push any state changes that happened before handshake completed
          final syncReq = WorkerRequest(
            id: _nextRequestId++,
            op: 'loadState',
            payload: {'state': _fallbackDispatcher.exportStateJson()},
          );
          w.postMessage(jsonEncode(syncReq.toJson()).toJS);
          return;
        }
        final entry = _pending.remove(response.id);
        entry?.completer.complete(response);
      }).toJS;
      w.onerror = ((web.Event event) {
        event.preventDefault();
        _workerAvailable = false;
        _worker = null;
        if (_pending.isNotEmpty) {
          final entries = _pending.values.toList();
          _pending.clear();
          for (final entry in entries) {
            if (!entry.completer.isCompleted) {
              entry.completer.complete(
                _fallbackDispatcher.handle(entry.request),
              );
            }
          }
          _stopBusyTracking();
        }
      }).toJS;
      _worker = w;
      _workerAvailable = false;
      final handshakeReq = WorkerRequest(
        id: handshakeId,
        op: 'loadState',
        payload: {'state': _fallbackDispatcher.exportStateJson()},
      );
      w.postMessage(jsonEncode(handshakeReq.toJson()).toJS);
    } catch (_) {
      _worker = null;
      _workerAvailable = false;
    }
  }

  /// Cancels any in-flight computation immediately by terminating the worker,
  /// spawning a replacement worker, and replaying the last committed state.
  void cancelActiveComputation() {
    if (_pending.isEmpty) return;
    _worker?.terminate();
    _worker = null;
    _workerAvailable = false;
    for (final entry in _pending.values) {
      if (!entry.completer.isCompleted) {
        entry.completer.complete(
          const WorkerResponse(
            id: 0,
            ok: false,
            error: {
              'kind': 'error',
              'message': 'Computation cancelled by user.',
              'suggestion': 'Try a smaller degree/order or use approx(...) / numeric commands.',
            },
          ),
        );
      }
    }
    _pending.clear();
    _stopBusyTracking();
    _spawnWorker();
  }

  /// Evaluates a statement in Scroll mode and appends a [WorksheetCell].
  Future<WorksheetCell> evaluateScroll(
    String input, {
    bool forceNumeric = false,
    bool recordHistory = true,
  }) async {
    final resp = await _request('evalScroll', {
      'input': input,
      'forceNumeric': forceNumeric,
      'recordHistory': recordHistory,
    });
    if (!resp.ok || resp.result == null) {
      final errMsg =
          resp.error?['message'] as String? ?? 'Computation aborted.';
      final errCell = session.addResult(
        input: input,
        value: ErrorValue(
          errMsg,
          suggestion: resp.error?['suggestion'] as String?,
          source: input,
        ),
      );
      onStateUpdated?.call();
      return errCell;
    }
    _syncFromWorkerResult(resp.result!);
    final cellMap = (resp.result!['cell']! as Map).cast<String, Object?>();
    final cell = WorksheetCell.fromJson(cellMap);
    onStateUpdated?.call();
    return session.allCells[cell.id] ?? cell;
  }

  /// Re-evaluates an existing Scroll cell [cellId] in-place.
  Future<({WorksheetCell cell, List<int> staleIds})> updateScrollCell(
    int cellId,
    String newInput, {
    bool forceNumeric = false,
  }) async {
    final resp = await _request('updateScrollCell', {
      'cellId': cellId,
      'input': newInput,
      'forceNumeric': forceNumeric,
    });
    if (!resp.ok || resp.result == null) {
      final errMsg =
          resp.error?['message'] as String? ?? 'Computation aborted.';
      final staleIds = session.updateCell(
        cellId,
        input: newInput,
        value: ErrorValue(errMsg, source: newInput),
      );
      onStateUpdated?.call();
      return (cell: session.allCells[cellId]!, staleIds: staleIds);
    }
    _syncFromWorkerResult(resp.result!);
    final staleIds = (resp.result!['staleIds'] as List<Object?>? ?? const [])
        .map((e) => (e! as num).toInt())
        .toList();
    onStateUpdated?.call();
    return (cell: session.allCells[cellId]!, staleIds: staleIds);
  }

  /// Recomputes all stale Scroll cells in topological order.
  Future<void> recomputeStaleCells() async {
    final resp = await _request('recomputeStale', const {});
    if (resp.ok && resp.result != null) {
      _syncFromWorkerResult(resp.result!);
      onStateUpdated?.call();
    }
  }

  /// Deletes a Scroll cell (leaving a tombstone).
  Future<List<int>> deleteCell(int cellId) async {
    final resp = await _request('deleteCell', {'cellId': cellId});
    if (resp.ok && resp.result != null) {
      _syncFromWorkerResult(resp.result!);
      final staleIds = (resp.result!['staleIds'] as List<Object?>? ?? const [])
          .map((e) => (e! as num).toInt())
          .toList();
      onStateUpdated?.call();
      return staleIds;
    }
    final stale = session.deleteCell(cellId);
    stack.removeResultId(cellId);
    onStateUpdated?.call();
    return stale;
  }

  /// Pushes an existing Scroll cell [cellId] onto the RPN stack (`1:`).
  Future<void> pushCellToStack(int cellId) async {
    final resp = await _request('pushCellToStack', {
      'cellId': cellId,
    }, trackBusy: false);
    if (resp.ok && resp.result != null) {
      _syncFromWorkerResult(resp.result!);
      onStateUpdated?.call();
    }
  }

  /// Executes an RPN token line (`2 3 +`).
  Future<ErrorValue?> evaluateRpnLine(String line) async {
    final resp = await _request('evalRpnLine', {'line': line});
    if (!resp.ok) {
      final errMsg =
          resp.error?['message'] as String? ?? 'Computation aborted.';
      return ErrorValue(
        errMsg,
        suggestion: resp.error?['suggestion'] as String?,
        source: line,
      );
    }
    _syncFromWorkerResult(resp.result!);
    onStateUpdated?.call();
    final errJson = resp.result!['error'] as Map?;
    if (errJson != null) {
      return ErrorValue(
        errJson['message'] as String? ?? 'Error',
        offset: (errJson['offset'] as num?)?.toInt(),
        suggestion: errJson['suggestion'] as String?,
        source: errJson['source'] as String?,
      );
    }
    return null;
  }

  /// Executes an immediate RPN command (`SWAP`, `DUP`, `FACT`, `TAYL`, `+`, ...).
  Future<ErrorValue?> executeRpnCommand(String command) async {
    final resp = await _request('execRpnCommand', {'command': command});
    if (!resp.ok) {
      final errMsg =
          resp.error?['message'] as String? ?? 'Computation aborted.';
      return ErrorValue(errMsg);
    }
    _syncFromWorkerResult(resp.result!);
    onStateUpdated?.call();
    final errJson = resp.result!['error'] as Map?;
    if (errJson != null) {
      return ErrorValue(
        errJson['message'] as String? ?? 'Error',
        suggestion: errJson['suggestion'] as String?,
      );
    }
    return null;
  }

  /// Restores the previous session, environment, and stack snapshot.
  Future<bool> undo() async {
    final resp = await _request('undo', const {}, trackBusy: false);
    if (resp.ok && resp.result != null) {
      _syncFromWorkerResult(resp.result!);
      onStateUpdated?.call();
      return resp.result!['applied'] as bool? ?? false;
    }
    return false;
  }

  /// Reapplies the most recently undone session, environment, and stack snapshot.
  Future<bool> redo() async {
    final resp = await _request('redo', const {}, trackBusy: false);
    if (resp.ok && resp.result != null) {
      _syncFromWorkerResult(resp.result!);
      onStateUpdated?.call();
      return resp.result!['applied'] as bool? ?? false;
    }
    return false;
  }

  /// Updates calculator settings on both the local mirror and the worker.
  Future<void> updateSettings(CalcSettings newSettings) async {
    environment.settings = newSettings;
    final resp = await _request('setSettings', {
      'settings': newSettings.toJson(),
    }, trackBusy: false);
    if (resp.ok && resp.result != null) {
      _syncFromWorkerResult(resp.result!);
    }
    onStateUpdated?.call();
  }

  /// Restores a complete state snapshot (e.g. from `localStorage` or URL hash).
  Future<void> loadSnapshot(Map<String, Object?> snapshot) async {
    _fallbackDispatcher.importStateJson(snapshot);
    if (_workerAvailable) {
      await _sendToWorker('loadState', {'state': snapshot}, trackBusy: false);
    }
    onStateUpdated?.call();
  }

  /// Exports the full state snapshot for persistence or sharing.
  Map<String, Object?> exportSnapshot() =>
      _fallbackDispatcher.exportStateJson();

  /// Resets the entire session, environment, and stack.
  Future<void> resetAll() async {
    _fallbackDispatcher.handle(const WorkerRequest(id: 0, op: 'reset'));
    if (_workerAvailable) {
      await _sendToWorker('reset', const {}, trackBusy: false);
    }
    onStateUpdated?.call();
  }

  Future<WorkerResponse> _request(
    String op,
    Map<String, Object?> payload, {
    bool trackBusy = true,
  }) async {
    if (_workerAvailable && _worker != null) {
      return _sendToWorker(op, payload, trackBusy: trackBusy);
    }
    return _fallbackDispatcher.handle(
      WorkerRequest(id: _nextRequestId++, op: op, payload: payload),
    );
  }

  Future<WorkerResponse> _sendToWorker(
    String op,
    Map<String, Object?> payload, {
    required bool trackBusy,
  }) async {
    final reqId = _nextRequestId++;
    final req = WorkerRequest(id: reqId, op: op, payload: payload);
    final completer = Completer<WorkerResponse>();
    _pending[reqId] = (request: req, completer: completer);

    if (trackBusy) _startBusyTracking();

    try {
      _worker!.postMessage(jsonEncode(req.toJson()).toJS);
      final timeoutMs = environment.settings.timeoutMs;
      final response = await completer.future.timeout(
        Duration(milliseconds: timeoutMs),
        onTimeout: () {
          _pending.remove(reqId);
          _worker?.terminate();
          _worker = null;
          _spawnWorker();
          return WorkerResponse(
            id: reqId,
            ok: false,
            error: {
              'kind': 'error',
              'message':
                  'Computation timed out after ${(timeoutMs / 1000).toStringAsFixed(0)} s.',
              'suggestion': 'Try reducing the polynomial degree / series order or use numeric evaluation.',
            },
          );
        },
      );
      return response;
    } catch (_) {
      _workerAvailable = false;
      return _fallbackDispatcher.handle(req);
    } finally {
      if (_pending.isEmpty) {
        _stopBusyTracking();
      }
    }
  }

  void _syncFromWorkerResult(Map<String, Object?> result) {
    if (result['state'] case final Map<Object?, Object?> stateMap) {
      final casted = stateMap.cast<String, Object?>();
      _canUndo = casted['canUndo'] as bool? ?? false;
      _canRedo = casted['canRedo'] as bool? ?? false;
      if (_workerAvailable) {
        _fallbackDispatcher.importStateJson(casted);
      }
    }
  }

  void _startBusyTracking() {
    _busyStopwatch ??= Stopwatch()..start();
    _busyTicker ??= Timer.periodic(const Duration(milliseconds: 120), (_) {
      final elapsed = _busyStopwatch?.elapsedMilliseconds ?? 0;
      if (elapsed >= 150) {
        _isBusy = true;
        onBusyStateChanged?.call(true, elapsed);
      }
    });
  }

  void _stopBusyTracking() {
    _busyTicker?.cancel();
    _busyTicker = null;
    _busyStopwatch?.stop();
    _busyStopwatch = null;
    if (_isBusy) {
      _isBusy = false;
      onBusyStateChanged?.call(false, 0);
    }
  }
}
