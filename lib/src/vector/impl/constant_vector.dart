library data.vector.impl.constant;

import 'package:data/type.dart';

import '../mixins/unmodifiable_vector.dart';
import '../vector.dart';

class ConstantVector<T> extends Vector<T> with UnmodifiableVectorMixin<T> {
  @override
  final DataType<T> dataType;

  @override
  final int count;

  final T _value;

  ConstantVector(this.dataType, this.count, this._value);

  @override
  Vector<T> copy() => this;

  @override
  T getUnchecked(int index) => _value;
}
