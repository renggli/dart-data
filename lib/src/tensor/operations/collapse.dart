import '../layout.dart';
import '../tensor.dart';
import '../utils/layout.dart' as utils;

extension CollapseTensorExtension<T> on Tensor<T> {
  /// Returns a view with a single-element axis at `axis` removed.
  Tensor<T> collapse({int axis = 0}) => Tensor<T>.internal(
      type: type, layout: layout.collapse(axis: axis), data: data);
}

extension CollapseLayoutExtension on Layout {
  /// Returns a layout with a single-element axis at `axis` removed.
  Layout collapse({int axis = 0}) {
    RangeError.checkValueInInterval(axis, 0, rank - 1, 'axis');
    if (shape[axis] != 1) {
      throw ArgumentError.value(
          axis, 'axis', '$shape at $axis is greater than 1');
    }
    final shape_ = [...shape.take(axis), ...shape.skip(axis + 1)];
    final strides_ = [...strides.take(axis), ...strides.skip(axis + 1)];
    return Layout.internal(
      rank: rank - 1,
      length: length,
      offset: offset,
      shape: utils.toIndices(shape_),
      strides: utils.toIndices(strides_),
      isContiguous: isContiguous,
    );
  }
}
