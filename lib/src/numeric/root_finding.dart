import '../../symbolic.dart';

/// 1D root-finding algorithms: Brent-Dekker, Newton-Raphson, and Bisection.

/// Finds a root of $f(x) = 0$ on bracket $[a, b]$ using Brent's method.
///
/// Guaranteed to converge as long as $f(a)$ and $f(b)$ have opposite signs.
/// Combines bisection, secant method, and inverse quadratic interpolation.
/// Accepts either `double Function(double)` or an [Expr].
double brentRoot(
  Object f,
  double a,
  double b, {
  String variable = 'x',
  double tolerance = 1e-12,
  int maxIterations = 100,
}) {
  final double Function(double) fn;
  if (f is Expr) {
    fn = (x) => f.evaluate({variable: x});
  } else if (f is double Function(double)) {
    fn = f;
  } else if (f is num Function(num)) {
    fn = (x) => f(x).toDouble();
  } else {
    throw ArgumentError('Unsupported function type: ${f.runtimeType}');
  }

  var fa = fn(a);
  var fb = fn(b);

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
  var d = 0.0;
  var e = 0.0;

  for (var iter = 0; iter < maxIterations; iter++) {
    if ((fb > 0.0 && fc > 0.0) || (fb < 0.0 && fc < 0.0)) {
      xC = xA;
      fc = fa;
      d = xB - xA;
      e = d;
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

    if (e.abs() >= tol1 && fa.abs() > fb.abs()) {
      final s = fb / fa;
      double p, q;
      if (xA == xC) {
        // Linear interpolation
        p = 2.0 * xm * s;
        q = 1.0 - s;
      } else {
        // Inverse quadratic interpolation
        q = fa / fc;
        final r = fb / fc;
        p = s * (2.0 * xm * q * (q - r) - (xB - xA) * (r - 1.0));
        q = (q - 1.0) * (r - 1.0) * (s - 1.0);
      }
      if (p > 0.0) q = -q;
      p = p.abs();
      final min1 = 3.0 * xm * q - (tol1 * q).abs();
      final min2 = (e * q).abs();
      if (2.0 * p < (min1 < min2 ? min1 : min2)) {
        e = d;
        d = p / q;
      } else {
        d = xm;
        e = d;
      }
    } else {
      d = xm;
      e = d;
    }

    xA = xB;
    fa = fb;
    if (d.abs() > tol1) {
      xB += d;
    } else {
      xB += xm >= 0.0 ? tol1 : -tol1;
    }
    fb = fn(xB);
  }

  return xB;
}

/// Finds a root of $f(x) = 0$ starting from [x0] using Newton-Raphson iteration.
double newtonRaphson(
  Object f,
  double x0, {
  Object? derivative,
  String variable = 'x',
  double tolerance = 1e-12,
  int maxIterations = 100,
}) {
  final double Function(double) fn;
  final double Function(double) dfn;

  if (f is Expr) {
    fn = (x) => f.evaluate({variable: x});
    final diffExpr = f.diff(variable).simplify();
    dfn = (x) => diffExpr.evaluate({variable: x});
  } else if (f is double Function(double)) {
    fn = f;
    if (derivative is double Function(double)) {
      dfn = derivative;
    } else {
      dfn = (x) {
        const h = 1e-6;
        return (f(x + h) - f(x - h)) / (2.0 * h);
      };
    }
  } else {
    throw ArgumentError('Unsupported function type: ${f.runtimeType}');
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
  Object f,
  double a,
  double b, {
  String variable = 'x',
  double tolerance = 1e-12,
  int maxIterations = 100,
}) {
  final double Function(double) fn;
  if (f is Expr) {
    fn = (x) => f.evaluate({variable: x});
  } else if (f is double Function(double)) {
    fn = f;
  } else if (f is num Function(num)) {
    fn = (x) => f(x).toDouble();
  } else {
    throw ArgumentError('Unsupported function type: ${f.runtimeType}');
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
