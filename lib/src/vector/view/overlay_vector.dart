library data.vector.view.overlay;

import '../../../type.dart';
import '../vector.dart';
import 'overlay_mask_vector.dart';
import 'overlay_offset_vector.dart';

extension OverlayVectorExtension<T> on Vector<T> {
  /// Returns a mutable view where this [Vector] is overlaid on top of a
  /// provided [base] vector. This happens either by using the given [offset],
  /// or using using a boolean [mask].
  Vector<T> overlay(
    Vector<T> base, {
    DataType<T> dataType,
    Vector<bool> mask,
    int offset,
  }) {
    dataType ??= this.dataType;
    if (mask == null && offset != null) {
      return OverlayOffsetVector<T>(dataType, this, offset, base);
    } else if (mask != null && offset == null) {
      if (count != base.count || count != mask.count) {
        throw ArgumentError('Dimension of overlay ($count), mask '
            '(${mask.count}) and base (${base.count}) do not match.');
      }
      return OverlayMaskVector<T>(dataType, this, mask, base);
    }
    throw ArgumentError('Either a mask or an offset required.');
  }
}
