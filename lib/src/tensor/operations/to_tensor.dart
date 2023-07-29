import '../../type/type.dart';
import '../tensor.dart';

extension ToTensorIterable<T> on Iterable<T> {
  /// Returns a [Tensor] from the given iterable.
  Tensor<T> toTensor(
          {List<int>? shape, List<int>? strides, DataType<T>? type}) =>
      Tensor<T>.fromIterable(this, shape: shape, strides: strides, type: type);
}
