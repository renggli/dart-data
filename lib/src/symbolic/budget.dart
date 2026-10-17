import 'dart:async';

/// Exception thrown when a symbolic computation exceeds the active
/// [ComputationBudget] step or time limit.
final class ComputationLimitException implements Exception {
  /// Creates a computation limit exception with [message].
  const new(this.message, {this.steps, this.elapsed});

  /// Human-readable description of the exceeded limit.
  final String message;

  /// Number of symbolic steps executed before termination, if tracked.
  final int? steps;

  /// Elapsed wall-clock time before termination, if tracked.
  final Duration? elapsed;

  @override
  String toString() => 'ComputationLimitException: $message';
}

/// Cooperative zone-scoped computation budget for bounding symbolic algorithms.
///
/// Wrap long-running symbolic operations (such as simplification, integration,
/// series expansion, polynomial factorization, or Gröbner basis reduction) in
/// [ComputationBudget.run] to enforce cooperative step count or wall-clock
/// `timeout` limits without terminating the isolate.
///
/// ```dart
/// final result = ComputationBudget.run(
///   () => expr.integrate('x'),
///   timeout: const Duration(seconds: 2),
///   maxSteps: 50000,
/// );
/// ```
abstract final class ComputationBudget {
  static final Object _budgetKey = Object();
  static int _activeZones = 0;

  /// Executes [body] within a cooperative computation budget enforcing
  /// [timeout] and/or [maxSteps].
  ///
  /// Throws a [ComputationLimitException] if [body] exceeds either limit.
  /// If nested inside an outer [ComputationBudget.run], both the inner and
  /// outer budgets are checked at each step.
  static R run<R>(R Function() body, {Duration? timeout, int? maxSteps}) {
    if (timeout != null && timeout.isNegative) {
      throw ArgumentError.value(timeout, 'timeout', 'Must be non-negative');
    }
    if (maxSteps != null && maxSteps < 0) {
      throw ArgumentError.value(maxSteps, 'maxSteps', 'Must be non-negative');
    }
    final parent = _activeZones > 0
        ? Zone.current[_budgetKey] as _BudgetState?
        : null;
    final state = _BudgetState(
      parent: parent,
      maxSteps: maxSteps,
      timeoutMicroseconds: timeout?.inMicroseconds,
    );
    _activeZones++;
    try {
      return runZoned(body, zoneValues: {_budgetKey: state});
    } finally {
      _activeZones--;
    }
  }

  /// Records one computation step against the active [ComputationBudget], if any,
  /// throwing a [ComputationLimitException] when a configured limit is exceeded.
  static void check() {
    if (_activeZones == 0) return;
    final state = Zone.current[_budgetKey] as _BudgetState?;
    state?.step();
  }
}

final class _BudgetState {
  new({
    required this.parent,
    required this.maxSteps,
    required this.timeoutMicroseconds,
  }) : stopwatch = timeoutMicroseconds != null ? (Stopwatch()..start()) : null;

  final _BudgetState? parent;
  final int? maxSteps;
  final int? timeoutMicroseconds;
  final Stopwatch? stopwatch;
  int steps = 0;

  void step() {
    steps++;
    final limit = maxSteps;
    if (limit != null && steps > limit) {
      throw ComputationLimitException(
        'Exceeded maximum computation steps ($limit)',
        steps: steps,
        elapsed: stopwatch?.elapsed,
      );
    }
    final maxMicros = timeoutMicroseconds;
    final sw = stopwatch;
    if (maxMicros != null && sw != null) {
      final elapsedMicros = sw.elapsedMicroseconds;
      if (elapsedMicros > maxMicros) {
        throw ComputationLimitException(
          'Exceeded computation timeout (${Duration(microseconds: maxMicros)})',
          steps: steps,
          elapsed: Duration(microseconds: elapsedMicros),
        );
      }
    }
    parent?.step();
  }
}
