import '../layout.dart';
import '../tensor.dart';

extension CopyTensorExtension<T> on Tensor<T> {
  /// Copies the data of this tensor.
  ///
  /// Only if [contiguous] is set to `true`, the data is realigned so that the
  /// layout is contiguous.
  Tensor<T> copy({bool contiguous = false}) {
    final (layout_, data_) = contiguous
        ? (Layout(shape: layout.shape), type.copyList(values))
        : (layout, type.copyList(data));
    return Tensor.internal(type: type, layout: layout_, data: data_);
  }
}
