import '../../symbolic.dart';

/// Numerical integration via adaptive quadrature.

/// Computes the definite integral $\int_a^b f(x) dx$ using Adaptive Simpson's quadrature.
///
/// Accepts either a scalar closure `double Function(double)` or an [Expr].
double adaptiveSimpson(
  Object function,
  double a,
  double b, {
  String variable = 'x',
  double tolerance = 1e-9,
  int maxDepth = 25,
}) {
  final double Function(double) fn;
  if (function is Expr) {
    fn = (x) => function.evaluate({variable: x});
  } else if (function is double Function(double)) {
    fn = function;
  } else if (function is num Function(num)) {
    fn = (x) => function(x).toDouble();
  } else {
    throw ArgumentError('Unsupported function type: ${function.runtimeType}');
  }

  if (a == b) return 0.0;
  if (a > b) {
    return -adaptiveSimpson(
      function,
      b,
      a,
      variable: variable,
      tolerance: tolerance,
      maxDepth: maxDepth,
    );
  }

  final mid = 0.5 * (a + b);
  final fa = fn(a);
  final fb = fn(b);
  final fMid = fn(mid);
  final whole = (b - a) * (fa + 4.0 * fMid + fb) / 6.0;

  return _adaptiveSimpsonStep(
    fn,
    a,
    b,
    fa,
    fb,
    fMid,
    whole,
    tolerance,
    maxDepth,
  );
}

/// Computes the definite integral $\int_a^b f(x) dx$ using Adaptive Gauss-Kronrod (GK15) quadrature.
double gaussKronrod(
  Object function,
  double a,
  double b, {
  String variable = 'x',
  double tolerance = 1e-9,
  int maxDepth = 25,
}) {
  final double Function(double) fn;
  if (function is Expr) {
    fn = (x) => function.evaluate({variable: x});
  } else if (function is double Function(double)) {
    fn = function;
  } else if (function is num Function(num)) {
    fn = (x) => function(x).toDouble();
  } else {
    throw ArgumentError('Unsupported function type: ${function.runtimeType}');
  }

  if (a == b) return 0.0;
  if (a > b) {
    return -gaussKronrod(
      function,
      b,
      a,
      variable: variable,
      tolerance: tolerance,
      maxDepth: maxDepth,
    );
  }

  return _gaussKronrodStep(fn, a, b, tolerance, maxDepth);
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

  if (depth <= 0 || delta.abs() <= 15.0 * tol) {
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
  0.1903505780147724,
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

    // Gauss rule uses nodes 2, 4, 6 (1-indexed: 2, 4, 6)
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

  if (depth <= 0 || error <= tol) {
    return kronrodResult;
  }

  return _gaussKronrodStep(fn, a, center, tol * 0.5, depth - 1) +
      _gaussKronrodStep(fn, center, b, tol * 0.5, depth - 1);
}
