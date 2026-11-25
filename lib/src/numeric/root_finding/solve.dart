import 'dart:math' as math;

import '../calculus/derivative.dart' as calculus;
import 'root_method.dart';

/// Finds a root of `f(x) = 0` using the specified [method].
///
/// Conceptually, finding a root identifies where a continuous curve crosses the
/// horizontal axis (`f(x) = 0`), solving the non-linear equation for `x`.
/// Formally, it executes the chosen [method] ([RootMethod.brent] by default
/// when [b] is provided, [RootMethod.newtonRaphson] when only [a] is provided,
/// or [RootMethod.bisection]).
///
/// For bracketed methods ([RootMethod.brent] and [RootMethod.bisection]), both
/// [a] and [b] are required, must be finite, and must satisfy `f(a) * f(b) ≤ 0`.
/// For open methods ([RootMethod.newtonRaphson]), [a] serves as the finite
/// initial guess `x₀`, and [b] is ignored.
///
/// ```dart
/// final root = solve((x) => x * x - 4.0, 0.0, b: 5.0); // 2.0
/// ```
double solve(
  double Function(double) function,
  double a, {
  double? b,
  RootMethod? method,
  double tolerance = 1e-12,
  int maxIterations = 100,
  double Function(double)? derivative,
}) {
  if (!a.isFinite) {
    throw ArgumentError.value(a, 'a', 'Initial point or bound must be finite.');
  }
  if (tolerance <= 0 || !tolerance.isFinite) {
    throw ArgumentError.value(
      tolerance,
      'tolerance',
      'Tolerance must be positive and finite.',
    );
  }
  if (maxIterations <= 0) {
    throw ArgumentError.value(
      maxIterations,
      'maxIterations',
      'Max iterations must be positive.',
    );
  }
  final resolvedMethod =
      method ?? (b != null ? RootMethod.brent : RootMethod.newtonRaphson);
  switch (resolvedMethod) {
    case RootMethod.brent:
      if (b == null || !b.isFinite) {
        throw ArgumentError.value(
          b,
          'b',
          'RootMethod.brent requires finite interval bounds a and b.',
        );
      }
      return _brent(
        function,
        a,
        b,
        tolerance: tolerance,
        maxIterations: maxIterations,
      );
    case RootMethod.bisection:
      if (b == null || !b.isFinite) {
        throw ArgumentError.value(
          b,
          'b',
          'RootMethod.bisection requires finite interval bounds a and b.',
        );
      }
      return _bisection(
        function,
        a,
        b,
        tolerance: tolerance,
        maxIterations: maxIterations,
      );
    case RootMethod.newtonRaphson:
      return _newtonRaphson(
        function,
        a,
        derivative: derivative,
        tolerance: tolerance,
        maxIterations: maxIterations,
      );
  }
}

double _brent(
  double Function(double) fn,
  double a,
  double b, {
  required double tolerance,
  required int maxIterations,
}) {
  var fa = fn(a);
  var fb = fn(b);

  if (fa.isNaN || fb.isNaN) return double.nan;
  if (_sameSign(fa, fb)) {
    throw ArgumentError(
      'Root is not bracketed: f($a) = $fa and f($b) = $fb have identical signs.',
    );
  }
  if (fa == 0.0) return a;
  if (fb == 0.0) return b;

  var xA = a;
  var xB = b;
  var xC = a;
  var fc = fa;
  var dStep = 0.0;
  var eStep = 0.0;

  for (var iter = 0; iter < maxIterations; iter++) {
    if (_sameSign(fb, fc)) {
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
        pVal = 2.0 * xm * ratioS;
        qVal = 1.0 - ratioS;
      } else {
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
    if (fb.isNaN) return double.nan;
  }

  return xB;
}

double _newtonRaphson(
  double Function(double) fn,
  double x0, {
  double Function(double)? derivative,
  required double tolerance,
  required int maxIterations,
}) {
  final dfn = derivative ?? (double x) => calculus.derivative(fn, x);

  var x = x0;
  for (var i = 0; i < maxIterations; i++) {
    final fx = fn(x);
    if (!fx.isFinite) {
      throw StateError(
        'Function evaluation returned non-finite value at x = $x.',
      );
    }
    if (fx == 0.0) return x;
    final dfx = dfn(x);
    if (!dfx.isFinite) {
      throw StateError('Derivative returned non-finite value at x = $x.');
    }
    if (dfx == 0.0) {
      if (fx.abs() < tolerance) return x;
      throw StateError('Derivative is zero at x = $x.');
    }
    final step = fx / dfx;
    if (!step.isFinite) {
      if (fx.abs() < tolerance) return x;
      throw StateError('Newton step overflowed near x = $x.');
    }
    x -= step;
    if (!x.isFinite) {
      throw StateError('Newton iterate became non-finite.');
    }
    if (step.abs() <= tolerance * math.max(1.0, x.abs())) {
      final newFx = fn(x);
      if (newFx.isFinite && newFx.abs() <= math.max(tolerance, 1e-6)) {
        return x;
      }
    }
  }
  final finalFx = fn(x);
  if (finalFx.isFinite && (finalFx == 0.0 || finalFx.abs() <= tolerance)) {
    return x;
  }
  throw StateError(
    'Newton-Raphson failed to converge after $maxIterations iterations.',
  );
}

double _bisection(
  double Function(double) fn,
  double a,
  double b, {
  required double tolerance,
  required int maxIterations,
}) {
  var fa = fn(a);
  var fb = fn(b);

  if (fa.isNaN || fb.isNaN) return double.nan;
  if (_sameSign(fa, fb)) {
    throw ArgumentError(
      'Root is not bracketed: f($a) = $fa and f($b) = $fb have identical signs.',
    );
  }
  if (fa == 0.0) return a;
  if (fb == 0.0) return b;

  var xA = a;
  var xB = b;
  for (var i = 0; i < maxIterations; i++) {
    final halfSpan = 0.5 * (xB - xA);
    final mid = xA + halfSpan;
    final fMid = fn(mid);
    if (fMid.isNaN) return double.nan;
    if (fMid == 0.0 || halfSpan.abs() <= tolerance || mid == xA || mid == xB) {
      return mid;
    }
    if (_oppositeSign(fa, fMid)) {
      xB = mid;
      fb = fMid;
    } else {
      xA = mid;
      fa = fMid;
    }
  }
  return xA + 0.5 * (xB - xA);
}

bool _sameSign(double a, double b) =>
    (a > 0.0 && b > 0.0) || (a < 0.0 && b < 0.0);

bool _oppositeSign(double a, double b) =>
    (a < 0.0 && b > 0.0) || (a > 0.0 && b < 0.0);
