import '../../../type.dart';
import '../../shared/storage.dart';
import '../../tensor/tensor.dart';
import '../vector.dart';

/// Tensor vector.
class TensorVector<T> with Vector<T> {
  TensorVector(DataType<T> dataType, int count)
      : _tensor = Tensor<T>.filled(dataType.defaultValue,
            type: dataType, shape: [count]);

  final Tensor<T> _tensor;

  @override
  DataType<T> get dataType => _tensor.type;

  @override
  int get count => _tensor.layout.shape[0];

  @override
  Set<Storage> get storage => {this};

  @override
  T getUnchecked(int index) =>
      _tensor.data[_tensor.layout.offset + _tensor.layout.strides[0] * index];

  @override
  void setUnchecked(int index, T value) =>
      _tensor.data[_tensor.layout.offset + _tensor.layout.strides[0] * index] =
          value;
}
