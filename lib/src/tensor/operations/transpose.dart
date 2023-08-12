import 'package:more/collection.dart';

import '../layout.dart';
import '../tensor.dart';
import '../utils/layout.dart' as utils;

extension TransposeTensorExtension<T> on Tensor<T> {
  /// Returns a transposed view.
  Tensor<T> transpose({List<int>? axes}) => Tensor<T>.internal(
      type: type, layout: layout.transpose(axes: axes), data: data);
}

extension TransposeLayoutExtension on Layout {
  /// Returns a layout with the transposed axis.
  Layout transpose({List<int>? axes}) {
    axes ??= IntegerRange(rank).reversed;
    final shape_ = utils.toIndices(axes.map((each) => shape[each]));
    final strides_ = utils.toIndices(axes.map((each) => strides[each]));
    return Layout.internal(
      rank: rank,
      length: length,
      shape: shape_,
      strides: strides_,
      offset: offset,
      isContiguous: utils.isContiguous(shape: shape_, strides: strides_),
    );
  }
}
