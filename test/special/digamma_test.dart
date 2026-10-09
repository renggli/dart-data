import 'dart:math' as math;

import 'package:data/special.dart';
import 'package:test/test.dart';

void main() {
  group('digamma and trigamma functions', () {
    test('digamma known values', () {
      expect(digamma(1), closeTo(-0.5772156649, 1e-6)); // -EulerMascheroni
      expect(digamma(2), closeTo(1.0 - 0.5772156649, 1e-6));
      expect(digamma(0.5), closeTo(-2.0 * math.ln2 - 0.5772156649, 1e-6));
      expect(digamma(0).isNaN, isTrue);
      expect(digamma(-1).isNaN, isTrue);
    });

    test('trigamma known values', () {
      expect(trigamma(1), closeTo(math.pi * math.pi / 6.0, 1e-6));
      expect(trigamma(2), closeTo(math.pi * math.pi / 6.0 - 1.0, 1e-6));
      expect(trigamma(0).isNaN, isTrue);
      expect(trigamma(-1).isNaN, isTrue);
    });
  });
}
