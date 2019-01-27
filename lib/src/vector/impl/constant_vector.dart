library data.vector.impl.constant;

import 'package:data/src/vector/mixins/unmodifiable_vector.dart';
import 'package:data/src/vector/vector.dart';
import 'package:data/type.dart';

/// Read-only vector with a constant value.
class ConstantVector<T> extends Vector<T> with UnmodifiableVectorMixin<T> {
  final T _value;

  ConstantVector(this.dataType, this.count, this._value);

  @override
  final DataType<T> dataType;

  @override
  final int count;

  @override
  Vector<T> copy() => this;

  @override
  T getUnchecked(int index) => _value;
}
