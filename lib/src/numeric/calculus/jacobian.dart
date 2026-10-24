import 'dart:math' as math;

import '../../linear/matrix.dart';
import '../../linear/vector.dart';
import '../../type/data_type.dart';

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
  final result = Matrix<double>.filled(
    numFuncs,
    dim,
    0.0,
    type: DataType.float64,
  );
  if (dim == 0 || numFuncs == 0) return result;

  final xWork = point.copy();
  for (var col = 0; col < dim; col++) {
    final original = point[col];
    final h = step * math.max(1.0, original.abs());
    xWork[col] = original + h;
    final fPlus = function(xWork);
    xWork[col] = original - h;
    final fMinus = function(xWork);
    xWork[col] = original;

    final invTwoH = 1.0 / (2.0 * h);
    for (var row = 0; row < numFuncs; row++) {
      result.set(row, col, (fPlus[row] - fMinus[row]) * invTwoH);
    }
  }
  return result;
}
