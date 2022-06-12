import '../../../vector.dart';
import '../functions.dart';
import 'utils.dart';

/// A function providing linear interpolation of a discrete monotonically
/// increasing set of sample points [x] and [y]. Returns [left] or [right],
/// if the point is outside the data range.
///
/// See https://en.wikipedia.org/wiki/Linear_interpolation.
UnaryFunction<double> linearInterpolation({
  required Vector<double> x,
  required Vector<double> y,
  double left = double.nan,
  double right = double.nan,
}) {
  assert(x.count > 0 && y.count > 0, 'Expected $x and $y to be non-empty.');
  assert(x.count == y.count, 'Expected $x and $y to have consistent size.');
  return (double value) {
    if (value < x.getUnchecked(0)) {
      return left;
    } else if (x.getUnchecked(x.count - 1) < value) {
      return right;
    }
    final index = binarySearchLeft(x, value).clamp(1, x.count - 1);
    return y.getUnchecked(index - 1) +
        (y.getUnchecked(index) - y.getUnchecked(index - 1)) /
            (x.getUnchecked(index) - x.getUnchecked(index - 1)) *
            (value - x.getUnchecked(index - 1));
  };
}
