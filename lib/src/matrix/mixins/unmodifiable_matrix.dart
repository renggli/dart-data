library data.matrix.mixins.unmodifiable_matrix;

import '../matrix.dart';

abstract class UnmodifiableMatrixMixin<T> implements Matrix<T> {
  @override
  void setUnchecked(int row, int col, T value) =>
      throw UnsupportedError('Matrix is not mutable.');
}
