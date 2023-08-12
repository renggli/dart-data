import '../layout.dart';
import '../tensor.dart';
import '../utils/layout.dart' as utils;

extension ExpandTensorExtension<T> on Tensor<T> {
  /// Returns a view with a single-element axis at `axis` added.
  Tensor<T> expand({int axis = 0}) => Tensor<T>.internal(
      type: type, layout: layout.expand(axis: axis), data: data);
}

extension ExpandLayoutExtension on Layout {
  /// Returns a layout with a single-element axis at `axis` added.
  Layout expand({int axis = 0}) {
    RangeError.checkValueInInterval(axis, 0, rank, 'axis');
    final shape_ = [...shape.take(axis), 1, ...shape.skip(axis)];
    final strides_ = [
      ...strides.take(axis),
      axis < rank ? strides[axis] : 1,
      ...strides.skip(axis),
    ];
    return Layout.internal(
      rank: rank + 1,
      length: length,
      offset: offset,
      shape: utils.toIndices(shape_),
      strides: utils.toIndices(strides_),
      isContiguous: isContiguous,
    );
  }
}
