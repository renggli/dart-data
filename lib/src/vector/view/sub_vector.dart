library data.vector.view.sub_vector;

import 'package:data/type.dart';

import '../vector.dart';

class SubVector<T> extends Vector<T> {
  final Vector<T> _vector;
  final int _start;

  SubVector(this._vector, this._start, int end) : count = end - _start;

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
  Vector<T> subVectorUnchecked(int start, int end) =>
      SubVector<T>(_vector, _start + start, _start + end);
}
