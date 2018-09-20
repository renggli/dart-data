library data.vector.impl.standard;

import 'package:data/type.dart';

import '../vector.dart';

class StandardVector<T> extends Vector<T> {
  @override
  final DataType<T> dataType;

  final List<T> _values;

  StandardVector(DataType<T> dataType, int count)
      : this.internal(dataType, dataType.newList(count));

  StandardVector.internal(this.dataType, this._values);

  @override
  Vector<T> copy() =>
      StandardVector.internal(dataType, dataType.copyList(_values));

  @override
  int get count => _values.length;

  @override
  T getUnchecked(int index) => _values[index];

  @override
  void setUnchecked(int index, T value) => _values[index] = value;
}
