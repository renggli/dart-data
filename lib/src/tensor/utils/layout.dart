import 'package:collection/collection.dart';

import '../../../type.dart';

/// Comparator for list indices.
const indicesEquality = ListEquality<int>();

/// Converts an iterable of ints to an efficient read-only list.
List<int> toIndices(Iterable<int> iterable) =>
    DataType.integer.copyList(iterable, readonly: true);

/// Converts a shape list to a stride list.
List<int> toStrides({required List<int> shape}) {
  final result = DataType.integer.newList(shape.length, fillValue: 1);
  for (var i = result.length - 1; i > 0; i--) {
    result[i - 1] = result[i] * shape[i];
  }
  return toIndices(result);
}

/// Returns `true`, if the [shape] and [strides] result in a tensor where
/// the values are in a contiguous sequence.
bool isContiguous({required List<int> shape, required List<int> strides}) {
  for (var i = shape.length - 1, p = 1; i >= 0; i--) {
    if (shape[i] != 1) {
      if (strides[i] == p) {
        p *= shape[i];
      } else {
        return false;
      }
    }
  }
  return true;
}
