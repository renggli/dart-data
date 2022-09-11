import '../../vector/vector.dart';

extension BinarySearchExtension<T> on Comparator<T> {
  /// Performs a binary search on the sorted [vector] with the value [value].
  ///
  /// Returns the first suitable insertion index such that
  /// `vector[result - 1] < value <= vector[result]`.
  int binarySearchLeft(Vector<T> vector, T value) {
    var min = 0;
    var max = vector.count;
    while (min < max) {
      final mid = min + ((max - min) >> 1);
      if (this(vector.getUnchecked(mid), value) < 0) {
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
  int binarySearchRight(Vector<T> vector, T value) {
    var min = 0;
    var max = vector.count;
    while (min < max) {
      final mid = min + ((max - min) >> 1);
      if (this(vector.getUnchecked(mid), value) <= 0) {
        min = mid + 1;
      } else {
        max = mid;
      }
    }
    return min;
  }
}
