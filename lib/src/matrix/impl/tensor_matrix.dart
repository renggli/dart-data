import '../../../type.dart';
import '../../shared/storage.dart';
import '../../tensor/tensor.dart';
import '../matrix.dart';

/// Tensor matrix.
class TensorMatrix<T> with Matrix<T> {
  TensorMatrix(DataType<T> dataType, int rowCount, int colCount)
      : _tensor = Tensor<T>.filled(dataType.defaultValue,
            type: dataType, shape: [rowCount, colCount]);

  final Tensor<T> _tensor;

  @override
  DataType<T> get dataType => _tensor.type;

  @override
  int get rowCount => _tensor.layout.shape[0];

  @override
  int get colCount => _tensor.layout.shape[1];

  @override
  Set<Storage> get storage => {this};

  @override
  T getUnchecked(int row, int col) => _tensor.data[_tensor.layout.offset +
      _tensor.layout.strides[0] * row +
      _tensor.layout.strides[1] * col];

  @override
  void setUnchecked(int row, int col, T value) =>
      _tensor.data[_tensor.layout.offset +
          _tensor.layout.strides[0] * row +
          _tensor.layout.strides[1] * col] = value;
}
