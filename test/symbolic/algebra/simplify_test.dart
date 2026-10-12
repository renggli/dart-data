import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:test/scaffolding.dart';

void main() {
  const x = Variable('x');
  const y = Variable('y');

  group('SimplifierExtension - field axioms & arithmetic', () {
    test('additive identities and constant folding', () {
      check((x + 0).simplify()).equals(x);
      check((const RationalNumber(0) + x).simplify()).equals(x);
      check((x - 0).simplify()).equals(x);
      check((const RationalNumber(0) - x).simplify()).equals(-x);
      check((x - x).simplify()).equals(RationalNumber.zero);
      check((const RationalNumber(3) + const RationalNumber(4)).simplify())
          .equals(const RationalNumber(7));
      check((const RationalNumber(5) - const RationalNumber(2)).simplify())
          .equals(const RationalNumber(3));
      check((x + x).simplify()).equals(const RationalNumber(2) * x);
      check((x * 3 - x).simplify()).equals(const RationalNumber(2) * x);
    });

    test('multiplicative identities and annihilators', () {
      check((x * 0).simplify()).equals(RationalNumber.zero);
      check((RationalNumber.zero * x).simplify()).equals(RationalNumber.zero);
      check((x * 1).simplify()).equals(x);
      check((RationalNumber.one * x).simplify()).equals(x);
      check((x * -1).simplify()).equals(-x);
      check((RationalNumber.negativeOne * x).simplify()).equals(-x);
      check((const RationalNumber(3) * const RationalNumber(4)).simplify())
          .equals(const RationalNumber(12));
    });

    test('division identities', () {
      check((x / 1).simplify()).equals(x);
      check((x / x).simplify()).equals(RationalNumber.one);
      check((RationalNumber.zero / x).simplify()).equals(RationalNumber.zero);
      check((const RationalNumber(6) / const RationalNumber(2)).simplify())
          .equals(const RationalNumber(3));
      check((x / const RationalNumber(2)).simplify())
          .equals(const RationalNumber(1, 2) * x);
    });
  });

  group('SimplifierExtension - powers and exponentials', () {
    test('power identities', () {
      check(x.pow(0).simplify()).equals(RationalNumber.one);
      check(x.pow(1).simplify()).equals(x);
      check(const RationalNumber(1).pow(x).simplify())
          .equals(RationalNumber.one);
      check(const RationalNumber(2).pow(3).simplify())
          .equals(const RationalNumber(8));
      check((x.pow(2) * x.pow(3)).simplify()).equals(x.pow(5));
      check((x.pow(5) / x.pow(2)).simplify()).equals(x.pow(3));
    });

    test('involution square root of square is absolute value', () {
      final xSq = x.pow(2);
      final sqrtXSq = xSq.pow(const RationalNumber(1, 2));
      check(sqrtXSq.simplify()).equals(const Abs(x));
    });

    test('exponential and logarithm inverses', () {
      check(const Exp(Ln(x)).simplify()).equals(x);
      check(const Ln(Exp(x)).simplify()).equals(x);
      check(Ln(x.pow(3)).simplify())
          .equals(const RationalNumber(3) * const Ln(x));
    });
  });

  group('SimplifierExtension - trigonometric & hyperbolic identities', () {
    test('Pythagorean identity: sin^2(x) + cos^2(x) = 1', () {
      final sinSq = const Sin(x).pow(2);
      final cosSq = const Cos(x).pow(2);
      check((sinSq + cosSq).simplify()).equals(RationalNumber.one);
    });

    test('Pythagorean variations: 1 - sin^2(x) = cos^2(x)', () {
      final sinSq = const Sin(x).pow(2);
      check((const RationalNumber(1) - sinSq).simplify())
          .equals(const Cos(x).pow(2));
    });

    test('Pythagorean variations: 1 - cos^2(x) = sin^2(x)', () {
      final cosSq = const Cos(x).pow(2);
      check((const RationalNumber(1) - cosSq).simplify())
          .equals(const Sin(x).pow(2));
    });

    test('Hyperbolic Pythagorean: cosh^2(x) - sinh^2(x) = 1', () {
      final coshSq = const Cosh(x).pow(2);
      final sinhSq = const Sinh(x).pow(2);
      check((coshSq - sinhSq).simplify()).equals(RationalNumber.one);
    });

    test('trigonometric and hyperbolic parity', () {
      check(Sin(-x).simplify()).equals(-const Sin(x));
      check(Cos(-x).simplify()).equals(const Cos(x));
      check(Tan(-x).simplify()).equals(-const Tan(x));
      check(Sinh(-x).simplify()).equals(-const Sinh(x));
      check(Cosh(-x).simplify()).equals(const Cosh(x));
      check(Tanh(-x).simplify()).equals(-const Tanh(x));
    });
  });

  group('SimplifierExtension - logarithm combining', () {
    test('sum of logarithms: ln(x) + ln(y) = ln(x * y)', () {
      check((const Ln(x) + const Ln(y)).simplify()).equals(Ln(x * y));
    });

    test('difference of logarithms: ln(x) - ln(y) = ln(x / y)', () {
      check((const Ln(x) - const Ln(y)).simplify()).equals(Ln(x / y));
    });
  });

  group('SimplifierExtension - polynomial term ordering', () {
    test('orders terms in descending degree', () {
      final expr =
          const RationalNumber(5) +
          const RationalNumber(2) * x.pow(2) +
          x.pow(3) -
          x;
      final simplified = expr.simplify();
      // Degree 3, Degree 2, Degree 1 (negative), Constant
      final expected = x.pow(3) + const RationalNumber(2) * x.pow(2) - x + 5;
      check(simplified).equals(expected);
    });
  });
}
