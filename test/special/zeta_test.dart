import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/special.dart';
import 'package:more/number.dart' show Complex;
import 'package:test/test.dart';

void main() {
  group('zeta function', () {
    test('zeta positive arguments', () {
      check(zeta(1)).equals(double.infinity);
      check(zeta(2)).isCloseTo(math.pi * math.pi / 6.0, 1e-14);
      check(zeta(3)).isCloseTo(1.2020569031595942, 1e-14);
      check(zeta(4)).isCloseTo(math.pow(math.pi, 4) / 90.0, 1e-14);
      check(zeta(10)).isCloseTo(1.000994575127818, 1e-14);
      check(zeta(30)).isCloseTo(
        1.0 + math.pow(2.0, -30) + math.pow(3.0, -30) + math.pow(4.0, -30),
        1e-15,
      );
      check(zeta(60)).equals(1.0);
      check(zeta(double.infinity)).equals(1.0);
      // Near pole s = 1 + eps: ζ(s) ≈ 1/(s - 1) + γ
      const sNear = 1.0 + 1e-8;
      check(zeta(sNear) - 1.0 / (sNear - 1.0)).isCloseTo(0.5772156649, 1e-6);
    });

    test('zeta zero and negative arguments', () {
      check(zeta(0)).isCloseTo(-0.5, 1e-10);
      check(zeta(-1)).isCloseTo(-1.0 / 12.0, 1e-10);
      check(zeta(-2)).isCloseTo(0.0, 1e-10);
      check(zeta(-3)).isCloseTo(1.0 / 120.0, 1e-10);
      check(zeta(-4)).isCloseTo(0.0, 1e-10);
      check(zeta(-5)).isCloseTo(-1.0 / 252.0, 1e-10);
      check(zeta(-6)).isCloseTo(0.0, 1e-10);

      // s < -170 avoids overflow in gamma
      check(zeta(-170)).equals(0.0);
      check(zeta(-171).isFinite).isTrue;
      check(zeta(-170.5).isFinite).isTrue;
      check(zeta(-301).isInfinite).isTrue;
    });

    test('zeta edge cases', () {
      check(zeta(double.nan)).isNaN;
      check(zeta(double.negativeInfinity)).isNaN;
    });

    test('zetaComplex', () {
      for (final s in [2.0, 3.0, 0.5, -1.5]) {
        final zc = zetaComplex(Complex(s));
        check(zc.a).isCloseTo(zeta(s), 1e-12);
        check(zc.b).isCloseTo(0.0, 1e-12);
      }
      // Non-trivial Riemann zeros on the critical line (1st, 2nd, 10th, 100th)
      for (final (t, tol) in const [
        (14.13472514173469379, 1e-13),
        (21.02203963877155499, 1e-13),
        (49.77383247767230218, 1e-12),
        (236.5242296658162058, 1e-11),
      ]) {
        check(zetaComplex(Complex(0.5, t)).abs()).isLessThan(tol);
        check(zetaComplex(Complex(0.5, -t)).abs()).isLessThan(tol);
      }

      // No spurious pole at 1 - 2^(1 - s) = 0 (s = 1 + 2πi / ln 2)
      const spuriousPole = Complex(1.0, 2.0 * math.pi / math.ln2);
      final zAtSpurious = zetaComplex(spuriousPole);
      check(zAtSpurious.a.isFinite).isTrue;
      check(zAtSpurious.b.isFinite).isTrue;
      check(zAtSpurious.a).isCloseTo(1.3465795428363176, 1e-13);
      check(zAtSpurious.b).isCloseTo(0.1098831367962698, 1e-13);

      // Functional equation at complex point s = 0.3 + 1.5i
      const s = Complex(0.3, 1.5);
      final rhs =
          const Complex(2.0).pow(s) *
          const Complex(math.pi).pow(s - Complex.one) *
          (const Complex(0.5 * math.pi) * s).sin() *
          gammaComplex(Complex.one - s) *
          zetaComplex(Complex.one - s);
      check((zetaComplex(s) - rhs).abs()).isLessThan(1e-12);

      // Log-space reflection at large imaginary part (t = 50 and t = 500)
      final zReflect50 = zetaComplex(const Complex(0.2, 50.0));
      check(zReflect50.a.isFinite).isTrue;
      check(zReflect50.b.isFinite).isTrue;
      final zReflect500 = zetaComplex(const Complex(0.2, 500.0));
      check(zReflect500.a.isFinite).isTrue;
      check(zReflect500.b.isFinite).isTrue;

      // Exact trivial zeros at negative even integers
      check(zetaComplex(const Complex(-2))).equals(Complex.zero);
      check(zetaComplex(const Complex(-120))).equals(Complex.zero);

      // Large negative real part uses log-space reflection without overflow
      final zNegLarge = zetaComplex(const Complex(-105.5, 1.0));
      check(zNegLarge.a.isFinite).isTrue;
      check(zNegLarge.b.isFinite).isTrue;
    });

    test('hurwitzZeta and hurwitzZetaComplex', () {
      check(hurwitzZeta(double.nan, 1.0)).isNaN;
      check(hurwitzZeta(2.0, double.nan)).isNaN;
      check(hurwitzZeta(1.0, 2.0)).equals(double.infinity);
      check(hurwitzZeta(2.0, 1.0)).isCloseTo(zeta(2.0), 1e-14);
      check(hurwitzZeta(2.0, 0.5)).isCloseTo(math.pi * math.pi / 2.0, 1e-12);
      check(hurwitzZeta(3.0, 0.5)).isCloseTo(7.0 * zeta(3.0), 1e-12);

      // Bernoulli polynomial identities at non-positive integer s
      check(hurwitzZeta(0.0, 0.25)).isCloseTo(0.25, 1e-12);
      check(hurwitzZeta(0.0, 0.0)).equals(0.5);
      check(hurwitzZeta(-1.0, 0.5)).isCloseTo(1.0 / 24.0, 1e-12);
      check(hurwitzZeta(-1.0, 0.0)).isCloseTo(-1.0 / 12.0, 1e-12);
      check(hurwitzZeta(2.0, 0.0)).isNaN;
      check(hurwitzZeta(2.0, -2.0)).isNaN;

      // Shift identity: ζ(s, a) = a^(-s) + ζ(s, a + 1)
      const s = Complex(2.3, 1.1);
      const a = Complex(0.4, 0.6);
      check(
        (hurwitzZetaComplex(s, a) -
                (a.pow(-s) + hurwitzZetaComplex(s, a + Complex.one)))
            .abs(),
      ).isLessThan(1e-12);

      // Shift identity at large imaginary part (relative error < 1e-14)
      const sLarge = Complex(0.5, 25.0);
      final lhsLarge = hurwitzZetaComplex(sLarge, a);
      final rhsLarge =
          a.pow(-sLarge) + hurwitzZetaComplex(sLarge, a + Complex.one);
      check((lhsLarge - rhsLarge).abs() / lhsLarge.abs()).isLessThan(1e-14);

      // Negative real part shift in complex Hurwitz zeta
      const aNeg = Complex(-1.3, 0.5);
      check(
        (hurwitzZetaComplex(s, aNeg) -
                (aNeg.pow(-s) + hurwitzZetaComplex(s, aNeg + Complex.one)))
            .abs(),
      ).isLessThan(1e-12);
    });
  });
}
