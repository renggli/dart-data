import '../vector.dart';

extension StatisticsExtension<T> on Vector<T> {
  /// Returns the index of the minimum element.
  int minimumIndex() {
    var index = 0;
    var min = getUnchecked(0);
    for (var i = 1; i < count; i++) {
      if (dataType.comparator(min, getUnchecked(i)) > 0) {
        index = i;
        min = getUnchecked(i);
      }
    }
    return index;
  }

  /// Returns the value of the absolute minimum element.
  T minimum() => getUnchecked(minimumIndex());

  /// Returns the index of the maximum element.
  int maximumIndex() {
    var index = 0;
    var max = getUnchecked(0);
    for (var i = 1; i < count; i++) {
      if (dataType.comparator(max, getUnchecked(i)) < 0) {
        index = i;
        max = getUnchecked(i);
      }
    }
    return index;
  }

  /// Returns the value of the maximum element.
  T maximum() => getUnchecked(maximumIndex());
}
