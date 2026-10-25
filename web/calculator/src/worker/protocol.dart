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
  new() {
    _resetState();
  }

  late Environment environment;
  late Session session;
  late RpnStack stack;
  late CalcEvaluator evaluator;
  late RpnInterpreter rpn;

  void _resetState() {
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
        final input = payload['input']! as String;
        final forceNumeric = payload['forceNumeric'] as bool? ?? false;
        final recordHistory = payload['recordHistory'] as bool? ?? true;
        final cell = evaluator.evaluateScroll(
          input,
          forceNumeric: forceNumeric,
          recordHistory: recordHistory,
        );
        return {
          'cell': cell.toJson(digits: environment.settings.digits),
          'state': exportStateJson(),
        };

      case 'updateScrollCell':
        final cellId = (payload['cellId']! as num).toInt();
        final input = payload['input']! as String;
        final forceNumeric = payload['forceNumeric'] as bool? ?? false;
        final (:cell, :staleIds) = evaluator.updateScrollCell(
          cellId,
          input,
          forceNumeric: forceNumeric,
        );
        return {
          'cell': cell.toJson(digits: environment.settings.digits),
          'staleIds': staleIds,
          'state': exportStateJson(),
        };

      case 'recomputeStale':
        final updated = evaluator.recomputeStaleCells();
        return {
          'updatedCells': [
            for (final c in updated)
              c.toJson(digits: environment.settings.digits),
          ],
          'state': exportStateJson(),
        };

      case 'deleteCell':
        final cellId = (payload['cellId']! as num).toInt();
        final staleIds = session.deleteCell(cellId);
        stack.removeResultId(cellId);
        return {'staleIds': staleIds, 'state': exportStateJson()};

      case 'pushCellToStack':
        final cellId = (payload['cellId']! as num).toInt();
        final cell = session.allCells[cellId];
        if (cell != null &&
            !cell.deleted &&
            cell.value is! ErrorValue &&
            cell.value is! InfoValue) {
          stack.push(StackItem(resultId: cell.id, value: cell.value));
        }
        return {'state': exportStateJson()};

      case 'evalRpnLine':
        final line = payload['line']! as String;
        final err = rpn.executeLine(line);
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
        final err = rpn.executeCommand(cmd);
        return {
          'error': ?(err != null
              ? CalcSerialization.toJson(
                  err,
                  digits: environment.settings.digits,
                )
              : null),
          'state': exportStateJson(),
        };

      case 'setSettings':
        environment.settings = CalcSettings.fromJson(
          (payload['settings']! as Map).cast<String, Object?>(),
        );
        return {'state': exportStateJson()};

      case 'loadState':
        importStateJson((payload['state']! as Map).cast<String, Object?>());
        return {'state': exportStateJson()};

      case 'reset':
        _resetState();
        return {'state': exportStateJson()};

      default:
        throw ArgumentError('Unknown worker operation: $op');
    }
  }

  /// Exports a full snapshot of the current session, environment, and RPN
  /// stack as a JSON map.
  Map<String, Object?> exportStateJson() {
    final digits = environment.settings.digits;
    return {
      'settings': environment.settings.toJson(),
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

  /// Restores the worker state from a snapshot produced by [exportStateJson].
  void importStateJson(Map<String, Object?> state) {
    if (state['settings'] case final Map<Object?, Object?> s) {
      environment.settings = CalcSettings.fromJson(s.cast<String, Object?>());
    }
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
