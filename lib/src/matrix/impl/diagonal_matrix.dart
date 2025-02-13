import 'dart:math' as math;

import '../../../type.dart';
import '../../shared/storage.dart';
import '../../vector/vector.dart';
import '../../vector/vector_format.dart';
import '../matrix.dart';

/// Sparse matrix with diagonal storage.
class DiagonalMatrix<T> with Matrix<T> {
  DiagonalMatrix(
    this.dataType,
    this.rowCount,
    this.colCount, {
    VectorFormat? format,
  }) : _format = format;

  final Map<int, Vector<T>> _diagonals = <int, Vector<T>>{};
  final VectorFormat? _format;

  @override
  final DataType<T> dataType;

  @override
  final int rowCount;

  @override
  final int colCount;

  @override
  Set<Storage> get storage => {this};

  @override
  T getUnchecked(int row, int col) {
    final offset = row - col;
    final index = offset < 0 ? col + offset : col;
    final diagonal = _diagonals[offset];
    return diagonal == null ? dataType.defaultValue : diagonal[index];
  }

  @override
  void setUnchecked(int row, int col, T value) {
    final offset = row - col;
    final index = offset < 0 ? col + offset : col;
    _diagonals.putIfAbsent(offset, () {
          final length = math.min(rowCount - offset, colCount + offset);
          return Vector(dataType, length, format: _format);
        })[index] =
        value;
  }

  @override
  void forEach(void Function(int row, int col, T value) callback) {
    for (final entry in _diagonals.entries) {
      final offset = entry.key;
      entry.value.forEach((index, value) {
        final col = offset < 0 ? index - offset : index;
        final row = offset + col;
        callback(row, col, value);
      });
    }
  }
}
