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
      for (final tuple in betaTuples) {
        if (tuple.$3.isNaN) {
          check(
            because: 'beta(${tuple.$1}, ${tuple.$2})',
            beta(tuple.$1, tuple.$2),
          ).isNaN();
        } else {
          check(
            because: 'beta(${tuple.$1}, ${tuple.$2})',
            beta(tuple.$1, tuple.$2),
          ).isCloseTo(tuple.$3, 1e-6);
        }
      }
    });

    test('betaLn', () {
      for (final tuple in betaTuples.where((tuple) => !tuple.$3.isNaN)) {
        check(
          because: 'betaLn(${tuple.$1}, ${tuple.$2})',
          betaLn(tuple.$1, tuple.$2),
        ).isCloseTo(math.log(tuple.$3), 1e-6);
      }
    });

    test('ibeta and ibetaInv', () {
      check(ibetaInv(0.0, 2.5, 0.5)).equals(0.0);
      check(ibetaInv(1.0, 2.5, 0.5)).equals(1.0);
      check(ibeta(0.0, 2.0, 3.0)).equals(0.0);
      check(ibeta(1.0, 2.0, 3.0)).equals(1.0);
      check(ibeta(0.5, 1.0, 1.0)).isCloseTo(0.5, 1e-6);
      check(ibeta(-0.1, 1, 1)).isNaN();
      check(ibeta(1.1, 1, 1)).isNaN();

      final prob = ibeta(0.4, 3.0, 4.0);
      check(ibetaInv(prob, 3.0, 4.0)).isCloseTo(0.4, 1e-5);
    });
  });
}
