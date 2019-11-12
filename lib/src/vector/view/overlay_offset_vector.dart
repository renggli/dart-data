library data.vector.view.overlay_offset;

import '../../../tensor.dart';
import '../../../type.dart';
import '../vector.dart';

/// Mutable overlay of one vector over another.
///
/// The resulting vector has the same size of the base vector, but the overlay
/// can be of different size and be offset relative to the base.
class OverlayOffsetVector<T> extends Vector<T> {
  final int _offset;
  final Vector<T> _overlay;
  final Vector<T> _base;

  OverlayOffsetVector(this.dataType, this._overlay, this._offset, this._base);

  @override
  final DataType<T> dataType;

  @override
  int get count => _base.count;

  @override
  Set<Tensor> get storage => {..._overlay.storage, ..._base.storage};

  @override
  Vector<T> copy() =>
      OverlayOffsetVector(dataType, _overlay.copy(), _offset, _base.copy());

  @override
  T getUnchecked(int index) {
    final overlayIndex = index - _offset;
    if (_overlay.isWithinBounds(overlayIndex)) {
      return _overlay.getUnchecked(overlayIndex);
    } else {
      return _base.getUnchecked(index);
    }
  }

  @override
  void setUnchecked(int index, T value) {
    final overlayIndex = index - _offset;
    if (_overlay.isWithinBounds(overlayIndex)) {
      return _overlay.setUnchecked(overlayIndex, value);
    } else {
      return _base.setUnchecked(index, value);
    }
  }
}
