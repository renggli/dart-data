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
