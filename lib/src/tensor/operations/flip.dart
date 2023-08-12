import '../layout.dart';
import '../tensor.dart';
import '../utils/checks.dart';
import '../utils/layout.dart' as utils;

extension FlipTensorExtension<T> on Tensor<T> {
  /// Returns a view with the elements along the given axis reversed.
  Tensor<T> flip({int axis = 0}) => Tensor<T>.internal(
      type: type, layout: layout.flip(axis: axis), data: data);
}

extension FlipLayoutExtension on Layout {
  /// Returns a layout with the elements along the given axis reversed.
  Layout flip({int axis = 0}) {
    final axis_ = checkStart(axis, rank, 'axis');
    final offset_ = offset + strides[axis_] * (shape[axis_] - 1);
    final strides_ = [...strides];
    strides_[axis_] *= -1;
    return Layout.internal(
      rank: rank,
      length: length,
      offset: offset_,
      shape: shape,
      strides: utils.toIndices(strides_),
      isContiguous: utils.isContiguous(shape: shape, strides: strides_),
    );
  }
}
