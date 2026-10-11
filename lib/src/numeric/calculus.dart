import '../../linear.dart';
import '../../type.dart';

/// Univariate and multivariate numerical calculus utilities.

/// Computes the derivative of [function] at [x].
///
/// Conceptually, the derivative is the instantaneous slope or rate
/// of change of a curve at a single point (such as a speedometer reading representing the derivative of position).
/// Formally, it computes the $n$-th derivative $f^{(n)}(x)$ using central finite
/// differences for the specified [order] (1 or 2) and [accuracy] order.
///
/// ```dart
/// final slope = derivative((x) => x * x, 3.0); // ~6.0
/// final curvature = derivative((x) => x * x * x, 2.0, order: 2); // ~12.0
/// ```
double derivative(
  double Function(double) function,
  double x, {
  int order = 1,
  int accuracy = 2,
  double step = 1e-5,
}) {
  if (order == 1) {
    if (accuracy >= 4) {
      return (-function(x + 2.0 * step) +
              8.0 * function(x + step) -
              8.0 * function(x - step) +
              function(x - 2.0 * step)) /
          (12.0 * step);
    }
    return (function(x + step) - function(x - step)) / (2.0 * step);
  } else if (order == 2) {
    if (accuracy >= 4) {
      return (-function(x + 2.0 * step) +
              16.0 * function(x + step) -
              30.0 * function(x) +
              16.0 * function(x - step) -
              function(x - 2.0 * step)) /
          (12.0 * step * step);
    }
    return (function(x + step) - 2.0 * function(x) + function(x - step)) /
        (step * step);
  }
  throw ArgumentError('Unsupported derivative order: $order (must be 1 or 2)');
}

/// Computes the gradient vector $\nabla f(\mathbf{x})$ of multivariate function [function] at [point].
///
/// Conceptually, the gradient is a vector pointing in the direction of
/// steepest ascent on a multivariate surface, with its Euclidean norm representing the steepness.
/// Formally, it computes $\nabla f(\mathbf{x}) = \left(\frac{\partial f}{\partial x_1}, \dots, \frac{\partial f}{\partial x_n}\right)^T$
/// via coordinate-wise central finite differences.
///
/// ```dart
/// final p = Vector<double>.fromList([1.0, 2.0]);
/// final grad = gradient((v) => v[0] * v[0] + v[1] * v[1], p);
/// // grad: Vector([2.0, 4.0])
/// ```
Vector<double> gradient(
  double Function(Vector<double>) function,
  Vector<double> point, {
  double step = 1e-5,
}) {
  final dim = point.length;
  return Vector<double>.generate(dim, (i) {
    final xPlus = point.copy();
    final xMinus = point.copy();
    xPlus[i] += step;
    xMinus[i] -= step;
    return (function(xPlus) - function(xMinus)) / (2.0 * step);
  }, type: DataType.float64);
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
/// final jac = jacobian(
///   (v) => Vector<double>.fromList([v[0] + v[1], v[0] * v[1]]),
///   p,
/// );
/// ```
Matrix<double> jacobian(
  Vector<double> Function(Vector<double>) function,
  Vector<double> point, {
  double step = 1e-5,
}) {
  final dim = point.length;
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

/// Computes the Hessian matrix $H_{i, j} = \frac{\partial^2 f}{\partial x_i \partial x_j}$ of [function] at [point].
///
/// Conceptually, the Hessian describes the local curvature of a multivariate surface,
/// determining whether a critical point is a local minimum (bowl), local maximum (dome), or saddle pass.
/// Formally, it computes the symmetric second partial derivative matrix
/// $H \in \mathbb{R}^{n \times n}$ whose eigenvalues characterize surface curvature and local extrema.
///
/// ```dart
/// final p = Vector<double>.fromList([1.0, 2.0]);
/// final hess = hessian((v) => v[0] * v[0] + v[1] * v[1], p);
/// ```
Matrix<double> hessian(
  double Function(Vector<double>) function,
  Vector<double> point, {
  double step = 1e-4,
}) {
  final dim = point.length;
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
