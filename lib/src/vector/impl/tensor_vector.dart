import '../../../type.dart';
import '../../shared/storage.dart';
import '../../tensor/tensor.dart';
import '../vector.dart';

/// Tensor vector.
class TensorVector<T> with Vector<T> {
  TensorVector(DataType<T> dataType, int count)
    : this.fromTensor(
        Tensor<T>.filled(dataType.defaultValue, type: dataType, shape: [count]),
      );

  TensorVector.fromTensor(this.tensor)
    : assert(tensor.layout.rank == 1, 'Expected a tensor of rank 1');

  final Tensor<T> tensor;

  @override
  DataType<T> get dataType => tensor.type;

  @override
  int get count => tensor.layout.shape[0];

  @override
  Set<Storage> get storage => {this};

  @override
  T getUnchecked(int index) =>
      tensor.data[tensor.layout.offset + tensor.layout.strides[0] * index];

  @override
  void setUnchecked(int index, T value) =>
      tensor.data[tensor.layout.offset + tensor.layout.strides[0] * index] =
          value;
}
