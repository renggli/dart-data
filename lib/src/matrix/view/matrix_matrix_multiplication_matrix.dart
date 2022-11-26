import '../../../type.dart';
import '../../shared/storage.dart';
import '../matrix.dart';
import '../mixin/unmodifiable_matrix.dart';

class MatrixMatrixMultiplicationMatrix<T>
    with Matrix<T>, UnmodifiableMatrixMixin<T> {
  MatrixMatrixMultiplicationMatrix(this.dataType, this.first, this.second)
      : assert(
            first.colCount == second.rowCount,
            'Expected a matrix with ${first.colCount} rows, '
            'but got one with ${second.rowCount}.');

  final Matrix<T> first;
  final Matrix<T> second;

  @override
  final DataType<T> dataType;

  @override
  int get rowCount => first.rowCount;

  @override
  int get colCount => second.colCount;

  @override
  Set<Storage> get storage => {...first.storage, ...second.storage};

  @override
  T getUnchecked(int row, int col) {
    final add = dataType.field.add, mul = dataType.field.mul;
    var result = dataType.field.additiveIdentity;
    for (var i = 0; i < first.colCount; i++) {
      result = add(
        result,
        mul(
          first.getUnchecked(row, i),
          second.getUnchecked(i, col),
        ),
      );
    }
    return result;
  }
}

extension MatrixMatrixMultiplicationMatrixExtension<T> on Matrix<T> {
  /// Returns a view of this [Matrix] multiplied with [other].
  Matrix<T> mulMatrix(Matrix<T> other, {DataType<T>? dataType}) =>
      MatrixMatrixMultiplicationMatrix<T>(
          dataType ?? this.dataType, this, other);
}
