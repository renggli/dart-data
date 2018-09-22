library data.vector.view.unmodifiable_vector;

import 'package:data/src/type/type.dart';

import '../mixins/unmodifiable_vector.dart';
import '../vector.dart';

/// An unmodifiable vector.
class UnmodifiableVector<T> extends Vector<T> with UnmodifiableVectorMixin<T> {
  final Vector<T> _vector;

  UnmodifiableVector(this._vector);

  @override
  Vector<T> copy() => UnmodifiableVector(_vector.copy());

  @override
  DataType<T> get dataType => _vector.dataType;

  @override
  int get count => _vector.count;

  @override
  T getUnchecked(int index) => _vector.getUnchecked(index);

  @override
  Vector<T> get unmodifiable => this;
}
