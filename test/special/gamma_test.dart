import 'dart:math' as math;

import 'package:checks/checks.dart';
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
          check(because: 'gamma(${tuple.$1})', gamma(tuple.$1)).isNaN();
        } else {
          check(
            because: 'gamma(${tuple.$1})',
            gamma(tuple.$1),
          ).isCloseTo(tuple.$2, 1e-4);
        }
      }
    });

    test('gammaLn', () {
      for (final tuple in gammaTuples.where((tuple) => tuple.$1 > 0)) {
        check(
          because: 'gammaLn(${tuple.$1})',
          gammaLn(tuple.$1),
        ).isCloseTo(math.log(tuple.$2), 1e-6);
      }
      check(gammaLn(0)).isNaN();
      check(gammaLn(-1)).isNaN();
    });

    test('gammap and lowRegGamma', () {
      check(lowRegGamma(1, 1)).isCloseTo(1.0 - math.exp(-1), 1e-6);
      check(gammap(1, 1)).isCloseTo(1.0 - math.exp(-1), 1e-6);
      check(lowRegGamma(-1, 1)).isNaN();
      check(lowRegGamma(1, -1)).isNaN();
    });

    test('gammapInv', () {
      check(gammapInv(0.0, 2.0)).equals(0.0);
      check(gammapInv(1.0, 2.0)).isGreaterThan(10.0);
      final prob = lowRegGamma(2.5, 3.0);
      check(gammapInv(prob, 2.5)).isCloseTo(3.0, 1e-4);

      // a <= 1.0 branches
      final pSmall = lowRegGamma(0.5, 0.2);
      check(gammapInv(pSmall, 0.5)).isCloseTo(0.2, 1e-3);
      final pLarge = lowRegGamma(0.5, 2.0);
      check(gammapInv(pLarge, 0.5)).isCloseTo(2.0, 1e-3);

      // a > 1.0 with p < 0.5
      final pLow = lowRegGamma(3.0, 0.5);
      check(gammapInv(pLow, 3.0)).isCloseTo(0.5, 1e-3);
    });

    test('gamma for large x', () {
      check(gamma(105.0).isFinite).isTrue();
    });

    test('factorial and combinations', () {
      check(factorial(0)).isCloseTo(1.0, 1e-8);
      check(factorial(5)).isCloseTo(120.0, 1e-8);
      check(factorial(-1)).isNaN();
      check(factorialLn(5)).isCloseTo(math.log(120.0), 1e-6);
      check(combination(5, 2)).isCloseTo(10.0, 1e-6);
      check(combinationLn(5, 2)).isCloseTo(math.log(10.0), 1e-6);
      check(permutation(5, 2)).isCloseTo(20.0, 1e-6);
      check(permutationLn(5, 2)).isCloseTo(math.log(20.0), 1e-6);
    });
  });
}
