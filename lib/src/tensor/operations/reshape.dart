import '../../stats/iterable.dart';
import '../layout.dart';
import '../tensor.dart';

extension ReshapeTensorExtension<T> on Tensor<T> {
  /// Returns a reshaped view, if possible. If a dimension is set to `-1` it is
  /// inferred automatically to keep the length constant.
  Tensor<T> reshape(List<int> shape) {
    // Test if there is an undefined value.
    final inferredIndex = shape.indexOf(-1);
    if (inferredIndex >= 0) {
      shape = shape.toList(growable: false);
      shape[inferredIndex] = length ~/ -shape.product();
    }
    // Create new layout and copy data if necessary.
    final (layout_, data_) = layout.isContiguous
        ? (Layout(shape: shape, offset: layout.offset), data)
        : (Layout(shape: shape), type.copyList(values));
    // Check if the new layout is compatible at all.
    if (layout.length != layout_.length) {
      throw ArgumentError.value(shape, 'shape', 'Incompatible with $layout');
    }
    return Tensor<T>.internal(type: type, layout: layout_, data: data_);
  }

  /// Return the tensor collapsed into one dimension.
  Tensor<T> flatten() => reshape([length]);
}
