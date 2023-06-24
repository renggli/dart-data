import '../../../type.dart';

/// Constructs the strides from a list.
List<int> fromIterable(Iterable<int> strides) =>
    DataType.index.copyList(strides, readonly: true);

/// Constructs the default strides from the given shape.
List<int> fromShape(List<int> shape) {
  final result = DataType.index.newList(shape.length, fillValue: 1);
  for (var i = result.length - 1; i > 0; i--) {
    result[i - 1] = result[i] * shape[i];
  }
  return fromIterable(result);
}
