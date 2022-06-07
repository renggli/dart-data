import 'package:more/ordering.dart';

import '../../../vector.dart';

/// A function object providing linear interpolation of a discrete monotonically
/// increasing set of sample points [x] and [y].
///
/// See https://en.wikipedia.org/wiki/Linear_interpolation.
class LinearInterpolation {
  LinearInterpolation({
    required this.x,
    required this.y,
    this.left,
    this.right,
  });

  /// The x-coordinates of the data points in monotonically increasing order.
  final Vector<double> x;

  /// The y-coordinates of the data points.
  final Vector<double> y;

  /// Value to return for values smaller than `x[0]`, if undefined `y[0]` is
  /// returned.
  final double? left;

  /// Value to return for values larger than `x[x.length - 1]`, if undefined
  /// `y[y.length - 1]` is returned.
  final double? right;

  /// Evaluates the interpolation at [value].
  double call(double value) {
    if (value < x[0]) {
      return left ?? y[0];
    } else if (x[x.count - 1] < value) {
      return right ?? y[y.count - 1];
    }
    final index = _binarySearch(value);
    if (index < 0) {
      final i = -index - 2;
      return y[i] + (y[i + 1] - y[i]) / (x[i + 1] - x[i]) * (value - x[i]);
    } else {
      return y[index];
    }
  }

  int _binarySearch(double value) {
    var min = 0;
    var max = x.count;
    while (min < max) {
      final mid = min + ((max - min) >> 1);
      final comp = x.getUnchecked(mid).compareTo(value);
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
}

final o = Ordering.natural().binarySearch([], 1.0);
