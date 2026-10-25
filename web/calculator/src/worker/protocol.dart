import '../engine/evaluator.dart';
import '../engine/rpn.dart';
import '../model/environment.dart';
import '../model/serialization.dart';
import '../model/session.dart';
import '../model/stack.dart';
import '../model/value.dart';

/// Pure-Dart JSON request envelope sent from the UI thread to the Web Worker.
final class WorkerRequest {
  const new({required this.id, required this.op, this.payload = const {}});

  final int id;
  final String op;
  final Map<String, Object?> payload;

  Map<String, Object?> toJson() => {'id': id, 'op': op, 'payload': payload};

  factory fromJson(Map<String, Object?> json) => WorkerRequest(
    id: (json['id']! as num).toInt(),
    op: json['op']! as String,
    payload:
        (json['payload'] as Map?)?.cast<String, Object?>() ??
        const <String, Object?>{},
  );
}

/// Pure-Dart JSON response envelope returned from the Web Worker to the UI
/// thread.
final class WorkerResponse {
  const new({
    required this.id,
    required this.ok,
    this.result,
    this.error,
    this.elapsedMs = 0,
  });

  final int id;
  final bool ok;
  final Map<String, Object?>? result;
  final Map<String, Object?>? error;
  final int elapsedMs;

  Map<String, Object?> toJson() => {
    'id': id,
    'ok': ok,
    'result': ?result,
    'error': ?error,
    'elapsedMs': elapsedMs,
  };

  factory fromJson(Map<String, Object?> json) => WorkerResponse(
    id: (json['id']! as num).toInt(),
    ok: json['ok'] as bool? ?? true,
    result: (json['result'] as Map?)?.cast<String, Object?>(),
    error: (json['error'] as Map?)?.cast<String, Object?>(),
    elapsedMs: (json['elapsedMs'] as num?)?.toInt() ?? 0,
  );
}

/// Stateful worker dispatcher that processes [WorkerRequest] messages against
/// an isolated [Environment], [Session], and [RpnStack].
///
/// Kept pure-Dart (no `package:web`) so it can be unit-tested directly on VM
/// and Node.js in addition to running inside `worker.dart`.
final class WorkerDispatcher {
  static const int _maxUndoLevels = 64;

  new() {
    environment = Environment();
    session = Session();
    stack = RpnStack();
    evaluator = CalcEvaluator(
      environment: environment,
      session: session,
      stack: stack,
    );
    rpn = RpnInterpreter(stack: stack, evaluator: evaluator);
  }

  late final Environment environment;
  late final Session session;
  late final RpnStack stack;
  late final CalcEvaluator evaluator;
  late final RpnInterpreter rpn;

  final List<Map<String, Object?>> _undoStack = [];
  final List<Map<String, Object?>> _redoStack = [];

  /// Whether at least one undo snapshot is available.
  bool get canUndo => _undoStack.isNotEmpty;

  /// Whether at least one redo snapshot is available.
  bool get canRedo => _redoStack.isNotEmpty;

  /// Restores the previous session, environment, and stack snapshot.
  bool undo() {
    if (_undoStack.isEmpty) return false;
    _redoStack.add(_exportCoreState());
    final prev = _undoStack.removeLast();
    _importCoreState(prev);
    return true;
  }

  /// Reapplies the most recently undone session, environment, and stack snapshot.
  bool redo() {
    if (_redoStack.isEmpty) return false;
    _undoStack.add(_exportCoreState());
    final next = _redoStack.removeLast();
    _importCoreState(next);
    return true;
  }

  void _resetState() {
    environment.clearAll();
    session.clear();
    stack.clear();
  }

  /// Processes a single [request] and returns a [WorkerResponse].
  WorkerResponse handle(WorkerRequest request) {
    final sw = Stopwatch()..start();
    try {
      final res = _dispatch(request.op, request.payload);
      sw.stop();
      return WorkerResponse(
        id: request.id,
        ok: true,
        result: res,
        elapsedMs: sw.elapsedMilliseconds,
      );
    } catch (e) {
      sw.stop();
      final errVal = ErrorValue(e.toString());
      return WorkerResponse(
        id: request.id,
        ok: false,
        error: CalcSerialization.toJson(
          errVal,
          digits: environment.settings.digits,
        ),
        elapsedMs: sw.elapsedMilliseconds,
      );
    }
  }

  Map<String, Object?> _dispatch(String op, Map<String, Object?> payload) {
    switch (op) {
      case 'evalScroll':
        final before = _exportCoreState();
        final input = payload['input']! as String;
        final forceNumeric = payload['forceNumeric'] as bool? ?? false;
        final recordHistory = payload['recordHistory'] as bool? ?? true;
        final cell = evaluator.evaluateScroll(
          input,
          forceNumeric: forceNumeric,
          recordHistory: recordHistory,
        );
        _recordUndoSnapshot(before);
        return {
          'cell': cell.toJson(digits: environment.settings.digits),
          'state': exportStateJson(),
        };

      case 'updateScrollCell':
        final before = _exportCoreState();
        final cellId = (payload['cellId']! as num).toInt();
        final input = payload['input']! as String;
        final forceNumeric = payload['forceNumeric'] as bool? ?? false;
        final (:cell, :staleIds) = evaluator.updateScrollCell(
          cellId,
          input,
          forceNumeric: forceNumeric,
        );
        _recordUndoSnapshot(before);
        return {
          'cell': cell.toJson(digits: environment.settings.digits),
          'staleIds': staleIds,
          'state': exportStateJson(),
        };

      case 'recomputeStale':
        final before = _exportCoreState();
        final updated = evaluator.recomputeStaleCells();
        if (updated.isNotEmpty) {
          _recordUndoSnapshot(before);
        }
        return {
          'updatedCells': [
            for (final c in updated)
              c.toJson(digits: environment.settings.digits),
          ],
          'state': exportStateJson(),
        };

      case 'deleteCell':
        final before = _exportCoreState();
        final cellId = (payload['cellId']! as num).toInt();
        final staleIds = session.deleteCell(cellId);
        stack.removeResultId(cellId);
        _recordUndoSnapshot(before);
        return {'staleIds': staleIds, 'state': exportStateJson()};

      case 'pushCellToStack':
        final cellId = (payload['cellId']! as num).toInt();
        final cell = session.allCells[cellId];
        if (cell != null &&
            !cell.deleted &&
            cell.value is! ErrorValue &&
            cell.value is! InfoValue) {
          final before = _exportCoreState();
          stack.push(StackItem(resultId: cell.id, value: cell.value));
          _recordUndoSnapshot(before);
        }
        return {'state': exportStateJson()};

      case 'evalRpnLine':
        final before = _exportCoreState();
        final line = payload['line']! as String;
        final err = rpn.executeLine(line);
        if (err == null) {
          _recordUndoSnapshot(before);
        } else {
          _importCoreState(before);
        }
        return {
          'error': ?(err != null
              ? CalcSerialization.toJson(
                  err,
                  digits: environment.settings.digits,
                )
              : null),
          'state': exportStateJson(),
        };

      case 'execRpnCommand':
        final cmd = payload['command']! as String;
        final upper = cmd.toUpperCase().trim();
        if (upper == 'UNDO') {
          undo();
          return {'state': exportStateJson()};
        }
        if (upper == 'REDO') {
          redo();
          return {'state': exportStateJson()};
        }
        final before = _exportCoreState();
        final err = rpn.executeCommand(cmd);
        if (err == null) {
          _recordUndoSnapshot(before);
        } else {
          _importCoreState(before);
        }
        return {
          'error': ?(err != null
              ? CalcSerialization.toJson(
                  err,
                  digits: environment.settings.digits,
                )
              : null),
          'state': exportStateJson(),
        };

      case 'undo':
        final applied = undo();
        return {'applied': applied, 'state': exportStateJson()};

      case 'redo':
        final applied = redo();
        return {'applied': applied, 'state': exportStateJson()};

      case 'setSettings':
        environment.settings = CalcSettings.fromJson(
          (payload['settings']! as Map).cast<String, Object?>(),
        );
        return {'state': exportStateJson()};

      case 'loadState':
        _undoStack.clear();
        _redoStack.clear();
        importStateJson((payload['state']! as Map).cast<String, Object?>());
        return {'state': exportStateJson()};

      case 'reset':
        if (session.activeCells.isNotEmpty ||
            stack.depth > 0 ||
            environment.variables.isNotEmpty ||
            environment.functions.isNotEmpty) {
          _recordUndoSnapshot(_exportCoreState());
        }
        _resetState();
        return {'state': exportStateJson()};

      default:
        throw ArgumentError('Unknown worker operation: $op');
    }
  }

  /// Exports a full snapshot of the current session, environment, and RPN
  /// stack as a JSON map.
  Map<String, Object?> exportStateJson() => {
    'settings': environment.settings.toJson(),
    ..._exportCoreState(),
    'canUndo': canUndo,
    'canRedo': canRedo,
  };

  /// Restores the worker state from a snapshot produced by [exportStateJson].
  void importStateJson(Map<String, Object?> state) {
    if (state['settings'] case final Map<Object?, Object?> s) {
      environment.settings = CalcSettings.fromJson(s.cast<String, Object?>());
    }
    _importCoreState(state);
  }

  void _recordUndoSnapshot(Map<String, Object?> before) {
    _undoStack.add(before);
    if (_undoStack.length > _maxUndoLevels) {
      _undoStack.removeAt(0);
    }
    _redoStack.clear();
  }

  Map<String, Object?> _exportCoreState() {
    final digits = environment.settings.digits;
    return {
      'variables': {
        for (final entry in environment.variables.entries)
          entry.key: CalcSerialization.toJson(entry.value, digits: digits),
      },
      'functions': {
        for (final entry in environment.functions.entries)
          entry.key: entry.value.toJson(),
      },
      'session': session.toJson(digits: digits),
      'stack': stack.toJson(digits: digits),
    };
  }

  void _importCoreState(Map<String, Object?> state) {
    environment.clearAll();
    if (state['variables'] case final Map<Object?, Object?> vars) {
      for (final entry in vars.entries) {
        environment.setVariable(
          entry.key! as String,
          CalcSerialization.fromJson(
            (entry.value! as Map).cast<String, Object?>(),
          ),
        );
      }
    }
    if (state['functions'] case final Map<Object?, Object?> fns) {
      for (final entry in fns.entries) {
        environment.setFunction(
          UserFunction.fromJson((entry.value! as Map).cast<String, Object?>()),
        );
      }
    }
    if (state['session'] case final Map<Object?, Object?> sess) {
      session.loadFromJson(sess.cast<String, Object?>());
    }
    if (state['stack'] case final List<Object?> stk) {
      stack.loadFromJson(stk);
    }
  }
}
