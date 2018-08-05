library data.matrix.utils;

import 'package:data/type.dart';

int binarySearch<T extends num>(List<T> list, int min, int max, T value) {
  while (min < max) {
    final mid = min + ((max - min) >> 1);
    final comp = list[mid] - value;
    if (comp == 0) {
      return mid;
    } else if (comp < 0) {
      min = mid + 1;
    } else {
      max = mid;
    }
  }
  return -min - 1;
}

/// Inserts an entry into a fixed-length list, possibly reallocates.
List<T> insertAt<T>(
    DataType<T> type, List<T> list, int length, int index, T value) {
  if (list.length == length) {
    final updatedList = type.newList(2 * length);
    updatedList.setRange(0, index, list);
    updatedList[index] = value;
    updatedList.setRange(index + 1, length + 1, list, index);
    return updatedList;
  } else {
    list.setRange(index + 1, length + 1, list, index);
    list[index] = value;
    return list;
  }
}

/// Removes an entry from a fixed-length list.
List<T> removeAt<T>(DataType<T> type, List<T> list, int length, int index) {
  list.setRange(index, length - 1, list, index + 1);
  list[length] = type.nullValue;
  return list;
}
