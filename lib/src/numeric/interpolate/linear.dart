import '../../../type.dart';
import '../../../vector.dart';
import '../../shared/checks.dart';
import '../functions.dart';
import 'binary_search.dart';

/// A function providing linear interpolation of a discrete monotonically
/// increasing set of sample points [xs] and [ys]. Returns [left] or [right],
/// if the point is outside the data range, by default extrapolate linearly.
///
/// See https://en.wikipedia.org/wiki/Linear_interpolation.
UnaryFunction<T> linearInterpolation<T>(
  DataType<T> dataType, {
  required Vector<T> xs,
  required Vector<T> ys,
  T? left,
  T? right,
}) {
  checkPoints(dataType, xs: xs, ys: ys, min: 1, ordered: true, unique: true);
  final add = dataType.field.add, sub = dataType.field.sub;
  final mul = dataType.field.mul, div = dataType.field.div;
  final ordering = dataType.ordering;
  final below = ordering.lessThan(xs.getUnchecked(0));
  final above = ordering.greaterThan(xs.getUnchecked(xs.count - 1));
  final slopes = Vector<T>.generate(
      dataType,
      xs.count - 1,
      (i) => div(sub(ys.getUnchecked(i + 1), ys.getUnchecked(i)),
          sub(xs.getUnchecked(i + 1), xs.getUnchecked(i))),
      format: VectorFormat.standard);
  return (T x) {
    if (below(x) && left != null) {
      return left;
    } else if (above(x) && right != null) {
      return right;
    } else {
      final index = ordering.binarySearchLeft(xs, x).clamp(1, xs.count - 1);
      return add(
          ys.getUnchecked(index - 1),
          mul(slopes.getUnchecked(index - 1),
              sub(x, xs.getUnchecked(index - 1))));
    }
  };
}
