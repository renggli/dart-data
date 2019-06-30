library data.matrix.view.overlay_offset;

import 'package:data/src/matrix/matrix.dart';
import 'package:data/tensor.dart';
import 'package:data/type.dart';

/// Mutable overlay of one matrix over another.
///
/// The resulting matrix has the same size as the base matrix, but the overlay
/// can be of different size and be offset relative to the base.
class OverlayOffsetMatrix<T> extends Matrix<T> {
  final int _rowOffset;
  final int _colOffset;
  final Matrix<T> _overlay;
  final Matrix<T> _base;

  OverlayOffsetMatrix(this.dataType, this._overlay, this._rowOffset,
      this._colOffset, this._base);

  @override
  final DataType<T> dataType;

  @override
  int get rowCount => _base.rowCount;

  @override
  int get colCount => _base.colCount;

  @override
  Set<Tensor> get storage => {..._overlay.storage, ..._base.storage};

  @override
  Matrix<T> copy() => OverlayOffsetMatrix(
      dataType, _overlay.copy(), _rowOffset, _colOffset, _base.copy());

  @override
  T getUnchecked(int row, int col) {
    final overlayRow = row - _rowOffset, overlayCol = col - _colOffset;
    if (_overlay.isWithinBounds(overlayRow, overlayCol)) {
      return _overlay.getUnchecked(overlayRow, overlayCol);
    } else {
      return _base.getUnchecked(row, col);
    }
  }

  @override
  void setUnchecked(int row, int col, T value) {
    final overlayRow = row - _rowOffset, overlayCol = col - _colOffset;
    if (_overlay.isWithinBounds(overlayRow, overlayCol)) {
      return _overlay.setUnchecked(overlayRow, overlayCol, value);
    } else {
      return _base.setUnchecked(row, col, value);
    }
  }
}
