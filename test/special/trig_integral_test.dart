import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/special.dart';
import 'package:more/number.dart' show Complex;
import 'package:test/test.dart';

void main() {
  group('trigonometric and hyperbolic integrals', () {
    test('sinIntegral and cosIntegral', () {
      check(sinIntegral(0.0)).equals(0.0);
      check(sinIntegral(1.0)).isCloseTo(0.946083070367183, 1e-12);
      check(sinIntegral(-1.0)).isCloseTo(-0.946083070367183, 1e-12);
      check(sinIntegral(5.0)).isCloseTo(1.5499312449446738, 1e-12);
      check(sinIntegral(double.infinity)).isCloseTo(math.pi / 2.0, 1e-12);

      check(cosIntegral(1.0)).isCloseTo(0.33740392290096813, 1e-12);
      check(cosIntegral(5.0)).isCloseTo(-0.19002974965664385, 1e-12);
      check(cosIntegral(0.0)).equals(double.negativeInfinity);
      check(cosIntegral(double.infinity)).equals(0.0);
      check(cosIntegral(-1.0)).isNaN;
    });

    test('sinhIntegral and coshIntegral', () {
      check(sinhIntegral(0.0)).equals(0.0);
      check(sinhIntegral(1.0)).isCloseTo(1.0572508753757285, 1e-12);
      check(sinhIntegral(-1.0)).isCloseTo(-1.0572508753757285, 1e-12);
      check(sinhIntegral(5.0)).isCloseTo(20.093211825697228, 1e-11);

      check(coshIntegral(1.0)).isCloseTo(0.8378669409802082, 1e-12);
      check(coshIntegral(5.0)).isCloseTo(20.09206353010595, 1e-11);
      check(coshIntegral(0.0)).equals(double.negativeInfinity);
      check(coshIntegral(-1.0)).isNaN;
    });

    test('complex trigonometric and hyperbolic integrals', () {
      const z = Complex(1.2, 0.7);
      check(
        (sinIntegralComplex(z) - sinhIntegralComplex(Complex.i * z) / Complex.i)
            .abs(),
      ).isLessThan(1e-12);
      check(cosIntegralComplex(const Complex(1.0)).a)
          .isCloseTo(cosIntegral(1.0), 1e-12);
      check(coshIntegralComplex(const Complex(1.0)).a)
          .isCloseTo(coshIntegral(1.0), 1e-12);
    });
  });
}
