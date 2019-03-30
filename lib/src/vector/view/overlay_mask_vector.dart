library data.vector.view.overlay_mask;

import 'package:data/src/vector/vector.dart';
import 'package:data/tensor.dart';
import 'package:data/type.dart';

/// Mutable overlay of one vector over another controlled by a mask.
///
/// All vectors (mask, overlay, base) have to be of the same size. The mask
/// determines whether the overlay is revealed or not.
class OverlayMaskVector<T> extends Vector<T> {
  final Vector<bool> _mask;
  final Vector<T> _overlay;
  final Vector<T> _base;

  OverlayMaskVector(this._mask, this._overlay, this._base);

  @override
  DataType<T> get dataType => _base.dataType;

  @override
  int get count => _base.count;

  @override
  Set<Tensor> get storage => {}
    ..addAll(_mask.storage)
    ..addAll(_overlay.storage)
    ..addAll(_base.storage);

  @override
  Vector<T> copy() =>
      OverlayMaskVector(_mask.copy(), _overlay.copy(), _base.copy());

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
