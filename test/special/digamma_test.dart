import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/special.dart';
import 'package:more/number.dart' show Complex;
import 'package:test/scaffolding.dart';

void main() {
  group('digamma', () {
    test('evaluates positive values and negative-axis reflection', () {
      const euler = 0.5772156649015329;
      check(digamma(1)).isCloseTo(-euler, 1e-15);
      check(digamma(2)).isCloseTo(1.0 - euler, 1e-15);
      check(digamma(0.5)).isCloseTo(-2.0 * math.ln2 - euler, 1e-14);
      check(digamma(-1.5)).isCloseTo(digamma(2.5), 1e-14);
      check(digamma(-10000000.5)).isCloseTo(digamma(10000001.5), 1e-12);
    });

    test('handles poles and infinities', () {
      check(digamma(0)).isNaN;
      check(digamma(-1)).isNaN;
      check(digamma(double.nan)).isNaN;
      check(digamma(double.infinity)).equals(double.infinity);
      check(digamma(double.negativeInfinity)).isNaN;
    });
  });

  group('digammaComplex', () {
    test('matches real values and satisfies recurrence', () {
      for (final x in [0.5, 1.0, 2.5, -0.7]) {
        final dc = digammaComplex(Complex(x));
        check(dc.a).isCloseTo(digamma(x), 1e-13);
        check(dc.b).isCloseTo(0.0, 1e-13);
      }
      for (final z in const [
        Complex(1.3, 0.7),
        Complex(-1.3, 250.0),
        Complex(1.0, 250.0),
      ]) {
        check(
          (digammaComplex(z + Complex.one) -
                  (digammaComplex(z) + Complex.one / z))
              .abs(),
        ).isLessThan(1e-12);
      }
    });

    test('handles poles and non-finite inputs', () {
      check(digammaComplex(Complex.zero).isNaN).isTrue;
      check(digammaComplex(const Complex(-2)).isNaN).isTrue;
      check(digammaComplex(Complex.nan).isNaN).isTrue;
      check(digammaComplex(const Complex(double.infinity, 1.0)).isNaN).isTrue;
    });
  });

  group('polygamma', () {
    test('matches digamma and trigamma for orders 0 and 1', () {
      for (final x in [0.5, 1.0, 2.0, 3.5]) {
        check(polygamma(0, x)).isCloseTo(digamma(x), 1e-14);
      }
      check(polygamma(1, 1)).isCloseTo(math.pi * math.pi / 6.0, 1e-14);
      check(polygamma(1, 2)).isCloseTo(math.pi * math.pi / 6.0 - 1.0, 1e-14);
      check(polygamma(1, -1.5))
          .isCloseTo(math.pi * math.pi - polygamma(1, 2.5), 1e-13);
    });

    test('evaluates higher orders and reflection identities', () {
      check(polygamma(2, 1)).isCloseTo(-2.4041138063191885, 1e-14);
      check(polygamma(2, 2)).isCloseTo(-0.4041138063191885, 1e-14);
      check(polygamma(2, -0.5)).isCloseTo(polygamma(2, 1.5), 1e-13);
      check(polygamma(2, -1.5)).isCloseTo(polygamma(2, 2.5), 1e-13);
      check(polygamma(3, -0.5))
          .isCloseTo(2 * math.pow(math.pi, 4) - polygamma(3, 1.5), 1e-11);
      check(polygamma(2, -1e14 - 0.5))
          .isCloseTo(polygamma(2, 1e14 + 1.5), 1e-12);

      final psi200 = polygamma(200, 5.0);
      check(psi200).isLessThan(0.0);
      final logAsymp200 = gammaLn(201.0) - 201.0 * math.log(5.0);
      check(math.log(-psi200)).isCloseTo(logAsymp200, 1e-2);
    });

    test('handles invalid orders, poles, and infinities', () {
      check(() => polygamma(-1, 1.0)).throws<ArgumentError>();
      check(polygamma(1, 0)).isNaN;
      check(polygamma(2, -2)).isNaN;
      check(polygamma(1, double.infinity)).equals(0.0);
      check(polygamma(2, double.negativeInfinity)).isNaN;
    });
  });

  group('polygammaComplex', () {
    test('satisfies recurrence across real and large-imaginary inputs', () {
      final pc = polygammaComplex(1, const Complex(2.5));
      check(pc.a).isCloseTo(polygamma(1, 2.5), 1e-14);
      check(pc.b).isCloseTo(0.0, 1e-14);

      for (final z in const [Complex(-0.5, 0.4), Complex(-1.3, 250.0)]) {
        final lhs = polygammaComplex(2, z);
        final rhs =
            polygammaComplex(2, z + Complex.one) -
            const Complex(2.0) / z.pow(3);
        check((lhs - rhs).abs() / rhs.abs()).isLessThan(1e-10);
      }
    });

    test('handles invalid orders and non-finite inputs', () {
      check(() => polygammaComplex(-1, const Complex(1.3, 0.7)))
          .throws<ArgumentError>();
      check(polygammaComplex(2, Complex.zero).isNaN).isTrue;
      check(polygammaComplex(2, Complex.nan).isNaN).isTrue;
    });
  });
}
