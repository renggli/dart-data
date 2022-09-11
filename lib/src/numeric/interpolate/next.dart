import '../../../type.dart';
import '../../../vector.dart';
import '../../shared/checks.dart';
import '../functions.dart';
import 'binary_search.dart';

/// A function providing the next value of a discrete monotonically
/// increasing set of sample points [xs] and [ys]. Returns [right] if there is
/// no next sample point.
UnaryFunction<double> nextInterpolation({
  required Vector<double> xs,
  required Vector<double> ys,
  double right = double.nan,
}) {
  checkPoints(DataType.float,
      xs: xs, ys: ys, min: 1, ordered: true, unique: true);
  return (double x) {
    if (x < xs.getUnchecked(0)) {
      return ys.getUnchecked(0);
    } else if (xs.getUnchecked(xs.count - 1) < x) {
      return right;
    } else {
      return ys.getUnchecked(DataType.float.comparator
          .binarySearchLeft(xs, x)
          .clamp(0, xs.count - 1));
    }
  };
}
