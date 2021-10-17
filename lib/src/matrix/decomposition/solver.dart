import '../../shared/config.dart';
import '../matrix.dart';
import '../view/identity_matrix.dart';
import '../view/transposed_matrix.dart';
import 'lu.dart';
import 'qr.dart';

extension SolverExtension<T extends num> on Matrix<T> {
  /// Returns the solution `x` of `A * x = B`, where `A` is this [Matrix] and
  /// [b] is the argument to the function.
  Matrix<double> solve(Matrix<num> b) =>
      rowCount == columnCount ? lu.solve(b) : qr.solve(b);

  /// Returns the solution `x` of `x * A = B`, where `A` is this [Matrix] and
  /// [b] is the argument to the function. This is equivalent to solving
  /// `A' * x' = B'`.
  Matrix<double> solveTranspose(Matrix<num> b) =>
      transposed.solve(b.transposed).transposed;

  /// Returns the determinant of this [Matrix].
  double get det => lu.det;

  /// Returns the inverse if this [Matrix] is square, return the pseudo-inverse
  /// otherwise.
  Matrix<double> get inverse => solve(IdentityMatrix<double>(floatDataType,
      rowCount, rowCount, floatDataType.field.multiplicativeIdentity));
}
