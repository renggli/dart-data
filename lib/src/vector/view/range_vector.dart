library data.vector.view.range_vector;

import 'package:data/type.dart';

import '../vector.dart';

/// A mutable range of a vector.
class RangeVector<T> extends Vector<T> {
  final Vector<T> _vector;
  final int _start;

  RangeVector(this._vector, this._start, int end) : count = end - _start;

  @override
  DataType<T> get dataType => _vector.dataType;

  @override
  final int count;

  @override
  T getUnchecked(int index) => _vector.getUnchecked(_start + index);

  @override
  void setUnchecked(int index, T value) =>
      _vector.setUnchecked(_start + index, value);

  @override
  Vector<T> rangeUnchecked(int start, int end) =>
      RangeVector(_vector, _start + start, _start + end);
}
