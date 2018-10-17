library data.vector.view.unmodifiable_vector;

import 'package:data/src/type/type.dart';

import '../mixins/unmodifiable_vector.dart';
import '../vector.dart';

/// Read-only view of a mutable vector.
class UnmodifiableVector<T> extends Vector<T> with UnmodifiableVectorMixin<T> {
  final Vector<T> _vector;

  UnmodifiableVector(this._vector);

  @override
  DataType<T> get dataType => _vector.dataType;

  @override
  int get count => _vector.count;

  @override
  Vector<T> get base => _vector.base;

  @override
  Vector<T> copy() => UnmodifiableVector(_vector.copy());

  @override
  T getUnchecked(int index) => _vector.getUnchecked(index);
}
