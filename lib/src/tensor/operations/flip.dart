import '../layout.dart';
import '../tensor.dart';
import '../utils/layout.dart' as utils;

extension FlipTensorExtension<T> on Tensor<T> {
  /// Returns a view with the elements along the given axis reversed.
  Tensor<T> flip({int axis = 0}) => Tensor<T>.internal(
      type: type, layout: layout.flip(axis: axis), data: data);
}

extension FlipLayoutExtension on Layout {
  Layout flip({int axis = 0}) {
    RangeError.checkValueInInterval(axis, 0, rank, 'axis');
    final offset_ = offset + strides[axis] * (shape[axis] - 1);
    final strides_ = [...strides];
    strides_[axis] *= -1;
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
