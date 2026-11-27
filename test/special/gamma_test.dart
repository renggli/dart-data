import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/special.dart';
import 'package:more/number.dart' show Complex;
import 'package:test/scaffolding.dart';

void main() {
  const gammaTuples = <(double, double)>[
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
    (-2.5, -0.9453087204829419),
    (-1.5, 2.363271801207355),
    (-0.5, -3.544907701811032),
    (0.5, 1.772453850905516),
    (1.5, 0.886226925452758),
    (2.5, 1.329340388179137),
    (3.5, 3.3233509704478426),
  ];

  group('gamma', () {
    test('evaluates exact integers, half-integers, and large values', () {
      for (final (x, expected) in gammaTuples) {
        check(because: 'gamma($x)', gamma(x)).isCloseTo(expected, 1e-13);
      }
      check(gamma(23.0)).equals(1124000727777607680000.0);
      for (final x in [105.0, 171.5]) {
        check(math.log(gamma(x))).isCloseTo(gammaLn(x), 1e-12);
      }
      final gNegLarge = gamma(-171.5);
      check(gNegLarge).isGreaterThan(0.0);
      check(math.log(gNegLarge))
          .isCloseTo(math.log(math.pi) - gammaLn(172.5), 1e-12);
    });

    test('handles poles, overflows, and non-finite inputs', () {
      for (final pole in [0.0, -0.0, -1.0, -2.0, -10.0]) {
        check(gamma(pole)).isNaN;
      }
      check(gamma(-1e-315)).equals(double.negativeInfinity);
      check(gamma(double.nan)).isNaN;
      check(gamma(double.negativeInfinity)).isNaN;
      check(gamma(double.infinity)).equals(double.infinity);
      check(gamma(172.0)).equals(double.infinity);
    });
  });

  group('gammaLn', () {
    test('matches log(gamma) and handles boundaries', () {
      for (final (x, expected) in gammaTuples) {
        if (x > 0) {
          check(
            because: 'gammaLn($x)',
            gammaLn(x),
          ).isCloseTo(math.log(expected), 1e-14);
        }
      }
      check(gammaLn(1.0)).equals(0.0);
      check(gammaLn(2.0)).equals(0.0);
    });

    test('handles poles and non-finite inputs', () {
      for (final pole in [0.0, -0.0, -1.0, -2.0, -10.0]) {
        check(gammaLn(pole)).isNaN;
      }
      check(gammaLn(double.nan)).isNaN;
      check(gammaLn(double.negativeInfinity)).isNaN;
      check(gammaLn(double.infinity)).equals(double.infinity);
    });
  });

  group('gammaComplex', () {
    test('matches real values and satisfies reflection and recurrence', () {
      for (final x in [0.5, 2.5, 5.0, -1.3]) {
        final gc = gammaComplex(Complex(x));
        check(gc.a).isCloseTo(gamma(x), 1e-12);
        check(gc.b).equals(0.0);
      }

      const zRefl = Complex(-1.5, 0.5);
      final expectedRefl =
          const Complex(math.pi) / (const Complex(math.pi) * zRefl).sin();
      check(
        (gammaComplex(zRefl) * gammaComplex(Complex.one - zRefl) - expectedRefl)
            .abs(),
      ).isLessThan(1e-12);

      for (final z in const [
        Complex(1.5, 0.8),
        Complex(120.0, 1.0),
        Complex(0.2, 250.0),
      ]) {
        final lhs = gammaComplex(z + Complex.one);
        final rhs = z * gammaComplex(z);
        final mag = math.max(rhs.a.abs(), rhs.b.abs());
        check((lhs - rhs).a.abs()).isLessThan(1e-11 * mag);
        check((lhs - rhs).b.abs()).isLessThan(1e-11 * mag);
      }
    });

    test('handles poles and non-finite inputs', () {
      check(gammaComplex(Complex.zero).isNaN).isTrue;
      check(gammaComplex(const Complex(-3)).isNaN).isTrue;
      check(gammaComplex(Complex.nan).isNaN).isTrue;
      check(gammaComplex(const Complex(double.infinity, 1.0)).isNaN).isTrue;
      check(gammaComplex(const Complex(double.infinity)))
          .equals(const Complex(double.infinity));
    });
  });

  group('gammaLnComplex', () {
    test('satisfies log-gamma recurrence across real and large-Im inputs', () {
      check(gammaLnComplex(const Complex(3.5)).a.toDouble())
          .isCloseTo(gammaLn(3.5), 1e-13);

      for (final z in const [Complex(1.5, 0.8), Complex(0.2, 250.0)]) {
        final diff = gammaLnComplex(z + Complex.one) - gammaLnComplex(z);
        check((diff - z.log()).abs()).isLessThan(1e-12);
      }
      check(gammaLnComplex(Complex.zero).isNaN).isTrue;
      check(gammaLnComplex(Complex.nan).isNaN).isTrue;
    });
  });

  group('gammaP', () {
    test('satisfies reference values and domain boundaries', () {
      check(gammaP(1, 1)).isCloseTo(1.0 - math.exp(-1), 1e-14);
      check(gammaP(2.0, 0.0)).equals(0.0);
      check(gammaP(2.0, double.infinity)).equals(1.0);
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
      check(gammaP(double.infinity, double.infinity)).isNaN;
    });
  });

  group('gammaQ', () {
    test('satisfies reference values and domain boundaries', () {
      check(gammaQ(1, 1)).isCloseTo(math.exp(-1), 1e-14);
      check(gammaQ(2.0, 0.0)).equals(1.0);
      check(gammaQ(2.0, double.infinity)).equals(0.0);
      check(gammaQ(-1, 1)).isNaN;
      check(gammaQ(1, -1)).isNaN;
      check(gammaQ(double.infinity, double.infinity)).isNaN;
    });
  });

  group('gammaPInv', () {
    test('inverts gammaP across moderate and extreme shapes', () {
      for (final (a, x) in [
        (2.5, 3.0),
        (0.5, 0.2),
        (0.5, 2.0),
        (3.0, 0.5),
        (5.0, 1e-5),
      ]) {
        final p = gammaP(a, x);
        check(gammaPInv(a, p)).isCloseTo(x, 1e-12 * math.max(1.0, x));
      }
      for (final (a, p) in [(0.05, 1e-6), (0.05, 0.999999), (0.2, 1e-12)]) {
        final x = gammaPInv(a, p);
        check(gammaP(a, x)).isCloseTo(p, 1e-11 * p);
      }
    });

    test('handles boundaries and invalid parameters', () {
      check(gammaPInv(2.0, 0.0)).equals(0.0);
      check(gammaPInv(2.0, 1.0)).equals(double.infinity);
      check(gammaPInv(2.0, -0.1)).isNaN;
      check(gammaPInv(2.0, 1.1)).isNaN;
      check(gammaPInv(2.0, double.nan)).isNaN;
      check(gammaPInv(0.0, 0.5)).isNaN;
      check(gammaPInv(-1.0, 0.5)).isNaN;
      check(gammaPInv(double.infinity, 0.5)).isNaN;
    });
  });

  group('gammaQInv', () {
    test('inverts gammaQ across moderate and deep tails', () {
      for (final a in [0.5, 1.0, 2.5, 5.0, 10.0, 50.0]) {
        for (final q in [0.001, 0.01, 0.1, 0.25, 0.5, 0.8, 0.99]) {
          final x = gammaQInv(a, q);
          check(gammaQ(a, x)).isCloseTo(q, 1e-12);
        }
      }
      final qDeep = gammaQ(3.0, 60.0);
      check(gammaQInv(3.0, qDeep)).isCloseTo(60.0, 1e-10);
      for (final (a, q) in [(0.01, 1e-10), (0.05, 0.99999)]) {
        final x = gammaQInv(a, q);
        check(gammaQ(a, x)).isCloseTo(q, 1e-10 * q);
      }
    });

    test('handles boundaries and invalid parameters', () {
      check(gammaQInv(2.0, 0.0)).equals(double.infinity);
      check(gammaQInv(2.0, 1.0)).equals(0.0);
      check(gammaQInv(2.0, -0.1)).isNaN;
      check(gammaQInv(2.0, 1.1)).isNaN;
      check(gammaQInv(2.0, double.nan)).isNaN;
      check(gammaQInv(0.0, 0.5)).isNaN;
      check(gammaQInv(-1.0, 0.5)).isNaN;
      check(gammaQInv(double.infinity, 0.5)).isNaN;
    });
  });

  group('lowerGamma', () {
    test('evaluates positive, negative, and large arguments', () {
      check(lowerGamma(1.0, 2.0)).isCloseTo(1.0 - math.exp(-2.0), 1e-14);
      check(lowerGamma(-0.5, 1.0) + upperGamma(-0.5, 1.0))
          .isCloseTo(gamma(-0.5), 1e-12);

      final lg = lowerGamma(160.0, 170.0);
      check(math.log(lg))
          .isCloseTo(gammaLn(160.0) + math.log(gammaP(160.0, 170.0)), 1e-13);
      check(lowerGamma(double.negativeInfinity, 1.0)).isNaN;
    });
  });

  group('upperGamma', () {
    test('evaluates positive, zero, negative, and large arguments', () {
      check(upperGamma(1.0, 2.0)).isCloseTo(math.exp(-2.0), 1e-14);
      check(upperGamma(2.0, 1.0)).isCloseTo(2.0 * math.exp(-1.0), 1e-14);
      check(upperGamma(0.0, 1.0)).isCloseTo(-expIntegral(-1.0), 1e-13);
      check(upperGamma(-1.0, 1.0))
          .isCloseTo(math.exp(-1.0) + expIntegral(-1.0), 1e-13);
      check(-1.5 * upperGamma(-1.5, 1.0) + math.exp(-1.0))
          .isCloseTo(upperGamma(-0.5, 1.0), 1e-12);

      final ug = upperGamma(160.0, 170.0);
      check(math.log(ug))
          .isCloseTo(gammaLn(160.0) + math.log(gammaQ(160.0, 170.0)), 1e-13);
      check(upperGamma(double.negativeInfinity, 1.0)).isNaN;
    });
  });

  group('lowerGammaComplex', () {
    test('satisfies complementarity with upperGammaComplex', () {
      const s = Complex(1.2, 0.5);
      for (final w in const [Complex(2.5, -0.7), Complex(0.4, 0.3)]) {
        check(
          (lowerGammaComplex(s, w) + upperGammaComplex(s, w) - gammaComplex(s))
              .abs(),
        ).isLessThan(1e-12);
      }
      check(lowerGammaComplex(Complex.nan, Complex.one).isNaN).isTrue;
    });
  });

  group('upperGammaComplex', () {
    test('satisfies zero and negative-order recurrences', () {
      const zSmall = Complex(0.5, 0.2);
      check(
        (upperGammaComplex(Complex.zero, zSmall) -
                expIntegralEComplex(Complex.one, zSmall))
            .abs(),
      ).isLessThan(1e-12);

      final ugNeg1 = upperGammaComplex(const Complex(-1), zSmall);
      final expectedUgNeg1 =
          (zSmall.pow(const Complex(-1)) * (-zSmall).exp()) -
          upperGammaComplex(Complex.zero, zSmall);
      check((ugNeg1 - expectedUgNeg1).abs()).isLessThan(1e-12);
      check(upperGammaComplex(Complex.nan, zSmall).isNaN).isTrue;
      check(gammaPInv(0.02, 0.99)).isGreaterThan(0.0);
      check(gammaQInv(0.02, 0.01)).isGreaterThan(0.0);
    });
  });
}
