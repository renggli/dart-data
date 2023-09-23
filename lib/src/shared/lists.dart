import 'dart:math' as math;

import '../../type.dart';

/// Initial length of fixed-length lists.
const initialListLength = 4;

/// Inserts an entry into a fixed-length list, possibly reallocates.
List<T> insertAt<T>(
    DataType<T> type, List<T> list, int length, int index, T value,
    {T? fillValue}) {
  if (list.length == length) {
    final newLength = 3 * length ~/ 2 + 1;
    final newList = type.newList(newLength);
    newList.setRange(0, index, list);
    newList[index] = value;
    newList.setRange(index + 1, length + 1, list, index);
    final paddingValue = fillValue ?? type.defaultValue;
    if (length + 1 < newList.length && paddingValue != newList[length + 1]) {
      newList.fillRange(length + 1, newLength, paddingValue);
    }
    return newList;
  }
  list.setRange(index + 1, length + 1, list, index);
  list[index] = value;
  return list;
}

/// Removes an entry from a fixed-length list, possibly reallocates.
List<T> removeAt<T>(DataType<T> type, List<T> list, int length, int index,
    {T? fillValue}) {
  if (2 * length < list.length) {
    final newLength = math.max(initialListLength, length - 1);
    if (newLength < list.length) {
      final newList = type.newList(newLength);
      newList.setRange(0, index, list);
      newList.setRange(index, length - 1, list, index + 1);
      final paddingValue = fillValue ?? type.defaultValue;
      if (length - 1 < newList.length && paddingValue != newList[length - 1]) {
        newList.fillRange(length - 1, newLength, paddingValue);
      }
      return newList;
    }
  }
  list.setRange(index, length - 1, list, index + 1);
  list[length - 1] = fillValue ?? type.defaultValue;
  return list;
}

/// Performs a binary search on the range of a sorted list.
int binarySearch<T extends Comparable<T>>(
    List<T> list, int min, int max, T value) {
  while (min < max) {
    final mid = min + ((max - min) >> 1);
    final comp = list[mid].compareTo(value);
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
