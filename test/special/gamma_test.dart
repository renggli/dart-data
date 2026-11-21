import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/special.dart';
import 'package:more/number.dart' show Complex;
import 'package:test/test.dart';

void main() {
  group('gamma function', () {
    const gammaTuples = <(double, double)>[
      // Integers
      (1.0, 1.0),
      (2.0, 1.0),
      (3.0, 2.0),
      (4.0, 6.0),
      (5.0, 24.0),
      (6.0, 120.0),
      (7.0, 720.0),
      (8.0, 5040.0),
      (9.0, 40320.0),
      (10.0, 362880.0),
      // Half-integers
      (-2.5, -0.94530872048),
      (-1.5, 2.36327180121),
      (-0.5, -3.54490770181),
      (0.5, 1.77245385091),
      (1.5, 0.88622692545),
      (2.5, 1.32934038818),
      (3.5, 3.32335097045),
      // Local minima
      (1.46163214496, 0.88560319441),
      (-0.50408300826, -3.54464361115),
      (-1.57349847316, 2.30240725833),
      (-2.61072086844, -0.88813635840),
      (-3.63529336643, 0.24512753983),
      (-4.65323776174, -0.05277963958),
      (-5.66716244155, 0.00932459448),
      (-6.67841821307, -0.00139739660),
      (-7.68778832503, 0.00018187844),
      (-8.69576416381, -0.00002092529),
      (-9.70267254000, 0.00000215741),
      // Undefined
      (0.0, double.nan),
      (-0.0, double.nan),
      (-1.0, double.nan),
      (-2.0, double.nan),
      (-3.0, double.nan),
      (-4.0, double.nan),
      (-5.0, double.nan),
      (-6.0, double.nan),
      (-7.0, double.nan),
      (-8.0, double.nan),
      (-9.0, double.nan),
      (-10.0, double.nan),
    ];

    test('gamma', () {
      for (final (x, expected) in gammaTuples) {
        if (expected.isNaN) {
          check(because: 'gamma($x)', gamma(x)).isNaN;
        } else {
          check(because: 'gamma($x)', gamma(x)).isCloseTo(expected, 1e-4);
        }
      }
    });

    test('gammaLn', () {
      for (final (x, expected) in gammaTuples) {
        if (x > 0) {
          check(
            because: 'gammaLn($x)',
            gammaLn(x),
          ).isCloseTo(math.log(expected), 1e-6);
        }
      }
      check(gammaLn(0)).isNaN;
      check(gammaLn(-1)).isNaN;
    });

    test('gammaP and gammaQ', () {
      check(gammaP(1, 1)).isCloseTo(1.0 - math.exp(-1), 1e-14);
      check(gammaQ(1, 1)).isCloseTo(math.exp(-1), 1e-14);
      // High-precision partition and convergence tests across x < a+1 and x >= a+1
      for (final (a, x) in [
        (5.0, 3.0),
        (5.0, 7.0),
        (12.0, 10.0),
        (12.0, 15.0),
      ]) {
        check(gammaP(a, x) + gammaQ(a, x)).isCloseTo(1.0, 1e-14);
      }
      check(gammaP(-1, 1)).isNaN;
      check(gammaP(1, -1)).isNaN;
      check(gammaQ(-1, 1)).isNaN;
      check(gammaQ(1, -1)).isNaN;
      check(gamma(double.infinity)).equals(double.infinity);
      check(gammaLn(double.infinity)).equals(double.infinity);
      check(gammaP(2.0, double.infinity)).equals(1.0);
      check(gammaQ(2.0, double.infinity)).equals(0.0);
    });

    test('gammaPInv', () {
      check(gammaPInv(0.0, 2.0)).equals(0.0);
      check(gammaPInv(1.0, 2.0)).equals(double.infinity);
      check(gammaPInv(-0.1, 2.0)).isNaN;
      check(gammaPInv(1.1, 2.0)).isNaN;
      check(gammaPInv(double.nan, 2.0)).isNaN;
      check(gammaPInv(0.5, 0.0)).isNaN;
      check(gammaPInv(0.5, -1.0)).isNaN;
      final prob = gammaP(2.5, 3.0);
      check(gammaPInv(prob, 2.5)).isCloseTo(3.0, 1e-12);

      // a <= 1.0 branches
      final pSmall = gammaP(0.5, 0.2);
      check(gammaPInv(pSmall, 0.5)).isCloseTo(0.2, 1e-12);
      final pLarge = gammaP(0.5, 2.0);
      check(gammaPInv(pLarge, 0.5)).isCloseTo(2.0, 1e-12);

      // a > 1.0 with p < 0.5
      final pLow = gammaP(3.0, 0.5);
      check(gammaPInv(pLow, 3.0)).isCloseTo(0.5, 1e-12);
    });

    test('gammaQInv', () {
      check(gammaQInv(0.0, 2.0)).equals(double.infinity);
      check(gammaQInv(1.0, 2.0)).equals(0.0);
      check(gammaQInv(-0.1, 2.0)).isNaN;
      check(gammaQInv(1.1, 2.0)).isNaN;
      check(gammaQInv(double.nan, 2.0)).isNaN;
      check(gammaQInv(0.5, 0.0)).isNaN;
      check(gammaQInv(0.5, -1.0)).isNaN;

      // Invertibility: gammaQ(a, gammaQInv(q, a)) == q
      for (final a in [0.5, 1.0, 2.5, 5.0, 10.0, 50.0]) {
        for (final q in [0.001, 0.01, 0.1, 0.2, 0.25, 0.5, 0.8, 0.99]) {
          final x = gammaQInv(q, a);
          check(gammaQ(a, x)).isCloseTo(q, 1e-11);
        }
      }
    });

    test('gamma for large x', () {
      check(gamma(105.0).isFinite).isTrue;
    });

    test('factorial and combinations', () {
      check(factorial(0)).isCloseTo(1.0, 1e-8);
      check(factorial(5)).isCloseTo(120.0, 1e-8);
      check(factorial(-1)).isNaN;
      check(factorial(double.nan)).isNaN;
      check(factorialLn(5)).isCloseTo(math.log(120.0), 1e-6);
      check(factorialLn(double.nan)).isNaN;
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

      check(permutation(5, 2)).equals(20.0);
      check(permutation(10, 3)).equals(720.0);
      check(permutation(20, 3)).equals(6840.0);
      check(permutation(50, 10)).isCloseTo(3.7276043023296e16, 1e10);
      check(permutation(200, 2)).equals(39800.0);
      check(permutation(5, 0)).equals(1.0);
      check(permutation(5, 6)).equals(0.0);
      check(permutation(5, -1)).equals(0.0);
      check(permutation(double.nan, 2)).isNaN;
      check(permutation(5, double.nan)).isNaN;
      check(permutation(double.infinity, 2)).equals(double.infinity);
      check(permutation(double.infinity, double.infinity)).isNaN;
      check(permutationLn(5, 2)).isCloseTo(math.log(20.0), 1e-6);
    });

    test('upperGamma and lowerGamma', () {
      check(upperGamma(1.0, 2.0)).isCloseTo(math.exp(-2.0), 1e-12);
      check(lowerGamma(1.0, 2.0)).isCloseTo(1.0 - math.exp(-2.0), 1e-12);
      check(upperGamma(2.0, 1.0)).isCloseTo(2.0 * math.exp(-1.0), 1e-12);
      check(upperGamma(3.0, 1.0) + lowerGamma(3.0, 1.0))
          .isCloseTo(gamma(3.0), 1e-12);
      check(upperGamma(0.0, 1.0)).isCloseTo(-expIntegral(-1.0), 1e-12);
      check(upperGamma(-1.0, 1.0))
          .isCloseTo(math.exp(-1.0) + expIntegral(-1.0), 1e-12);
    });

    test('complex gamma, factorial, binomial, and incomplete gamma', () {
      for (final x in [0.5, 2.5, 5.0, -1.3]) {
        final gc = gammaComplex(Complex(x));
        check(gc.a).isCloseTo(gamma(x), 1e-12);
        check(gc.b).isCloseTo(0.0, 1e-12);
      }
      const z = Complex(1.5, 0.8);
      final gz1 = gammaComplex(z + Complex.one);
      final zGz = z * gammaComplex(z);
      check((gz1 - zGz).abs()).isLessThan(1e-12);
      check(gammaLnComplex(const Complex(3.5)).a.toDouble())
          .isCloseTo(gammaLn(3.5), 1e-12);
      check((factorialComplex(z) - gammaComplex(z + Complex.one)).abs())
          .isLessThan(1e-12);
      check(
        (binomialComplex(const Complex(5, 1), const Complex(2)) -
                (const Complex(5, 1) * const Complex(4, 1) / const Complex(2)))
            .abs(),
      ).isLessThan(1e-12);

      // upperGammaComplex + lowerGammaComplex == gammaComplex
      const s = Complex(1.2, 0.5);
      const w = Complex(2.5, -0.7);
      final sum = upperGammaComplex(s, w) + lowerGammaComplex(s, w);
      check((sum - gammaComplex(s)).abs()).isLessThan(1e-12);
      // Small |z| series branch
      const wSmall = Complex(0.4, 0.3);
      final sumSmall =
          upperGammaComplex(s, wSmall) + lowerGammaComplex(s, wSmall);
      check((sumSmall - gammaComplex(s)).abs()).isLessThan(1e-12);
    });
  });
}
