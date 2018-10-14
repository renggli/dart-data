library data.vector.impl.keyed;

import 'package:data/type.dart';

import '../vector.dart';

class KeyedVector<T> extends Vector<T> {
  final Map<int, T> _values;

  KeyedVector(DataType<T> dataType, int count)
      : this.internal(dataType, count, <int, T>{});

  KeyedVector.internal(this.dataType, this.count, this._values);

  @override
  final DataType<T> dataType;

  @override
  final int count;

  @override
  Vector<T> get base => this;

  @override
  Vector<T> copy() => KeyedVector.internal(dataType, count, Map.of(_values));

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
