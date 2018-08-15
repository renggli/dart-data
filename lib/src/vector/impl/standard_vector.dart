library data.vector.impl.standard;

import 'package:data/type.dart';

import '../vector.dart';

class StandardVector<T> extends Vector<T> {
  @override
  final DataType<T> dataType;

  final List<T> _values;

  StandardVector(this.dataType, int count) : _values = dataType.newList(count);

  @override
  int get count => _values.length;

  @override
  T getUnchecked(int index) => _values[index];

  @override
  void setUnchecked(int index, T value) => _values[index] = value;
}
