import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/special.dart';
import 'package:test/test.dart';

void main() {
  group('exponential and trigonometric integrals', () {
    test('expIntegralEi', () {
      check(expIntegralEi(1.0)).isCloseTo(1.8951178163559368, 1e-12);
      check(expIntegralEi(2.0)).isCloseTo(4.95423435600189, 1e-12);
      check(expIntegralEi(-1.0)).isCloseTo(-0.21938393439552027, 1e-12);
      check(expIntegralEi(-5.0)).isCloseTo(-0.0011482955912753257, 1e-12);
      check(expIntegralEi(45.0)).isCloseTo(7.943916035704453e17, 1e5);
      check(expIntegralEi(0.0)).equals(double.negativeInfinity);
      check(expIntegralEi(double.infinity)).equals(double.infinity);
      check(expIntegralEi(double.negativeInfinity)).equals(0.0);
      check(expIntegralEi(double.nan)).isNaN;
    });

    test('logIntegralLi', () {
      check(logIntegralLi(0.0)).equals(0.0);
      check(logIntegralLi(1.0)).equals(double.negativeInfinity);
      check(logIntegralLi(2.0)).isCloseTo(1.0451637801174928, 1e-12);
      check(logIntegralLi(math.e)).isCloseTo(expIntegralEi(1.0), 1e-12);
      check(logIntegralLi(-1.0)).isNaN;
    });

    test('sinIntegralSi and cosIntegralCi', () {
      check(sinIntegralSi(0.0)).equals(0.0);
      check(sinIntegralSi(1.0)).isCloseTo(0.946083070367183, 1e-12);
      check(sinIntegralSi(-1.0)).isCloseTo(-0.946083070367183, 1e-12);
      check(sinIntegralSi(5.0)).isCloseTo(1.5499312449446738, 1e-12);
      check(sinIntegralSi(double.infinity)).isCloseTo(math.pi / 2.0, 1e-12);

      check(cosIntegralCi(1.0)).isCloseTo(0.33740392290096813, 1e-12);
      check(cosIntegralCi(5.0)).isCloseTo(-0.19002974965664385, 1e-12);
      check(cosIntegralCi(0.0)).equals(double.negativeInfinity);
      check(cosIntegralCi(double.infinity)).equals(0.0);
      check(cosIntegralCi(-1.0)).isNaN;
    });

    test('sinhIntegralShi and coshIntegralChi', () {
      check(sinhIntegralShi(0.0)).equals(0.0);
      check(sinhIntegralShi(1.0)).isCloseTo(1.0572508753757285, 1e-12);
      check(sinhIntegralShi(-1.0)).isCloseTo(-1.0572508753757285, 1e-12);
      check(sinhIntegralShi(5.0)).isCloseTo(20.093211825697228, 1e-11);

      check(coshIntegralChi(1.0)).isCloseTo(0.8378669409802082, 1e-12);
      check(coshIntegralChi(5.0)).isCloseTo(20.09206353010595, 1e-11);
      check(coshIntegralChi(0.0)).equals(double.negativeInfinity);
      check(coshIntegralChi(-1.0)).isNaN;
    });
  });
}
