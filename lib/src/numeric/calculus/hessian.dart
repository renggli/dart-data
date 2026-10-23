import 'dart:math' as math;

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
  final result = Matrix<double>.filled(dim, dim, 0.0, type: DataType.float64);
  if (dim == 0) return result;

  final xWork = point.copy();
  for (var i = 0; i < dim; i++) {
    final xi = point[i];
    final hi = step * math.max(1.0, xi.abs());

    // Diagonal entry: H_ii
    xWork[i] = xi + hi;
    final fPlus = function(xWork);
    xWork[i] = xi - hi;
    final fMinus = function(xWork);
    xWork[i] = xi;

    final diagVal = (fPlus - 2.0 * f0 + fMinus) / (hi * hi);
    result.set(i, i, diagVal);

    // Off-diagonal entries: H_ij = H_ji for j > i (exploiting symmetry)
    for (var j = i + 1; j < dim; j++) {
      final xj = point[j];
      final hj = step * math.max(1.0, xj.abs());

      // f(x + hi*ei + hj*ej)
      xWork[i] = xi + hi;
      xWork[j] = xj + hj;
      final fPP = function(xWork);

      // f(x + hi*ei - hj*ej)
      xWork[j] = xj - hj;
      final fPM = function(xWork);

      // f(x - hi*ei + hj*ej)
      xWork[i] = xi - hi;
      xWork[j] = xj + hj;
      final fMP = function(xWork);

      // f(x - hi*ei - hj*ej)
      xWork[j] = xj - hj;
      final fMM = function(xWork);

      // Restore
      xWork[i] = xi;
      xWork[j] = xj;

      final offDiagVal = (fPP - fPM - fMP + fMM) / (4.0 * hi * hj);
      result.set(i, j, offDiagVal);
      result.set(j, i, offDiagVal);
    }
  }

  return result;
}
