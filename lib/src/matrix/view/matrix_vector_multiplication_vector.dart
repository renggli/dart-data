import '../../../type.dart';
import '../../shared/storage.dart';
import '../../vector/mixin/unmodifiable_vector.dart';
import '../../vector/vector.dart';
import '../matrix.dart';

class MatrixVectorMultiplicationVector<T>
    with Vector<T>, UnmodifiableVectorMixin<T> {
  MatrixVectorMultiplicationVector(this.dataType, this.matrix, this.vector)
      : assert(
            matrix.colCount == vector.count,
            'Expected a vector with ${matrix.colCount} elements, '
            'but got one with ${vector.count}.');

  final Matrix<T> matrix;
  final Vector<T> vector;

  @override
  final DataType<T> dataType;

  @override
  int get count => matrix.rowCount;

  @override
  Set<Storage> get storage => {...matrix.storage, ...vector.storage};

  @override
  T getUnchecked(int index) {
    final add = dataType.field.add, mul = dataType.field.mul;
    var result = dataType.field.additiveIdentity;
    for (var c = 0; c < matrix.colCount; c++) {
      result = add(
        result,
        mul(
          matrix.getUnchecked(index, c),
          vector.getUnchecked(c),
        ),
      );
    }
    return result;
  }
}

extension MatrixVectorMultiplicationVectorExtension<T> on Matrix<T> {
  /// Returns a view of this [Matrix] multiplied with [other].
  Vector<T> mulVector(Vector<T> other, {DataType<T>? dataType}) =>
      MatrixVectorMultiplicationVector<T>(
          dataType ?? this.dataType, this, other);
}
