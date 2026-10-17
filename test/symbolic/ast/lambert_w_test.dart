import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:more/number.dart' show Complex;
import 'package:test/test.dart';

void main() {
  group('LambertW AST construction and traversal', () {
    test('symbolic construction, branch selection, and exact identities', () {
      const x = Variable('x');
      const y = Variable('y');
      final w0 = LambertW(x);
      final wm1 = LambertW(x, branch: -1);

      check(w0.branch).equals(0);
      check(wm1.branch).equals(-1);
      check(w0.freeVariables).unorderedEquals(['x']);
      check(w0.dependsOn('x')).isTrue();
      check(w0.dependsOn('y')).isFalse();
      check(w0.substitute('x', y)).equals(LambertW(y));
      check(wm1.substitute('x', y)).equals(LambertW(y, branch: -1));
      check(w0.mapChildren((_) => y)).equals(LambertW(y));
      check(wm1.mapChildren((_) => y)).equals(LambertW(y, branch: -1));
      check(w0.anyNode((e) => e == x)).isTrue();
      check(w0 == wm1).isFalse();
      check(w0).equals(LambertW(x));
      check(w0.hashCode).equals(LambertW(x).hashCode);
      check(wm1.hashCode).equals(LambertW(x, branch: -1).hashCode);

      check(LambertW(IntegerNumber.zero).simplify()).equals(IntegerNumber.zero);
      check(LambertW(Constant.e).simplify()).equals(IntegerNumber.one);
      check(
        LambertW(
          Mul([
            IntegerNumber.negativeOne,
            Pow(Constant.e, IntegerNumber.negativeOne),
          ]),
        ).simplify(),
      ).equals(IntegerNumber.negativeOne);
      check(
        LambertW(
          Mul([
            IntegerNumber.negativeOne,
            Pow(Constant.e, IntegerNumber.negativeOne),
          ]),
          branch: -1,
        ).simplify(),
      ).equals(IntegerNumber.negativeOne);
    });
  });

  group('LambertW numerical evaluation', () {
    test('real evaluation on principal and -1 branches', () {
      const x = Variable('x');
      final w0 = LambertW(x);
      final wm1 = LambertW(x, branch: -1);

      check(w0.evaluate({'x': 0.0})).equals(0.0);
      check(w0.evaluate({'x': math.e})).isCloseTo(1.0, 1e-14);
      final w1 = w0.evaluate({'x': 1.0});
      check(w1 * math.exp(w1)).isCloseTo(1.0, 1e-14);

      final w2 = w0.evaluate({'x': 2.0});
      check(w2 * math.exp(w2)).isCloseTo(2.0, 1e-14);

      final wm1Val = wm1.evaluate({'x': -0.2});
      check(wm1Val).isLessThan(-1.0);
      check(wm1Val * math.exp(wm1Val)).isCloseTo(-0.2, 1e-13);

      // Out of real domain returns NaN
      check(w0.evaluate({'x': -0.5}).isNaN).isTrue();
      check(wm1.evaluate({'x': 0.5}).isNaN).isTrue();
    });

    test('evaluateComplex on real-embedded complex argument', () {
      const z = Complex(1.0);
      final w = LambertW(const Variable('x')).evaluateComplex({'x': z});
      final checkZ = w * w.exp();
      check(checkZ.a).isCloseTo(z.a, 1e-12);
      check(checkZ.b).isCloseTo(0.0, 1e-12);
    });
  });
}
