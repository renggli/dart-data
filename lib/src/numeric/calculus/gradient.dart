import 'dart:math' as math;

import '../../linear/vector.dart';
import '../../type/data_type.dart';

/// Computes the gradient vector $\nabla f(\mathbf{x})$ of multivariate function
/// [function] at [point].
///
/// Conceptually, the gradient is a vector pointing in the direction of steepest
/// ascent on a multivariate surface, with its Euclidean norm representing the
/// steepness. Formally, it computes
/// $\nabla f(\mathbf{x}) =$
/// $\left(\frac{\partial f}{\partial x_1}, \dots,\right.$
/// $\left.\frac{\partial f}{\partial x_n}\right)^T$
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
  final result = Vector<double>.filled(dim, 0.0, type: DataType.float64);
  if (dim == 0) return result;

  final xWork = point.copy();
  for (var i = 0; i < dim; i++) {
    final xi = point[i];
    final h = step * math.max(1.0, xi.abs());
    xWork[i] = xi + h;
    final fPlus = function(xWork);
    xWork[i] = xi - h;
    final fMinus = function(xWork);
    xWork[i] = xi;
    result[i] = (fPlus - fMinus) / (2.0 * h);
  }
  return result;
}
