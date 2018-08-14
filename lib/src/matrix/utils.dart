library data.matrix.utils;

import 'dart:math' as math;

import 'package:data/type.dart';

/// Integer data type to index column and row indexes.
const DataType<int> indexDataType = DataType.uint32;

/// Floating data type for numeric matrices.
const DataType<double> valueDataType = DataType.float64;

/// Performs a binary search on the range of a sorted list.
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

/// Initial size of fixed-length lists.
const int initialListSize = 4;

/// Inserts an entry into a fixed-length list, possibly reallocates.
List<T> insertAt<T>(
    DataType<T> type, List<T> list, int length, int index, T value) {
  if (list.length == length) {
    final newList = type.newList(2 * length);
    newList.setRange(0, index, list);
    newList[index] = value;
    newList.setRange(index + 1, length + 1, list, index);
    return newList;
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

/// sqrt(a^2 + b^2) without under/overflow. **/
double hypot(double a, double b) {
  if (a.abs() > b.abs()) {
    final r = b / a;
    return a.abs() * math.sqrt(1 + r * r);
  } else if (b != 0) {
    final r = a / b;
    return b.abs() * math.sqrt(1 + r * r);
  } else {
    return 0.0;
  }
}
