library data.vector.impl.keyed;

import 'package:data/type.dart';

import '../vector.dart';

class KeyedVector<T> extends Vector<T> {
  @override
  final DataType<T> dataType;

  @override
  final int count;

  final Map<int, T> _values;

  KeyedVector(this.dataType, this.count) : _values = {};

  @override
  T getUnchecked(int index) => _values[index] ?? dataType.nullValue;

  @override
  void setUnchecked(int index, T value) {
    if (value == dataType.nullValue) {
      _values.remove(index);
    } else {
      _values[index] = value;
    }
  }
}
