import '../../../vector.dart';
import '../functions.dart';
import 'utils.dart';

/// A function providing the next value of a discrete monotonically
/// increasing set of sample points [x] and [y]. Returns [right] if there is
/// no next sample point.
UnaryFunction<double> nextInterpolation({
  required Vector<double> x,
  required Vector<double> y,
  double right = double.nan,
}) {
  assert(x.count > 0 && y.count > 0, 'Expected $x and $y to be non-empty.');
  assert(x.count == y.count, 'Expected $x and $y to have consistent size.');
  return (double value) {
    if (value < x.getUnchecked(0)) {
      return y.getUnchecked(0);
    } else if (x.getUnchecked(x.count - 1) < value) {
      return right;
    }
    final index = binarySearchLeft(x, value).clamp(0, x.count - 1);
    return y.getUnchecked(index);
  };
}
