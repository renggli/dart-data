import '../../../type.dart';
import '../../../vector.dart';
import '../../shared/validation.dart';
import '../functions.dart';
import 'binary_search.dart';

/// A function providing the nearest value of a discrete monotonically
/// increasing set of sample points [xs] and [ys].
UnaryFunction<double> nearestInterpolation({
  required Vector<double> xs,
  required Vector<double> ys,
  bool preferLower = true,
}) {
  validatePoints(DataType.float,
      xs: xs, ys: ys, min: 1, ordered: true, unique: true);
  return (double x) {
    if (x <= xs.getUnchecked(0)) {
      return ys.getUnchecked(0);
    } else if (xs.getUnchecked(xs.count - 1) <= x) {
      return ys.getUnchecked(ys.count - 1);
    }
    final index = binarySearchLeft(xs, x).clamp(1, xs.count - 1);
    final distanceLo = x - xs.getUnchecked(index - 1);
    final distanceHi = xs.getUnchecked(index) - x;
    if (distanceLo < distanceHi || (distanceLo == distanceHi && preferLower)) {
      return ys.getUnchecked(index - 1);
    } else {
      return ys.getUnchecked(index);
    }
  };
}
