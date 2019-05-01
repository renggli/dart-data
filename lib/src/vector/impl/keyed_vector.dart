library data.vector.impl.keyed;

import 'package:data/src/vector/vector.dart';
import 'package:data/type.dart';

/// Sparse keyed vector.
class KeyedVector<T> extends Vector<T> {
  final Map<int, T> _values;

  KeyedVector(DataType<T> dataType, int count)
      : this._(dataType, count, <int, T>{});

  KeyedVector._(this.dataType, this.count, this._values);

  @override
  final DataType<T> dataType;

  @override
  final int count;

  @override
  Vector<T> copy() => KeyedVector._(dataType, count, Map.of(_values));

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
