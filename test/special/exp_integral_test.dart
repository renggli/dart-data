import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/special.dart';
import 'package:more/number.dart' show Complex;
import 'package:test/test.dart';

void main() {
  group('exponential and trigonometric integrals', () {
    test('expIntegral', () {
      check(expIntegral(1.0)).isCloseTo(1.8951178163559368, 1e-12);
      check(expIntegral(2.0)).isCloseTo(4.95423435600189, 1e-12);
      check(expIntegral(-1.0)).isCloseTo(-0.21938393439552027, 1e-12);
      check(expIntegral(-5.0)).isCloseTo(-0.0011482955912753257, 1e-12);
      check(expIntegral(45.0)).isCloseTo(7.943916035704453e17, 1e5);
      check(expIntegral(0.0)).equals(double.negativeInfinity);
      check(expIntegral(double.infinity)).equals(double.infinity);
      check(expIntegral(double.negativeInfinity)).equals(0.0);
      check(expIntegral(double.nan)).isNaN;
    });

    test('logIntegral', () {
      check(logIntegral(0.0)).equals(0.0);
      check(logIntegral(1.0)).equals(double.negativeInfinity);
      check(logIntegral(2.0)).isCloseTo(1.0451637801174928, 1e-12);
      check(logIntegral(math.e)).isCloseTo(expIntegral(1.0), 1e-12);
      check(logIntegral(-1.0)).isNaN;
    });

    test('expIntegralComplex and expIntegralE1Complex', () {
      check(expIntegralComplex(Complex.nan).isNaN).isTrue;
      check(expIntegralE1Complex(Complex.nan).isNaN).isTrue;
      check(expIntegralE1Complex(Complex.zero).a).equals(double.infinity);

      // Near positive real axis (analytic: Ei(x + i*eps) ≈ Ei(x) + i*eps*exp(x)/x)
      final eiNearPos = expIntegralComplex(const Complex(10.0, 1e-6));
      check(eiNearPos.a.toDouble()).isCloseTo(expIntegral(10.0), 1e-6);
      check(eiNearPos.b.toDouble())
          .isCloseTo(1e-6 * math.exp(10.0) / 10.0, 1e-6);

      // Asymptotic region Re(z) > 30
      final eiAsymp = expIntegralComplex(const Complex(35.0, 0.5));
      check(eiAsymp.a.isFinite).isTrue;
      check(eiAsymp.b.isFinite).isTrue;

      // E1 near negative real axis uses convergent power series
      final e1NearNeg = expIntegralE1Complex(const Complex(-5.0, 1e-6));
      check(e1NearNeg.a.toDouble()).isCloseTo(-expIntegral(5.0), 1e-6);
      check(e1NearNeg.b.toDouble()).isCloseTo(-math.pi, 1e-3);

      // E1(1) = -Ei(-1)
      check(expIntegralE1Complex(Complex.one).a.toDouble())
          .isCloseTo(-expIntegral(-1.0), 1e-12);
    });

    test('expIntegralE and expIntegralEComplex', () {
      check(expIntegralE(double.nan, 1.0)).isNaN;
      check(expIntegralE(1.0, double.nan)).isNaN;
      check(expIntegralE(0.0, 2.0)).isCloseTo(math.exp(-2.0) / 2.0, 1e-14);
      check(expIntegralE(2.0, 0.0)).equals(1.0);
      check(expIntegralE(3.0, 0.0)).equals(0.5);
      check(expIntegralE(1.0, 0.0)).equals(double.infinity);
      check(expIntegralE(1.0, 1.0)).isCloseTo(-expIntegral(-1.0), 1e-12);

      // Recurrence identity: n * E_{n+1}(x) + x * E_n(x) = exp(-x)
      // Including large x and n where naive forward recurrence is unstable
      for (final (n, x) in [
        (1.0, 0.5),
        (2.0, 0.8),
        (1.5, 2.5),
        (10.0, 20.0),
        (20.0, 30.0),
      ]) {
        final en = expIntegralE(n, x);
        final en1 = expIntegralE(n + 1.0, x);
        final rhs = math.exp(-x);
        check(n * en1 + x * en).isCloseTo(rhs, 1e-12 * rhs);
      }

      // Complex recurrence identity: n * E_{n+1}(z) + z * E_n(z) = exp(-z)
      const zn = Complex(2.5, 0.4);
      const zz = Complex(3.0, -1.2);
      final cen = expIntegralEComplex(zn, zz);
      final cen1 = expIntegralEComplex(zn + Complex.one, zz);
      check((zn * cen1 + zz * cen - (-zz).exp()).abs()).isLessThan(1e-12);

      // Small |z| complex branch
      const zSmall = Complex(0.4, 0.3);
      final ces = expIntegralEComplex(const Complex(2.0), zSmall);
      final ces1 = expIntegralEComplex(const Complex(3.0), zSmall);
      check((const Complex(2.0) * ces1 + zSmall * ces - (-zSmall).exp()).abs())
          .isLessThan(1e-12);
    });
  });
}
