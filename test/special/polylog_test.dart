import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/special.dart';
import 'package:test/test.dart';

void main() {
  group('polylogarithm', () {
    test('polylog at special and general points', () {
      check(polylog(2, 0.0)).equals(0.0);
      check(polylog(2, 1.0)).isCloseTo(math.pi * math.pi / 6.0, 1e-12);
      check(polylog(2, -1.0)).isCloseTo(-math.pi * math.pi / 12.0, 1e-12);
      check(polylog(2, 0.5)).isCloseTo(
        math.pi * math.pi / 12.0 - 0.5 * math.pow(math.ln2, 2),
        1e-12,
      );
      check(polylog(2, -2.0)).isCloseTo(-1.436746366883681, 1e-12);
      check(polylog(2, -0.9)).isCloseTo(-0.7521631792172616, 1e-12);
      check(polylog(3, 1.0)).isCloseTo(zeta(3.0), 1e-12);
      check(polylog(1, 0.5)).isCloseTo(math.ln2, 1e-12);
      check(polylog(0, 0.5)).isCloseTo(1.0, 1e-12);
      check(polylog(-1, 0.5)).isCloseTo(2.0, 1e-12);
      check(polylog(2, 1.5)).isNaN();
    });
  });
}
