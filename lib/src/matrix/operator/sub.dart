import '../../../type.dart';
import '../matrix.dart';
import '../matrix_format.dart';
import 'utils.dart';

extension SubMatrixExtension<T> on Matrix<T> {
  /// Subtracts [other] from this [Matrix].
  Matrix<T> sub(Matrix<T> other,
      {Matrix<T>? target, DataType<T>? dataType, MatrixFormat? format}) {
    final result = createMatrix<T>(this, target, dataType, format);
    binaryOperator<T>(result, this, other, result.dataType.field.sub);
    return result;
  }

  /// Subtracts [other] from this [Matrix].
  Matrix<T> operator -(Matrix<T> other) => sub(other);
}
