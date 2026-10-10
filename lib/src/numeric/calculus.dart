import '../../linear.dart';
import '../../symbolic.dart';
import '../../type.dart';

/// Univariate and multivariate numerical and symbolic calculus utilities.

/// Computes the first derivative of [function] at [x].
///
/// Accepts either a scalar closure `double Function(double)` or an [Expr].
double numericalDerivative(
  Object function,
  double x, {
  String variable = 'x',
  double step = 1e-5,
}) {
  if (function is Expr) {
    final deriv = function.diff(variable).simplify();
    return deriv.evaluate({variable: x});
  } else if (function is double Function(double)) {
    return (function(x + step) - function(x - step)) / (2.0 * step);
  } else if (function is num Function(num)) {
    return (function(x + step).toDouble() - function(x - step).toDouble()) /
        (2.0 * step);
  }
  throw ArgumentError('Unsupported function type: ${function.runtimeType}');
}

/// Computes the second derivative of [function] at [x].
double numericalSecondDerivative(
  Object function,
  double x, {
  String variable = 'x',
  double step = 1e-4,
}) {
  if (function is Expr) {
    final secondDeriv = function.diff(variable).diff(variable).simplify();
    return secondDeriv.evaluate({variable: x});
  } else if (function is double Function(double)) {
    return (function(x + step) - 2.0 * function(x) + function(x - step)) /
        (step * step);
  } else if (function is num Function(num)) {
    return (function(x + step).toDouble() -
            2.0 * function(x).toDouble() +
            function(x - step).toDouble()) /
        (step * step);
  }
  throw ArgumentError('Unsupported function type: ${function.runtimeType}');
}

/// Computes the gradient vector $\nabla f(x)$ of multivariate function [function] at [point].
///
/// Accepts either a vector closure `double Function(Vector<double>)` or an [Expr].
Vector<double> numericalGradient(
  Object function,
  Vector<double> point, {
  List<String>? variables,
  double step = 1e-5,
}) {
  final dim = point.length;
  if (function is Expr) {
    final vars = variables ?? (function.freeVariables.toList()..sort());
    if (vars.length != dim) {
      throw ArgumentError(
        'Variable count (${vars.length}) must match point dimension ($dim).',
      );
    }
    final ctx = <String, double>{
      for (var i = 0; i < dim; i++) vars[i]: point[i],
    };
    final gradExprs = Calculus.gradient(function, vars);
    return Vector<double>.generate(
      dim,
      (i) => gradExprs[i].evaluate(ctx),
      type: DataType.float64,
    );
  } else if (function is double Function(Vector<double>)) {
    return Vector<double>.generate(dim, (i) {
      final xPlus = point.copy();
      final xMinus = point.copy();
      xPlus[i] += step;
      xMinus[i] -= step;
      return (function(xPlus) - function(xMinus)) / (2.0 * step);
    }, type: DataType.float64);
  }
  throw ArgumentError('Unsupported function type: ${function.runtimeType}');
}

/// Computes the Jacobian matrix $J_{i, j} = \frac{\partial f_i}{\partial x_j}$ of vector function [function] at [point].
Matrix<double> numericalJacobian(
  Object function,
  Vector<double> point, {
  List<String>? variables,
  double step = 1e-5,
}) {
  final dim = point.length;
  if (function is List<Expr>) {
    final vars =
        variables ??
        ({for (final expr in function) ...expr.freeVariables}.toList()..sort());
    if (vars.length != dim) {
      throw ArgumentError(
        'Variable count (${vars.length}) must match point dimension ($dim).',
      );
    }
    final ctx = <String, double>{
      for (var i = 0; i < dim; i++) vars[i]: point[i],
    };
    final jacExprs = Calculus.jacobian(function, vars);
    return Matrix<double>.generate(
      function.length,
      dim,
      (row, col) => jacExprs[row][col].evaluate(ctx),
      type: DataType.float64,
    );
  } else if (function is Vector<double> Function(Vector<double>)) {
    final f0 = function(point);
    final numFuncs = f0.length;
    return Matrix<double>.generate(numFuncs, dim, (row, col) {
      final xPlus = point.copy();
      final xMinus = point.copy();
      xPlus[col] += step;
      xMinus[col] -= step;
      final fPlus = function(xPlus);
      final fMinus = function(xMinus);
      return (fPlus[row] - fMinus[row]) / (2.0 * step);
    }, type: DataType.float64);
  }
  throw ArgumentError('Unsupported function type: ${function.runtimeType}');
}

/// Computes the Hessian matrix $H_{i, j} = \frac{\partial^2 f}{\partial x_i \partial x_j}$ of [function] at [point].
Matrix<double> numericalHessian(
  Object function,
  Vector<double> point, {
  List<String>? variables,
  double step = 1e-4,
}) {
  final dim = point.length;
  if (function is Expr) {
    final vars = variables ?? (function.freeVariables.toList()..sort());
    if (vars.length != dim) {
      throw ArgumentError(
        'Variable count (${vars.length}) must match point dimension ($dim).',
      );
    }
    final ctx = <String, double>{
      for (var i = 0; i < dim; i++) vars[i]: point[i],
    };
    final hessExprs = Calculus.hessian(function, vars);
    return Matrix<double>.generate(
      dim,
      dim,
      (row, col) => hessExprs[row][col].evaluate(ctx),
      type: DataType.float64,
    );
  } else if (function is double Function(Vector<double>)) {
    final f0 = function(point);
    return Matrix<double>.generate(dim, dim, (i, j) {
      if (i == j) {
        final xPlus = point.copy();
        final xMinus = point.copy();
        xPlus[i] += step;
        xMinus[i] -= step;
        return (function(xPlus) - 2.0 * f0 + function(xMinus)) / (step * step);
      } else {
        final xPP = point.copy();
        final xPM = point.copy();
        final xMP = point.copy();
        final xMM = point.copy();
        xPP[i] += step;
        xPP[j] += step;
        xPM[i] += step;
        xPM[j] -= step;
        xMP[i] -= step;
        xMP[j] += step;
        xMM[i] -= step;
        xMM[j] -= step;
        return (function(xPP) - function(xPM) - function(xMP) + function(xMM)) /
            (4.0 * step * step);
      }
    }, type: DataType.float64);
  }
  throw ArgumentError('Unsupported function type: ${function.runtimeType}');
}
