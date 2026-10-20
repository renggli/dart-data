import '../../../linear.dart';
import '../../../type.dart';

/// Computes the Hessian matrix
/// $H_{i, j} = \frac{\partial^2 f}{\partial x_i \partial x_j}$ of [function] at
/// [point].
///
/// Conceptually, the Hessian describes the local curvature of a multivariate
/// surface, determining whether a critical point is a local minimum (bowl),
/// local maximum (dome), or saddle pass. Formally, it computes the symmetric
/// second partial derivative matrix $H \in \mathbb{R}^{n \times n}$ whose
/// eigenvalues characterize surface curvature and local extrema.
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
