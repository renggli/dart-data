import '../../vector/vector.dart';

/// Performs a binary search on the sorted [vector] with the value [value].
///
/// Returns the first suitable insertion index such that
/// `vector[result - 1] < value <= vector[result]`.
int binarySearchLeft(Vector<double> vector, double value) {
  var min = 0;
  var max = vector.count;
  while (min < max) {
    final mid = min + ((max - min) >> 1);
    if (vector.getUnchecked(mid).compareTo(value) < 0) {
      min = mid + 1;
    } else {
      max = mid;
    }
  }
  return min;
}

/// Performs a binary search on the sorted [vector] with the value [value].
///
/// Returns the first suitable insertion index such that
/// `vector[result - 1] <= value < vector[result]`.
int binarySearchRight(Vector<double> vector, double value) {
  var min = 0;
  var max = vector.count;
  while (min < max) {
    final mid = min + ((max - min) >> 1);
    if (vector.getUnchecked(mid).compareTo(value) <= 0) {
      min = mid + 1;
    } else {
      max = mid;
    }
  }
  return min;
}
