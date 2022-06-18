import '../../../vector.dart';
import '../../shared/config.dart';
import '../functions.dart';
import 'utils.dart';

/// A function providing the previous value of a discrete monotonically
/// increasing set of sample points [xs] and [ys]. Returns [left] if there is
/// no previous sample point.
UnaryFunction<double> previousInterpolation({
  required Vector<double> xs,
  required Vector<double> ys,
  double left = double.nan,
}) {
  validateCoordinates(floatDataType,
      xs: xs, ys: ys, min: 1, ordered: true, unique: true);
  return (double x) {
    if (x < xs.getUnchecked(0)) {
      return left;
    } else if (xs.getUnchecked(xs.count - 1) < x) {
      return ys.getUnchecked(ys.count - 1);
    }
    final index = binarySearchRight(xs, x).clamp(1, xs.count);
    return ys.getUnchecked(index - 1);
  };
}
