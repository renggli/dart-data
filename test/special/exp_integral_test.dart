import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/special.dart';
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
  });
}
