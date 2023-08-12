import 'package:more/collection.dart';

import '../layout.dart';
import '../tensor.dart';
import '../utils/checks.dart';
import '../utils/layout.dart' as utils;

extension TransposeTensorExtension<T> on Tensor<T> {
  /// Returns a transposed view.
  Tensor<T> transpose({List<int>? axes}) => Tensor<T>.internal(
      type: type, layout: layout.transpose(axes: axes), data: data);

  /// Returns a view with axis `first` and `second` swapped.
  Tensor<T> swapAxes(int first, int second) => Tensor<T>.internal(
      type: type, layout: layout.swapAxes(first, second), data: data);

  /// Returns a view with axis `source` moved to `destination`.
  Tensor<T> moveAxes(int source, int destination) => Tensor<T>.internal(
      type: type, layout: layout.moveAxes(source, destination), data: data);
}

extension TransposeLayoutExtension on Layout {
  /// Returns a layout with the transposed axis.
  Layout transpose({Iterable<int>? axes}) {
    final axes_ = axes != null
        ? axes.map((index) => checkIndex(index, rank, 'axes')).toList()
        : IntegerRange(rank).reversed;
    final shape_ = utils.toIndices(axes_.map((each) => shape[each]));
    final strides_ = utils.toIndices(axes_.map((each) => strides[each]));
    return Layout.internal(
      rank: rank,
      length: length,
      shape: shape_,
      strides: strides_,
      offset: offset,
      isContiguous: utils.isContiguous(shape: shape_, strides: strides_),
    );
  }

  /// Returns a layout with axis `first` and `second` swapped.
  Layout swapAxes(int first, int second) {
    final first_ = checkIndex(first, rank, 'first');
    final second_ = checkIndex(second, rank, 'second');
    final axes = IntegerRange(rank).toList();
    axes[first_] = second_;
    axes[second_] = first_;
    return transpose(axes: axes);
  }

  /// Returns a layout with axis `source` moved to `target`.
  Layout moveAxes(int source, int target) {
    final source_ = checkIndex(source, rank, 'source');
    final target_ = checkIndex(target, rank, 'target');
    final axes = IntegerRange(rank).toList();
    axes.removeAt(source_);
    axes.insert(target_, source_);
    return transpose(axes: axes);
  }
}
