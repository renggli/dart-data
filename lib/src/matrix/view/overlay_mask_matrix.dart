import '../../../type.dart';
import '../../shared/storage.dart';
import '../matrix.dart';

/// Mutable overlay of one matrix over another controlled by a mask.
///
/// All matrices (overlay, mask, and base) have to be of the same size. The mask
/// determines whether the overlay is revealed or not.
class OverlayMaskMatrix<T> with Matrix<T> {
  OverlayMaskMatrix(this.dataType, this.overlay, this.mask, this.base);

  final Matrix<T> overlay;
  final Matrix<bool> mask;
  final Matrix<T> base;

  @override
  final DataType<T> dataType;

  @override
  int get rowCount => base.rowCount;

  @override
  int get columnCount => base.columnCount;

  @override
  Set<Storage> get storage =>
      {...overlay.storage, ...mask.storage, ...base.storage};

  @override
  Matrix<T> copy() =>
      OverlayMaskMatrix(dataType, overlay.copy(), mask.copy(), base.copy());

  @override
  T getUnchecked(int row, int col) {
    if (mask.getUnchecked(row, col)) {
      return overlay.getUnchecked(row, col);
    } else {
      return base.getUnchecked(row, col);
    }
  }

  @override
  void setUnchecked(int row, int col, T value) {
    if (mask.getUnchecked(row, col)) {
      return overlay.setUnchecked(row, col, value);
    } else {
      return base.setUnchecked(row, col, value);
    }
  }
}
