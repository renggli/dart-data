import '../vector.dart';

/// Mixin for unmodifiable vectors.
mixin UnmodifiableVectorMixin<T> implements Vector<T> {
  @override
  void setUnchecked(int index, T value) =>
      throw UnsupportedError('Vector is not mutable.');
}
