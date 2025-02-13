import '../../../type.dart';
import '../../vector/vector.dart';
import '../matrix.dart';
import '../matrix_format.dart';
import 'utils.dart';

extension ApplyMatrixExtension<T> on Matrix<T> {
  /// Applies an [operator] and a [vector] over each row of this matrix.
  Matrix<T> applyByRow(
    T Function(T a, T b) operator,
    Vector<T> vector, {
    Matrix<T>? target,
    DataType<T>? dataType,
    MatrixFormat? format,
  }) {
    final result = createMatrix<T>(this, target, dataType, format);
    if (rowCount != vector.count) {
      throw ArgumentError.value(
        vector,
        'vector',
        'Vector must have $rowCount elements, but it has ${vector.count}.',
      );
    }
    for (var r = 0; r < rowCount; r++) {
      for (var c = 0; c < colCount; c++) {
        result.setUnchecked(
          r,
          c,
          operator(getUnchecked(r, c), vector.getUnchecked(r)),
        );
      }
    }
    return result;
  }

  /// Applies an [operator] and a [vector] over each column of this matrix.
  Matrix<T> applyByColumn(
    T Function(T a, T b) operator,
    Vector<T> vector, {
    Matrix<T>? target,
    DataType<T>? dataType,
    MatrixFormat? format,
  }) {
    final result = createMatrix<T>(this, target, dataType, format);
    if (colCount != vector.count) {
      throw ArgumentError.value(
        vector,
        'vector',
        'Vector must have $colCount elements, but it has ${vector.count}.',
      );
    }
    for (var r = 0; r < rowCount; r++) {
      for (var c = 0; c < colCount; c++) {
        result.setUnchecked(
          r,
          c,
          operator(getUnchecked(r, c), vector.getUnchecked(c)),
        );
      }
    }
    return result;
  }
}
