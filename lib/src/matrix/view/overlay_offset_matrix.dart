library data.matrix.view.overlay_offset;

import '../../../tensor.dart';
import '../../../type.dart';
import '../matrix.dart';

/// Mutable overlay of one matrix over another.
///
/// The resulting matrix has the same size as the base matrix, but the overlay
/// can be of different size and be offset relative to the base.
class OverlayOffsetMatrix<T> extends Matrix<T> {
  final int rowOffset;
  final int colOffset;
  final Matrix<T> overlay;
  final Matrix<T> base;

  OverlayOffsetMatrix(
      this.dataType, this.overlay, this.rowOffset, this.colOffset, this.base);

  @override
  final DataType<T> dataType;

  @override
  int get rowCount => base.rowCount;

  @override
  int get colCount => base.colCount;

  @override
  Set<Tensor> get storage => {...overlay.storage, ...base.storage};

  @override
  Matrix<T> copy() => OverlayOffsetMatrix(
      dataType, overlay.copy(), rowOffset, colOffset, base.copy());

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
