import '../../linear.dart';
import '../../symbolic.dart';
import '../../type.dart';

/// Univariate and multivariate numerical and symbolic calculus utilities.

/// Computes the first derivative of [function] at [x].
///
/// Conceptually, the derivative is the instantaneous slope or rate
/// of change of a curve at a single point (such as a speedometer reading representing the derivative of position).
/// Formally, it computes $f'(x)$ using analytical symbolic differentiation
/// for [Expr], or $\mathcal{O}(h^2)$ central finite differences $\frac{f(x+h) - f(x-h)}{2h}$
/// for numerical functions.
///
/// ```dart
/// final slope = numericalDerivative((x) => x * x, 3.0); // ~6.0
/// ```
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
  } else if (function is Function) {
    final f1 = ((function as dynamic)(x + step) as num).toDouble();
    final f2 = ((function as dynamic)(x - step) as num).toDouble();
    return (f1 - f2) / (2.0 * step);
  }
  throw ArgumentError('Unsupported function type: ${function.runtimeType}');
}

/// Computes the second derivative of [function] at [x].
///
/// Conceptually, the second derivative measures how rapidly the slope itself
/// is changing, indicating whether a curve bends upwards or downwards (acceleration or curvature).
/// Formally, it computes $f''(x)$ using analytical derivation for [Expr],
/// or $\mathcal{O}(h^2)$ central second differences $\frac{f(x+h) - 2f(x) + f(x-h)}{h^2}$.
///
/// ```dart
/// final curvature = numericalSecondDerivative((x) => x * x * x, 2.0); // ~12.0
/// ```
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
  } else if (function is Function) {
    final fPlus = ((function as dynamic)(x + step) as num).toDouble();
    final f0 = ((function as dynamic)(x) as num).toDouble();
    final fMinus = ((function as dynamic)(x - step) as num).toDouble();
    return (fPlus - 2.0 * f0 + fMinus) / (step * step);
  }
  throw ArgumentError('Unsupported function type: ${function.runtimeType}');
}

/// Computes the gradient vector $\nabla f(x)$ of multivariate function [function] at [point].
///
/// Conceptually, the gradient is a vector pointing in the direction of
/// steepest ascent on a multivariate surface, with its Euclidean norm representing the steepness.
/// Formally, it computes $\nabla f(\mathbf{x}) = \left(\frac{\partial f}{\partial x_1}, \dots, \frac{\partial f}{\partial x_n}\right)^T$
/// via exact symbolic derivation or coordinate-wise central finite differences.
///
/// ```dart
/// final p = Vector<double>.fromList([1.0, 2.0]);
/// final grad = numericalGradient((v) => v[0] * v[0] + v[1] * v[1], p);
/// // grad: Vector([2.0, 4.0])
/// ```
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
    final gradExprs = function.gradient(vars);
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
  } else if (function is Function) {
    return Vector<double>.generate(dim, (i) {
      final xPlus = point.copy();
      final xMinus = point.copy();
      xPlus[i] += step;
      xMinus[i] -= step;
      final fPlus = ((function as dynamic)(xPlus) as num).toDouble();
      final fMinus = ((function as dynamic)(xMinus) as num).toDouble();
      return (fPlus - fMinus) / (2.0 * step);
    }, type: DataType.float64);
  }
  throw ArgumentError('Unsupported function type: ${function.runtimeType}');
}

/// Computes the Jacobian matrix $J_{i, j} = \frac{\partial f_i}{\partial x_j}$ of vector function [function] at [point].
///
/// Conceptually, the Jacobian is a matrix of partial slopes describing how a multi-output
/// vector field distorts, rotates, or shears coordinate space near a point.
/// Formally, it computes the best local linear affine approximation
/// $D\mathbf{f}(\mathbf{x}) \in \mathbb{R}^{m \times n}$ where $J_{i, j} = \frac{\partial f_i}{\partial x_j}$.
///
/// ```dart
/// final p = Vector<double>.fromList([1.0, 2.0]);
/// final jac = numericalJacobian(
///   (v) => Vector<double>.fromList([v[0] + v[1], v[0] * v[1]]),
///   p,
/// );
/// ```
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
    final jacExprs = function.jacobian(vars);
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
  } else if (function is Function) {
    final f0 = (function as dynamic)(point) as Vector<double>;
    final numFuncs = f0.length;
    return Matrix<double>.generate(numFuncs, dim, (row, col) {
      final xPlus = point.copy();
      final xMinus = point.copy();
      xPlus[col] += step;
      xMinus[col] -= step;
      final fPlus = (function as dynamic)(xPlus) as Vector<double>;
      final fMinus = (function as dynamic)(xMinus) as Vector<double>;
      return (fPlus[row] - fMinus[row]) / (2.0 * step);
    }, type: DataType.float64);
  }
  throw ArgumentError('Unsupported function type: ${function.runtimeType}');
}

/// Computes the Hessian matrix $H_{i, j} = \frac{\partial^2 f}{\partial x_i \partial x_j}$ of [function] at [point].
///
/// Conceptually, the Hessian describes the local curvature of a multivariate surface,
/// determining whether a critical point is a local minimum (bowl), local maximum (dome), or saddle pass.
/// Formally, it computes the symmetric second partial derivative matrix
/// $H \in \mathbb{R}^{n \times n}$ whose eigenvalues characterize surface curvature and local extrema.
///
/// ```dart
/// final p = Vector<double>.fromList([1.0, 2.0]);
/// final hess = numericalHessian((v) => v[0] * v[0] + v[1] * v[1], p);
/// ```
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
    final hessExprs = function.hessian(vars);
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
  } else if (function is Function) {
    final f0 = ((function as dynamic)(point) as num).toDouble();
    return Matrix<double>.generate(dim, dim, (i, j) {
      if (i == j) {
        final xPlus = point.copy();
        final xMinus = point.copy();
        xPlus[i] += step;
        xMinus[i] -= step;
        final fPlus = ((function as dynamic)(xPlus) as num).toDouble();
        final fMinus = ((function as dynamic)(xMinus) as num).toDouble();
        return (fPlus - 2.0 * f0 + fMinus) / (step * step);
      } else {
        final xPP = point.copy();
        final xPM = point.copy();
        final xMP = point.copy();
        final xMM = point.copy();
        xPP[i] += step;
        xPP[j] += step;
        xPM[i] += step;
        xPM[j] -= step;
        xMP[i] += step;
        xMP[j] += step;
        xMM[i] -= step;
        xMM[j] -= step;
        final fPP = ((function as dynamic)(xPP) as num).toDouble();
        final fPM = ((function as dynamic)(xPM) as num).toDouble();
        final fMP = ((function as dynamic)(xMP) as num).toDouble();
        final fMM = ((function as dynamic)(xMM) as num).toDouble();
        return (fPP - fPM - fMP + fMM) / (4.0 * step * step);
      }
    }, type: DataType.float64);
  }
  throw ArgumentError('Unsupported function type: ${function.runtimeType}');
}
