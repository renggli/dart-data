library data.vector.view.overlay_mask;

import 'package:data/src/vector/vector.dart';
import 'package:data/tensor.dart';
import 'package:data/type.dart';

/// Mutable overlay of one vector over another controlled by a mask.
///
/// All vectors (overlay, mask, and base) have to be of the same size. The mask
/// determines whether the overlay is revealed or not.
class OverlayMaskVector<T> extends Vector<T> {
  final Vector<T> _overlay;
  final Vector<bool> _mask;
  final Vector<T> _base;

  OverlayMaskVector(this.dataType, this._overlay, this._mask, this._base);

  @override
  final DataType<T> dataType;

  @override
  int get count => _base.count;

  @override
  Set<Tensor> get storage =>
      {..._overlay.storage, ..._mask.storage, ..._base.storage};

  @override
  Vector<T> copy() =>
      OverlayMaskVector(dataType, _overlay.copy(), _mask.copy(), _base.copy());

  @override
  T getUnchecked(int index) {
    if (_mask.getUnchecked(index)) {
      return _overlay.getUnchecked(index);
    } else {
      return _base.getUnchecked(index);
    }
  }

  @override
  void setUnchecked(int index, T value) {
    if (_mask.getUnchecked(index)) {
      return _overlay.setUnchecked(index, value);
    } else {
      return _base.setUnchecked(index, value);
    }
  }
}
