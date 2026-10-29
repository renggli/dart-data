import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/special.dart';
import 'package:test/test.dart';

void main() {
  group('beta functions', () {
    const betaTuples = <(double, double, double)>[
      (0.0, 0.0, double.nan),
      (1.0, 0.0, double.nan),
      (0.0, 1.0, double.nan),
      (9.9, 0.7, 0.2635858645),
      (7.1, 0.3, 1.686552489),
      (7.6, 4.9, 0.0003435970659),
      (2.2, 8.0, 0.009733731844),
      (5.7, 6.5, 0.0003203685430),
      (7.1, 6.6, 0.0001046727608),
      (0.8, 1.0, 1.250000000),
      (0.3, 0.2, 7.748481389),
    ];

    test('beta', () {
      for (final (a, b, expected) in betaTuples) {
        if (expected.isNaN) {
          check(because: 'beta($a, $b)', beta(a, b)).isNaN();
        } else {
          check(because: 'beta($a, $b)', beta(a, b)).isCloseTo(expected, 1e-6);
        }
      }
      // Sum > 171.6 where gamma(x + y) overflows
      check(beta(90, 90)).isGreaterThan(0.0);
      check(beta(100, 100)).isGreaterThan(0.0);
    });

    test('betaLn', () {
      for (final (a, b, expected) in betaTuples) {
        if (!expected.isNaN) {
          check(
            because: 'betaLn($a, $b)',
            betaLn(a, b),
          ).isCloseTo(math.log(expected), 1e-6);
        }
      }
    });

    test('ibeta and ibetaInv', () {
      check(ibetaInv(0.0, 2.5, 0.5)).equals(0.0);
      check(ibetaInv(1.0, 2.5, 0.5)).equals(1.0);
      check(ibeta(0.0, 2.0, 3.0)).equals(0.0);
      check(ibeta(1.0, 2.0, 3.0)).equals(1.0);
      check(ibeta(0.5, 1.0, 1.0)).isCloseTo(0.5, 1e-12);
      check(ibeta(-0.1, 1, 1)).isNaN();
      check(ibeta(1.1, 1, 1)).isNaN();

      final prob = ibeta(0.4, 3.0, 4.0);
      check(ibetaInv(prob, 3.0, 4.0)).isCloseTo(0.4, 1e-10);

      // Inversion accuracy and round-trip on diverse (a, b) including large parameters
      for (final (a, b, x) in [
        (2.0, 5.0, 0.3),
        (10.0, 10.0, 0.5),
        (50.0, 50.0, 0.48),
        (100.0, 50.0, 0.65),
      ]) {
        final p = ibeta(x, a, b);
        check(ibetaInv(p, a, b)).isCloseTo(x, 1e-8);
      }

      check(beta(double.nan, 1.0)).isNaN();
      check(betaLn(double.nan, 1.0)).isNaN();
      check(ibeta(double.nan, 2.0, 3.0)).isNaN();
      check(ibeta(0.5, double.nan, 3.0)).isNaN();
      check(ibetaInv(-0.1, 2.0, 3.0)).isNaN();
      check(ibetaInv(1.1, 2.0, 3.0)).isNaN();
      check(ibetaInv(double.nan, 2.0, 3.0)).isNaN();
      check(beta(150.0, 2.0)).isCloseTo(math.exp(betaLn(150.0, 2.0)), 1e-12);
      check(ibetaInv(0.95, 0.3, 0.3))
          .isCloseTo(1.0 - ibetaInv(0.05, 0.3, 0.3), 1e-8);
    });
  });
}
