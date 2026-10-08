import '../../../type.dart';
import '../matrix.dart';
import '../view/identity_matrix.dart';
import '../view/transposed_matrix.dart';
import 'lu.dart';
import 'qr.dart';

extension SolverExtension<T extends num> on Matrix<T> {
  /// Returns the solution `x` of `A * x = B`, where `A` is this [Matrix] and
  /// [b] is the argument to the function.
  Matrix<double> solve(Matrix<num> b) =>
      rowCount == colCount ? lu.solve(b) : qr.solve(b);

  /// Returns the solution `x` of `x * A = B`, where `A` is this [Matrix] and
  /// [b] is the argument to the function. This is equivalent to solving
  /// `A' * x' = B'`.
  Matrix<double> solveTranspose(Matrix<num> b) =>
      transposed.solve(b.transposed).transposed;

  /// Returns the determinant of this [Matrix].
  double get det => lu.det;

  /// Returns the inverse of this square, non-singular [Matrix]. Throws an
  /// [ArgumentError] if the matrix is non-square or singular.
  Matrix<double> get inverse {
    if (rowCount != colCount) {
      throw ArgumentError('Matrix must be square to be inverted.');
    }
    return solve(
      IdentityMatrix<double>(
        DataType.float,
        rowCount,
        rowCount,
        DataType.float.field.multiplicativeIdentity,
      ),
    );
  }
}
