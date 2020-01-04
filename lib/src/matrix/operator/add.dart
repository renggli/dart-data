library data.matrix.operator.add;

import '../../../type.dart';
import '../matrix.dart';
import '../matrix_format.dart';
import 'utils.dart';

extension AddExtension<T> on Matrix<T> {
  /// Adds [other] to this [Matrix].
  Matrix<T> add(Matrix<T> other,
      {Matrix<T> target, DataType<T> dataType, MatrixFormat format}) {
    final result = createMatrix<T>(this, target, dataType, format);
    binaryOperator<T>(result, this, other, result.dataType.field.add);
    return result;
  }

  /// Adds [other] to this [Matrix].
  Matrix<T> operator +(Matrix<T> other) => add(other);
}
