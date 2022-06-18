import '../../../type.dart';
import '../../../vector.dart';
import '../../shared/checks.dart';
import '../functions.dart';
import 'binary_search.dart';

/// A function providing linear interpolation of a discrete monotonically
/// increasing set of sample points [xs] and [ys]. Returns [left] or [right],
/// if the point is outside the data range.
///
/// See https://en.wikipedia.org/wiki/Linear_interpolation.
UnaryFunction<double> linearInterpolation({
  required Vector<double> xs,
  required Vector<double> ys,
  double left = double.nan,
  double right = double.nan,
}) {
  checkPoints(DataType.float,
      xs: xs, ys: ys, min: 1, ordered: true, unique: true);
  final slopes = Vector.generate(
      DataType.float,
      xs.count - 1,
      (i) =>
          (ys.getUnchecked(i + 1) - ys.getUnchecked(i)) /
          (xs.getUnchecked(i + 1) - xs.getUnchecked(i)),
      format: defaultVectorFormat);
  return (double x) {
    if (x < xs.getUnchecked(0)) {
      return left;
    } else if (xs.getUnchecked(xs.count - 1) < x) {
      return right;
    }
    final index = binarySearchLeft(xs, x).clamp(1, xs.count - 1);
    return ys.getUnchecked(index - 1) +
        slopes.getUnchecked(index - 1) * (x - xs.getUnchecked(index - 1));
  };
}
