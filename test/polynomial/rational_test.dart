import 'package:checks/checks.dart';
import 'package:data/polynomial.dart';
import 'package:test/test.dart';

void main() {
  group('RationalFunction', () {
    test('construction and basic properties', () {
      final num = Polynomial<double>.fromCoefficients([1.0, 2.0]); // 1 + 2x
      final den = Polynomial<double>.fromCoefficients([
        3.0,
        0.0,
        1.0,
      ]); // 3 + x^2

      final rf = RationalFunction(num, den);
      check(rf.numerator).equals(num);
      check(rf.denominator).equals(den);
      check(rf.toString()).contains('/');

      final fromP = RationalFunction.fromPolynomial(num);
      check(fromP.denominator.degree).equals(0);
      check(fromP.evaluate(2.0)).equals(5.0);

      final zero = Polynomial<double>.zero();
      check(() => RationalFunction(num, zero)).throws<UnsupportedError>();
    });

    test('evaluation and pole exception', () {
      // R(x) = (x + 2) / (x - 1)
      final num = Polynomial<double>.fromCoefficients([2.0, 1.0]);
      final den = Polynomial<double>.fromCoefficients([-1.0, 1.0]);
      final rf = RationalFunction(num, den);

      check(rf.evaluate(2.0)).equals(4.0); // (2 + 2) / (2 - 1) = 4
      check(rf.evaluateDouble(0.0)).equals(-2.0); // 2 / -1 = -2
      check(() => rf.evaluate(1.0)).throws<UnsupportedError>();
      check(() => rf.evaluateDouble(1.0)).throws<UnsupportedError>();
    });

    test('automatic and explicit GCD simplification', () {
      // (x^2 - 1) / (x - 1) = (x - 1)(x + 1) / (x - 1) = x + 1
      final num = Polynomial<double>.fromCoefficients([-1.0, 0.0, 1.0]);
      final den = Polynomial<double>.fromCoefficients([-1.0, 1.0]);
      final rf = RationalFunction(num, den);

      final simplified = rf.simplify();
      check(simplified.denominator.degree).equals(0);
      check(simplified.numerator.degree).equals(1);
      check(simplified.evaluate(3.0)).equals(4.0);
    });

    test('arithmetic: addition and subtraction', () {
      // 1 / x
      final p1 = Polynomial<double>.fromCoefficients([1.0]);
      final px = Polynomial<double>.fromCoefficients([0.0, 1.0]);
      final r1 = RationalFunction(p1, px);

      // 1 / (x + 1)
      final pxPlus1 = Polynomial<double>.fromCoefficients([1.0, 1.0]);
      final r2 = RationalFunction(p1, pxPlus1);

      // 1/x + 1/(x+1) = (2x + 1) / (x^2 + x)
      final sum = r1 + r2;
      check(sum.evaluate(2.0)).isCloseTo(0.5 + (1.0 / 3.0), 1e-9);

      // 1/x - 1/(x+1) = 1 / (x^2 + x)
      final diff = r1 - r2;
      check(diff.evaluate(2.0)).isCloseTo(0.5 - (1.0 / 3.0), 1e-9);

      // Negation
      final neg = -r1;
      check(neg.evaluate(2.0)).equals(-0.5);
    });

    test('arithmetic: multiplication and division', () {
      // x / (x + 1)
      final px = Polynomial<double>.fromCoefficients([0.0, 1.0]);
      final pxPlus1 = Polynomial<double>.fromCoefficients([1.0, 1.0]);
      final r1 = RationalFunction(px, pxPlus1);

      // (x + 1) / x^2
      final pxSq = Polynomial<double>.fromCoefficients([0.0, 0.0, 1.0]);
      final r2 = RationalFunction(pxPlus1, pxSq);

      // Product: 1 / x
      final prod = r1 * r2;
      check(prod.evaluate(4.0)).isCloseTo(0.25, 1e-9);

      // Division: (x / (x+1)) / (x / (x-1)) = (x - 1) / (x + 1)
      final pxMinus1 = Polynomial<double>.fromCoefficients([-1.0, 1.0]);
      final r3 = RationalFunction(px, pxMinus1);
      final quot = r1 / r3;
      check(quot.evaluate(3.0))
          .isCloseTo(0.5, 1e-9); // (3 - 1) / (3 + 1) = 2/4 = 0.5

      // Division by zero rational function
      final zeroRf = RationalFunction.fromPolynomial(Polynomial<double>.zero());
      check(() => r1 / zeroRf).throws<UnsupportedError>();
    });

    test('derivative using quotient rule', () {
      // R(x) = 1 / x -> R'(x) = -1 / x^2
      final p1 = Polynomial<double>.fromCoefficients([1.0]);
      final px = Polynomial<double>.fromCoefficients([0.0, 1.0]);
      final r = RationalFunction(p1, px);

      final deriv = r.derivative();
      check(deriv.evaluate(2.0)).isCloseTo(-0.25, 1e-9);
      check(deriv.evaluate(3.0)).isCloseTo(-1.0 / 9.0, 1e-9);

      // R(x) = x^2 / (x + 1) -> R'(x) = (2x(x+1) - x^2) / (x+1)^2 = (x^2 + 2x)
      // / (x+1)^2
      final pxSq = Polynomial<double>.fromCoefficients([0.0, 0.0, 1.0]);
      final pxPlus1 = Polynomial<double>.fromCoefficients([1.0, 1.0]);
      final r2 = RationalFunction(pxSq, pxPlus1);
      final deriv2 = r2.derivative();
      // At x = 1: (1 + 2) / 4 = 0.75
      check(deriv2.evaluate(1.0)).isCloseTo(0.75, 1e-9);
    });

    test('equality and hashCode', () {
      final num1 = Polynomial<double>.fromCoefficients([2.0, 4.0]); // 2 + 4x
      final den1 = Polynomial<double>.fromCoefficients([1.0, 1.0]); // 1 + x

      final num2 = Polynomial<double>.fromCoefficients([4.0, 8.0]); // 4 + 8x
      final den2 = Polynomial<double>.fromCoefficients([2.0, 2.0]); // 2 + 2x

      final rf1 = RationalFunction(num1, den1);
      final rf2 = RationalFunction(num2, den2);

      check(rf1 == rf2).isTrue();
      check(rf1.hashCode).equals(rf2.hashCode);
    });
  });
}
