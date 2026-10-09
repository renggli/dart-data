import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/special.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('digamma and trigamma functions', () {
    test('digamma known values', () {
      check(digamma(1)).isCloseTo(-0.5772156649, 1e-6); // -EulerMascheroni
      check(digamma(2)).isCloseTo(1.0 - 0.5772156649, 1e-6);
      check(digamma(0.5)).isCloseTo(-2.0 * math.ln2 - 0.5772156649, 1e-6);
      check(digamma(0)).isNaN();
      check(digamma(-1)).isNaN();
    });

    test('trigamma known values', () {
      check(trigamma(1)).isCloseTo(math.pi * math.pi / 6.0, 1e-6);
      check(trigamma(2)).isCloseTo(math.pi * math.pi / 6.0 - 1.0, 1e-6);
      check(trigamma(0)).isNaN();
      check(trigamma(-1)).isNaN();
    });
  });
}
