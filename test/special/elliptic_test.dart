import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/special.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('Elliptic integrals', () {
    test('complete elliptic K standard values', () {
      check(ellipticK(0)).equals(math.pi / 2.0);
      check(ellipticK(1)).equals(double.infinity);
      check(ellipticK(-1)).equals(double.infinity);
      check(ellipticK(0.5)).isCloseTo(1.685750354812635, 1e-12);
      check(ellipticK(-0.5)).isCloseTo(1.685750354812635, 1e-12);
      check(ellipticK(0.9)).isCloseTo(2.280549138422770, 1e-12);
    });

    test('complete elliptic K edge cases', () {
      check(ellipticK(1.01)).isNaN();
      check(ellipticK(-1.01)).isNaN();
      check(ellipticK(double.nan)).isNaN();
    });

    test('complete elliptic E standard values', () {
      check(ellipticE(0)).equals(math.pi / 2.0);
      check(ellipticE(1)).equals(1.0);
      check(ellipticE(-1)).equals(1.0);
      check(ellipticE(0.5)).isCloseTo(1.4674622093394272, 1e-12);
      check(ellipticE(-0.5)).isCloseTo(1.4674622093394272, 1e-12);
      check(ellipticE(0.9)).isCloseTo(1.1716968, 1e-5);
    });

    test('complete elliptic E edge cases', () {
      check(ellipticE(1.01)).isNaN();
      check(ellipticE(-1.01)).isNaN();
      check(ellipticE(double.nan)).isNaN();
    });
  });
}
