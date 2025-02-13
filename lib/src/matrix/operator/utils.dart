import '../../../type.dart';
import '../matrix.dart';
import '../matrix_format.dart';

Matrix<T> createMatrix<T>(
  Matrix<T> source,
  Matrix<T>? result,
  DataType<T>? dataType,
  MatrixFormat? format,
) {
  if (result == null) {
    return Matrix<T>(
      dataType ?? source.dataType,
      source.rowCount,
      source.colCount,
      format: format,
    );
  } else if (source.rowCount != result.rowCount ||
      source.colCount != result.colCount) {
    throw ArgumentError(
      'Matrix result and operand dimensions do not match: '
      '${result.rowCount}*${result.colCount} and '
      '${source.rowCount}*${source.colCount}.',
    );
  }
  return result;
}
