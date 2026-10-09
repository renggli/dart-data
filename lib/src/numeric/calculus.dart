import '../../linear.dart';
import '../../symbolic.dart';
import '../../type.dart';

/// Univariate and multivariate numerical and symbolic calculus utilities.

/// Computes the first derivative of [f] at [x].
///
/// Accepts either a scalar closure `double Function(double)` or an [Expr].
double numericalDerivative(
  Object f,
  double x, {
  String variable = 'x',
  double h = 1e-5,
}) {
  if (f is Expr) {
    final deriv = f.diff(variable).simplify();
    return deriv.evaluate({variable: x});
  } else if (f is double Function(double)) {
    return (f(x + h) - f(x - h)) / (2.0 * h);
  } else if (f is num Function(num)) {
    return (f(x + h).toDouble() - f(x - h).toDouble()) / (2.0 * h);
  }
  throw ArgumentError('Unsupported function type: ${f.runtimeType}');
}

/// Computes the second derivative of [f] at [x].
double numericalSecondDerivative(
  Object f,
  double x, {
  String variable = 'x',
  double h = 1e-4,
}) {
  if (f is Expr) {
    final secondDeriv = f.diff(variable).diff(variable).simplify();
    return secondDeriv.evaluate({variable: x});
  } else if (f is double Function(double)) {
    return (f(x + h) - 2.0 * f(x) + f(x - h)) / (h * h);
  } else if (f is num Function(num)) {
    return (f(x + h).toDouble() - 2.0 * f(x).toDouble() + f(x - h).toDouble()) /
        (h * h);
  }
  throw ArgumentError('Unsupported function type: ${f.runtimeType}');
}

/// Computes the gradient vector $\nabla f(x)$ of multivariate function [f] at [point].
///
/// Accepts either a vector closure `double Function(Vector<double>)` or an [Expr].
Vector<double> numericalGradient(
  Object f,
  Vector<double> point, {
  List<String>? variables,
  double h = 1e-5,
}) {
  final n = point.length;
  if (f is Expr) {
    final vars = variables ?? (f.freeVariables.toList()..sort());
    if (vars.length != n) {
      throw ArgumentError(
        'Variable count (${vars.length}) must match point dimension ($n).',
      );
    }
    final ctx = <String, double>{for (var i = 0; i < n; i++) vars[i]: point[i]};
    final gradExprs = Calculus.gradient(f, vars);
    return Vector<double>.generate(
      n,
      (i) => gradExprs[i].evaluate(ctx),
      type: DataType.float64,
    );
  } else if (f is double Function(Vector<double>)) {
    return Vector<double>.generate(n, (i) {
      final xPlus = point.copy();
      final xMinus = point.copy();
      xPlus[i] += h;
      xMinus[i] -= h;
      return (f(xPlus) - f(xMinus)) / (2.0 * h);
    }, type: DataType.float64);
  }
  throw ArgumentError('Unsupported function type: ${f.runtimeType}');
}

/// Computes the Jacobian matrix $J_{i, j} = \frac{\partial f_i}{\partial x_j}$ of vector function [f] at [point].
Matrix<double> numericalJacobian(
  Object f,
  Vector<double> point, {
  List<String>? variables,
  double h = 1e-5,
}) {
  final n = point.length;
  if (f is List<Expr>) {
    final vars =
        variables ??
        ({for (final expr in f) ...expr.freeVariables}.toList()..sort());
    if (vars.length != n) {
      throw ArgumentError(
        'Variable count (${vars.length}) must match point dimension ($n).',
      );
    }
    final ctx = <String, double>{for (var i = 0; i < n; i++) vars[i]: point[i]};
    final jacExprs = Calculus.jacobian(f, vars);
    return Matrix<double>.generate(
      f.length,
      n,
      (r, c) => jacExprs[r][c].evaluate(ctx),
      type: DataType.float64,
    );
  } else if (f is Vector<double> Function(Vector<double>)) {
    final f0 = f(point);
    final m = f0.length;
    return Matrix<double>.generate(m, n, (r, c) {
      final xPlus = point.copy();
      final xMinus = point.copy();
      xPlus[c] += h;
      xMinus[c] -= h;
      final fPlus = f(xPlus);
      final fMinus = f(xMinus);
      return (fPlus[r] - fMinus[r]) / (2.0 * h);
    }, type: DataType.float64);
  }
  throw ArgumentError('Unsupported function type: ${f.runtimeType}');
}

/// Computes the Hessian matrix $H_{i, j} = \frac{\partial^2 f}{\partial x_i \partial x_j}$ of [f] at [point].
Matrix<double> numericalHessian(
  Object f,
  Vector<double> point, {
  List<String>? variables,
  double h = 1e-4,
}) {
  final n = point.length;
  if (f is Expr) {
    final vars = variables ?? (f.freeVariables.toList()..sort());
    if (vars.length != n) {
      throw ArgumentError(
        'Variable count (${vars.length}) must match point dimension ($n).',
      );
    }
    final ctx = <String, double>{for (var i = 0; i < n; i++) vars[i]: point[i]};
    final hessExprs = Calculus.hessian(f, vars);
    return Matrix<double>.generate(
      n,
      n,
      (r, c) => hessExprs[r][c].evaluate(ctx),
      type: DataType.float64,
    );
  } else if (f is double Function(Vector<double>)) {
    final f0 = f(point);
    return Matrix<double>.generate(n, n, (i, j) {
      if (i == j) {
        final xPlus = point.copy();
        final xMinus = point.copy();
        xPlus[i] += h;
        xMinus[i] -= h;
        return (f(xPlus) - 2.0 * f0 + f(xMinus)) / (h * h);
      } else {
        final xPP = point.copy();
        final xPM = point.copy();
        final xMP = point.copy();
        final xMM = point.copy();
        xPP[i] += h;
        xPP[j] += h;
        xPM[i] += h;
        xPM[j] -= h;
        xMP[i] -= h;
        xMP[j] += h;
        xMM[i] -= h;
        xMM[j] -= h;
        return (f(xPP) - f(xPM) - f(xMP) + f(xMM)) / (4.0 * h * h);
      }
    }, type: DataType.float64);
  }
  throw ArgumentError('Unsupported function type: ${f.runtimeType}');
}
