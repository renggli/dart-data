import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/special.dart';
import 'package:more/number.dart' show Complex;
import 'package:test/scaffolding.dart';

void main() {
  const betaTuples = <(double, double, double)>[
    (1.0, 1.0, 1.0),
    (0.5, 0.5, math.pi),
    (2.0, 3.0, 1.0 / 12.0),
    (9.9, 0.7, 0.26358586452611564),
    (7.1, 0.3, 1.6865524891432026),
    (7.6, 4.9, 0.00034359706592169696),
    (2.2, 8.0, 0.00973373184426085),
    (5.7, 6.5, 0.0003203685429795221),
    (7.1, 6.6, 0.00010467276084467527),
    (0.8, 1.0, 1.25),
    (0.3, 0.2, 7.748481388500046),
  ];

  group('beta', () {
    test('evaluates reference values and prevents overflow', () {
      for (final (a, b, expected) in betaTuples) {
        check(because: 'beta($a, $b)', beta(a, b)).isCloseTo(expected, 1e-9);
        check(beta(a, b)).isCloseTo(beta(b, a), 1e-14 * expected);
      }
      for (final a in [90.0, 100.0]) {
        check(math.log(beta(a, a))).isCloseTo(betaLn(a, a), 1e-13);
      }
      check(beta(150.0, 2.0)).isCloseTo(math.exp(betaLn(150.0, 2.0)), 1e-14);
      check(beta(160.0, 1e-30)).isCloseTo(1e30, 1e-12 * 1e30);
    });

    test('handles boundaries, infinities, and NaN', () {
      check(beta(0.0, 0.0)).isNaN;
      check(beta(1.0, 0.0)).isNaN;
      check(beta(0.0, 1.0)).isNaN;
      check(beta(double.infinity, 2.0)).equals(0.0);
      check(beta(double.nan, 1.0)).isNaN;
    });
  });

  group('betaLn', () {
    test('matches log(beta) and handles boundaries', () {
      for (final (a, b, expected) in betaTuples) {
        check(
          because: 'betaLn($a, $b)',
          betaLn(a, b),
        ).isCloseTo(math.log(expected), 1e-9);
      }
      check(betaLn(0.0, 1.0)).isNaN;
      check(betaLn(double.infinity, 2.0)).equals(double.negativeInfinity);
      check(betaLn(double.nan, 1.0)).isNaN;
    });
  });

  group('betaComplex', () {
    test('matches real values and large-argument log-exp path', () {
      final bcReal = betaComplex(const Complex(2.0), const Complex(3.0));
      check(bcReal.a).isCloseTo(beta(2.0, 3.0), 1e-14);
      check(bcReal.b).equals(0.0);

      const a = Complex(1.5, 0.4);
      const b = Complex(2.2, -0.3);
      final expected = gammaComplex(a) * gammaComplex(b) / gammaComplex(a + b);
      check((betaComplex(a, b) - expected).abs()).isLessThan(1e-12);

      // Large |a + b| switches to betaLnComplex(...).exp()
      const aLarge = Complex(90.0, 1.0);
      const bLarge = Complex(90.0, -1.0);
      final bVal = betaComplex(aLarge, bLarge);
      final bLogExp = betaLnComplex(aLarge, bLarge).exp();
      check((bVal - bLogExp).abs() / bLogExp.abs()).isLessThan(1e-13);
      check((bVal - betaComplex(bLarge, aLarge)).abs() / bVal.abs())
          .isLessThan(1e-13);
      check(betaComplex(Complex.nan, b).isNaN).isTrue;
    });
  });

  group('betaLnComplex', () {
    test('satisfies identity with gammaLnComplex and boundaries', () {
      const a = Complex(1.5, 0.4);
      const b = Complex(2.2, -0.3);
      final expected =
          gammaLnComplex(a) + gammaLnComplex(b) - gammaLnComplex(a + b);
      check((betaLnComplex(a, b) - expected).abs()).isLessThan(1e-13);
      check(betaLnComplex(Complex.zero, b).isNaN).isTrue;
      check(betaLnComplex(Complex.nan, b).isNaN).isTrue;
    });
  });

  group('betaI', () {
    test('evaluates symmetric, exact, and infinite cases', () {
      check(betaI(0.0, 2.0, 3.0)).equals(0.0);
      check(betaI(1.0, 2.0, 3.0)).equals(1.0);
      check(betaI(0.5, 1.0, 1.0)).isCloseTo(0.5, 1e-14);
      check(betaI(0.4, 2.0, 3.0)).isCloseTo(1.0 - betaI(0.6, 3.0, 2.0), 1e-14);
      check(betaI(-0.1, 1, 1)).isNaN;
      check(betaI(1.1, 1, 1)).isNaN;
      check(betaI(double.nan, 2.0, 3.0)).isNaN;
      check(betaI(0.5, double.nan, 3.0)).isNaN;
      check(betaI(0.5, double.infinity, 2.0)).equals(0.0);
      check(betaI(0.5, 2.0, double.infinity)).equals(1.0);
      check(betaI(0.5, double.infinity, double.infinity)).isNaN;
    });
  });

  group('betaIInv', () {
    test('inverts betaI across moderate, skewed, and extreme shapes', () {
      for (final (a, b, x) in [
        (3.0, 4.0, 0.4),
        (2.0, 5.0, 0.3),
        (10.0, 10.0, 0.5),
        (50.0, 50.0, 0.48),
        (100.0, 50.0, 0.65),
        (5.0, 2.0, 0.001),
        (0.02, 0.02, 0.1),
        (0.05, 50.0, 0.5),
        (50.0, 0.05, 0.5),
      ]) {
        final p = betaI(x, a, b);
        final inv = betaIInv(p, a, b);
        check(betaI(inv, a, b)).isCloseTo(p, 1e-11);
      }
      check(betaIInv(0.95, 0.3, 0.3))
          .isCloseTo(1.0 - betaIInv(0.05, 0.3, 0.3), 1e-11);
    });

    test('handles boundaries and invalid parameters', () {
      check(betaIInv(0.0, 2.5, 0.5)).equals(0.0);
      check(betaIInv(1.0, 2.5, 0.5)).equals(1.0);
      check(betaIInv(-0.1, 2.0, 3.0)).isNaN;
      check(betaIInv(1.1, 2.0, 3.0)).isNaN;
      check(betaIInv(double.nan, 2.0, 3.0)).isNaN;
      check(betaIInv(0.5, double.infinity, 2.0)).isNaN;
      check(betaIInv(0.15, 0.05, 50.0)).isGreaterThan(0.0);
      check(betaIInv(0.85, 50.0, 0.05)).isLessThan(1.0);
    });
  });
}
