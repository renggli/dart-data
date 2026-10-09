import 'dart:math' as math;

import 'package:data/special.dart';
import 'package:test/test.dart';

void main() {
  group('gamma function', () {
    const gammaTuples = <(double, double)>[
      // Integers
      (1.0, 1.0),
      (2.0, 1.0),
      (3.0, 2.0),
      (4.0, 6.0),
      (5.0, 24.0),
      (6.0, 120.0),
      (7.0, 720.0),
      (8.0, 5040.0),
      (9.0, 40320.0),
      (10.0, 362880.0),
      // Half-integers
      (-2.5, -0.94530872048),
      (-1.5, 2.36327180121),
      (-0.5, -3.54490770181),
      (0.5, 1.77245385091),
      (1.5, 0.88622692545),
      (2.5, 1.32934038818),
      (3.5, 3.32335097045),
      // Local minima
      (1.46163214496, 0.88560319441),
      (-0.50408300826, -3.54464361115),
      (-1.57349847316, 2.30240725833),
      (-2.61072086844, -0.88813635840),
      (-3.63529336643, 0.24512753983),
      (-4.65323776174, -0.05277963958),
      (-5.66716244155, 0.00932459448),
      (-6.67841821307, -0.00139739660),
      (-7.68778832503, 0.00018187844),
      (-8.69576416381, -0.00002092529),
      (-9.70267254000, 0.00000215741),
      // Undefined
      (0.0, double.nan),
      (-0.0, double.nan),
      (-1.0, double.nan),
      (-2.0, double.nan),
      (-3.0, double.nan),
      (-4.0, double.nan),
      (-5.0, double.nan),
      (-6.0, double.nan),
      (-7.0, double.nan),
      (-8.0, double.nan),
      (-9.0, double.nan),
      (-10.0, double.nan),
    ];

    test('gamma', () {
      for (final tuple in gammaTuples) {
        if (tuple.$2.isNaN) {
          expect(gamma(tuple.$1).isNaN, isTrue, reason: 'gamma(${tuple.$1})');
        } else {
          expect(
            gamma(tuple.$1),
            closeTo(tuple.$2, 1e-4),
            reason: 'gamma(${tuple.$1})',
          );
        }
      }
    });

    test('gammaLn', () {
      for (final tuple in gammaTuples.where((t) => t.$1 > 0)) {
        expect(
          gammaLn(tuple.$1),
          closeTo(math.log(tuple.$2), 1e-6),
          reason: 'gammaLn(${tuple.$1})',
        );
      }
      expect(gammaLn(0).isNaN, isTrue);
      expect(gammaLn(-1).isNaN, isTrue);
    });

    test('gammap and lowRegGamma', () {
      expect(lowRegGamma(1, 1), closeTo(1.0 - math.exp(-1), 1e-6));
      expect(gammap(1, 1), closeTo(1.0 - math.exp(-1), 1e-6));
      expect(lowRegGamma(-1, 1).isNaN, isTrue);
      expect(lowRegGamma(1, -1).isNaN, isTrue);
    });

    test('gammapInv', () {
      expect(gammapInv(0.0, 2.0), 0.0);
      expect(gammapInv(1.0, 2.0), greaterThan(10.0));
      final p = lowRegGamma(2.5, 3.0);
      expect(gammapInv(p, 2.5), closeTo(3.0, 1e-4));
    });

    test('factorial and combinations', () {
      expect(factorial(0), closeTo(1.0, 1e-8));
      expect(factorial(5), closeTo(120.0, 1e-8));
      expect(factorial(-1).isNaN, isTrue);
      expect(factorialLn(5), closeTo(math.log(120.0), 1e-6));
      expect(combination(5, 2), closeTo(10.0, 1e-6));
      expect(combinationLn(5, 2), closeTo(math.log(10.0), 1e-6));
      expect(permutation(5, 2), closeTo(20.0, 1e-6));
      expect(permutationLn(5, 2), closeTo(math.log(20.0), 1e-6));
    });
  });
}
