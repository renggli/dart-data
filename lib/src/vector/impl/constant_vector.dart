library data.vector.impl.constant;

import 'package:data/type.dart';

import '../mixins/unmodifiable_vector.dart';
import '../vector.dart';

class ConstantVector<T> extends Vector<T> with UnmodifiableVectorMixin<T> {
  final T _value;

  ConstantVector(this.dataType, this.count, this._value);

  @override
  final DataType<T> dataType;

  @override
  final int count;

  @override
  Vector<T> get base => this;

  @override
  Vector<T> copy() => this;

  @override
  T getUnchecked(int index) => _value;
}
