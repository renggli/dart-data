library data.vector.view.unmodifiable_vector;

import 'package:data/tensor.dart';
import 'package:data/type.dart';

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
  List<Tensor> get storage => _vector.storage;

  @override
  Vector<T> copy() => UnmodifiableVector(_vector.copy());

  @override
  T getUnchecked(int index) => _vector.getUnchecked(index);
}
