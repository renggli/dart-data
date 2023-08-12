import 'package:collection/collection.dart';

import '../../../type.dart';

const indicesEquality = ListEquality<int>();

List<int> toIndices(Iterable<int> iterable) =>
    DataType.integer.copyList(iterable, readonly: true);

List<int> toStrides({required List<int> shape}) {
  final result = DataType.integer.newList(shape.length, fillValue: 1);
  for (var i = result.length - 1; i > 0; i--) {
    result[i - 1] = result[i] * shape[i];
  }
  return toIndices(result);
}

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
