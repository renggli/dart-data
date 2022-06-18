import '../../../vector.dart';
import '../../shared/config.dart';
import '../functions.dart';
import 'utils.dart';

/// A function providing the next value of a discrete monotonically
/// increasing set of sample points [xs] and [ys]. Returns [right] if there is
/// no next sample point.
UnaryFunction<double> nextInterpolation({
  required Vector<double> xs,
  required Vector<double> ys,
  double right = double.nan,
}) {
  validateCoordinates(floatDataType,
      xs: xs, ys: ys, min: 1, ordered: true, unique: true);
  return (double x) {
    if (x < xs.getUnchecked(0)) {
      return ys.getUnchecked(0);
    } else if (xs.getUnchecked(xs.count - 1) < x) {
      return right;
    }
    final index = binarySearchLeft(xs, x).clamp(0, xs.count - 1);
    return ys.getUnchecked(index);
  };
}
