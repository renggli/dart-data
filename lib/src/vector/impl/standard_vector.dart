library data.vector.impl.standard;

import 'package:data/src/vector/vector.dart';
import 'package:data/type.dart';

/// Standard vector.
class StandardVector<T> extends Vector<T> {
  final List<T> _values;

  StandardVector(DataType<T> dataType, int count)
      : this.fromList(dataType, dataType.newList(count));

  StandardVector.fromList(this.dataType, this._values);

  @override
  final DataType<T> dataType;

  @override
  int get count => _values.length;

  @override
  Vector<T> copy() =>
      StandardVector.fromList(dataType, dataType.copyList(_values));

  @override
  T getUnchecked(int index) => _values[index];

  @override
  void setUnchecked(int index, T value) => _values[index] = value;
}
