library matrix.decomposition.solver;

import '../../shared/config.dart';
import '../matrix.dart';
import '../view/identity_matrix.dart';
import '../view/transposed_matrix.dart';
import 'lu.dart';
import 'qr.dart';

extension SolverExtension<T extends num> on Matrix<T> {
  /// Returns the solution of [a] * x = [b].
  Matrix<double> solve(Matrix<num> b) =>
      rowCount == colCount ? lu.solve(b) : qr.solve(b);

  /// Returns the solution of x * [a] = [b], which is also [a]' * x' = [b]'.
  Matrix<double> solveTranspose(Matrix<num> b) =>
      transposed.solve(b.transposed);

  /// Returns the determinant of this [Matrix].
  double get det => lu.det;

  /// Returns the inverse if this [Matrix] is square, return the pseudo-inverse
  /// otherwise.
  Matrix<double> get inverse => solve(IdentityMatrix<double>(floatDataType,
      rowCount, rowCount, floatDataType.field.multiplicativeIdentity));
}
