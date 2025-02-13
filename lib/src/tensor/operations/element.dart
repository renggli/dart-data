import '../layout.dart';
import '../tensor.dart';
import '../utils/checks.dart';

extension ElementTensorExtension<T> on Tensor<T> {
  /// Returns a view with the given [axis] resolved to [index].
  Tensor<T> elementAt(int index, {int axis = 0}) => Tensor<T>.internal(
    type: type,
    layout: layout.elementAt(index, axis: axis),
    data: data,
  );
}

extension ElementLayoutExtension on Layout {
  /// Returns an updated layout with the given [axis] resolved to [index].
  Layout elementAt(int index, {int axis = 0}) {
    final axis_ = checkIndex(axis, rank, 'axis');
    final index_ = checkIndex(index, shape[axis_], 'index');
    return Layout(
      shape: [...shape.take(axis_), ...shape.skip(axis_ + 1)],
      strides: [...strides.take(axis_), ...strides.skip(axis_ + 1)],
      offset: offset + index_ * strides[axis_],
    );
  }
}
