import 'dart:math' as math;

import 'package:data/special.dart';
import 'package:more/tuple.dart';
import 'package:test/test.dart';

import 'utils/matchers.dart';

void main() {
  group('gamma function', () {
    // https://en.wikipedia.org/wiki/Particular_values_of_the_gamma_function
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
      (-1.0, double.nan),
      (-2.0, double.nan),
      (-3.0, double.nan),
      // Various
      (0.1, 9.513507699),
      (0.2, 4.590843712),
      (0.3, 2.991568988),
      (0.4, 2.218159544),
      (0.5, 1.772453851),
      (0.6, 1.489192249),
      (0.7, 1.298055333),
      (0.8, 1.164229714),
      (0.9, 1.068628702),
      (1.1, 0.9513507699),
      (1.2, 0.9181687424),
      (1.3, 0.8974706963),
      (1.4, 0.8872638175),
      (1.5, 0.8862269255),
      (1.6, 0.8935153493),
      (1.7, 0.9086387329),
      (1.8, 0.931383771),
      (1.9, 0.9617658319),
    ];
    const logGammaTuples = <(double, double)>[
      (2.0, 0.0000000000E+00),
      (5.0, 3.1780538303E+00),
      (10.0, 1.2801827480E+01),
      (50.0, 1.4456574395E+02),
      (100.0, 3.5913420537E+02),
      (500.0, 2.6051158504E+03),
      (1000.0, 5.9052204232E+03),
      (5000.0, 3.7582626316E+04),
      (10000.0, 8.2099717496E+04),
    ];
    const factorialTuples = <(int, int)>[
      (1, 1),
      (2, 2),
      (3, 6),
      (4, 24),
      (5, 120),
      (6, 720),
      (7, 5040),
      (8, 40320),
      (9, 362880),
      (10, 3628800),
    ];
    const combinationTuples = <(int, int, int)>[
      (1, 1, 1),
      (2, 2, 1),
      (3, 1, 3),
      (4, 2, 6),
      (5, 5, 1),
      (6, 4, 15),
      (7, 3, 35),
      (8, 7, 8),
      (9, 7, 36),
      (10, 10, 1),
      (11, 5, 462),
      (12, 2, 66),
      (13, 4, 715),
      (14, 12, 91),
      (15, 4, 1365),
      (16, 8, 12870),
      (17, 10, 19448),
      (18, 8, 43758),
      (19, 10, 92378),
      (20, 14, 38760),
      (21, 10, 352716),
      (22, 10, 646646),
      (23, 15, 490314),
      (24, 20, 10626),
      (25, 11, 4457400),
      (26, 11, 7726160),
      (27, 18, 4686825),
      (28, 14, 40116600),
      (29, 20, 10015005),
    ];
    const permutationTuples = <(int, int, int)>[
      (6, 4, 360),
      (7, 3, 210),
      (7, 5, 2520),
    ];
    const gammapTuples = <(int, int, double)>[
      (5, 5, 13.4281611),
      (5, 4, 8.90791355),
      (5, 7, 19.8482014),
    ];
    const lowRegGammaTuples = <(int, int, double)>[
      (5, 5, 0.5595067),
      (4, 5, 0.7349741),
      (11, 10, 0.4169602),
    ];
    test('gamma', () {
      for (final tuple in gammaTuples) {
        expect(gamma(tuple.first), isCloseTo(tuple.second),
            reason: 'gamma(${tuple.first}) = ${tuple.second}');
      }
      expect(gamma(101.0), closeTo(9.332621544394415e157, 1.0e150));
    });
    test('gammaLn', () {
      for (final tuple in gammaTuples
          .map((tuple) => tuple.withSecond(math.log(tuple.second)))
          .followedBy(logGammaTuples)) {
        expect(gammaLn(tuple.first),
            tuple.first <= 0 ? isNaN : isCloseTo(tuple.second),
            reason: 'gammaLn(${tuple.first}) = ${tuple.second}');
      }
    });
    test('gammap', () {
      for (final tuple in gammapTuples) {
        expect(gammap(tuple.first, tuple.second), isCloseTo(tuple.third),
            reason: 'gammap(${tuple.first}, ${tuple.second}) = ${tuple.third}');
      }
    });
    test('lowRegGamma', () {
      for (final tuple in lowRegGammaTuples) {
        expect(lowRegGamma(tuple.first, tuple.second), isCloseTo(tuple.third),
            reason:
                'lowRegGamma(${tuple.first}, ${tuple.second}) = ${tuple.third}');
      }
    });
    test('factorial', () {
      for (final tuple in factorialTuples) {
        expect(factorial(tuple.first), isCloseTo(tuple.second),
            reason: 'factorial(${tuple.first}) = ${tuple.second}');
      }
    });
    test('factorialLn', () {
      for (final tuple in factorialTuples
          .map((tuple) => tuple.withLast(math.log(tuple.second)))) {
        expect(factorialLn(tuple.first), isCloseTo(tuple.second),
            reason: 'factorialLn(${tuple.first}) = ${tuple.second}');
      }
    });
    test('combination', () {
      for (final tuple in combinationTuples) {
        expect(combination(tuple.first, tuple.second), isCloseTo(tuple.third),
            reason: 'combination(${tuple.first}, ${tuple.second}) '
                '= ${tuple.third}');
      }
    });
    test('combinationLn', () {
      for (final tuple in combinationTuples
          .map((tuple) => tuple.withThird(math.log(tuple.third)))) {
        expect(combinationLn(tuple.first, tuple.second), isCloseTo(tuple.third),
            reason: 'combinationLn(${tuple.first}, ${tuple.second}) '
                '= ${tuple.third}');
      }
    });
    test('permutation', () {
      for (final tuple in permutationTuples) {
        expect(permutation(tuple.first, tuple.second), isCloseTo(tuple.third),
            reason: 'permutation(${tuple.first}, ${tuple.second}) '
                '= ${tuple.third}');
      }
    });
    test('permutationLn', () {
      for (final tuple in permutationTuples
          .map((tuple) => tuple.withThird(math.log(tuple.third)))) {
        expect(permutationLn(tuple.first, tuple.second), isCloseTo(tuple.third),
            reason: 'permutationLn(${tuple.first}, ${tuple.second}) '
                '= ${tuple.third}');
      }
    });
  });
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
        expect(beta(tuple.first, tuple.second), isCloseTo(tuple.third),
            reason: 'beta(${tuple.first}, ${tuple.second}) '
                '= ${tuple.third}');
      }
    });
    test('betaln', () {
      for (final tuple in betaTuples
          .map((tuple) => tuple.withThird(math.log(tuple.third)))) {
        expect(betaLn(tuple.first, tuple.second), isCloseTo(tuple.third),
            reason: 'logBeta(${tuple.first}, ${tuple.second}) '
                '= ${tuple.third}');
      }
    });
  });
  group('error function', () {
    const errorFunctionTuples = <(double, double)>[
      (double.negativeInfinity, -1.0),
      (-10.0, -1.0),
      (-3.0, -0.99997791),
      (-2.0, -0.99532226),
      (-1.0, -0.84270079),
      (-0.1, -0.11246291),
      (-0.5, -0.52049987),
      (0.0, 0.00000000),
      (0.1, 0.11246291),
      (0.5, 0.52049987),
      (1.0, 0.84270079),
      (2.0, 0.99532226),
      (3.0, 0.99997791),
      (10.0, 1.0),
      (double.infinity, 1.0),
    ];
    const complementaryErrorFunctionTuples = <(double, double)>[
      (double.negativeInfinity, 2.0),
      (-10.0, 2.0),
      (-3.0, 1.99997791),
      (-2.0, 1.99532226),
      (-1.0, 1.84270079),
      (-0.1, 1.11246291),
      (-0.5, 1.52049987),
      (0.0, 1.00000000),
      (0.1, 0.88753709),
      (0.5, 0.47950013),
      (1.0, 0.15729921),
      (2.0, 0.00467774),
      (3.0, 0.00002209),
      (10.0, 0.0),
      (double.infinity, 0.0),
    ];
    test('errorFunction', () {
      for (final tuple in errorFunctionTuples) {
        expect(erf(tuple.first), isCloseTo(tuple.second),
            reason: 'erf(${tuple.first}) = ${tuple.second}');
      }
    });
    test('complementaryErrorFunction', () {
      for (final tuple in complementaryErrorFunctionTuples) {
        expect(erfc(tuple.first), isCloseTo(tuple.second),
            reason: 'erfc(${tuple.first}) = ${tuple.second}');
      }
    });
    test('inverseErrorFunction', () {
      for (final tuple in errorFunctionTuples) {
        if (tuple.first.abs() < 3 || tuple.first.isInfinite) {
          expect(erfInv(tuple.second),
              tuple.first.isInfinite ? tuple.first : isCloseTo(tuple.first),
              reason: 'erfinv(${tuple.second}) = ${tuple.first}');
        }
      }
    });
    test('inverseComplementaryErrorFunction', () {
      for (final tuple in complementaryErrorFunctionTuples) {
        if (tuple.first.abs() < 3 || tuple.first.isInfinite) {
          expect(erfcInv(tuple.second),
              tuple.first.isInfinite ? tuple.first : isCloseTo(tuple.first),
              reason: 'erfcinv(${tuple.second}) = ${tuple.first}');
        }
      }
    });
  });
}
