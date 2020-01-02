library data.matrix.overlay_matrix;

import '../../../type.dart';
import '../matrix.dart';
import 'overlay_mask_matrix.dart';
import 'overlay_offset_matrix.dart';

extension OverlayMatrixExtension<T> on Matrix<T> {
  /// Returns a mutable view where this matrix is overlaid on top of a provided
  /// [base] matrix. This happens either by using the given [rowOffset] and
  /// [colOffset], or using a boolean [mask].
  Matrix<T> overlay(
    Matrix<T> base, {
    DataType<T> dataType,
    Matrix<bool> mask,
    int rowOffset,
    int colOffset,
  }) {
    dataType ??= this.dataType;
    if (mask == null && rowOffset != null && colOffset != null) {
      return OverlayOffsetMatrix<T>(dataType, this, rowOffset, colOffset, base);
    } else if (mask != null && rowOffset == null && colOffset == null) {
      if (rowCount != base.rowCount ||
          rowCount != mask.rowCount ||
          colCount != base.colCount ||
          colCount != mask.colCount) {
        throw ArgumentError('Dimensions of overlay ($rowCount * $colCount), '
            'mask (${mask.rowCount} * ${mask.colCount}) and base '
            '(${base.rowCount} * ${base.colCount}) matrices do not match.');
      }
      return OverlayMaskMatrix<T>(dataType, this, mask, base);
    }
    throw ArgumentError('Either a mask or an offset required.');
  }
}
