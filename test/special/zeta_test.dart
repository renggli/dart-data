import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/special.dart';
import 'package:more/number.dart' show Complex;
import 'package:test/scaffolding.dart';

void main() {
  group('zeta', () {
    test('evaluates positive arguments and pole behavior', () {
      check(zeta(1)).equals(double.infinity);
      check(zeta(2)).isCloseTo(math.pi * math.pi / 6.0, 1e-15);
      check(zeta(3)).isCloseTo(1.2020569031595942, 1e-15);
      check(zeta(4)).isCloseTo(math.pow(math.pi, 4) / 90.0, 1e-15);
      check(zeta(10)).isCloseTo(1.000994575127818, 1e-15);
      check(zeta(30)).isCloseTo(
        1.0 + math.pow(2.0, -30) + math.pow(3.0, -30) + math.pow(4.0, -30),
        1e-15,
      );
      check(zeta(60)).equals(1.0);
      check(zeta(double.infinity)).equals(1.0);

      const sNear = 1.0 + 1e-8;
      check(zeta(sNear) - 1.0 / (sNear - 1.0))
          .isCloseTo(0.5772156649015329, 1e-7);
    });

    test('evaluates zero, negative integers, reflection logs, and NaN', () {
      check(zeta(0)).isCloseTo(-0.5, 1e-14);
      check(zeta(-1)).isCloseTo(-1.0 / 12.0, 1e-14);
      check(zeta(-2)).equals(0.0);
      check(zeta(-3)).isCloseTo(1.0 / 120.0, 1e-14);
      check(zeta(-4)).equals(0.0);
      check(zeta(-5)).isCloseTo(-1.0 / 252.0, 1e-14);
      check(zeta(-6)).equals(0.0);
      check(zeta(-170)).equals(0.0);

      // Functional equation log|zeta(s)| = s*ln(2) + (s-1)*ln(pi) + ln|sin(pi*s/2)| + lgamma(1-s) + ln(zeta(1-s))
      for (final (s, expectedSign) in [(-171.0, 1.0), (-170.5, 1.0)]) {
        final v = zeta(s);
        check(v * expectedSign).isGreaterThan(0.0);
        final expectedLog =
            s * math.ln2 +
            (s - 1.0) * math.log(math.pi) +
            math.log(math.sin(0.5 * math.pi * s).abs()) +
            gammaLn(1.0 - s) +
            math.log(zeta(1.0 - s));
        check(math.log(v.abs())).isCloseTo(expectedLog, 1e-12);
      }

      check(zeta(-301)).equals(double.negativeInfinity);
      check(zeta(double.nan)).isNaN;
      check(zeta(double.negativeInfinity)).isNaN;
    });
  });

  group('zetaComplex', () {
    test('evaluates critical-line zeros and avoids spurious Borwein poles', () {
      for (final s in [2.0, 3.0, 0.5, -1.5]) {
        final zc = zetaComplex(Complex(s));
        check(zc.a).isCloseTo(zeta(s), 1e-13);
        check(zc.b).isCloseTo(0.0, 1e-13);
      }
      for (final (t, tol) in const [
        (14.13472514173469379, 1e-13),
        (21.02203963877155499, 1e-13),
        (49.77383247767230218, 1e-12),
        (236.5242296658162058, 1e-11),
      ]) {
        check(zetaComplex(Complex(0.5, t)).abs()).isLessThan(tol);
        check(zetaComplex(Complex(0.5, -t)).abs()).isLessThan(tol);
      }

      const spuriousPole = Complex(1.0, 2.0 * math.pi / math.ln2);
      final zAtSpurious = zetaComplex(spuriousPole);
      check(zAtSpurious.a).isCloseTo(1.3465795428363176, 1e-13);
      check(zAtSpurious.b).isCloseTo(0.1098831367962698, 1e-13);
    });

    test('satisfies functional equation and log-space reflection', () {
      for (final s in const [Complex(0.3, 1.5), Complex(0.2, 50.0)]) {
        final lhs = zetaComplex(s);
        final rhs =
            (const Complex(math.ln2) * s +
                    Complex(math.log(math.pi)) * (s - Complex.one) +
                    gammaLnComplex(Complex.one - s))
                .exp() *
            (const Complex(0.5 * math.pi) * s).sin() *
            zetaComplex(Complex.one - s);
        check((lhs - rhs).abs() / lhs.abs()).isLessThan(1e-11);
      }

      const sNegLarge = Complex(-105.5, 1.0);
      final lhsLog =
          sNegLarge * const Complex(math.ln2) +
          (sNegLarge - Complex.one) * Complex(math.log(math.pi)) +
          gammaLnComplex(Complex.one - sNegLarge) +
          (const Complex(0.5 * math.pi) * sNegLarge).sin().log() +
          zetaComplex(Complex.one - sNegLarge).log();
      final actualNegLarge = zetaComplex(sNegLarge);
      check((actualNegLarge - lhsLog.exp()).abs() / actualNegLarge.abs())
          .isLessThan(1e-11);

      const sHighT = Complex(0.2, 500.0);
      final zHigh = zetaComplex(sHighT);
      check((zHigh.conjugate() - zetaComplex(sHighT.conjugate())).abs())
          .isLessThan(1e-12);
      check(zetaComplex(const Complex(-2))).equals(Complex.zero);
      check(zetaComplex(const Complex(-120))).equals(Complex.zero);
      check(zetaComplex(const Complex(double.negativeInfinity, 1.0)).isNaN)
          .isTrue;
    });
  });

  group('hurwitzZeta', () {
    test('evaluates positive, Bernoulli polynomial, and negative-a shifts', () {
      check(hurwitzZeta(1.0, 2.0)).equals(double.infinity);
      check(hurwitzZeta(2.0, 1.0)).isCloseTo(zeta(2.0), 1e-14);
      check(hurwitzZeta(2.0, 0.5)).isCloseTo(math.pi * math.pi / 2.0, 1e-13);
      check(hurwitzZeta(3.0, 0.5)).isCloseTo(7.0 * zeta(3.0), 1e-13);

      check(hurwitzZeta(0.0, 0.25)).isCloseTo(0.25, 1e-14);
      check(hurwitzZeta(0.0, 0.0)).equals(0.5);
      check(hurwitzZeta(-1.0, 0.5)).isCloseTo(1.0 / 24.0, 1e-14);
      check(hurwitzZeta(-1.0, 0.0)).isCloseTo(-1.0 / 12.0, 1e-14);
      check(hurwitzZeta(-24.0, 0.5)).isCloseTo(0.0, 1e-8);
      check(hurwitzZeta(-25.0, 0.5))
          .isCloseTo((math.pow(2.0, -25) - 1.0) * zeta(-25.0), 1e-8);

      // Integer a <= 0 with negative s < -50 uses zeta(s) + sum_{j=1}^m (-j)^{-s}
      final expectedShift = zeta(-51.0) - 1.0 - math.pow(2.0, 51);
      check(hurwitzZeta(-51.0, -2.0))
          .isCloseTo(expectedShift, 1e-12 * expectedShift.abs());
    });

    test('handles infinities and domain errors', () {
      check(hurwitzZeta(double.infinity, 0.5)).equals(double.infinity);
      check(hurwitzZeta(double.infinity, 1.0)).equals(1.0);
      check(hurwitzZeta(double.infinity, 2.0)).equals(0.0);
      check(hurwitzZeta(2.0, double.infinity)).equals(0.0);
      check(hurwitzZeta(0.5, double.infinity)).isNaN;
      check(hurwitzZeta(double.nan, 1.0)).isNaN;
      check(hurwitzZeta(2.0, double.nan)).isNaN;
      check(hurwitzZeta(2.0, 0.0)).isNaN;
      check(hurwitzZeta(2.0, -2.0)).isNaN;
      check(hurwitzZeta(-0.5, -2.0)).isNaN;
    });
  });

  group('hurwitzZetaComplex', () {
    test('satisfies shift identity across Re(a) and Re(s) signs', () {
      const s = Complex(2.3, 1.1);
      const a = Complex(0.4, 0.6);
      check(
        (hurwitzZetaComplex(s, a) -
                (a.pow(-s) + hurwitzZetaComplex(s, a + Complex.one)))
            .abs(),
      ).isLessThan(1e-13);

      const sLarge = Complex(0.5, 25.0);
      final lhsLarge = hurwitzZetaComplex(sLarge, a);
      final rhsLarge =
          a.pow(-sLarge) + hurwitzZetaComplex(sLarge, a + Complex.one);
      check((lhsLarge - rhsLarge).abs() / lhsLarge.abs()).isLessThan(1e-14);

      const aNeg = Complex(-1.3, 0.5);
      check(
        (hurwitzZetaComplex(s, aNeg) -
                (aNeg.pow(-s) + hurwitzZetaComplex(s, aNeg + Complex.one)))
            .abs(),
      ).isLessThan(1e-13);

      // Integer a <= 0: for Re(s) < 0, 0^(-s) = 0; for Re(s) > 0, pole (NaN)
      const sNegRe = Complex(-0.5, 0.2);
      final expectedNegAInt =
          const Complex(-1.0).pow(-sNegRe) + zetaComplex(sNegRe);
      check(
        (hurwitzZetaComplex(sNegRe, const Complex(-1.0)) - expectedNegAInt)
            .abs(),
      ).isLessThan(1e-13);
      check(
        hurwitzZetaComplex(const Complex(0.5, 0.2), const Complex(-1.0)).isNaN,
      ).isTrue;
      check(hurwitzZetaComplex(const Complex(-1.0), Complex.zero).a)
          .isCloseTo(-1.0 / 12.0, 1e-14);
    });
  });
}
