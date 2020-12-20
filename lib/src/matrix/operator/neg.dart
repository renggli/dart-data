import '../../../type.dart';
import '../matrix.dart';
import '../matrix_format.dart';
import 'utils.dart';

extension NegMatrixExtension<T> on Matrix<T> {
  /// Negates this [Matrix].
  Matrix<T> neg(
      {Matrix<T>? target, DataType<T>? dataType, MatrixFormat? format}) {
    final result = createMatrix<T>(this, target, dataType, format);
    unaryOperator<T>(result, this, result.dataType.field.neg);
    return result;
  }

  /// Convenience method to negate this [Matrix].
  Matrix<T> operator -() => neg();
}
