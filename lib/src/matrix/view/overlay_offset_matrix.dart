import '../../../type.dart';
import '../../shared/storage.dart';
import '../matrix.dart';

/// Mutable overlay of one matrix over another.
///
/// The resulting matrix has the same size as the base matrix, but the overlay
/// can be of different size and be offset relative to the base.
class OverlayOffsetMatrix<T> with Matrix<T> {
  OverlayOffsetMatrix(
      this.dataType, this.overlay, this.rowOffset, this.colOffset, this.base);

  final int rowOffset;
  final int colOffset;
  final Matrix<T> overlay;
  final Matrix<T> base;

  @override
  final DataType<T> dataType;

  @override
  int get rowCount => base.rowCount;

  @override
  int get columnCount => base.columnCount;

  @override
  Set<Storage> get storage => {...overlay.storage, ...base.storage};

  @override
  T getUnchecked(int row, int col) {
    final overlayRow = row - rowOffset, overlayCol = col - colOffset;
    if (overlay.isWithinBounds(overlayRow, overlayCol)) {
      return overlay.getUnchecked(overlayRow, overlayCol);
    } else {
      return base.getUnchecked(row, col);
    }
  }

  @override
  void setUnchecked(int row, int col, T value) {
    final overlayRow = row - rowOffset, overlayCol = col - colOffset;
    if (overlay.isWithinBounds(overlayRow, overlayCol)) {
      return overlay.setUnchecked(overlayRow, overlayCol, value);
    } else {
      return base.setUnchecked(row, col, value);
    }
  }
}
