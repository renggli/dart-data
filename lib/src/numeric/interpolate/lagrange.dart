import '../../../polynomial.dart';
import '../../../type.dart';
import '../../../vector.dart';
import '../functions.dart';
import 'utils.dart';

/// A function providing a lagrange polynomial interpolation through unique
/// sample points [xs] and [ys].
///
/// See https://en.wikipedia.org/wiki/Lagrange_polynomial.
UnaryFunction<T> lagrangeInterpolation<T>(
  DataType<T> dataType, {
  required Vector<T> xs,
  required Vector<T> ys,
}) {
  validateCoordinates<T>(dataType, xs: xs, ys: ys, min: 1, unique: true);
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

///
///
/// See https://en.wikipedia.org/wiki/Lagrange_polynomial.
Polynomial<T> lagrangePolynomialInterpolation<T>(DataType<T> dataType,
    {required Vector<T> x, required Vector<T> y}) {
  assert(x.count == y.count, 'Expected $x and $y to have consistent size.');

  var result = Polynomial<T>(dataType);

  for (var i = 0; i < x.count; i++) {
    var p = x.getUnchecked(i);
    var c = y.getUnchecked(i);
    final roots = <T>[];
    for (var j = 0; j < x.count; j++) {
      if (j != i) {
        c = dataType.field.div(c, dataType.field.sub(p, x.getUnchecked(j)));
        roots.add(x.getUnchecked(j));
      }
    }
    final coefficients = Polynomial.fromRoots(dataType, roots);
    // [
    //   dataType.field.multiplicativeIdentity,
    //   ...Polynomial.fromRoots(dataType, roots).toList(),
    // ];
    for (var j = 0; j <= coefficients.degree; j++) {
      result.setUnchecked(
          j,
          dataType.field.add(
              result.getUnchecked(j),
              dataType.field.scale(
                  dataType.field.mul(c, coefficients.getUnchecked(j)),
                  j.isOdd ? -1 : 1)));
    }
  }
  return result;
}
