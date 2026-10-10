import '../../symbolic.dart';

/// 1D root-finding algorithms: Brent-Dekker, Newton-Raphson, and Bisection.

/// Finds a root of $f(x) = 0$ on bracket $[a, b]$ using Brent's method.
///
/// Guaranteed to converge as long as $f(a)$ and $f(b)$ have opposite signs.
/// Combines bisection, secant method, and inverse quadratic interpolation.
/// Accepts either `double Function(double)` or an [Expr].
double brentRoot(
  Object function,
  double a,
  double b, {
  String variable = 'x',
  double tolerance = 1e-12,
  int maxIterations = 100,
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

  var fa = fn(a);
  var fb = fn(b);

  if (fa.isNaN || fb.isNaN) return double.nan;
  if (fa * fb > 0.0) {
    throw ArgumentError(
      'Root is not bracketed: f($a) = $fa and f($b) = $fb have identical signs.',
    );
  }
  if (fa.abs() < tolerance) return a;
  if (fb.abs() < tolerance) return b;

  var xA = a;
  var xB = b;
  var xC = a;
  var fc = fa;
  var dStep = 0.0;
  var eStep = 0.0;

  for (var iter = 0; iter < maxIterations; iter++) {
    if ((fb > 0.0 && fc > 0.0) || (fb < 0.0 && fc < 0.0)) {
      xC = xA;
      fc = fa;
      dStep = xB - xA;
      eStep = dStep;
    }
    if (fc.abs() < fb.abs()) {
      xA = xB;
      xB = xC;
      xC = xA;
      fa = fb;
      fb = fc;
      fc = fa;
    }

    final tol1 = 2.0 * 2.220446049250313e-16 * xB.abs() + 0.5 * tolerance;
    final xm = 0.5 * (xC - xB);

    if (xm.abs() <= tol1 || fb == 0.0) {
      return xB;
    }

    if (eStep.abs() >= tol1 && fa.abs() > fb.abs()) {
      final ratioS = fb / fa;
      double pVal, qVal;
      if (xA == xC) {
        // Linear interpolation
        pVal = 2.0 * xm * ratioS;
        qVal = 1.0 - ratioS;
      } else {
        // Inverse quadratic interpolation
        qVal = fa / fc;
        final ratioR = fb / fc;
        pVal =
            ratioS *
            (2.0 * xm * qVal * (qVal - ratioR) - (xB - xA) * (ratioR - 1.0));
        qVal = (qVal - 1.0) * (ratioR - 1.0) * (ratioS - 1.0);
      }
      if (pVal > 0.0) qVal = -qVal;
      pVal = pVal.abs();
      final min1 = 3.0 * xm * qVal - (tol1 * qVal).abs();
      final min2 = (eStep * qVal).abs();
      if (2.0 * pVal < (min1 < min2 ? min1 : min2)) {
        eStep = dStep;
        dStep = pVal / qVal;
      } else {
        dStep = xm;
        eStep = dStep;
      }
    } else {
      dStep = xm;
      eStep = dStep;
    }

    xA = xB;
    fa = fb;
    if (dStep.abs() > tol1) {
      xB += dStep;
    } else {
      xB += xm >= 0.0 ? tol1 : -tol1;
    }
    fb = fn(xB);
  }

  return xB;
}

/// Finds a root of $f(x) = 0$ starting from [x0] using Newton-Raphson iteration.
double newtonRaphson(
  Object function,
  double x0, {
  Object? derivative,
  String variable = 'x',
  double tolerance = 1e-12,
  int maxIterations = 100,
}) {
  final double Function(double) fn;
  final double Function(double) dfn;

  if (function is Expr) {
    fn = (x) => function.evaluate({variable: x});
    final diffExpr = function.diff(variable).simplify();
    dfn = (x) => diffExpr.evaluate({variable: x});
  } else if (function is double Function(double)) {
    fn = function;
    if (derivative is double Function(double)) {
      dfn = derivative;
    } else {
      dfn = (x) {
        const step = 1e-6;
        return (function(x + step) - function(x - step)) / (2.0 * step);
      };
    }
  } else if (function is num Function(num)) {
    fn = (x) => function(x).toDouble();
    if (derivative is num Function(num)) {
      dfn = (x) => derivative(x).toDouble();
    } else {
      dfn = (x) {
        const step = 1e-6;
        return (function(x + step).toDouble() - function(x - step).toDouble()) /
            (2.0 * step);
      };
    }
  } else {
    throw ArgumentError('Unsupported function type: ${function.runtimeType}');
  }

  var x = x0;
  for (var i = 0; i < maxIterations; i++) {
    final fx = fn(x);
    if (fx.abs() < tolerance) return x;
    final dfx = dfn(x);
    if (dfx.abs() < 1e-15) {
      throw StateError('Derivative near zero at x = $x.');
    }
    final step = fx / dfx;
    x -= step;
    if (step.abs() < tolerance) return x;
  }
  return x;
}

/// Finds a root of $f(x) = 0$ on bracket $[a, b]$ using Bisection.
double bisection(
  Object function,
  double a,
  double b, {
  String variable = 'x',
  double tolerance = 1e-12,
  int maxIterations = 100,
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

  var fa = fn(a);
  var fb = fn(b);

  if (fa * fb > 0.0) {
    throw ArgumentError(
      'Root is not bracketed: f($a) and f($b) have identical signs.',
    );
  }

  var xA = a;
  var xB = b;
  for (var i = 0; i < maxIterations; i++) {
    final mid = 0.5 * (xA + xB);
    final fMid = fn(mid);
    if (fMid.abs() < tolerance || (xB - xA).abs() < tolerance) {
      return mid;
    }
    if (fa * fMid < 0.0) {
      xB = mid;
      fb = fMid;
    } else {
      xA = mid;
      fa = fMid;
    }
  }
  return 0.5 * (xA + xB);
}
