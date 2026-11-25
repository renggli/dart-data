import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/special.dart';
import 'package:more/number.dart' show Complex;
import 'package:test/scaffolding.dart';

void main() {
  group('binomial', () {
    test('computes exact integers and BigInt promotions', () {
      check(binomial(5, 2)).equals(10.0);
      check(binomial(10, 3)).equals(120.0);
      check(binomial(20, 10)).equals(184756.0);
      check(binomial(60, 5)).equals(5461512.0);
      check(binomial(62, 31)).isCloseTo(4.654283532552611e17, 1e5);
      check(binomial(100, 10)).isCloseTo(1.731030945644e13, 1e2);
      check(binomial(200, 2)).equals(19900.0);
      check(binomial(1e20, 2)).isCloseTo(0.5e40, 1e26);
    });

    test('evaluates negative integers and fractional parameters', () {
      check(binomial(-5, 0)).equals(1.0);
      check(binomial(-5, 2)).equals(15.0);
      check(binomial(-5, 3)).equals(-35.0);

      // Large k with negative integer n uses identity (-1)^k * C(-n + k - 1, k)
      final negLargeK = binomial(-5, 1005);
      check(negLargeK).equals(-42930693876.0);

      check(binomial(5.5, 2.5))
          .isCloseTo(gamma(6.5) / (gamma(3.5) * gamma(4.0)), 1e-13);
      check(binomial(1100.5, 550.5)).equals(double.infinity);
    });

    test('handles boundaries, infinities, and NaN', () {
      check(binomial(5, 0)).equals(1.0);
      check(binomial(5, 5)).equals(1.0);
      check(binomial(5, 6)).equals(0.0);
      check(binomial(5, -1)).equals(0.0);
      check(binomial(5, double.infinity)).equals(0.0);
      check(binomial(-5, double.infinity)).isNaN;
      check(binomial(5, double.negativeInfinity)).isNaN;
      check(binomial(double.nan, 2)).isNaN;
      check(binomial(5, double.nan)).isNaN;
      check(binomial(double.infinity, 2)).equals(double.infinity);
      check(binomial(double.infinity, double.infinity)).isNaN;
      check(binomial(double.infinity, 1.5)).isNaN;
    });
  });

  group('binomialLn', () {
    test('avoids cancellation for small k and matches gammaLn', () {
      check(binomialLn(5, 2)).isCloseTo(math.log(10.0), 1e-14);
      check(binomialLn(1e10, 2))
          .isCloseTo(math.log(1e10) + math.log(1e10 - 1.0) - math.ln2, 1e-14);
      check(binomialLn(100, 50))
          .isCloseTo(gammaLn(101) - 2.0 * gammaLn(51), 1e-13);
    });

    test('handles boundaries and non-finite inputs', () {
      check(binomialLn(5, 0)).equals(0.0);
      check(binomialLn(5, 5)).equals(0.0);
      check(binomialLn(double.infinity, 2)).equals(double.infinity);
      check(binomialLn(double.infinity, double.infinity)).isNaN;
      check(binomialLn(5, 6)).isNaN;
      check(binomialLn(-1, 2)).isNaN;
      check(binomialLn(5, double.nan)).isNaN;
    });
  });

  group('binomialComplex', () {
    test('evaluates real-integer reduction and negative integers', () {
      check(binomialComplex(const Complex(5), const Complex(4)))
          .equals(const Complex(5.0));
      check(binomialComplex(const Complex(5, 1), Complex.zero))
          .equals(Complex.one);
      check(binomialComplex(const Complex(5, 1), const Complex(-1)))
          .equals(Complex.zero);
      check(binomialComplex(const Complex(5), const Complex(1500)))
          .equals(Complex.zero);

      final negSmallK = binomialComplex(const Complex(-5), const Complex(25));
      check(negSmallK.a.toDouble()).isCloseTo(-23751.0, 1e-10);
      check(negSmallK.b).equals(0.0);

      final negLargeK = binomialComplex(const Complex(-5), const Complex(1005));
      check(negLargeK.a.toDouble()).isCloseTo(-42930693876.0, 1e-3);
      check(negLargeK.b).equals(0.0);
    });

    test('evaluates general complex parameters and NaN guards', () {
      check(
        (binomialComplex(const Complex(5, 1), const Complex(2)) -
                (const Complex(5, 1) * const Complex(4, 1) / const Complex(2)))
            .abs(),
      ).isLessThan(1e-12);

      const n = Complex(5.5, 0.3);
      const k = Complex(2.5, 0.1);
      final expected =
          gammaComplex(n + 1) / (gammaComplex(k + 1) * gammaComplex(n - k + 1));
      check((binomialComplex(n, k) - expected).abs()).isLessThan(1e-12);
      check(binomialComplex(Complex.nan, k).isNaN).isTrue;
      check(binomialComplex(const Complex(double.infinity), k).isNaN).isTrue;
    });
  });
}
