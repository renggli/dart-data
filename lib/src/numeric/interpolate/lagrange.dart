import '../../../type.dart';
import '../../../vector.dart';
import '../../shared/checks.dart';
import '../functions.dart';

/// A function providing a Lagrange polynomial interpolation through the unique
/// sample points [xs] and [ys]. Related to [Polynomial.lagrange].
///
/// See https://en.wikipedia.org/wiki/Lagrange_polynomial.
UnaryFunction<T> lagrangeInterpolation<T>(
  DataType<T> dataType, {
  required Vector<T> xs,
  required Vector<T> ys,
}) {
  checkPoints<T>(dataType, xs: xs, ys: ys, min: 1, unique: true);
  final addId = dataType.field.additiveIdentity;
  final add = dataType.field.add, sub = dataType.field.sub;
  final mulId = dataType.field.multiplicativeIdentity;
  final mul = dataType.field.mul, div = dataType.field.div;
  final l = Vector<T>.constant(dataType, xs.count,
      value: mulId, format: defaultVectorFormat);
  for (var i = 0; i < xs.count; i++) {
    final xi = xs.getUnchecked(i);
    for (var k = 0; k < xs.count; k++) {
      if (k != i) {
        l.setUnchecked(i, mul(l.getUnchecked(i), sub(xi, xs.getUnchecked(k))));
      }
    }
    l.setUnchecked(i, div(mulId, l.getUnchecked(i)));
  }
  return (x) {
    var a = addId, b = addId;
    for (var i = 0; i < xs.count; i++) {
      final xi = xs.getUnchecked(i);
      if (x == xi) {
        return ys.getUnchecked(i);
      }
      final s = div(l.getUnchecked(i), sub(x, xi));
      b = add(b, s);
      a = add(a, mul(s, ys.getUnchecked(i)));
    }
    return div(a, b);
  };
}
