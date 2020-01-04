library data.matrix.mixin.unmodifiable;

import '../matrix.dart';

/// Mixin for unmodifiable matrices.
mixin UnmodifiableMatrixMixin<T> implements Matrix<T> {
  @override
  void setUnchecked(int row, int col, T value) =>
      throw UnsupportedError('Matrix is not mutable.');
}
