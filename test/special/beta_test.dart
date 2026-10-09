import 'dart:math' as math;

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
          expect(beta(tuple.$1, tuple.$2).isNaN, isTrue);
        } else {
          expect(
            beta(tuple.$1, tuple.$2),
            closeTo(tuple.$3, 1e-6),
            reason: 'beta(${tuple.$1}, ${tuple.$2})',
          );
        }
      }
    });

    test('betaLn', () {
      for (final tuple in betaTuples.where((t) => !t.$3.isNaN)) {
        expect(
          betaLn(tuple.$1, tuple.$2),
          closeTo(math.log(tuple.$3), 1e-6),
          reason: 'betaLn(${tuple.$1}, ${tuple.$2})',
        );
      }
    });

    test('ibeta and ibetaInv', () {
      expect(ibetaInv(0.0, 2.5, 0.5), 0.0);
      expect(ibetaInv(1.0, 2.5, 0.5), 1.0);
      expect(ibeta(0.0, 2.0, 3.0), 0.0);
      expect(ibeta(1.0, 2.0, 3.0), 1.0);
      expect(ibeta(0.5, 1.0, 1.0), closeTo(0.5, 1e-6));
      expect(ibeta(-0.1, 1, 1).isNaN, isTrue);
      expect(ibeta(1.1, 1, 1).isNaN, isTrue);

      final p = ibeta(0.4, 3.0, 4.0);
      expect(ibetaInv(p, 3.0, 4.0), closeTo(0.4, 1e-5));
    });
  });
}
