import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/special.dart';
import 'package:test/test.dart';

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

    test('incomplete elliptic F', () {
      check(ellipticF(0, 0.5)).equals(0.0);
      check(ellipticF(1.2, 0)).isCloseTo(1.2, 1e-12);
      check(ellipticF(math.pi / 2.0, 0.5)).isCloseTo(ellipticK(0.5), 1e-12);
      check(ellipticF(math.pi / 2.0, 0.8)).isCloseTo(ellipticK(0.8), 1e-12);
      check(ellipticF(-0.7, 0.5)).isCloseTo(-ellipticF(0.7, 0.5), 1e-12);

      // Quasi-periodicity: F(phi + pi, k) = F(phi, k) + 2 * K(k)
      final fBase = ellipticF(0.6, 0.4);
      final fShifted = ellipticF(0.6 + math.pi, 0.4);
      check(fShifted).isCloseTo(fBase + 2.0 * ellipticK(0.4), 1e-12);

      check(ellipticF(0.5, 1.2)).isNaN();
      check(ellipticF(double.nan, 0.5)).isNaN();
    });

    test('incomplete elliptic E', () {
      check(ellipticEIncomplete(0, 0.5)).equals(0.0);
      check(ellipticEIncomplete(1.2, 0)).isCloseTo(1.2, 1e-12);
      check(ellipticEIncomplete(math.pi / 2.0, 0.5))
          .isCloseTo(ellipticE(0.5), 1e-7);
      check(ellipticEIncomplete(math.pi / 2.0, 0.8))
          .isCloseTo(ellipticE(0.8), 1e-7);
      check(ellipticEIncomplete(-0.7, 0.5))
          .isCloseTo(-ellipticEIncomplete(0.7, 0.5), 1e-7);

      // Quasi-periodicity: E(phi + pi, k) = E(phi, k) + 2 * E(k)
      final eBase = ellipticEIncomplete(0.6, 0.4);
      final eShifted = ellipticEIncomplete(0.6 + math.pi, 0.4);
      check(eShifted).isCloseTo(eBase + 2.0 * ellipticE(0.4), 1e-7);

      check(ellipticEIncomplete(0.5, 1.2)).isNaN();
      check(ellipticEIncomplete(double.nan, 0.5)).isNaN();
    });
  });
}
