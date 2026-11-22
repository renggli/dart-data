import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/special.dart';
import 'package:more/number.dart' show Complex;
import 'package:test/test.dart';

void main() {
  group('binomial', () {
    test('binomial and binomialLn', () {
      check(binomial(5, 2)).equals(10.0);
      check(binomial(10, 3)).equals(120.0);
      check(binomial(20, 10)).equals(184756.0);
      check(binomial(60, 5)).equals(5461512.0);
      check(binomial(62, 31)).isCloseTo(4.654283532552611e17, 1e8);
      check(binomial(100, 10)).isCloseTo(1.731030945644e13, 1e5);
      check(binomial(200, 2)).equals(19900.0);
      check(binomial(5, 0)).equals(1.0);
      check(binomial(5, 5)).equals(1.0);
      check(binomial(5, 6)).equals(0.0);
      check(binomial(5, -1)).equals(0.0);
      check(binomial(5.5, 2.5)).isGreaterThan(0.0);
      check(binomial(double.nan, 2)).isNaN;
      check(binomial(5, double.nan)).isNaN;
      check(binomial(double.infinity, 2)).equals(double.infinity);
      check(binomial(double.infinity, double.infinity)).isNaN;
      check(binomial(double.infinity, 1.5)).isNaN;
      check(binomialLn(5, 2)).isCloseTo(math.log(10.0), 1e-6);
    });

    test('binomialComplex', () {
      check(
        (binomialComplex(const Complex(5, 1), const Complex(2)) -
                (const Complex(5, 1) * const Complex(4, 1) / const Complex(2)))
            .abs(),
      ).isLessThan(1e-12);
      check(binomialComplex(const Complex(5, 1), Complex.zero))
          .equals(Complex.one);
      check(binomialComplex(const Complex(5, 1), const Complex(-1)))
          .equals(Complex.zero);
      // Negative integer n with k > 20 uses exact product loop without NaN
      final negN = binomialComplex(const Complex(-5), const Complex(25));
      check(negN.a.isFinite).isTrue;
      check(negN.b).equals(0.0);
      // C(-5, 25) = (-1)^25 * C(29, 25) = -C(29, 4) = -23751
      check(negN.a.toDouble()).isCloseTo(-23751.0, 1e-8);
    });
  });
}
