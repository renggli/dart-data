import 'dart:math';

import 'package:data/stats.dart';
import 'package:more/tuple.dart';
import 'package:test/test.dart';

dynamic isCloseTo(num expected, {double epsilon = 1.0e-6}) =>
    expected.isInfinite
        ? expected
        : expected.isNaN
            ? isNaN
            : closeTo(expected, epsilon);

void main() {
  group('distribution', () {
    test('uniform', () {
      const dist = UniformDiscreteDistribution(1, 6);
      expect(dist.min, 1);
      expect(dist.max, 6);
      expect(dist.count, 6);
      expect(dist.mean, isCloseTo(3.5));
      expect(dist.variance, isCloseTo(35 / 12));

      expect(dist.pdf(0), isCloseTo(0));
      expect(dist.pdf(1), isCloseTo(1 / 6));
      expect(dist.pdf(6), isCloseTo(1 / 6));
      expect(dist.pdf(7), isCloseTo(0));

      expect(dist.cdf(0), isCloseTo(0));
      expect(dist.cdf(1), isCloseTo(1 / 6));
      expect(dist.cdf(2), isCloseTo(2 / 6));
      expect(dist.cdf(3), isCloseTo(3 / 6));
      expect(dist.cdf(4), isCloseTo(4 / 6));
      expect(dist.cdf(5), isCloseTo(5 / 6));
      expect(dist.cdf(6), isCloseTo(6 / 6));
      expect(dist.cdf(7), isCloseTo(1));
    });
    test('binomial', () {
      const dist = BinomialDistribution(15, 0.25);
      expect(dist.min, 0);
      expect(dist.max, 15);
      expect(dist.mean, isCloseTo(3.75));
      expect(dist.variance, isCloseTo(2.8125));

      expect(dist.pdf(10), isCloseTo(0.00067961));
      expect(dist.cdf(10), isCloseTo(0.9998847));
    });
  });
  group('iterable', () {
    test('sum', () {
      expect([3, 2.25, 4.5, -0.5, 1.0].sum(), isCloseTo(10.25));
    });
    test('sum (int)', () {
      expect([-1, 2, 3, 5, 7].sum(), 16);
    });
    test('average', () {
      expect(<num>[].average(), isNaN);
      expect([1, 2, 3, 4, 4].average(), isCloseTo(2.8));
    });
    test('arithmeticMean', () {
      expect(<num>[].arithmeticMean(), isNaN);
      expect([1, 2, 3, 4, 4].arithmeticMean(), isCloseTo(2.8));
    });
    test('geometricMean', () {
      expect(<num>[].geometricMean(), isNaN);
      expect([54, 24, 36].geometricMean(), isCloseTo(36.0));
    });
    test('harmonicMean', () {
      expect(<num>[].harmonicMean(), isNaN);
      expect([1, -1].harmonicMean(), isNaN);
      expect([2.5, 3, 10].harmonicMean(), isCloseTo(3.6));
    });
    test('variance', () {
      expect(<num>[].variance(), isNaN);
      expect([2.75].variance(), isNaN);
      expect([2.75, 1.75].variance(), isCloseTo(0.5));
      expect([2.75, 1.75, 1.25, 0.25, 0.5, 1.25, 3.5].variance(),
          isCloseTo(1.372023809523809));
    });
    test('variance (population)', () {
      expect(<num>[].variance(population: true), isNaN);
      expect([0.0].variance(population: true), isCloseTo(0.0));
      expect(
          [0.0, 0.25, 0.25, 1.25, 1.5, 1.75, 2.75, 3.25]
              .variance(population: true),
          isCloseTo(1.25));
    });
    test('standardDeviation', () {
      expect(<num>[].standardDeviation(), isNaN);
      expect([1.5].standardDeviation(), isNaN);
      expect([1.5, 2.5].standardDeviation(), isCloseTo(0.707106781186547));
      expect([1.5, 2.5, 2.5, 2.75, 3.25, 4.75].standardDeviation(),
          isCloseTo(1.081087415521982));
    });
    test('standardDeviation (population)', () {
      expect(<num>[].standardDeviation(population: true), isNaN);
      expect([1.5].standardDeviation(population: true), isCloseTo(0.0));
      expect(
          [1.5, 2.5, 2.5, 2.75, 3.25, 4.75].standardDeviation(population: true),
          isCloseTo(0.98689327352725));
    });
  });
  group('special', () {
    group('gamma function', () {
      // https://en.wikipedia.org/wiki/Particular_values_of_the_gamma_function
      const gammaValues = [
        // Integers
        Tuple2(1.0, 1.0),
        Tuple2(2.0, 1.0),
        Tuple2(3.0, 2.0),
        Tuple2(4.0, 6.0),
        Tuple2(5.0, 24.0),
        Tuple2(6.0, 120.0),
        Tuple2(7.0, 720.0),
        Tuple2(8.0, 5040.0),
        Tuple2(9.0, 40320.0),
        Tuple2(10.0, 362880.0),
        // Half-integers
        Tuple2(-2.5, -0.94530872048),
        Tuple2(-1.5, 2.36327180121),
        Tuple2(-0.5, -3.54490770181),
        Tuple2(0.5, 1.77245385091),
        Tuple2(1.5, 0.88622692545),
        Tuple2(2.5, 1.32934038818),
        Tuple2(3.5, 3.32335097045),
        // Local minima
        Tuple2(1.46163214496, 0.88560319441),
        Tuple2(-0.50408300826, -3.54464361115),
        Tuple2(-1.57349847316, 2.30240725833),
        Tuple2(-2.61072086844, -0.88813635840),
        Tuple2(-3.63529336643, 0.24512753983),
        Tuple2(-4.65323776174, -0.05277963958),
        Tuple2(-5.66716244155, 0.00932459448),
        Tuple2(-6.67841821307, -0.00139739660),
        Tuple2(-7.68778832503, 0.00018187844),
        Tuple2(-8.69576416381, -0.00002092529),
        Tuple2(-9.70267254000, 0.00000215741),
        // Undefined
        Tuple2(0.0, double.nan),
        Tuple2(-1.0, double.nan),
        Tuple2(-2.0, double.nan),
        Tuple2(-3.0, double.nan),
        // Various
        Tuple2(0.1, 9.513507699),
        Tuple2(0.2, 4.590843712),
        Tuple2(0.3, 2.991568988),
        Tuple2(0.4, 2.218159544),
        Tuple2(0.5, 1.772453851),
        Tuple2(0.6, 1.489192249),
        Tuple2(0.7, 1.298055333),
        Tuple2(0.8, 1.164229714),
        Tuple2(0.9, 1.068628702),
        Tuple2(1.1, 0.9513507699),
        Tuple2(1.2, 0.9181687424),
        Tuple2(1.3, 0.8974706963),
        Tuple2(1.4, 0.8872638175),
        Tuple2(1.5, 0.8862269255),
        Tuple2(1.6, 0.8935153493),
        Tuple2(1.7, 0.9086387329),
        Tuple2(1.8, 0.931383771),
        Tuple2(1.9, 0.9617658319),
      ];
      const lgammaValues = [
        Tuple2(2.0, 0.0000000000E+00),
        Tuple2(5.0, 3.1780538303E+00),
        Tuple2(10.0, 1.2801827480E+01),
        Tuple2(50.0, 1.4456574395E+02),
        Tuple2(100.0, 3.5913420537E+02),
        Tuple2(500.0, 2.6051158504E+03),
        Tuple2(1000.0, 5.9052204232E+03),
        Tuple2(5000.0, 3.7582626316E+04),
        Tuple2(10000.0, 8.2099717496E+04),
      ];
      const factorialValues = [
        Tuple2(1, 1),
        Tuple2(2, 2),
        Tuple2(3, 6),
        Tuple2(4, 24),
        Tuple2(5, 120),
        Tuple2(6, 720),
        Tuple2(7, 5040),
        Tuple2(8, 40320),
        Tuple2(9, 362880),
        Tuple2(10, 3628800),
      ];
      const combinationValues = [
        Tuple3(1, 1, 1),
        Tuple3(2, 2, 1),
        Tuple3(3, 1, 3),
        Tuple3(4, 2, 6),
        Tuple3(5, 5, 1),
        Tuple3(6, 4, 15),
        Tuple3(7, 3, 35),
        Tuple3(8, 7, 8),
        Tuple3(9, 7, 36),
        Tuple3(10, 10, 1),
        Tuple3(11, 5, 462),
        Tuple3(12, 2, 66),
        Tuple3(13, 4, 715),
        Tuple3(14, 12, 91),
        Tuple3(15, 4, 1365),
        Tuple3(16, 8, 12870),
        Tuple3(17, 10, 19448),
        Tuple3(18, 8, 43758),
        Tuple3(19, 10, 92378),
        Tuple3(20, 14, 38760),
        Tuple3(21, 10, 352716),
        Tuple3(22, 10, 646646),
        Tuple3(23, 15, 490314),
        Tuple3(24, 20, 10626),
        Tuple3(25, 11, 4457400),
        Tuple3(26, 11, 7726160),
        Tuple3(27, 18, 4686825),
        Tuple3(28, 14, 40116600),
        Tuple3(29, 20, 10015005),
      ];
      test('gamma', () {
        for (final value in gammaValues) {
          expect(gamma(value.first), isCloseTo(value.second),
              reason: 'gamma(${value.first}) = ${value.second}');
        }
      });
      test('lgamma', () {
        final logGammaValues = gammaValues
            .map((value) => Tuple2(value.first, log(value.second)))
            .followedBy(lgammaValues);
        for (final value in logGammaValues) {
          expect(lgamma(value.first),
              value.first <= 0 ? isNaN : isCloseTo(value.second),
              reason: 'lgamma(${value.first}) = ${value.second}');
        }
      });
      test('factorial', () {
        for (final value in factorialValues) {
          expect(factorial(value.first), isCloseTo(value.second),
              reason: 'factorial(${value.first}) = ${value.second}');
        }
      });
      test('lfactorial', () {
        final logFactorialValues = factorialValues
            .map((value) => Tuple2(value.first, log(value.second)));
        for (final value in logFactorialValues) {
          expect(lfactorial(value.first), isCloseTo(value.second),
              reason: 'lfactorial(${value.first}) = ${value.second}');
        }
      });
      test('combination', () {
        for (final value in combinationValues) {
          expect(combination(value.first, value.second), isCloseTo(value.third),
              reason: 'combination(${value.first}, ${value.second}) '
                  '= ${value.third}');
        }
      });
      test('lcombination', () {
        final logCombinationValues = combinationValues.map(
            (value) => Tuple3(value.first, value.second, log(value.third)));
        for (final value in logCombinationValues) {
          expect(
              lcombination(value.first, value.second), isCloseTo(value.third),
              reason: 'lcombination(${value.first}, ${value.second}) '
                  '= ${value.third}');
        }
      });
    });
    group('error function', () {
      const erfValues = [
        Tuple2(double.negativeInfinity, -1.0),
        Tuple2(-10.0, -1.0),
        Tuple2(-3.0, -0.99997791),
        Tuple2(-2.0, -0.99532226),
        Tuple2(-1.0, -0.84270079),
        Tuple2(-0.1, -0.11246291),
        Tuple2(-0.5, -0.52049987),
        Tuple2(0.0, 0.00000000),
        Tuple2(0.1, 0.11246291),
        Tuple2(0.5, 0.52049987),
        Tuple2(1.0, 0.84270079),
        Tuple2(2.0, 0.99532226),
        Tuple2(3.0, 0.99997791),
        Tuple2(10.0, 1.0),
        Tuple2(double.infinity, 1.0),
      ];
      const erfcValues = [
        Tuple2(double.negativeInfinity, 2.0),
        Tuple2(-10.0, 2.0),
        Tuple2(-3.0, 1.99997791),
        Tuple2(-2.0, 1.99532226),
        Tuple2(-1.0, 1.84270079),
        Tuple2(-0.1, 1.11246291),
        Tuple2(-0.5, 1.52049987),
        Tuple2(0.0, 1.00000000),
        Tuple2(0.1, 0.88753709),
        Tuple2(0.5, 0.47950013),
        Tuple2(1.0, 0.15729921),
        Tuple2(2.0, 0.00467774),
        Tuple2(3.0, 0.00002209),
        Tuple2(10.0, 0.0),
        Tuple2(double.infinity, 0.0),
      ];
      test('erf', () {
        for (final value in erfValues) {
          expect(erf(value.first), isCloseTo(value.second),
              reason: 'erf(${value.first}) = ${value.second}');
        }
      });
      test('erfc', () {
        for (final value in erfcValues) {
          expect(erfc(value.first), isCloseTo(value.second),
              reason: 'erfc(${value.first}) = ${value.second}');
        }
      });
      test('erfinv', () {
        for (final tuple in erfValues) {
          if (tuple.first.abs() < 3 || tuple.first.isInfinite) {
            expect(erfinv(tuple.second),
                tuple.first.isInfinite ? tuple.first : isCloseTo(tuple.first),
                reason: 'erfinv(${tuple.second}) = ${tuple.first}');
          }
        }
      });
      test('erfcinv', () {
        for (final tuple in erfcValues) {
          if (tuple.first.abs() < 3 || tuple.first.isInfinite) {
            expect(erfcinv(tuple.second),
                tuple.first.isInfinite ? tuple.first : isCloseTo(tuple.first),
                reason: 'erfcinv(${tuple.second}) = ${tuple.first}');
          }
        }
      });
    });
  });
}
