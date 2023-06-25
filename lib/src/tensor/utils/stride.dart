import '../../../type.dart';

/// Constructs the strides from an `iterable`.
List<int> fromIterable(Iterable<int> iterable) =>
    DataType.integer.copyList(iterable, readonly: true);

/// Computes the default strides from a `shape`.
List<int> fromShape(List<int> shape) {
  final result = DataType.index.newList(shape.length, fillValue: 1);
  for (var i = result.length - 1; i > 0; i--) {
    result[i - 1] = result[i] * shape[i];
  }
  return fromIterable(result);
}

/// Tests if the given shape and stride combination is contiguous.
bool isContiguous({required List<int> shape, required List<int> stride}) {
  for (var i = shape.length - 1, p = 1; i >= 0; i--) {
    if (shape[i] != 1) {
      if (stride[i] == p) {
        p *= shape[i];
      } else {
        return false;
      }
    }
  }
  return true;
}
