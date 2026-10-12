import 'dart:math' as math;

/// Method used for numerical quadrature.
enum IntegrationMethod {
  /// Adaptive Gauss-Kronrod 15-point rule (GK15).
  gaussKronrod,

  /// Adaptive Simpson's 3-point parabolic rule.
  simpson,
}

/// Integration warnings triggered for poorly behaving functions or recursion
/// limits.
enum IntegrateWarning {
  /// Quadrature failed to converge to the requested tolerance within max depth.
  doesNotConverge,

  /// Quadrature reached maximum recursion depth.
  depthTooShallow,
}

/// Error thrown when numerical integration fails to converge and no warning
/// callback handles it.
class IntegrateError extends Error {
  new(this.type, this.x);

  /// The integration warning thrown.
  final IntegrateWarning type;

  /// The approximate position of the integration warning.
  final double x;

  @override
  String toString() => 'IntegrateError: $type near x = $x';
}

/// Computes the definite or improper integral $\int_a^b f(x) dx$ using the
/// specified quadrature [method].
///
/// Conceptually, calculating an integral evaluates the total accumulated area
/// underneath a curve between two boundary points $x = a$ and $x = b$.
/// Formally, it recursively subdivides intervals using the selected [method]
/// ([IntegrationMethod.gaussKronrod] by default, or
/// [IntegrationMethod.simpson]).
///
/// Supports:
/// - Infinite and semi-infinite integration domains ($\[-\infty, \infty\]$,
///   $\[-\infty, b\]$, $\[a, \infty\)$) via reciprocal coordinate transformations
///   ($t \in \[\epsilon, 1\]$).
/// - Known poles and non-differentiable singularities via interval partitioning
///   ([poles]).
/// - Convergence error diagnostics and handling via [IntegrateWarning],
///   [IntegrateError], and [onWarning].
///
/// ```dart
/// final area = integrate((x) => x * x, 0.0, 3.0); // 9.0
/// final improper =
///     integrate((x) => math.exp(-x), 0.0, double.infinity); // 1.0
/// ```
double integrate(
  double Function(double) function,
  double a,
  double b, {
  IntegrationMethod method = IntegrationMethod.gaussKronrod,
  double tolerance = 1e-9,
  int maxDepth = 25,
  Iterable<double> poles = const [],
  void Function(IntegrateWarning type, double x)? onWarning,
}) {
  if (a.isNaN) {
    throw ArgumentError.value(a, 'a', 'Invalid lower bound');
  }
  if (b.isNaN) {
    throw ArgumentError.value(b, 'b', 'Invalid upper bound');
  }
  if (a == b) return 0.0;
  if (a > b) {
    return -integrate(
      function,
      b,
      a,
      method: method,
      tolerance: tolerance,
      maxDepth: maxDepth,
      poles: poles,
      onWarning: onWarning,
    );
  }

  // Handle interior poles by interval decomposition
  if (poles.isNotEmpty) {
    return _integratePoles(
      function,
      a,
      b,
      method: method,
      tolerance: tolerance,
      maxDepth: maxDepth,
      poles: poles,
      onWarning: onWarning,
    );
  }

  // Handle infinite bounds
  if (a == double.negativeInfinity && b == double.infinity) {
    return integrate(
          function,
          a,
          0.0,
          method: method,
          tolerance: tolerance,
          maxDepth: maxDepth,
          onWarning: onWarning,
        ) +
        integrate(
          function,
          0.0,
          b,
          method: method,
          tolerance: tolerance,
          maxDepth: maxDepth,
          onWarning: onWarning,
        );
  } else if (a == double.negativeInfinity) {
    final eps = math.max(tolerance * 1e-3, 1e-10);
    return integrate(
      (t) => function(b - (1.0 - t) / t) / (t * t),
      eps,
      1.0,
      method: method,
      tolerance: tolerance,
      maxDepth: maxDepth,
      onWarning: onWarning,
    );
  } else if (b == double.infinity) {
    final eps = math.max(tolerance * 1e-3, 1e-10);
    return integrate(
      (t) => function(a + (1.0 - t) / t) / (t * t),
      eps,
      1.0,
      method: method,
      tolerance: tolerance,
      maxDepth: maxDepth,
      onWarning: onWarning,
    );
  }

  switch (method) {
    case IntegrationMethod.gaussKronrod:
      return _gaussKronrodStep(function, a, b, tolerance, maxDepth, onWarning);
    case IntegrationMethod.simpson:
      final mid = 0.5 * (a + b);
      final fa = function(a);
      final fb = function(b);
      final fMid = function(mid);
      final whole = (b - a) * (fa + 4.0 * fMid + fb) / 6.0;
      return _adaptiveSimpsonStep(
        function,
        a,
        b,
        fa,
        fb,
        fMid,
        whole,
        tolerance,
        maxDepth,
        onWarning,
      );
  }
}

double _integratePoles(
  double Function(double) function,
  double a,
  double b, {
  required IntegrationMethod method,
  required double tolerance,
  required int maxDepth,
  required Iterable<double> poles,
  required void Function(IntegrateWarning type, double x)? onWarning,
}) {
  final normalized = poles.where((p) => p >= a && p <= b).toSet().toList()
    ..sort();
  if (normalized.isEmpty) {
    return integrate(
      function,
      a,
      b,
      method: method,
      tolerance: tolerance,
      maxDepth: maxDepth,
      poles: const [],
      onWarning: onWarning,
    );
  }

  bool isSingular(double p) {
    try {
      final v = function(p);
      return v.isNaN || v.isInfinite;
    } catch (_) {
      return true;
    }
  }

  final poleBuffer = tolerance > 1e-6 ? 1e-6 : tolerance;
  final intervals = <({double lo, double hi})>[];
  for (final pole in normalized) {
    if (isSingular(pole)) {
      intervals.add((lo: pole - poleBuffer, hi: pole + poleBuffer));
    } else {
      intervals.add((lo: pole, hi: pole));
    }
  }

  final mergedIntervals = <({double lo, double hi})>[];
  var current = intervals[0];
  for (var i = 1; i < intervals.length; i++) {
    final next = intervals[i];
    if (next.lo <= current.hi) {
      current = (lo: current.lo, hi: math.max(current.hi, next.hi));
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
        method: method,
        tolerance: tolerance,
        maxDepth: maxDepth,
        poles: const [],
        onWarning: onWarning,
      );
    }
    last = math.max(last, interval.hi);
  }
  if (last < b) {
    result += integrate(
      function,
      last,
      b,
      method: method,
      tolerance: tolerance,
      maxDepth: maxDepth,
      poles: const [],
      onWarning: onWarning,
    );
  }
  return result;
}

double _adaptiveSimpsonStep(
  double Function(double) fn,
  double a,
  double b,
  double fa,
  double fb,
  double fMid,
  double whole,
  double tol,
  int depth,
  void Function(IntegrateWarning type, double x)? onWarning,
) {
  final mid = 0.5 * (a + b);
  final leftMid = 0.5 * (a + mid);
  final rightMid = 0.5 * (mid + b);
  final fd = fn(leftMid);
  final fe = fn(rightMid);

  final left = (mid - a) * (fa + 4.0 * fd + fMid) / 6.0;
  final right = (b - mid) * (fMid + 4.0 * fe + fb) / 6.0;
  final sum = left + right;
  final delta = sum - whole;

  if (sum.isNaN || delta.isNaN) {
    if (onWarning != null) {
      onWarning(IntegrateWarning.doesNotConverge, mid);
    } else {
      throw IntegrateError(IntegrateWarning.doesNotConverge, mid);
    }
    return sum;
  }

  if (delta.abs() <= 15.0 * tol) {
    return sum + delta / 15.0;
  }

  if (depth <= 0) {
    if (onWarning != null) {
      onWarning(IntegrateWarning.depthTooShallow, mid);
    } else {
      throw IntegrateError(IntegrateWarning.depthTooShallow, mid);
    }
    return sum + delta / 15.0;
  }

  return _adaptiveSimpsonStep(
        fn,
        a,
        mid,
        fa,
        fMid,
        fd,
        left,
        tol * 0.5,
        depth - 1,
        onWarning,
      ) +
      _adaptiveSimpsonStep(
        fn,
        mid,
        b,
        fMid,
        fb,
        fe,
        right,
        tol * 0.5,
        depth - 1,
        onWarning,
      );
}

// Gauss-Kronrod 15-point rule abscissae and weights on [-1, 1]
const _gk15Nodes = [
  0.0,
  0.2077849550078985,
  0.4058451513773972,
  0.5860872354676911,
  0.7415311855993944,
  0.8648644233597691,
  0.9491079123427585,
  0.9914553711208126,
];

const _gk15WeightsKronrod = [
  0.2094821410847278,
  0.2044329400752989,
  0.1903505780647854,
  0.1690047266392680,
  0.1406532597155259,
  0.1047900103222502,
  0.0630920926299786,
  0.0229353220105292,
];

// 7-point Gauss weights (corresponding to indices 1, 3, 5, 7 of positive nodes)
const _gk7WeightsGauss = [
  0.4179591836734694, // node at 0.0
  0.3818300505051189, // node at 0.4058451513773972 (index 2)
  0.2797053914892767, // node at 0.7415311855993944 (index 4)
  0.1294849661688697, // node at 0.9491079123427585 (index 6)
];

double _gaussKronrodStep(
  double Function(double) fn,
  double a,
  double b,
  double tol,
  int depth,
  void Function(IntegrateWarning type, double x)? onWarning,
) {
  final center = 0.5 * (a + b);
  final halfWidth = 0.5 * (b - a);

  final fCenter = fn(center);
  var kronrodSum = _gk15WeightsKronrod[0] * fCenter;
  var gaussSum = _gk7WeightsGauss[0] * fCenter;

  for (var i = 1; i < 8; i++) {
    final xNode = halfWidth * _gk15Nodes[i];
    final f1 = fn(center - xNode);
    final f2 = fn(center + xNode);
    final fSum = f1 + f2;

    kronrodSum += _gk15WeightsKronrod[i] * fSum;

    if (i == 2) {
      gaussSum += _gk7WeightsGauss[1] * fSum;
    } else if (i == 4) {
      gaussSum += _gk7WeightsGauss[2] * fSum;
    } else if (i == 6) {
      gaussSum += _gk7WeightsGauss[3] * fSum;
    }
  }

  final kronrodResult = halfWidth * kronrodSum;
  final gaussResult = halfWidth * gaussSum;
  final error = (kronrodResult - gaussResult).abs();

  if (error.isNaN || kronrodResult.isNaN) {
    if (onWarning != null) {
      onWarning(IntegrateWarning.doesNotConverge, center);
    } else {
      throw IntegrateError(IntegrateWarning.doesNotConverge, center);
    }
    return kronrodResult;
  }

  if (error <= tol) {
    return kronrodResult;
  }

  if (depth <= 0) {
    if (onWarning != null) {
      onWarning(IntegrateWarning.depthTooShallow, center);
    } else {
      throw IntegrateError(IntegrateWarning.depthTooShallow, center);
    }
    return kronrodResult;
  }

  return _gaussKronrodStep(fn, a, center, tol * 0.5, depth - 1, onWarning) +
      _gaussKronrodStep(fn, center, b, tol * 0.5, depth - 1, onWarning);
}
