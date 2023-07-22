import '../../data.dart';

abstract class TensorIterator<T> implements Iterator<T> {
  /// Returns the iterated tensor.
  Tensor<T> get tensor;

  /// Returns the current indices.
  List<int> get currentIndices;

  /// Returns the current offset.
  int get currentOffset;
}

class EmptyTensorIterator<T> implements TensorIterator<T> {
  EmptyTensorIterator(this.tensor);

  @override
  final Tensor<T> tensor;

  @override
  T get current => _throw();

  @override
  List<int> get currentIndices => _throw();

  @override
  int get currentOffset => _throw();

  @override
  bool moveNext() => false;

  Never _throw() => throw StateError('Empty tensor: $tensor');
}

// TODO: provide more efficient implementation
typedef ContiguousTensorIterator<T> = GenericTensorIterator<T>;

class GenericTensorIterator<T> implements TensorIterator<T> {
  GenericTensorIterator(this.tensor)
      : _indices = DataType.index.newList(tensor.rank, fillValue: 0),
        _offset = tensor.offset - tensor.stride.last {
    _indices.last = -1;
  }

  @override
  final Tensor<T> tensor;

  final List<int> _indices;
  int _offset;

  @override
  T get current => tensor.data[_offset];

  @override
  List<int> get currentIndices => _indices;

  @override
  int get currentOffset => _offset;

  @override
  bool moveNext() {
    for (var i = tensor.rank - 1; i >= 0; i--) {
      _indices[i]++;
      _offset += tensor.stride[i];
      if (_indices[i] < tensor.shape[i]) return true;
      _indices[i] = 0;
      _offset -= tensor.shape[i] * tensor.stride[i];
    }
    return false;
  }
}
