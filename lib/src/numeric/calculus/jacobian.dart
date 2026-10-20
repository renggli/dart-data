import '../../../linear.dart';
import '../../../type.dart';

/// Computes the Jacobian matrix $J_{i, j} = \frac{\partial f_i}{\partial x_j}$
/// of vector function [function] at [point].
///
/// Conceptually, the Jacobian is a matrix of partial slopes describing how a
/// multi-output vector field distorts, rotates, or shears coordinate space near
/// a point. Formally, it computes the best local linear affine approximation
/// $D\mathbf{f}(\mathbf{x}) \in \mathbb{R}^{m \times n}$ where
/// $J_{i, j} = \frac{\partial f_i}{\partial x_j}$.
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
