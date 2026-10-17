import 'dart:typed_data';

import 'package:checks/checks.dart';
import 'package:data/linear.dart';
import 'package:data/symbolic.dart';
import 'package:more/number.dart' show Complex;
import 'package:test/test.dart';

void main() {
  group('Symbolic compiler', () {
    test('toFunction1D and toComplexFunction1D evaluate accurately', () {
      final f = Expr.parse('x^3 - 2*x + 1').toFunction1D('x');
      check(f(2.0)).equals(5.0);

      final cf = Expr.parse('exp(i * x)').toComplexFunction1D('x');
      final val = cf(const Complex(0.0));
      check(val.a).isCloseTo(1.0, 1e-12);
      check(val.b).isCloseTo(0.0, 1e-12);
    });

    test('toVectorFunction, compile, and compileTensorKernel evaluate multivariable expressions', () {
      final expr = Expr.parse('x^2 + 2*y');
      final vfn = expr.toVectorFunction(['x', 'y']);
      check(vfn(Vector.fromList([3.0, 4.0]))).equals(17.0);

      final cfn = expr.compile(['x', 'y']);
      check(cfn([3.0, 4.0])).equals(17.0);

      final kernel = expr.compileTensorKernel(['x', 'y']);
      final out = Float64List(2);
      kernel([
        Float64List.fromList([1.0, 3.0]),
        Float64List.fromList([2.0, 4.0]),
      ], out);
      check(out[0]).equals(5.0);
      check(out[1]).equals(17.0);
    });
  });
}
