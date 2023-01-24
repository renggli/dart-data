import '../vector.dart';

extension StatisticsExtension<T> on Vector<T> {
  /// Returns the index of the minimum element.
  int minimumIndex() {
    final isGreaterThan = dataType.equality.isGreaterThan;
    var index = 0;
    var min = getUnchecked(0);
    for (var i = 1; i < count; i++) {
      if (isGreaterThan(min, getUnchecked(i))) {
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
    final isLessThan = dataType.equality.isLessThan;
    var index = 0;
    var max = getUnchecked(0);
    for (var i = 1; i < count; i++) {
      if (isLessThan(max, getUnchecked(i))) {
        index = i;
        max = getUnchecked(i);
      }
    }
    return index;
  }

  /// Returns the value of the maximum element.
  T maximum() => getUnchecked(maximumIndex());
}
