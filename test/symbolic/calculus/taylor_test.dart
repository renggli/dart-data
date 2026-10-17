import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:test/test.dart';

void main() {
  const x = Variable('x');

  group('Power-series backed Taylor expansion', () {
    test('expands around integer, rationalizable double, and real points', () {
      final sinTaylor = Sin(x).taylorSeries('x', order: 5);
      check(sinTaylor.toString()).equals('x - 1/6 * x ^ 3 + 1/120 * x ^ 5');

      final lnTaylor = Ln(x).taylorSeries('x', around: 1, order: 3);
      check(lnTaylor.evaluate({'x': 1.1}))
          .isCloseTo(0.1 - 0.01 / 2 + 0.001 / 3, 1e-12);

      final rationalCenter = (x * x).taylorSeries('x', around: 0.5, order: 2);
      check(rationalCenter.evaluate({'x': 1.5})).isCloseTo(2.25, 1e-12);

      final realCenter = Sin(x).taylorSeries('x', around: math.pi, order: 3);
      check(realCenter.evaluate({'x': math.pi + 0.1}))
          .isCloseTo(math.sin(math.pi + 0.1), 1e-5);
    });
  });

  group('Derivative-based Taylor fallback', () {
    test('falls back to analytic derivatives when power series throws', () {
      final wAroundOne = LambertW(x).taylorSeries('x', around: 1, order: 2);
      check(wAroundOne.evaluate({'x': 1.05}))
          .isCloseTo(LambertW(x).evaluate({'x': 1.05}), 1e-4);

      final absPlusPi = Abs(x + Constant.pi)
          .taylorSeries('x', around: 0, order: 2);
      check(absPlusPi).equals(Constant.pi + x);

      final absMinusPi = Abs(x - Constant.pi)
          .taylorSeries('x', around: 0, order: 2);
      check(absMinusPi).equals(Constant.pi - x);

      final scaledShifted =
          (Abs(IntegerNumber.two * x + Constant.pi) - Constant.pi).taylorSeries(
            'x',
            around: 0,
            order: 2,
          );
      check(scaledShifted).equals(IntegerNumber.two * x);

      final zeroOrderZero =
          (LambertW(x + IntegerNumber.one) - LambertW(IntegerNumber.one))
              .taylorSeries('x', around: 0, order: 0);
      check(zeroOrderZero).equals(IntegerNumber.zero);

      final zeroOrderSingle = LambertW(x + IntegerNumber.one)
          .taylorSeries('x', around: 0, order: 0);
      check(zeroOrderSingle).equals(LambertW(IntegerNumber.one));
    });
  });
}
