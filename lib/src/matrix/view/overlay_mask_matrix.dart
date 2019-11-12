library data.matrix.view.overlay_mask;

import '../../../tensor.dart';
import '../../../type.dart';
import '../matrix.dart';

/// Mutable overlay of one matrix over another controlled by a mask.
///
/// All matrices (overlay, mask, and base) have to be of the same size. The mask
/// determines whether the overlay is revealed or not.
class OverlayMaskMatrix<T> extends Matrix<T> {
  final Matrix<T> _overlay;
  final Matrix<bool> _mask;
  final Matrix<T> _base;

  OverlayMaskMatrix(this.dataType, this._overlay, this._mask, this._base);

  @override
  final DataType<T> dataType;

  @override
  int get rowCount => _base.rowCount;

  @override
  int get colCount => _base.colCount;

  @override
  Set<Tensor> get storage =>
      {..._overlay.storage, ..._mask.storage, ..._base.storage};

  @override
  Matrix<T> copy() =>
      OverlayMaskMatrix(dataType, _overlay.copy(), _mask.copy(), _base.copy());

  @override
  T getUnchecked(int row, int col) {
    if (_mask.getUnchecked(row, col)) {
      return _overlay.getUnchecked(row, col);
    } else {
      return _base.getUnchecked(row, col);
    }
  }

  @override
  void setUnchecked(int row, int col, T value) {
    if (_mask.getUnchecked(row, col)) {
      return _overlay.setUnchecked(row, col, value);
    } else {
      return _base.setUnchecked(row, col, value);
    }
  }
}
