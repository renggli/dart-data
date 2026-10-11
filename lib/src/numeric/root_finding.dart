import '../../linear.dart';

/// Method used for numerical root-finding.
enum RootMethod {
  /// Brent-Dekker hybrid method combining inverse quadratic interpolation,
  /// secant steps, and bisection safeguards. Requires bracketed interval
  /// `[a, b]`.
  brent,

  /// Newton-Raphson method with quadratic convergence using analytical or
  /// finite-difference derivative. Starts from initial point `a`.
  newtonRaphson,

  /// Bisection method guaranteeing linear convergence. Requires bracketed
  /// interval `[a, b]`.
  bisection,
}

/// Finds a root of $f(x) = 0$ using the specified [method].
///
/// Conceptually, finding a root identifies where a continuous curve crosses the
/// horizontal axis ($f(x) = 0$), solving the non-linear equation for $x$.
/// Formally, it executes the chosen [method] ([RootMethod.brent] by default
/// when [b] is provided, [RootMethod.newtonRaphson] when only [a] is provided,
/// or [RootMethod.bisection]).
///
/// For bracketed methods ([RootMethod.brent] and [RootMethod.bisection]), both
/// [a] and [b] are required and must satisfy $f(a) \cdot f(b) \le 0$. For open
/// methods ([RootMethod.newtonRaphson]), [a] serves as the initial guess $x_0$,
/// and [b] is ignored.
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
  final resolvedMethod =
      method ?? (b != null ? RootMethod.brent : RootMethod.newtonRaphson);
  switch (resolvedMethod) {
    case RootMethod.brent:
      if (b == null) {
        throw ArgumentError(
          'RootMethod.brent requires both interval bounds a and b.',
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
      if (b == null) {
        throw ArgumentError(
          'RootMethod.bisection requires both interval bounds a and b.',
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

/// Solves a system of equations $F(\mathbf{x}) = \mathbf{0}$ using multivariate
/// Newton-Raphson iteration.
///
/// Conceptually, this finds coordinates where multiple equations simultaneously
/// equal zero. Formally, starting from [initialGuess] $\mathbf{x}_0$, it
/// iteratively updates:
/// $$\mathbf{x}_{k+1} = \mathbf{x}_k - J_F(\mathbf{x}_k)^{-1} F(\mathbf{x}_k)$$
/// where $J_F(\mathbf{x}_k)$ is the Jacobian matrix computed either via
/// [jacobian] or central finite differences.
///
/// ```dart
/// final sol = solveSystem([
///   (v) => v[0] + v[1] - 10,
///   (v) => v[0] - v[1] - 2,
/// ], Vector.fromList([0.0, 0.0]));
/// // sol: [6.0, 4.0]
/// ```
Vector<double> solveSystem(
  List<double Function(Vector<double>)> equations,
  Vector<double> initialGuess, {
  Matrix<double> Function(Vector<double>)? jacobian,
  double tolerance = 1e-10,
  int maxIterations = 100,
  double step = 1e-5,
}) {
  final n = initialGuess.length;
  if (equations.length != n) {
    throw ArgumentError(
      'Number of equations (${equations.length}) must match dimension of initialGuess ($n).',
    );
  }
  final x = initialGuess.copy();
  for (var iter = 0; iter < maxIterations; iter++) {
    final residual = Vector<double>.generate(n, (i) => equations[i](x));
    var maxRes = 0.0;
    for (var i = 0; i < n; i++) {
      final r = residual[i].abs();
      if (r > maxRes) maxRes = r;
    }
    if (maxRes <= tolerance) {
      return x;
    }

    final jac = jacobian != null
        ? jacobian(x)
        : Matrix<double>.generate(n, n, (row, col) {
            final xPlus = x.copy();
            final xMinus = x.copy();
            xPlus[col] += step;
            xMinus[col] -= step;
            return (equations[row](xPlus) - equations[row](xMinus)) /
                (2.0 * step);
          });

    Vector<double> delta;
    try {
      delta = jac.solve(residual);
    } on Object catch (e) {
      throw StateError(
        'Failed to converge: Jacobian is singular or step failed ($e).',
      );
    }
    for (var i = 0; i < n; i++) {
      x[i] -= delta[i];
    }
  }
  final finalResidual = Vector<double>.generate(n, (i) => equations[i](x));
  var maxRes = 0.0;
  for (var i = 0; i < n; i++) {
    final r = finalResidual[i].abs();
    if (r > maxRes) maxRes = r;
  }
  if (maxRes <= tolerance) {
    return x;
  }
  throw StateError(
    'solveSystem failed to converge within $maxIterations iterations.',
  );
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
  final dfn =
      derivative ??
      (double x) {
        const step = 1e-6;
        return (fn(x + step) - fn(x - step)) / (2.0 * step);
      };

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

double _bisection(
  double Function(double) fn,
  double a,
  double b, {
  required double tolerance,
  required int maxIterations,
}) {
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
