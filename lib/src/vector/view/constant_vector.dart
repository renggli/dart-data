library data.vector.view.constant;

import '../../../type.dart';
import '../mixins/unmodifiable_vector.dart';
import '../vector.dart';

/// Read-only vector with a constant value.
class ConstantVector<T> extends Vector<T> with UnmodifiableVectorMixin<T> {
  final T value;

  ConstantVector(this.dataType, this.count, this.value);

  @override
  final DataType<T> dataType;

  @override
  final int count;

  @override
  Vector<T> copy() => this;

  @override
  T getUnchecked(int index) => value;
}
