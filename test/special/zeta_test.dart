import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/special.dart';
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
    });

    test('zeta edge cases', () {
      check(zeta(double.nan)).isNaN();
      check(zeta(double.negativeInfinity)).isNaN();
    });
  });
}
