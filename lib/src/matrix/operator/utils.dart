import '../../../type.dart';
import '../matrix.dart';
import '../matrix_format.dart';

void checkDimensions<T>(Matrix<T> first, Matrix<T> second) {
  if (first.rowCount != second.rowCount ||
      first.columnCount != second.columnCount) {
    throw ArgumentError('Matrix operand dimensions do not match: '
        '${first.rowCount}*${first.columnCount} and '
        '${second.rowCount}*${second.columnCount}.');
  }
}

Matrix<T> createMatrix<T>(Matrix<T> source, Matrix<T>? result,
    DataType<T>? dataType, MatrixFormat? format) {
  if (result == null) {
    return Matrix<T>(
        dataType ?? source.dataType, source.rowCount, source.columnCount,
        format: format);
  } else if (source.rowCount != result.rowCount ||
      source.columnCount != result.columnCount) {
    throw ArgumentError('Matrix result and operand dimensions do not match: '
        '${result.rowCount}*${result.columnCount} and '
        '${source.rowCount}*${source.columnCount}.');
  }
  return result;
}

void unaryOperator<T>(
    Matrix<T> result, Matrix<T> source, T Function(T a) operator) {
  for (var r = 0; r < result.rowCount; r++) {
    for (var c = 0; c < result.columnCount; c++) {
      result.setUnchecked(r, c, operator(source.getUnchecked(r, c)));
    }
  }
}

void binaryOperator<T>(Matrix<T> result, Matrix<T> first, Matrix<T> second,
    T Function(T a, T b) operator) {
  checkDimensions<T>(first, second);
  for (var r = 0; r < result.rowCount; r++) {
    for (var c = 0; c < result.columnCount; c++) {
      result.setUnchecked(
          r, c, operator(first.getUnchecked(r, c), second.getUnchecked(r, c)));
    }
  }
}
