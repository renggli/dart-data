import '../../type/type.dart';
import '../tensor.dart';

extension ToObjectTensor<T> on Tensor<T> {
  /// Returns an object representing this tensor.
  ///
  /// Depending on its dimensionality this is a single value, a list of values,
  /// or a list of nested lists.
  dynamic toObject({DataType<T>? type}) =>
      _toObject(this, type: type ?? this.type, axis: 0, offset: layout.offset);
}

dynamic _toObject<T>(Tensor<T> tensor,
    {required DataType<T> type, required int axis, required int offset}) {
  if (axis == tensor.rank) {
    return tensor.data[offset]; // return a single value
  }
  final shape = tensor.layout.shape[axis];
  final stride = tensor.layout.strides[axis];
  if (axis == tensor.rank - 1) {
    final list = type.newList(shape); // creates an optimal list
    for (var i = 0, j = offset; i < shape; i++, j += stride) {
      list[i] = tensor.data[j];
    }
    return list;
  }
  return List.generate(
      tensor.layout.shape[axis],
      (i) => _toObject(tensor,
          type: type, axis: axis + 1, offset: offset + i * stride));
}
