import '../../type/type.dart';
import '../array.dart';

extension ToObjectArray<T> on Array<T> {
  /// Returns an object representing this array.
  ///
  /// Depending on its dimensionality this is a single value, a list of values,
  /// or a list of nested lists.
  dynamic toObject({DataType<T>? type}) =>
      _toObject(this, type: type ?? this.type, axis: 0, offset: offset);
}

dynamic _toObject<T>(Array<T> array,
    {required DataType<T> type, required int axis, required int offset}) {
  if (axis == array.dimensions) {
    return array.data[offset]; // return a single value
  }
  final shape = array.shape[axis];
  final stride = array.strides[axis];
  if (axis == array.dimensions - 1) {
    final list = type.newList(shape); // creates an optimal list
    for (var i = 0, j = offset; i < shape; i++, j += stride) {
      list[i] = array.data[j];
    }
    return list;
  }
  return List.generate(
      array.shape[axis],
      (i) => _toObject(array,
          type: type, axis: axis + 1, offset: offset + i * stride));
}
