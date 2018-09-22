library data.vector.mixins.unmodifiable_vector;

import '../vector.dart';

abstract class UnmodifiableVectorMixin<T> implements Vector<T> {
  @override
  void setUnchecked(int index, T value) =>
      throw UnsupportedError('Vector is not mutable.');
}
