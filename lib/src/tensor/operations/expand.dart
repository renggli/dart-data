import '../layout.dart';
import '../tensor.dart';
import '../utils/checks.dart';
import '../utils/layout.dart' as utils;

extension ExpandTensorExtension<T> on Tensor<T> {
  /// Returns a view with a single-element axis at [axis] added.
  Tensor<T> expand({int axis = 0}) => Tensor<T>.internal(
    type: type,
    layout: layout.expand(axis: axis),
    data: data,
  );
}

extension ExpandLayoutExtension on Layout {
  /// Returns a layout with a single-element axis at [axis] added.
  Layout expand({int axis = 0}) {
    final axis_ = checkStart(axis, rank, 'axis');
    final shape_ = [...shape.take(axis_), 1, ...shape.skip(axis_)];
    final strides_ = [
      ...strides.take(axis_),
      if (axis_ < rank) strides[axis_] else 1,
      ...strides.skip(axis_),
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
