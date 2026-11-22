import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/special.dart';
import 'package:more/number.dart' show Complex;
import 'package:test/test.dart';

void main() {
  group('zeta function', () {
    test('zeta positive arguments', () {
      check(zeta(1)).equals(double.infinity);
      check(zeta(2)).isCloseTo(math.pi * math.pi / 6.0, 1e-10);
      check(zeta(3)).isCloseTo(1.2020569031595942, 1e-10);
      check(zeta(4)).isCloseTo(math.pow(math.pi, 4) / 90.0, 1e-10);
      check(zeta(10)).isCloseTo(1.000994575127818, 1e-10);
      check(zeta(double.infinity)).equals(1.0);
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
      // First non-trivial Riemann zero ~ 0.5 + 14.134725141734693i
      final zZero = zetaComplex(const Complex(0.5, 14.134725141734693));
      check(zZero.abs()).isLessThan(1e-5);
      // Functional equation at complex point s = 0.3 + 1.5i
      const s = Complex(0.3, 1.5);
      final rhs =
          const Complex(2.0).pow(s) *
          const Complex(math.pi).pow(s - Complex.one) *
          (const Complex(0.5 * math.pi) * s).sin() *
          gammaComplex(Complex.one - s) *
          zetaComplex(Complex.one - s);
      check((zetaComplex(s) - rhs).abs()).isLessThan(1e-12);

      // Exact trivial zeros at negative even integers
      check(zetaComplex(const Complex(-2))).equals(Complex.zero);
      check(zetaComplex(const Complex(-120))).equals(Complex.zero);

      // Large negative real part uses log-space reflection without overflow
      final zNegLarge = zetaComplex(const Complex(-105.5, 1.0));
      check(zNegLarge.a.isFinite).isTrue;
      check(zNegLarge.b.isFinite).isTrue;
    });
  });
}
