import '../../../type.dart';
import '../../../vector.dart';
import '../../shared/validation.dart';
import '../functions.dart';
import 'binary_search.dart';

/// A function providing the previous value of a discrete monotonically
/// increasing set of sample points [xs] and [ys]. Returns [left] if there is
/// no previous sample point.
UnaryFunction<double> previousInterpolation({
  required Vector<double> xs,
  required Vector<double> ys,
  double left = double.nan,
}) {
  validatePoints(DataType.float,
      xs: xs, ys: ys, min: 1, ordered: true, unique: true);
  return (double x) {
    if (x < xs.getUnchecked(0)) {
      return left;
    } else if (xs.getUnchecked(xs.count - 1) < x) {
      return ys.getUnchecked(ys.count - 1);
    } else {
      return ys.getUnchecked(binarySearchRight(xs, x).clamp(1, xs.count) - 1);
    }
  };
}
