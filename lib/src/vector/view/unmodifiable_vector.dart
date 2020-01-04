library data.vector.view.unmodifiable;

import '../../../type.dart';
import '../../shared/storage.dart';
import '../mixin/unmodifiable_vector.dart';
import '../vector.dart';

/// Read-only view of a mutable vector.
class UnmodifiableVector<T> with Vector<T>, UnmodifiableVectorMixin<T> {
  final Vector<T> vector;

  UnmodifiableVector(this.vector);

  @override
  DataType<T> get dataType => vector.dataType;

  @override
  int get count => vector.count;

  @override
  Set<Storage> get storage => vector.storage;

  @override
  Vector<T> copy() => UnmodifiableVector(vector.copy());

  @override
  T getUnchecked(int index) => vector.getUnchecked(index);
}

extension UnmodifiableVectorExtension<T> on Vector<T> {
  /// Returns a unmodifiable view of this [Vector].
  Vector<T> get unmodifiable =>
      this is UnmodifiableVectorMixin<T> ? this : UnmodifiableVector<T>(this);
}
