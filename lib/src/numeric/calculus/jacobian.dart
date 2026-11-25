import 'dart:math' as math;

import '../../linear/matrix.dart';
import '../../linear/vector.dart';
import '../../type/data_type.dart';

/// Computes the Jacobian matrix `J[i, j] = ∂fᵢ/∂xⱼ` of vector function
/// [function] at [point].
///
/// Conceptually, the Jacobian is a matrix of partial slopes describing how a
/// multi-output vector field distorts, rotates, or shears coordinate space near
/// a point. Formally, it computes the best local linear affine approximation
/// `Df(x) ∈ R^(m×n)` where `J[i, j] = ∂fᵢ/∂xⱼ`.
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
  if (step <= 0.0 || !step.isFinite) {
    throw ArgumentError.value(step, 'step', 'Step must be positive and finite');
  }
  final dim = point.length;
  if (dim == 0) {
    final numFuncs = function(point).length;
    return Matrix<double>.filled(numFuncs, 0, 0.0, type: DataType.float64);
  }

  Matrix<double>? result;
  final xWork = point.copy();
  for (var col = 0; col < dim; col++) {
    final original = point.getUnchecked(col);
    final h = step * math.max(1.0, original.abs());
    xWork.setUnchecked(col, original + h);
    final fPlus = function(xWork);
    xWork.setUnchecked(col, original - h);
    final fMinus = function(xWork);
    xWork.setUnchecked(col, original);

    if (result == null) {
      final numFuncs = fPlus.length;
      result = Matrix<double>.filled(
        numFuncs,
        dim,
        0.0,
        type: DataType.float64,
      );
      if (numFuncs == 0) return result;
    }

    final invTwoH = 1.0 / (2.0 * h);
    for (var row = 0; row < result.rowCount; row++) {
      result.setUnchecked(
        row,
        col,
        (fPlus.getUnchecked(row) - fMinus.getUnchecked(row)) * invTwoH,
      );
    }
  }
  return result!;
}
