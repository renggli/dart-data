import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/special.dart';
import 'package:more/number.dart' show Complex;
import 'package:test/scaffolding.dart';

void main() {
  group('expIntegral', () {
    test('evaluates positive, negative, and split-exp regions', () {
      check(expIntegral(1.0)).isCloseTo(1.8951178163559368, 1e-14);
      check(expIntegral(2.0)).isCloseTo(4.95423435600189, 1e-14);
      check(expIntegral(-1.0)).isCloseTo(-0.21938393439552027, 1e-14);
      check(expIntegral(-5.0)).isCloseTo(-0.0011482955912753257, 1e-14);
      check(expIntegral(45.0)).isCloseTo(7.943916035704453e17, 1e5);

      final logEi712 = math.log(expIntegral(712.0));
      final expectedLog =
          712.0 -
          math.log(712.0) +
          math.log(
            1.0 +
                1.0 / 712.0 +
                2.0 / (712.0 * 712.0) +
                6.0 / (712.0 * 712.0 * 712.0),
          );
      check(logEi712).isCloseTo(expectedLog, 1e-10);
    });

    test('handles zero, infinities, and NaN', () {
      check(expIntegral(0.0)).equals(double.negativeInfinity);
      check(expIntegral(double.infinity)).equals(double.infinity);
      check(expIntegral(double.negativeInfinity)).equals(0.0);
      check(expIntegral(double.nan)).isNaN;
    });
  });

  group('expIntegralComplex', () {
    test('matches off-axis continuations and complex derivative', () {
      check(expIntegralComplex(Complex.nan).isNaN).isTrue;
      final eiNearPos = expIntegralComplex(const Complex(10.0, 1e-6));
      check(eiNearPos.a.toDouble()).isCloseTo(expIntegral(10.0), 1e-6);
      check(eiNearPos.b.toDouble())
          .isCloseTo(1e-6 * math.exp(10.0) / 10.0, 1e-6);

      const zAsymp = Complex(45.0, 0.5);
      const h = 1e-6;
      final dfAsymp =
          (expIntegralComplex(zAsymp + h) - expIntegralComplex(zAsymp - h)) /
          (2.0 * h);
      final expectedDeriv = zAsymp.exp() / zAsymp;
      check((dfAsymp - expectedDeriv).abs() / expectedDeriv.abs())
          .isLessThan(1e-7);

      final eiNearImag = expIntegralComplex(const Complex(1.0, 20.0));
      final e1Neg = expIntegralEComplex(
        Complex.one,
        const Complex(-1.0, -20.0),
      );
      check((eiNearImag - (-e1Neg + const Complex(0.0, math.pi))).abs())
          .isLessThan(1e-12);
    });
  });

  group('expIntegralE', () {
    test('evaluates special orders, negative arguments, and recurrence', () {
      check(expIntegralE(0.0, 2.0)).isCloseTo(math.exp(-2.0) / 2.0, 1e-14);
      check(expIntegralE(2.0, 0.0)).equals(1.0);
      check(expIntegralE(3.0, 0.0)).equals(0.5);
      check(expIntegralE(1.0, 0.0)).equals(double.infinity);
      check(expIntegralE(1.0, 1.0)).isCloseTo(-expIntegral(-1.0), 1e-14);

      // Half-integer E_{0.5}(x) = sqrt(pi / x) * erfc(sqrt(x))
      check(expIntegralE(0.5, 2.0))
          .isCloseTo(math.sqrt(math.pi / 2.0) * erfc(math.sqrt2), 1e-13);

      // Negative order real inputs and negative x branches
      check(expIntegralE(-1.0, 2.0))
          .isCloseTo(math.exp(-2.0) * (1.0 + 0.5) / 2.0, 1e-13);
      check(expIntegralE(-1.0, -2.0)).isCloseTo(-math.exp(2.0) / 4.0, 1e-13);
      check(expIntegralE(1.0, -1.0)).isNaN;

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
    });

    test('handles infinities and NaN', () {
      check(expIntegralE(double.nan, 1.0)).isNaN;
      check(expIntegralE(1.0, double.nan)).isNaN;
      check(expIntegralE(2.0, double.infinity)).equals(0.0);
      check(expIntegralE(double.infinity, 2.0)).equals(0.0);
    });
  });

  group('expIntegralEComplex', () {
    test(
      'satisfies recurrence across real, fractional, and negative orders',
      () {
        check(expIntegralEComplex(Complex.one, Complex.zero).a)
            .equals(double.infinity);
        check(expIntegralEComplex(Complex.one, Complex.one).a.toDouble())
            .isCloseTo(-expIntegral(-1.0), 1e-14);

        for (final (n, z) in const [
          (Complex(2.5, 0.4), Complex(3.0, -1.2)),
          (Complex(2.0), Complex(0.4, 0.3)),
          (Complex(0.5, 0.2), Complex(0.4, 0.3)),
          (Complex(-1.0), Complex(0.5, 0.3)),
        ]) {
          final en = expIntegralEComplex(n, z);
          final en1 = expIntegralEComplex(n + Complex.one, z);
          check((n * en1 + z * en - (-z).exp()).abs()).isLessThan(1e-12);
        }

        const zNegReal = Complex(-45.0, 0.5);
        const h = 1e-6;
        final df =
            (expIntegralEComplex(Complex.one, zNegReal + h) -
                expIntegralEComplex(Complex.one, zNegReal - h)) /
            (2.0 * h);
        final expected = -(-zNegReal).exp() / zNegReal;
        check((df - expected).abs() / expected.abs()).isLessThan(1e-7);
      },
    );
  });

  group('logIntegral', () {
    test('evaluates real values and boundaries', () {
      check(logIntegral(0.0)).equals(0.0);
      check(logIntegral(1.0)).equals(double.negativeInfinity);
      check(logIntegral(2.0)).isCloseTo(1.0451637801174928, 1e-14);
      check(logIntegral(math.e)).isCloseTo(expIntegral(1.0), 1e-14);
      check(logIntegral(-1.0)).isNaN;
      check(logIntegral(double.nan)).isNaN;
    });
  });

  group('logIntegralComplex', () {
    test('evaluates complex values and domain boundaries', () {
      check(logIntegralComplex(Complex.zero)).equals(Complex.zero);
      check(logIntegralComplex(Complex.one))
          .equals(const Complex(double.negativeInfinity));
      check(logIntegralComplex(const Complex(double.infinity)))
          .equals(const Complex(double.infinity));
      check(logIntegralComplex(Complex.nan).isNaN).isTrue;
      check(logIntegralComplex(const Complex(double.infinity, 1.0)).isNaN)
          .isTrue;

      const z = Complex(2.0, 1.0);
      check((logIntegralComplex(z) - expIntegralComplex(z.log())).abs())
          .isLessThan(1e-13);
    });
  });
}
