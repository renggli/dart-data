import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:test/scaffolding.dart';

void main() {
  const x = Variable('x');

  group('Piecewise differentiation', () {
    test('differentiates each branch independently', () {
      const pw = Piecewise([
        (LessThan(x, RationalNumber.zero), Neg(x)),
        (GreaterEqual(x, RationalNumber.zero), x),
      ]);

      final dpw = pw.derivative('x').simplify();
      check(dpw).isA<Piecewise>();
      check(dpw.evaluate({'x': -2.0})).equals(-1.0);
      check(dpw.evaluate({'x': 3.0})).equals(1.0);
    });

    test('differentiates otherwise branch', () {
      const pw = Piecewise([
        (LessThan(x, RationalNumber.zero), RationalNumber(5)),
      ], otherwise: Mul(RationalNumber(3), x));

      final dpw = pw.derivative('x').simplify();
      check(dpw.evaluate({'x': -4.0})).equals(0.0);
      check(dpw.evaluate({'x': 2.0})).equals(3.0);
    });
  });

  group('Piecewise C^0 integration with boundary matching', () {
    test('continuous integral of absolute value |x|', () {
      const pw = Piecewise([
        (LessThan(x, RationalNumber.zero), Neg(x)),
        (GreaterEqual(x, RationalNumber.zero), x),
      ]);

      final anti = pw.integrate('x').simplify();
      check(anti).isA<Piecewise>();

      // Evaluates continuously at boundary x = 0
      check(anti.evaluate({'x': -2.0}))
          .isCloseTo(-2.0, 1e-12); // -x^2/2 -> -(-2)^2/2 = -2.0
      check(anti.evaluate({'x': 0.0})).isCloseTo(0.0, 1e-12);
      check(anti.evaluate({'x': 2.0})).isCloseTo(2.0, 1e-12); // x^2/2 -> 2.0
    });

    test('step function boundary matching at x = 1', () {
      // f(x) = 2 for x < 1, 3 for x >= 1
      const pw = Piecewise([
        (LessThan(x, RationalNumber.one), RationalNumber(2)),
        (GreaterEqual(x, RationalNumber.one), RationalNumber(3)),
      ]);

      final anti = pw.integrate('x').simplify();
      check(anti).isA<Piecewise>();

      // Left branch at x = 1: 2*1 = 2
      // Right branch at x = 1: 3*1 - 1 = 2
      check(anti.evaluate({'x': 0.5})).isCloseTo(1.0, 1e-12);
      check(anti.evaluate({'x': 1.0})).isCloseTo(2.0, 1e-12);
      check(anti.evaluate({'x': 2.0})).isCloseTo(5.0, 1e-12); // 3*2 - 1 = 5
    });

    test('3-interval C^0 boundary matching at x = 0 and x = 2', () {
      // f(x) = 1 for x < 0, 2x + 1 for x < 2, 5 for x >= 2
      const pw = Piecewise([
        (LessThan(x, RationalNumber.zero), RationalNumber.one),
        (
          LessThan(x, RationalNumber(2)),
          Add(Mul(RationalNumber(2), x), RationalNumber.one),
        ),
      ], otherwise: RationalNumber(5));

      final anti = pw.integrate('x').simplify();
      check(anti).isA<Piecewise>();

      // Check values and continuity across both internal boundaries
      // Boundary 1: x = 0
      check(anti.evaluate({'x': -1.0})).isCloseTo(-1.0, 1e-12);
      check(anti.evaluate({'x': -1e-8})).isCloseTo(0.0, 1e-6);
      check(anti.evaluate({'x': 0.0})).isCloseTo(0.0, 1e-12);
      check(anti.evaluate({'x': 1e-8})).isCloseTo(0.0, 1e-6);

      // Boundary 2: x = 2 (left: 2^2 + 2 = 6, right: 5*2 - 4 = 6)
      check(anti.evaluate({'x': 1.0})).isCloseTo(2.0, 1e-12);
      check(anti.evaluate({'x': 2.0 - 1e-8})).isCloseTo(6.0, 1e-6);
      check(anti.evaluate({'x': 2.0})).isCloseTo(6.0, 1e-12);
      check(anti.evaluate({'x': 2.0 + 1e-8})).isCloseTo(6.0, 1e-6);
      check(anti.evaluate({'x': 3.0})).isCloseTo(11.0, 1e-12); // 5*3 - 4 = 11
    });

    test('4-interval C^0 boundary matching across x = -1, 1, 3', () {
      const pw = Piecewise([
        (LessThan(x, RationalNumber.negativeOne), RationalNumber(2)),
        (LessThan(x, RationalNumber.one), RationalNumber(4)),
        (LessThan(x, RationalNumber(3)), RationalNumber(6)),
      ], otherwise: RationalNumber(8));

      final anti = pw.integrate('x').simplify();
      check(anti).isA<Piecewise>();

      // Boundary x = -1: 2*(-1) = -2
      check(anti.evaluate({'x': -2.0})).isCloseTo(-4.0, 1e-12);
      check(anti.evaluate({'x': -1.0})).isCloseTo(-2.0, 1e-12);

      // Boundary x = 1: 4*1 + 2 = 6
      check(anti.evaluate({'x': 0.0})).isCloseTo(2.0, 1e-12);
      check(anti.evaluate({'x': 1.0})).isCloseTo(6.0, 1e-12);

      // Boundary x = 3: 6*3 = 18
      check(anti.evaluate({'x': 2.0})).isCloseTo(12.0, 1e-12);
      check(anti.evaluate({'x': 3.0})).isCloseTo(18.0, 1e-12);

      // Beyond x = 3: 8*4 - 6 = 26
      check(anti.evaluate({'x': 4.0})).isCloseTo(26.0, 1e-12);
    });
  });
}
