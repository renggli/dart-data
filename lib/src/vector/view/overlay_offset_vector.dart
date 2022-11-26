import '../../../type.dart';
import '../../shared/storage.dart';
import '../vector.dart';

/// Mutable overlay of one vector over another.
///
/// The resulting vector has the same size of the base vector, but the overlay
/// can be of different size and be offset relative to the base.
class OverlayOffsetVector<T> with Vector<T> {
  OverlayOffsetVector(this.dataType, this.overlay, this.offset, this.base);

  final int offset;
  final Vector<T> overlay;
  final Vector<T> base;

  @override
  final DataType<T> dataType;

  @override
  int get count => base.count;

  @override
  Set<Storage> get storage => {...overlay.storage, ...base.storage};

  @override
  T getUnchecked(int index) {
    final overlayIndex = index - offset;
    if (overlay.isWithinBounds(overlayIndex)) {
      return overlay.getUnchecked(overlayIndex);
    } else {
      return base.getUnchecked(index);
    }
  }

  @override
  void setUnchecked(int index, T value) {
    final overlayIndex = index - offset;
    if (overlay.isWithinBounds(overlayIndex)) {
      return overlay.setUnchecked(overlayIndex, value);
    } else {
      return base.setUnchecked(index, value);
    }
  }
}
