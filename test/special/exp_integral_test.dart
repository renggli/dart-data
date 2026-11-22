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
  });
}
