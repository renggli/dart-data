import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../engine/commands.dart';
import '../model/environment.dart';
import '../model/notebook.dart';
import 'protocol.dart';

@JS(r'$dartLoader')
external JSAny? get _dartLoader;

/// Browser-side client managing the notebook computation Web Worker with
/// timeout cancellation, worker respawn, and local fallback execution.
final class EngineClient {
  new({
    this.workerScriptUrl = 'worker.dart.js',
    this.onBusyStateChanged,
    this.onStateUpdated,
  }) {
    _spawnWorker();
  }

  final String workerScriptUrl;
  final void Function(bool isBusy, int elapsedMs)? onBusyStateChanged;
  final void Function()? onStateUpdated;

  final WorkerDispatcher _local = WorkerDispatcher();
  final CommandRegistry registry = CommandRegistry();

  NotebookDocument get document => _local.document;
  Environment get env => _local.document.env;

  web.Worker? _worker;
  bool _workerAvailable = false;
  int _nextRequestId = 1;
  final Map<int, Completer<Map<String, Object?>>> _pending = {};

  Timer? _busyTicker;
  Timer? _timeoutTimer;
  Stopwatch? _busyStopwatch;
  bool _isBusy = false;
  bool _canUndo = false;
  bool _canRedo = false;

  bool get isBusy => _isBusy;
  bool get canUndo => _canUndo;
  bool get canRedo => _canRedo;

  void _spawnWorker() {
    _workerAvailable = false;
    if (_dartLoader != null) {
      _worker = null;
      return;
    }
    try {
      final w = web.Worker(workerScriptUrl.toJS);
      final handshakeId = _nextRequestId++;
      w.onmessage = ((web.MessageEvent event) {
        final raw = (event.data as JSString).toDart;
        final res = (jsonDecode(raw) as Map).cast<String, Object?>();
        final id = (res['id'] as num?)?.toInt();
        if (id == handshakeId && res['ok'] == true) {
          _workerAvailable = true;
          _pushSnapshotToWorker(w);
          return;
        }
        final completer = id == null ? null : _pending.remove(id);
        if (completer != null) {
          _stopBusy();
          completer.complete(res);
        }
      }).toJS;

      w.onerror = ((web.Event _) {
        _workerAvailable = false;
        _worker = null;
        _failPending('Worker encountered an unexpected error');
      }).toJS;

      _worker = w;
      w.postMessage(
        jsonEncode({'id': handshakeId, 'type': 'getSnapshot'}).toJS,
      );
    } on Object {
      _worker = null;
      _workerAvailable = false;
    }
  }

  void _pushSnapshotToWorker(web.Worker w) {
    final id = _nextRequestId++;
    w.postMessage(
      jsonEncode({
        'id': id,
        'type': 'loadSnapshot',
        'snapshot': document.toJson(),
      }).toJS,
    );
  }

  void _startBusy(int timeoutMs) {
    _isBusy = true;
    _busyStopwatch = Stopwatch()..start();
    onBusyStateChanged?.call(true, 0);
    _busyTicker?.cancel();
    _busyTicker = Timer.periodic(const Duration(milliseconds: 100), (_) {
      onBusyStateChanged?.call(true, _busyStopwatch?.elapsedMilliseconds ?? 0);
    });
    _timeoutTimer?.cancel();
    if (timeoutMs > 0) {
      _timeoutTimer = Timer(Duration(milliseconds: timeoutMs), cancel);
    }
  }

  void _stopBusy() {
    _isBusy = false;
    _busyTicker?.cancel();
    _busyTicker = null;
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
    _busyStopwatch?.stop();
    onBusyStateChanged?.call(false, 0);
  }

  void _failPending(String message) {
    _stopBusy();
    final entries = _pending.values.toList();
    _pending.clear();
    for (final c in entries) {
      c.complete({'ok': false, 'error': message});
    }
  }

  /// Terminates the running worker and respawns a fresh one with the last
  /// valid document snapshot.
  void cancel() {
    _worker?.terminate();
    _worker = null;
    _workerAvailable = false;
    _failPending('Evaluation cancelled or timed out');
    _spawnWorker();
  }

  Future<Map<String, Object?>> _request(
    String type, [
    Map<String, Object?> params = const {},
  ]) async {
    final req = {'id': _nextRequestId++, 'type': type, ...params};

    if (!_workerAvailable || _worker == null) {
      final res = _local.handle(req);
      _applyResponse(res);
      return res;
    }

    final completer = Completer<Map<String, Object?>>();
    _pending[req['id']! as int] = completer;
    _startBusy(env.settings.timeoutMs);
    _worker!.postMessage(jsonEncode(req).toJS);

    final res = await completer.future;
    _applyResponse(res);
    return res;
  }

  void _applyResponse(Map<String, Object?> res) {
    if (res['ok'] != true) return;
    final snapshot = res['snapshot'] as Map<String, Object?>?;
    if (snapshot != null) {
      document.loadFromJson(snapshot);
    }
    _canUndo = res['canUndo'] as bool? ?? _canUndo;
    _canRedo = res['canRedo'] as bool? ?? _canRedo;
    onStateUpdated?.call();
  }

  Future<String?> evalCell(
    String source, {
    String? uid,
    int? index,
    bool forceApprox = false,
  }) async {
    final res = await _request('evalCell', {
      'source': source,
      'uid': ?uid,
      'index': ?index,
      'forceApprox': forceApprox,
    });
    return res['evaluatedUid'] as String?;
  }

  Future<String?> insertMarkdown(String source, {int? index}) async {
    final res = await _request('insertMarkdown', {
      'source': source,
      'index': ?index,
    });
    return res['insertedUid'] as String?;
  }

  Future<void> updateMarkdown(String uid, String source) =>
      _request('updateMarkdown', {'uid': uid, 'source': source});

  Future<void> moveCell(String uid, int newIndex) =>
      _request('moveCell', {'uid': uid, 'newIndex': newIndex});

  Future<void> deleteCell(String uid) => _request('deleteCell', {'uid': uid});

  Future<String?> convertCell(String uid) async {
    final res = await _request('convertCell', {'uid': uid});
    return res['convertedUid'] as String?;
  }

  Future<void> recomputeStale() => _request('recomputeStale');

  Future<void> recomputeAll() => _request('recomputeAll');

  Future<void> importMarkdown(String markdown) =>
      _request('importMarkdown', {'markdown': markdown});

  Future<String> exportMarkdown() async {
    final res = await _request('exportMarkdown');
    return res['markdown'] as String? ?? document.toMarkdown();
  }

  Future<void> loadSnapshot(Map<String, Object?> snapshot) =>
      _request('loadSnapshot', {'snapshot': snapshot});

  Future<void> undo() => _request('undo');

  Future<void> redo() => _request('redo');

  Future<void> updateSettings(NotebookSettings settings) =>
      _request('updateSettings', {'settings': settings.toJson()});

  Future<void> clearSession() => _request('clearSession');
}
