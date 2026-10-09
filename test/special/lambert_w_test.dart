import 'dart:math' as math;

import 'package:data/special.dart';
import 'package:test/test.dart';

void main() {
  group('Lambert W function', () {
    test('Lambert W0 known values', () {
      expect(lambertW0(0.0), 0.0);
      expect(lambertW0(math.e), closeTo(1.0, 1e-7));
      expect(lambertW0(-1.0 / math.e), closeTo(-1.0, 1e-6));
      expect(lambertW0(-0.5).isNaN, isTrue); // < -1/e
      expect(lambertW0(double.infinity), double.infinity);

      final w = lambertW0(2.0);
      expect(w * math.exp(w), closeTo(2.0, 1e-9));
    });

    test('Lambert W1 known values', () {
      expect(lambertW1(0.0).isNaN, isTrue);
      expect(lambertW1(1.0).isNaN, isTrue);
      expect(lambertW1(-1.0 / math.e), closeTo(-1.0, 1e-5));
      final w = lambertW1(-0.1);
      expect(w * math.exp(w), closeTo(-0.1, 1e-7));
    });
  });
}
