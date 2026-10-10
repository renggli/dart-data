import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/special.dart';
import 'package:test/test.dart';

void main() {
  group('Lambert W function', () {
    test('Lambert W0 known values', () {
      check(lambertW0(0.0)).equals(0.0);
      check(lambertW0(math.e)).isCloseTo(1.0, 1e-7);
      check(lambertW0(-1.0 / math.e)).isCloseTo(-1.0, 1e-6);
      check(lambertW0(-0.5)).isNaN(); // < -1/e
      check(lambertW0(double.infinity)).equals(double.infinity);

      final wVal = lambertW0(2.0);
      check(wVal * math.exp(wVal)).isCloseTo(2.0, 1e-9);
    });

    test('Lambert W1 known values', () {
      check(lambertW1(0.0)).isNaN();
      check(lambertW1(1.0)).isNaN();
      check(lambertW1(-1.0 / math.e)).isCloseTo(-1.0, 1e-5);
      final wVal = lambertW1(-0.1);
      check(wVal * math.exp(wVal)).isCloseTo(-0.1, 1e-7);
    });
  });
}
