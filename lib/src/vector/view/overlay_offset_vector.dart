library data.vector.view.overlay_offset;

import 'package:data/src/vector/vector.dart';
import 'package:data/tensor.dart';
import 'package:data/type.dart';

/// Mutable overlay of one vector over another.
///
/// The resulting vector has the same size of the base vector, but the overlay
/// can be of different size and offset relative to the base.
class OverlayOffsetVector<T> extends Vector<T> {
  final int _offset;
  final Vector<T> _overlay;
  final Vector<T> _base;

  OverlayOffsetVector(this._offset, this._overlay, this._base);

  @override
  DataType<T> get dataType => _base.dataType;

  @override
  int get count => _base.count;

  @override
  Set<Tensor> get storage =>
      {}..addAll(_overlay.storage)..addAll(_base.storage);

  @override
  Vector<T> copy() =>
      OverlayOffsetVector(_offset, _overlay.copy(), _base.copy());

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
