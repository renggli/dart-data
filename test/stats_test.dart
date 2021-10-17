import 'dart:math' as math;

import 'package:data/data.dart';
import 'package:more/collection.dart';
import 'package:more/feature.dart';
import 'package:more/tuple.dart';
import 'package:test/test.dart';

dynamic isCloseTo(num expected, {double epsilon = 1.0e-6}) =>
    expected.isInfinite
        ? expected
        : expected.isNaN
            ? isNaN
            : closeTo(expected, epsilon);
final throwsInvalidProbability = throwsA(isA<InvalidProbability>());

void testDistribution<T extends num>(Distribution<T> distribution,
    {T? min,
    T? max,
    double? mean,
    double? median,
    double? variance,
    List<Tuple2<T, double>>? probability,
    List<Tuple2<T, double>>? cumulativeProbability,
    List<Tuple2<double, T>>? inverseCumulativeProbability}) {
  final isDiscrete = distribution is DiscreteDistribution;
  test('lower bound', () {
    expect(
        distribution.lowerBound,
        isCloseTo(
            min ?? (isDiscrete ? minSafeInteger : double.negativeInfinity)));
    expect(
        distribution.isLowerBoundOpen,
        distribution.lowerBound == minSafeInteger ||
            distribution.lowerBound == double.negativeInfinity);
  });
  test('upper bound', () {
    expect(distribution.upperBound,
        isCloseTo(max ?? (isDiscrete ? maxSafeInteger : double.infinity)));
    expect(
        distribution.isUpperBoundOpen,
        distribution.upperBound == maxSafeInteger ||
            distribution.upperBound == double.infinity);
  });
  if (mean != null) {
    test('mean', () {
      expect(distribution.mean, isCloseTo(mean));
    });
  }
  if (median != null || mean != null) {
    test('median', () {
      expect(distribution.median, isCloseTo(median ?? mean ?? 0.0));
    });
  }
  if (variance != null) {
    test('variance', () {
      expect(distribution.variance, isCloseTo(variance));
    });
    test('standard deviation', () {
      expect(distribution.standardDeviation, isCloseTo(math.sqrt(variance)));
    });
  }
  if (probability != null) {
    test('probability', () {
      for (final tuple in probability) {
        expect(distribution.probability(tuple.first), isCloseTo(tuple.second),
            reason: 'p(${tuple.first}) = ${tuple.second}');
      }
    });
  }
  if (cumulativeProbability != null) {
    test('cumulative probability', () {
      for (final tuple in cumulativeProbability) {
        expect(distribution.cumulativeProbability(tuple.first),
            isCloseTo(tuple.second),
            reason: 'p(X <= ${tuple.first}) = ${tuple.second}');
      }
    });
    test('survival', () {
      for (final tuple in cumulativeProbability) {
        expect(
            distribution.survival(tuple.first), isCloseTo(1.0 - tuple.second),
            reason: 'p(X > ${tuple.first}) = ${tuple.second}');
      }
    });
  }
  if (inverseCumulativeProbability != null) {
    test('inverse cumulative probability', () {
      for (final tuple in inverseCumulativeProbability) {
        expect(distribution.inverseCumulativeProbability(tuple.first),
            isCloseTo(tuple.second),
            reason: 'P(X <= ${tuple.second}) = ${tuple.first}');
      }
      expect(() => distribution.inverseCumulativeProbability(-0.1),
          throwsInvalidProbability);
      expect(() => distribution.inverseCumulativeProbability(1.1),
          throwsInvalidProbability);
    });
    test('inverse survival', () {
      for (final tuple in inverseCumulativeProbability) {
        expect(distribution.inverseSurvival(1.0 - tuple.first),
            isCloseTo(tuple.second),
            reason: 'P(X > ${tuple.second}) = ${tuple.first}');
      }
      expect(
          () => distribution.inverseSurvival(-0.1), throwsInvalidProbability);
      expect(() => distribution.inverseSurvival(1.1), throwsInvalidProbability);
    });
  }
  test('sample', () {
    final histogram = Multiset<int>();
    final random = math.Random(distribution.hashCode);
    if (distribution is DiscreteDistribution) {
      for (var i = 0; i < 10000; i++) {
        histogram.add(distribution.sample(random: random) as int);
      }
      for (var k = math.max(-50, distribution.lowerBound.round());
          k < math.min(50, distribution.upperBound.round());
          k++) {
        expect(histogram[k] / histogram.length,
            isCloseTo(distribution.probability(k as T), epsilon: 0.1));
      }
    } else {
      final buckets = 0.1
          .to(1.0, step: 0.1)
          .map((each) => distribution.inverseCumulativeProbability(each))
          .toList();
      final bucketCount = buckets.length + 1;
      for (var i = 0; i < 10000; i++) {
        final value = distribution.sample(random: random) as double;
        for (var k = 0; k <= buckets.length; k++) {
          if (k == buckets.length || value < buckets[k]) {
            histogram.add(k);
            break;
          }
        }
      }
      // All the buckets are expected to have roughly the same size.
      expect(histogram.distinct, hasLength(bucketCount));
      for (var k = 0; k < bucketCount; k++) {
        expect(
            histogram[k] / histogram.length,
            isCloseTo(1.0 / bucketCount,
                epsilon: 1.0 / (bucketCount * bucketCount)));
      }
    }
  });
  const otherDistributions = [
    UniformDiscreteDistribution(-1, 1),
    NormalDistribution(-1, 1),
  ];
  test('equality', () {
    expect(distribution == distribution, isTrue);
    for (final other in otherDistributions) {
      expect(distribution == other, isFalse);
    }
  });
  test('hash code', () {
    expect(distribution.hashCode, distribution.hashCode);
    for (final other in otherDistributions) {
      expect(distribution, isNot(other.hashCode));
    }
  });
  test('string', () {
    expect(distribution.toString(), distribution.toString());
    for (final other in otherDistributions) {
      expect(distribution.toString(), isNot(other.toString()));
    }
  });
}

void main() {
  group('distribution', () {
    group('continuous', () {
      group('normal', () {
        const distribution = NormalDistribution(2.1, 1.4);
        testDistribution(distribution,
            mean: 2.1,
            variance: 1.4 * 1.4,
            probability: const [
              Tuple2(-2.226325228634938, 0.00240506434076),
              Tuple2(-1.156887023657177, 0.0190372444310),
              Tuple2(-0.643949578356075, 0.0417464784322),
              Tuple2(-0.2027950777320613, 0.0736683145538),
              Tuple2(0.305827808237559, 0.125355951380),
              Tuple2(6.42632522863494, 0.00240506434076),
              Tuple2(5.35688702365718, 0.0190372444310),
              Tuple2(4.843949578356074, 0.0417464784322),
              Tuple2(4.40279507773206, 0.0736683145538),
              Tuple2(3.89417219176244, 0.125355951380),
            ],
            cumulativeProbability: const [
              Tuple2(-2.226325228634938, 0.001),
              Tuple2(-1.156887023657177, 0.01),
              Tuple2(-0.643949578356075, 0.025),
              Tuple2(-0.2027950777320613, 0.05),
              Tuple2(0.305827808237559, 0.1),
              Tuple2(6.42632522863494, 0.999),
              Tuple2(5.35688702365718, 0.990),
              Tuple2(4.843949578356074, 0.975),
              Tuple2(4.40279507773206, 0.950),
              Tuple2(3.89417219176244, 0.900),
            ]);
      });
      group('normal (standard)', () {
        const distribution = NormalDistribution.standard();
        testDistribution(distribution, mean: 0.0, variance: 1.0);
      });
      group('uniform', () {
        const distribution = UniformDistribution(-0.5, 1.25);
        testDistribution(
          distribution,
          min: -0.5,
          max: 1.25,
          mean: 0.375,
          median: 0.375,
          variance: 0.255208333,
          probability: const [
            Tuple2(-0.5001, 0.0),
            Tuple2(-0.5, 0.571428571),
            Tuple2(-0.4999, 0.571428571),
            Tuple2(-0.25, 0.571428571),
            Tuple2(-0.0001, 0.571428571),
            Tuple2(0.0, 0.571428571),
            Tuple2(0.0001, 0.571428571),
            Tuple2(0.25, 0.571428571),
            Tuple2(1.0, 0.571428571),
            Tuple2(1.2499, 0.571428571),
            Tuple2(1.25, 0.571428571),
            Tuple2(1.2501, 0.0),
          ],
          cumulativeProbability: const [
            Tuple2(-0.5001, 0.0),
            Tuple2(-0.5, 0.0),
            Tuple2(-0.4999, 0.000057142),
            Tuple2(-0.25, 0.142857142),
            Tuple2(-0.0001, 0.285657142),
            Tuple2(0.0, 0.285714285),
            Tuple2(0.0001, 0.285771428),
            Tuple2(0.25, 0.428571428),
            Tuple2(1.0, 0.857142857),
            Tuple2(1.2499, 0.999942857),
            Tuple2(1.25, 1.0),
            Tuple2(1.2501, 1.0),
          ],
        );
      });
      group('uniform (standard)', () {
        const distribution = UniformDistribution.standard();
        testDistribution(
          distribution,
          min: 0.0,
          max: 1.0,
          mean: 0.5,
          variance: 0.08333333333,
        );
      });
    });
    group('discrete', () {
      group('bernoulli', () {
        const distribution = BernoulliDistribution(0.7);
        test('parameters', () {
          expect(distribution.p, isCloseTo(0.7));
          expect(distribution.q, isCloseTo(0.3));
        });
        testDistribution(distribution,
            min: 0,
            max: 1,
            mean: 0.7,
            median: 1.0,
            variance: 0.21,
            probability: const [
              Tuple2(-1, 0),
              Tuple2(0, 0.3),
              Tuple2(1, 0.7),
              Tuple2(2, 0),
            ],
            cumulativeProbability: const [
              Tuple2(-1, 0),
              Tuple2(0, 0.3),
              Tuple2(1, 1),
              Tuple2(2, 1),
            ]);
      });
      group('binomial', () {
        const distribution = BinomialDistribution(10, 0.7);
        test('parameters', () {
          expect(distribution.n, isCloseTo(10));
          expect(distribution.p, isCloseTo(0.7));
          expect(distribution.q, isCloseTo(0.3));
        });
        testDistribution(distribution,
            min: 0,
            max: 10,
            mean: 7,
            median: 7,
            variance: 2.1,
            probability: const [
              Tuple2(-1, 0),
              Tuple2(0, 0.0000059049),
              Tuple2(1, 0.000137781),
              Tuple2(2, 0.0014467005),
              Tuple2(3, 0.009001692),
              Tuple2(4, 0.036756909),
              Tuple2(5, 0.1029193452),
              Tuple2(6, 0.200120949),
              Tuple2(7, 0.266827932),
              Tuple2(8, 0.2334744405),
              Tuple2(9, 0.121060821),
              Tuple2(10, 0.0282475249),
              Tuple2(11, 0),
            ],
            cumulativeProbability: const [
              Tuple2(-1, 0),
              Tuple2(0, 5.9049e-06),
              Tuple2(1, 0.0001436859),
              Tuple2(2, 0.0015903864),
              Tuple2(3, 0.0105920784),
              Tuple2(4, 0.0473489874),
              Tuple2(5, 0.1502683326),
              Tuple2(6, 0.3503892816),
              Tuple2(7, 0.6172172136),
              Tuple2(8, 0.8506916541),
              Tuple2(9, 0.9717524751),
              Tuple2(10, 1),
              Tuple2(11, 1),
            ],
            inverseCumulativeProbability: const [
              Tuple2(0, 0),
              Tuple2(0.001, 2),
              Tuple2(0.010, 3),
              Tuple2(0.025, 4),
              Tuple2(0.050, 5),
              Tuple2(0.100, 5),
              Tuple2(0.999, 10),
              Tuple2(0.990, 10),
              Tuple2(0.975, 10),
              Tuple2(0.950, 9),
              Tuple2(0.900, 9),
              Tuple2(1, 10),
            ]);
      });
      group('poisson', () {
        const distribution = PoissonDistribution(4.0);
        testDistribution(
          distribution,
          min: 0,
          mean: 4.0,
          median: 4.0,
          variance: 4.0,
          probability: const [
            Tuple2(-1, 0),
            Tuple2(0, 0.018315638),
            Tuple2(1, 0.073262555),
            Tuple2(2, 0.146525111),
            Tuple2(3, 0.195366814),
            Tuple2(4, 0.195366814),
            Tuple2(5, 0.156293451),
            Tuple2(10, 0.005292476),
            Tuple2(15, 1.503911676e-05),
            Tuple2(16, 3.759779190e-06),
            Tuple2(20, 8.277463646e-09),
          ],
          // cumulativeProbability: const [
          //   Tuple2(0, 0),
          //   Tuple2(0.0183156388887, 0.018315638886),
          //   Tuple2(0.0915781944437, 0.018315638890),
          //   Tuple2(0.238103305554, 0.091578194441),
          //   Tuple2(0.433470120367, 0.091578194445),
          //   Tuple2(0.62883693518, 0.238103305552),
          //   Tuple2(0.78513038703, 0.238103305556),
          //   Tuple2(0.99716023388, -1),
          //   Tuple2(0.999999998077, -1),
          //   Tuple2(1.0, -1),
          // ],
        );
      });
      group('uniform', () {
        const distribution = UniformDiscreteDistribution(-3, 5);
        testDistribution<int>(distribution,
            min: -3,
            max: 5,
            mean: 1,
            variance: 80 / 12,
            probability: const [
              Tuple2(-4, 0),
              Tuple2(-3, 1 / 9),
              Tuple2(-2, 1 / 9),
              Tuple2(-1, 1 / 9),
              Tuple2(0, 1 / 9),
              Tuple2(1, 1 / 9),
              Tuple2(2, 1 / 9),
              Tuple2(3, 1 / 9),
              Tuple2(4, 1 / 9),
              Tuple2(5, 1 / 9),
              Tuple2(6, 0),
            ],
            cumulativeProbability: const [
              Tuple2(-4, 0),
              Tuple2(-3, 1 / 9),
              Tuple2(-2, 2 / 9),
              Tuple2(-1, 3 / 9),
              Tuple2(0, 4 / 9),
              Tuple2(1, 5 / 9),
              Tuple2(2, 6 / 9),
              Tuple2(3, 7 / 9),
              Tuple2(4, 8 / 9),
              Tuple2(5, 1),
              Tuple2(6, 1),
            ],
            inverseCumulativeProbability: const [
              Tuple2(0, -3),
              Tuple2(0.001, -3),
              Tuple2(0.010, -3),
              Tuple2(0.025, -3),
              Tuple2(0.050, -3),
              Tuple2(0.100, -3),
              Tuple2(0.200, -2),
              Tuple2(0.5, 1),
              Tuple2(0.999, 5),
              Tuple2(0.990, 5),
              Tuple2(0.975, 5),
              Tuple2(0.950, 5),
              Tuple2(0.900, 5),
              Tuple2(1, 5),
            ]);
      });
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
}
