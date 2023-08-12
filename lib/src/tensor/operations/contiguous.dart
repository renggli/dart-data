import '../layout.dart';
import '../tensor.dart';

extension ContiguousTensorExtension<T> on Tensor<T> {
  /// Returns a contiguous copy of this tensor, if the tensor is already
  /// contiguous return itself.
  Tensor<T> contiguous() => layout.isContiguous
      ? this
      : Tensor.internal(
          type: type,
          layout: Layout(shape: layout.shape),
          data: type.copyList(values));
}
