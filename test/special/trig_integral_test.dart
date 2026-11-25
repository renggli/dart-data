import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/special.dart';
import 'package:more/number.dart' show Complex;
import 'package:test/scaffolding.dart';

void main() {
  group('sinIntegral', () {
    test('evaluates reference values, odd symmetry, and boundaries', () {
      check(sinIntegral(0.0)).equals(0.0);
      check(sinIntegral(1.0)).isCloseTo(0.946083070367183, 1e-14);
      check(sinIntegral(-1.0)).isCloseTo(-0.946083070367183, 1e-14);
      check(sinIntegral(5.0)).isCloseTo(1.5499312449446738, 1e-14);
      check(sinIntegral(double.infinity)).isCloseTo(math.pi / 2.0, 1e-14);
      check(sinIntegral(double.negativeInfinity))
          .isCloseTo(-math.pi / 2.0, 1e-14);
      check(sinIntegral(double.nan)).isNaN;
    });
  });

  group('cosIntegral', () {
    test('evaluates reference values and boundaries', () {
      check(cosIntegral(1.0)).isCloseTo(0.33740392290096813, 1e-14);
      check(cosIntegral(5.0)).isCloseTo(-0.19002974965664385, 1e-14);
      check(cosIntegral(0.0)).equals(double.negativeInfinity);
      check(cosIntegral(double.infinity)).equals(0.0);
      check(cosIntegral(-1.0)).isNaN;
      check(cosIntegral(double.nan)).isNaN;
    });
  });

  group('sinhIntegral', () {
    test('evaluates reference values, odd symmetry, and boundaries', () {
      check(sinhIntegral(0.0)).equals(0.0);
      check(sinhIntegral(1.0)).isCloseTo(1.0572508753757285, 1e-14);
      check(sinhIntegral(-1.0)).isCloseTo(-1.0572508753757285, 1e-14);
      check(sinhIntegral(5.0)).isCloseTo(20.093211825697228, 1e-12);
      check(sinhIntegral(double.infinity)).equals(double.infinity);
      check(sinhIntegral(double.nan)).isNaN;
    });
  });

  group('coshIntegral', () {
    test('evaluates reference values and boundaries', () {
      check(coshIntegral(1.0)).isCloseTo(0.8378669409802082, 1e-14);
      check(coshIntegral(5.0)).isCloseTo(20.09206353010595, 1e-12);
      check(coshIntegral(0.0)).equals(double.negativeInfinity);
      check(coshIntegral(-1.0)).isNaN;
      check(coshIntegral(double.infinity)).equals(double.infinity);
      check(coshIntegral(double.nan)).isNaN;
    });
  });

  group('sinIntegralComplex', () {
    test('matches real, negative imaginary, and odd symmetries', () {
      check(sinIntegralComplex(const Complex(5.0)).a.toDouble())
          .isCloseTo(sinIntegral(5.0), 1e-13);

      const zLargePos = Complex(5.0, 1.0);
      check(
        (sinIntegralComplex(zLargePos) + sinIntegralComplex(-zLargePos)).abs(),
      ).isLessThan(1e-12);

      final siNegImag = sinIntegralComplex(const Complex(0.0, -5.0));
      check(siNegImag.a.toDouble()).isCloseTo(0.0, 1e-12);
      check(siNegImag.b.toDouble()).isCloseTo(-sinhIntegral(5.0), 1e-11);
      check(sinIntegralComplex(const Complex(double.infinity, 1.0)).isNaN)
          .isTrue;
    });
  });

  group('cosIntegralComplex', () {
    test('matches real axis and negative imaginary branch cut', () {
      check(cosIntegralComplex(const Complex(1.0)).a)
          .isCloseTo(cosIntegral(1.0), 1e-13);
      check(cosIntegralComplex(const Complex(5.0)).a.toDouble())
          .isCloseTo(cosIntegral(5.0), 1e-13);

      final ciNegImag = cosIntegralComplex(const Complex(0.0, -5.0));
      check(ciNegImag.a.toDouble()).isCloseTo(coshIntegral(5.0), 1e-11);
      check(ciNegImag.b.toDouble()).isCloseTo(-math.pi / 2.0, 1e-12);
      check(cosIntegralComplex(Complex.zero).a).equals(double.negativeInfinity);
      check(cosIntegralComplex(Complex.nan).isNaN).isTrue;
    });
  });

  group('sinhIntegralComplex', () {
    test('evaluates series and off-axis large-|z| regime via derivative', () {
      check(
        (sinhIntegralComplex(const Complex(-5.0, 0.0)).a.toDouble()) +
            sinhIntegral(5.0),
      ).isCloseTo(0.0, 1e-11);

      const h = 1e-6;
      for (final z in const [Complex(1.2, 0.7), Complex(5.0, 1.0)]) {
        check((sinhIntegralComplex(z) + sinhIntegralComplex(-z)).abs())
            .isLessThan(1e-12);
        final df =
            (sinhIntegralComplex(z + h) - sinhIntegralComplex(z - h)) /
            (2.0 * h);
        final expected = z.sinh() / z;
        check((df - expected).abs() / expected.abs()).isLessThan(1e-8);
      }
      check(sinhIntegralComplex(Complex.nan).isNaN).isTrue;
    });
  });

  group('coshIntegralComplex', () {
    test('matches real axis and negative real branch cut', () {
      check(coshIntegralComplex(const Complex(1.0)).a)
          .isCloseTo(coshIntegral(1.0), 1e-13);
      check(coshIntegralComplex(const Complex(5.0, 0.0)).a.toDouble())
          .isCloseTo(coshIntegral(5.0), 1e-12);

      final chiNegReal = coshIntegralComplex(const Complex(-5.0, 0.0));
      check(chiNegReal.a.toDouble()).isCloseTo(coshIntegral(5.0), 1e-11);
      check(chiNegReal.b.toDouble()).isCloseTo(math.pi, 1e-12);
      check(coshIntegralComplex(Complex.zero).a)
          .equals(double.negativeInfinity);
      check(coshIntegralComplex(Complex.nan).isNaN).isTrue;
    });
  });
}
