import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/special.dart';
import 'package:more/number.dart' show Complex;
import 'package:test/test.dart';

void main() {
  group('digamma and trigamma functions', () {
    test('digamma known values', () {
      check(digamma(1)).isCloseTo(-0.5772156649, 1e-6); // -EulerMascheroni
      check(digamma(2)).isCloseTo(1.0 - 0.5772156649, 1e-6);
      check(digamma(0.5)).isCloseTo(-2.0 * math.ln2 - 0.5772156649, 1e-6);
      check(digamma(0)).isNaN;
      check(digamma(-1)).isNaN;
      check(digamma(double.infinity)).equals(double.infinity);
      check(digamma(double.negativeInfinity)).isNaN;
      check(digamma(-1.5).isFinite).isTrue;
    });

    test('trigamma known values', () {
      check(polygamma(1, 1)).isCloseTo(math.pi * math.pi / 6.0, 1e-6);
      check(polygamma(1, 2)).isCloseTo(math.pi * math.pi / 6.0 - 1.0, 1e-6);
      check(polygamma(1, 0)).isNaN;
      check(polygamma(1, -1)).isNaN;
      check(polygamma(1, double.infinity)).equals(0.0);
      check(polygamma(1, double.negativeInfinity)).isNaN;
      check(polygamma(1, -1.5).isFinite).isTrue;
    });

    test('polygamma known values', () {
      check(() => polygamma(-1, 1.0)).throws<ArgumentError>();

      // polygamma(0, x) == digamma(x)
      for (final x in [0.5, 1.0, 2.0, 3.5]) {
        check(polygamma(0, x)).isCloseTo(digamma(x), 1e-10);
      }

      // polygamma(1, x) == polygamma(1, x)
      for (final x in [0.5, 1.0, 2.0, 3.5]) {
        check(polygamma(1, x)).isCloseTo(polygamma(1, x), 1e-10);
      }

      // polygamma(2, 1) = -2 * zeta(3) ~= -2.4041138063
      check(polygamma(2, 1)).isCloseTo(-2.4041138063191885, 1e-8);
      // polygamma(2, 2) = -2 * zeta(3) + 2 ~= -0.4041138063
      check(polygamma(2, 2)).isCloseTo(-0.4041138063191885, 1e-8);

      // Non-positive integers return NaN
      check(polygamma(2, 0)).isNaN;
      check(polygamma(2, -1)).isNaN;
      check(polygamma(2, -2)).isNaN;

      // Negative non-integers are finite via reflection
      check(polygamma(2, -0.5)).isCloseTo(polygamma(2, 1.5), 1e-10);
      check(polygamma(2, -1.5)).isCloseTo(polygamma(2, 2.5), 1e-10);
      check(polygamma(3, -0.5))
          .isCloseTo(2 * math.pow(math.pi, 4) - polygamma(3, 1.5), 1e-8);

      // Large negative values evaluate instantly via reflection without looping
      check(polygamma(2, -1e8 - 0.5).isFinite).isTrue;
      check(polygamma(2, -1e14 - 0.5).isFinite).isTrue;
      check(polygamma(3, -1e8 - 0.5).isFinite).isTrue;
    });

    test('digammaComplex and polygammaComplex', () {
      for (final x in [0.5, 1.0, 2.5, -0.7]) {
        final dc = digammaComplex(Complex(x));
        check(dc.a).isCloseTo(digamma(x), 1e-12);
        check(dc.b).isCloseTo(0.0, 1e-12);
        final pc = polygammaComplex(1, Complex(x));
        check(pc.a).isCloseTo(polygamma(1, x), 1e-12);
        check(pc.b).isCloseTo(0.0, 1e-12);
      }
      // Recurrence psi(z + 1) = psi(z) + 1/z
      const z = Complex(1.3, 0.7);
      check(
        (digammaComplex(z + Complex.one) -
                (digammaComplex(z) + Complex.one / z))
            .abs(),
      ).isLessThan(1e-12);
      // Reflection psi(-z) and polygamma(2, z)
      check(
        (polygammaComplex(2, const Complex(-0.5, 0.4)) -
                (polygammaComplex(2, const Complex(0.5, 0.4)) -
                    const Complex(2.0) / const Complex(-0.5, 0.4).pow(3)))
            .abs(),
      ).isLessThan(1e-11);
      check(() => polygammaComplex(-1, z)).throws<ArgumentError>();
    });
  });
}
