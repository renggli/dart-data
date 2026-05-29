import 'dart:math' show max;
import 'package:collection/collection.dart';
import 'package:more/more.dart';

import 'functions.dart';

/// Returns the numerical integration of the provided [function] from [a] to
/// [b], that is the result of _int(f(x), dx=a..b)_.
///
/// [epsilon] is the maximum error tolerance to be accepted. [depth] is the
/// maximum recursion depth, a warning is raised if it is too shallow.
///
/// [poles] is a list of points at which the [function] should not be
/// evaluated. The integration is automatically split over the generated
/// intervals: _\[a..p_1\[, \]p_1..p_2\[, ... \]p_n, b\]_.
///
/// In case of an integration problem, [onWarning] is evaluated with the
/// [IntegrateWarning] and the _x_ position. The default implementation throws
/// an [IntegrateError] exception, but a custom handler can continue the
/// evaluation.
///
/// ```dart
/// final area = integrate((x) => x * x, 0, 1);
/// print(area);  // 0.3333333333333333
/// ```
///
double integrate(
  UnaryFunction<double> function,
  double a,
  double b, {
  int depth = 6,
  double epsilon = 1e-6,
  Iterable<double> poles = const [],
  void Function(IntegrateWarning type, double x)? onWarning,
}) {
  onWarning ??= (type, x) => throw IntegrateError._(type, x);
  // Validate boundary condition.
  if (a.isNaN) {
    throw ArgumentError.value(a, 'a', 'Invalid lower bound');
  } else if (b.isNaN) {
    throw ArgumentError.value(b, 'b', 'Invalid upper bound');
  } else if (a > b) {
    return -integrate(
      function,
      b,
      a,
      depth: depth,
      epsilon: epsilon,
      poles: poles,
      onWarning: onWarning,
    );
  } else if (a == b) {
    return 0.0;
  }
  // Handle poles.
  if (poles.isNotEmpty) {
    return _integratePoles(
      function,
      a,
      b,
      depth: depth,
      epsilon: epsilon,
      poles: poles,
      onWarning: onWarning,
    );
  }
  // Handle infinite bounds.
  if (a == double.negativeInfinity && b == double.infinity) {
    return integrate(
          function,
          a,
          0,
          depth: depth,
          epsilon: epsilon,
          onWarning: onWarning,
        ) +
        integrate(
          function,
          0,
          b,
          depth: depth,
          epsilon: epsilon,
          onWarning: onWarning,
        );
  } else if (a == double.negativeInfinity) {
    return integrate(
      (t) => function(b - (1.0 - t) / t) / (t * t),
      epsilon,
      1,
      depth: depth,
      epsilon: epsilon,
      onWarning: onWarning,
    );
  } else if (b == double.infinity) {
    return integrate(
      (t) => function(a + (1.0 - t) / t) / (t * t),
      epsilon,
      1,
      depth: depth,
      epsilon: epsilon,
      onWarning: onWarning,
    );
  }

  // Adaptive quadrature for finite bounds without poles.
  return _integrateAdaptive(
    function,
    a,
    b,
    depth: depth,
    epsilon: epsilon,
    onWarning: onWarning,
  );
}

double _integratePoles(
  UnaryFunction<double> function,
  double a,
  double b, {
  required int depth,
  required double epsilon,
  required Iterable<double> poles,
  required void Function(IntegrateWarning type, double x) onWarning,
}) {
  final normalized = poles
      .where((pole) => a <= pole && pole <= b)
      .toSet()
      .toList();
  if (normalized.isEmpty) {
    return integrate(
      function,
      a,
      b,
      depth: depth,
      epsilon: epsilon,
      onWarning: onWarning,
    );
  }
  normalized.sort();
  final intervals = normalized
      .map((pole) => (lo: pole - epsilon, hi: pole + epsilon))
      .toList();
  final mergedIntervals = <({double lo, double hi})>[];
  var current = intervals[0];
  for (var i = 1; i < intervals.length; i++) {
    final next = intervals[i];
    if (next.lo <= current.hi) {
      current = (lo: current.lo, hi: max(current.hi, next.hi));
    } else {
      mergedIntervals.add(current);
      current = next;
    }
  }
  mergedIntervals.add(current);
  var last = a;
  var result = 0.0;
  for (final interval in mergedIntervals) {
    if (last < interval.lo) {
      result += integrate(
        function,
        last,
        interval.lo,
        depth: depth,
        epsilon: epsilon,
        onWarning: onWarning,
      );
    }
    last = interval.hi;
  }
  if (last < b) {
    result += integrate(
      function,
      last,
      b,
      depth: depth,
      epsilon: epsilon,
      onWarning: onWarning,
    );
  }
  return result;
}

double _integrateAdaptive(
  UnaryFunction<double> function,
  double a,
  double b, {
  required int depth,
  required double epsilon,
  required void Function(IntegrateWarning type, double x) onWarning,
}) {
  var result = 0.0;
  final queue = QueueList.from([
    _Quadrature.simpson(
      function,
      depth,
      epsilon,
      a,
      function(a),
      b,
      function(b),
    ),
  ]);
  while (queue.isNotEmpty) {
    final full = queue.removeLast();
    final nextDepth = full.depth - 1;
    final nextEpsilon = full.epsilon / 2.0;
    final left = _Quadrature.simpson(
      function,
      nextDepth,
      nextEpsilon,
      full.a,
      full.fa,
      full.m,
      full.fm,
    );
    final right = _Quadrature.simpson(
      function,
      nextDepth,
      nextEpsilon,
      full.m,
      full.fm,
      full.b,
      full.fb,
    );
    if (left.epsilon == full.epsilon || left.a == left.m) {
      onWarning(IntegrateWarning.doesNotConverge, full.m);
      result += full.w;
      continue;
    }
    if (full.depth <= 0) {
      onWarning(IntegrateWarning.depthTooShallow, full.m);
    }
    final delta = left.w + right.w - full.w;
    if (full.depth <= 0 || delta.abs() <= 15 * full.epsilon) {
      result += left.w + right.w + delta / 15;
    } else {
      queue.addLast(right);
      queue.addLast(left);
    }
  }
  return result;
}

/// Integration warnings that can be triggered for badly behaving functions or
/// ill defined parameters.
enum IntegrateWarning { doesNotConverge, depthTooShallow }

/// Integration error that is thrown when warnings are not handled explicitly.
class IntegrateError extends Error with ToStringPrinter {
  IntegrateError._(this.type, this.x);

  /// The integration warning thrown.
  final IntegrateWarning type;

  /// The approximate position of the integration warning.
  final double x;

  @override
  ObjectPrinter get toStringPrinter => super.toStringPrinter
    ..addValue(type, name: 'type')
    ..addValue(x, name: 'x');
}

class _Quadrature {
  factory _Quadrature.simpson(
    double Function(double) f,
    int depth,
    double epsilon,
    double a,
    double fa,
    double b,
    double fb,
  ) {
    final m = 0.5 * (a + b), fm = f(m);
    return _Quadrature(
      depth,
      epsilon,
      a,
      fa,
      m,
      fm,
      b,
      fb,
      (b - a) / 6.0 * (fa + 4.0 * fm + fb),
    );
  }

  _Quadrature(
    this.depth,
    this.epsilon,
    this.a,
    this.fa,
    this.m,
    this.fm,
    this.b,
    this.fb,
    this.w,
  );

  final int depth;
  final double epsilon;
  final double a;
  final double fa;
  final double m;
  final double fm;
  final double b;
  final double fb;
  final double w;
}
