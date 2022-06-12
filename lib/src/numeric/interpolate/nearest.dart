import '../../../vector.dart';
import '../functions.dart';
import 'utils.dart';

/// A function providing the nearest value of a discrete monotonically
/// increasing set of sample points [x] and [y].
UnaryFunction<double> nearestInterpolation({
  required Vector<double> x,
  required Vector<double> y,
  bool preferLower = true,
}) {
  assert(x.count > 0 && y.count > 0, 'Expected $x and $y to be non-empty.');
  assert(x.count == y.count, 'Expected $x and $y to have consistent size.');
  return (double value) {
    if (value <= x.getUnchecked(0)) {
      return y.getUnchecked(0);
    } else if (x.getUnchecked(x.count - 1) <= value) {
      return y.getUnchecked(y.count - 1);
    }
    final index = binarySearchLeft(x, value).clamp(1, x.count - 1);
    final distanceLo = value - x.getUnchecked(index - 1);
    final distanceHi = x.getUnchecked(index) - value;
    if (distanceLo < distanceHi || (distanceLo == distanceHi && preferLower)) {
      return y.getUnchecked(index - 1);
    } else {
      return y.getUnchecked(index);
    }
  };
}
