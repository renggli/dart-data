library data.vector.mixins.unmodifiable_vector;

import '../vector.dart';

/// Mixin for unmodifiable vectors.
mixin UnmodifiableVectorMixin<T> implements Vector<T> {
  @override
  Vector<T> get unmodifiable => this;

  @override
  void setUnchecked(int index, T value) =>
      throw UnsupportedError('Vector is not mutable.');
}
