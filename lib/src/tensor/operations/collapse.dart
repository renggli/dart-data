import '../layout.dart';
import '../tensor.dart';
import '../utils/checks.dart';
import '../utils/layout.dart' as utils;

extension CollapseTensorExtension<T> on Tensor<T> {
  /// Returns a view with a single-element axis at `axis` removed.
  Tensor<T> collapse({int axis = 0}) => Tensor<T>.internal(
      type: type, layout: layout.collapse(axis: axis), data: data);
}

extension CollapseLayoutExtension on Layout {
  /// Returns a layout with a single-element `axis` removed.
  Layout collapse({int axis = 0}) {
    final axis_ = checkIndex(axis, rank, 'axis');
    if (shape[axis_] != 1) {
      throw ArgumentError.value(
          axis, 'axis', 'Shape at $axis is ${shape[axis_]}, but expected 1');
    }
    final shape_ = [...shape.take(axis_), ...shape.skip(axis_ + 1)];
    final strides_ = [...strides.take(axis_), ...strides.skip(axis_ + 1)];
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
