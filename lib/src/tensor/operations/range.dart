import '../layout.dart';
import '../tensor.dart';
import '../utils/errors.dart';

extension RangeTensorExtension<T> on Tensor<T> {
  /// Returns a view with the given [axis] sliced to the range between [start]
  /// and [end] (exclusive).
  Tensor<T> getRange(int start, int? end, {int step = 1, int axis = 0}) =>
      Tensor<T>.internal(
          type: type,
          layout: layout.getRange(start, end, step: step, axis: axis),
          data: data);
}

extension RangeLayoutExtension on Layout {
  /// Returns an updated layout with the given [axis] sliced to the range
  /// between [start] and [end] (exclusive).
  Layout getRange(int start, int? end, {int step = 1, int axis = 0}) {
    final axis_ = checkIndex(axis, rank, 'axis');
    final start_ = checkIndex(start, shape[axis_], 'start');
    final end_ = RangeError.checkValidRange(
        start_,
        adjustIndex(end ?? shape[axis_], shape[axis_]),
        shape[axis_],
        'start',
        'end');
    checkPositive(step, 'step');
    final rangeLength = (end_ - start_) ~/ step;
    return Layout(
      shape: [...shape.take(axis_), rangeLength, ...shape.skip(axis_ + 1)],
      strides: [
        ...strides.take(axis_),
        step * strides[axis_],
        ...strides.skip(axis_ + 1),
      ],
      offset: offset + start_ * strides[axis_],
    );
  }
}
