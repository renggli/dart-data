import '../../../type.dart';
import '../../shared/storage.dart';
import '../../vector/vector.dart';
import '../../vector/vector_format.dart';
import '../../vector/view/column_matrix.dart';
import '../matrix.dart';
import '../matrix_format.dart';
import 'utils.dart';

extension MulMatrixExtension<T> on Matrix<T> {
  /// Multiplies this [Matrix] with [other].
  Matrix<T> mul(/* Matrix<T>|Vector<T>|T */ Object other,
      {Matrix<T>? target, DataType<T>? dataType, MatrixFormat? format}) {
    if (other is Matrix<T>) {
      return mulMatrix(other,
          target: target, dataType: dataType, format: format);
    } else if (other is Vector<T>) {
      return mulVector(other, dataType: dataType).columnMatrix;
    } else if (other is T) {
      return mulScalar(other as T,
          target: target, dataType: dataType, format: format);
    } else {
      throw ArgumentError.value(other, 'other', 'Invalid multiplication.');
    }
  }

  /// Multiplies this [Matrix] with [other].
  Matrix<T> operator *(/* Matrix<T>|Vector<T>|T */ Object other) => mul(other);

  /// Multiplies this [Matrix] with a [Matrix].
  Matrix<T> mulMatrix(Matrix<T> other,
      {Matrix<T>? target, DataType<T>? dataType, MatrixFormat? format}) {
    // Check the inner dimensions of the matrix.
    if (columnCount != other.rowCount) {
      throw ArgumentError('Expected a matrix with $columnCount rows, '
          'but got one with ${other.rowCount}.');
    }
    // Prepare the result matrix.
    var result = target;
    if (result == null) {
      result = Matrix<T>(dataType ?? this.dataType, rowCount, other.columnCount,
          format: format);
    } else if (rowCount != result.rowCount ||
        other.columnCount != result.columnCount) {
      throw ArgumentError('Expected result matrix to have dimensions '
          '$rowCount*$columnCount, but got a matrix with dimensions '
          '${result.rowCount}*${result.columnCount}.');
    }
    // Verify that this is not an in-place operation.
    if (identical(result, target)) {
      final sourcesStorage = Set<Storage>.identity()
        ..addAll(storage)
        ..addAll(other.storage);
      if (result.storage.any(sourcesStorage.contains)) {
        throw ArgumentError('Matrix multiplication cannot be done in-place.');
      }
    }
    // Perform the actual multiplication (finally).
    final field = result.dataType.field;
    for (var r = 0; r < rowCount; r++) {
      for (var c = 0; c < other.columnCount; c++) {
        var sum = field.additiveIdentity;
        for (var i = 0; i < columnCount; i++) {
          sum = field.add(
            sum,
            field.mul(
              getUnchecked(r, i),
              other.getUnchecked(i, c),
            ),
          );
        }
        result.setUnchecked(r, c, sum);
      }
    }
    return result;
  }

  /// Multiplies this [Matrix] with a [Vector].
  Vector<T> mulVector(Vector<T> vector,
      {Vector<T>? target, DataType<T>? dataType, VectorFormat? format}) {
    // Check the inner dimensions of the matrix.
    if (columnCount != vector.count) {
      throw ArgumentError('Expected a vector with $columnCount elements, '
          'but got one with ${vector.count}.');
    }
    // Prepare the result vector.
    var result = target;
    if (result == null) {
      result = Vector<T>(dataType ?? this.dataType, rowCount, format: format);
    } else if (rowCount != result.count) {
      throw ArgumentError('Expected result vector with $rowCount elements, '
          'but got a vector with ${result.count} elements.');
    }
    // Verify that this is not an in-place operation.
    if (identical(result, target)) {
      final sourcesStorage = Set<Storage>.identity()
        ..addAll(storage)
        ..addAll(vector.storage);
      if (result.storage.any(sourcesStorage.contains)) {
        throw ArgumentError('Vector multiplication cannot be done in-place.');
      }
    }
    // Perform the actual multiplication (finally).
    final field = result.dataType.field;
    for (var r = 0; r < rowCount; r++) {
      var sum = field.additiveIdentity;
      for (var c = 0; c < columnCount; c++) {
        sum = field.add(
          sum,
          field.mul(
            getUnchecked(r, c),
            vector.getUnchecked(c),
          ),
        );
      }
      result.setUnchecked(r, sum);
    }
    return result;
  }

  /// Multiplies this [Matrix] with a scalar.
  Matrix<T> mulScalar(T other,
      {Matrix<T>? target, DataType<T>? dataType, MatrixFormat? format}) {
    final result = createMatrix<T>(this, target, dataType, format);
    final mul = result.dataType.field.mul;
    unaryOperator<T>(result, this, (a) => mul(a, other));
    return result;
  }

  /// In-place multiplies this [Matrix] with a scalar.
  Matrix<T> mulScalarEq(T other) => mulScalar(other, target: this);
}
