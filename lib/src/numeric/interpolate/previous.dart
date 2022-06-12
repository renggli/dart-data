import '../../../vector.dart';
import '../functions.dart';
import 'utils.dart';

/// A function providing the previous value of a discrete monotonically
/// increasing set of sample points [x] and [y]. Returns [left] if there is
/// no previous sample point.
UnaryFunction<double> previousInterpolation({
  required Vector<double> x,
  required Vector<double> y,
  double left = double.nan,
}) {
  assert(x.count > 0 && y.count > 0, 'Expected $x and $y to be non-empty.');
  assert(x.count == y.count, 'Expected $x and $y to have consistent size.');
  return (double value) {
    if (value < x.getUnchecked(0)) {
      return left;
    } else if (x.getUnchecked(x.count - 1) < value) {
      return y.getUnchecked(y.count - 1);
    }
    final index = binarySearchRight(x, value).clamp(1, x.count);
    return y.getUnchecked(index - 1);
  };
}
