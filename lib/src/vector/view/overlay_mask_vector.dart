import '../../../type.dart';
import '../../shared/storage.dart';
import '../vector.dart';

/// Mutable overlay of one vector over another controlled by a mask.
///
/// All vectors (overlay, mask, and base) have to be of the same size. The mask
/// determines whether the overlay is revealed or not.
class OverlayMaskVector<T> with Vector<T> {
  OverlayMaskVector(this.dataType, this.overlay, this.mask, this.base);

  final Vector<T> overlay;
  final Vector<bool> mask;
  final Vector<T> base;

  @override
  final DataType<T> dataType;

  @override
  int get count => base.count;

  @override
  Set<Storage> get storage =>
      {...overlay.storage, ...mask.storage, ...base.storage};

  @override
  Vector<T> copy() =>
      OverlayMaskVector(dataType, overlay.copy(), mask.copy(), base.copy());

  @override
  T getUnchecked(int index) {
    if (mask.getUnchecked(index)) {
      return overlay.getUnchecked(index);
    } else {
      return base.getUnchecked(index);
    }
  }

  @override
  void setUnchecked(int index, T value) {
    if (mask.getUnchecked(index)) {
      return overlay.setUnchecked(index, value);
    } else {
      return base.setUnchecked(index, value);
    }
  }
}
