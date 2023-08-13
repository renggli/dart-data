import '../../../type.dart';
import '../../shared/storage.dart';
import '../../tensor/tensor.dart';
import '../matrix.dart';

/// Tensor matrix.
class TensorMatrix<T> with Matrix<T> {
  TensorMatrix(DataType<T> dataType, int rowCount, int colCount)
      : this.fromTensor(Tensor<T>.filled(dataType.defaultValue,
            type: dataType, shape: [rowCount, colCount]));

  TensorMatrix.fromTensor(this.tensor)
      : assert(tensor.layout.rank == 2, 'Expected a tensor of rank 2');

  final Tensor<T> tensor;

  @override
  DataType<T> get dataType => tensor.type;

  @override
  int get rowCount => tensor.layout.shape[0];

  @override
  int get colCount => tensor.layout.shape[1];

  @override
  Set<Storage> get storage => {this};

  @override
  T getUnchecked(int row, int col) => tensor.data[tensor.layout.offset +
      tensor.layout.strides[0] * row +
      tensor.layout.strides[1] * col];

  @override
  void setUnchecked(int row, int col, T value) =>
      tensor.data[tensor.layout.offset +
          tensor.layout.strides[0] * row +
          tensor.layout.strides[1] * col] = value;
}
