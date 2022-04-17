import 'dart:math' as math;
import 'dart:math';

import 'package:data/stats.dart';
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

void testSamples<T extends num>(
    Distribution<T> distribution, Iterable<T> samples) {
  final histogram = Multiset<int>();
  if (distribution is DiscreteDistribution) {
    histogram.addAll(samples.map((each) => each.toInt()));
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
    for (var sample in samples) {
      for (var k = 0; k <= buckets.length; k++) {
        if (k == buckets.length || sample < buckets[k]) {
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
}

void testDistribution<T extends num>(
  Distribution<T> distribution, {
  T? min,
  T? max,
  double? mean,
  double? median,
  double? mode,
  double? variance,
  double? skewness,
  double? kurtosisExcess,
  List<Tuple2<T, double>>? probability,
  List<Tuple2<T, double>>? cumulativeProbability,
  List<Tuple2<double, T>>? inverseCumulativeProbability,
  int sampleCount = 20000,
}) {
  final isDiscrete = distribution is DiscreteDistribution;
  test('lower bound', () {
    expect(
        distribution.lowerBound,
        isCloseTo(
            min ?? (isDiscrete ? minSafeInteger : double.negativeInfinity)));
    expect(
        distribution.isLowerUnbounded,
        distribution.lowerBound == minSafeInteger ||
            distribution.lowerBound == double.negativeInfinity);
  });
  test('upper bound', () {
    expect(distribution.upperBound,
        isCloseTo(max ?? (isDiscrete ? maxSafeInteger : double.infinity)));
    expect(
        distribution.isUpperUnbounded,
        distribution.upperBound == maxSafeInteger ||
            distribution.upperBound == double.infinity);
  });
  if (mean != null) {
    test('mean', () {
      expect(distribution.mean, isCloseTo(mean));
    });
  }
  if (median != null) {
    test('median', () {
      expect(distribution.median, isCloseTo(median));
    });
  }
  if (mode != null) {
    test('mode', () {
      expect(distribution.mode, isCloseTo(mode));
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
  if (skewness != null) {
    test('skewness', () {
      expect(distribution.skewness, isCloseTo(skewness));
    });
  }
  if (kurtosisExcess != null) {
    test('kurtosisExcess', () {
      expect(distribution.kurtosisExcess, isCloseTo(kurtosisExcess));
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
    final random = Random(Object.hash('sample', distribution));
    final samples = 0
        .to(sampleCount)
        .map((each) => distribution.sample(random: random))
        .toList();
    testSamples(distribution, samples);
  });
  test('samples', () {
    final random = Random(Object.hash('samples', distribution));
    final samples =
        distribution.samples(random: random).take(sampleCount).toList();
    testSamples(distribution, samples);
  });
  const otherDistributions = [
    // Continuous
    ExponentialDistribution(2.0),
    GammaDistribution(1.2, 2.3),
    InverseGammaDistribution(1.2, 2.3),
    NormalDistribution(-1, 1),
    StudentDistribution(42),
    UniformDistribution(-1, 1),
    WeibullDistribution(1.2, 1.9),
    // Discrete
    BernoulliDistribution(0.1),
    BinomialDistribution(5, 0.1),
    NegativeBinomialDistribution(5, 0.5),
    PoissonDistribution(2.0),
    UniformDiscreteDistribution(-1, 1),
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
      group('exponential (lambda = 4.0)', () {
        const distribution = ExponentialDistribution(4.0);
        testDistribution(
          distribution,
          min: 0.0,
          mean: 0.25,
          median: 0.17328679514,
          mode: 0.0,
          variance: 0.0625,
          probability: const [
            Tuple2(0.0, 4.0000000),
            Tuple2(1.0, 0.0732626),
            Tuple2(2.0, 0.0013418),
            Tuple2(3.0, 0.0000245),
            Tuple2(4.0, 0.0000000),
            Tuple2(5.0, 0.0000000),
          ],
          cumulativeProbability: const [
            Tuple2(0.0, 0.000000),
            Tuple2(1.0, 0.981684),
            Tuple2(2.0, 0.999665),
            Tuple2(3.0, 0.999994),
            Tuple2(4.0, 1.000000),
            Tuple2(5.0, 1.000000),
          ],
          inverseCumulativeProbability: [
            Tuple2(0.0, 0),
            Tuple2(0.1, 0.0263401),
            Tuple2(0.2, 0.0557859),
            Tuple2(0.3, 0.0891687),
            Tuple2(0.4, 0.127706),
            Tuple2(0.5, 0.173287),
            Tuple2(0.6, 0.229073),
            Tuple2(0.7, 0.300993),
            Tuple2(0.8, 0.402359),
            Tuple2(0.9, 0.575646),
            Tuple2(1.0, double.infinity),
          ],
        );
      });
      group('gamma (shape = 1.0; scale = 2.0)', () {
        const distribution = GammaDistribution(1.0, 2.0);
        testDistribution(
          distribution,
          min: 0.0,
          mean: 2.0,
          mode: double.nan,
          variance: 4.0,
          probability: [
            Tuple2(1.0, 0.303265),
            Tuple2(2.0, 0.183940),
            Tuple2(3.0, 0.111565),
            Tuple2(4.0, 0.067668),
            Tuple2(5.0, 0.041042),
            Tuple2(6.0, 0.024894),
            Tuple2(7.0, 0.015099),
            Tuple2(8.0, 0.009158),
            Tuple2(9.0, 0.005554),
          ],
          cumulativeProbability: [
            Tuple2(1.0, 0.393469),
            Tuple2(2.0, 0.632121),
            Tuple2(3.0, 0.776870),
            Tuple2(4.0, 0.864665),
            Tuple2(5.0, 0.917915),
            Tuple2(6.0, 0.950213),
            Tuple2(7.0, 0.969803),
            Tuple2(8.0, 0.981684),
            Tuple2(9.0, 0.988891),
          ],
          inverseCumulativeProbability: [
            Tuple2(0.0, 0.000000),
            Tuple2(0.1, 0.210721),
            Tuple2(0.2, 0.446287),
            Tuple2(0.3, 0.713350),
            Tuple2(0.4, 1.021651),
            Tuple2(0.5, 1.386294),
            Tuple2(0.6, 1.832581),
            Tuple2(0.7, 2.407946),
            Tuple2(0.8, 3.218876),
            Tuple2(0.9, 4.605170),
          ],
        );
        test('median', () {
          expect(() => distribution.median, throwsUnsupportedError);
        });
      });
      group('gamma (shape = 2.0; scale = 2.0)', () {
        const distribution = GammaDistribution(2.0, 2.0);
        testDistribution(
          distribution,
          min: 0.0,
          mean: 4.0,
          mode: 2.0,
          variance: 8.0,
          probability: [
            Tuple2(1.0, 0.151633),
            Tuple2(2.0, 0.183940),
            Tuple2(3.0, 0.167348),
            Tuple2(4.0, 0.135335),
            Tuple2(5.0, 0.102606),
            Tuple2(6.0, 0.074681),
            Tuple2(7.0, 0.052845),
            Tuple2(8.0, 0.036631),
            Tuple2(9.0, 0.024995),
          ],
          cumulativeProbability: [
            Tuple2(1.0, 0.090204),
            Tuple2(2.0, 0.264241),
            Tuple2(3.0, 0.442175),
            Tuple2(4.0, 0.593994),
            Tuple2(5.0, 0.712703),
            Tuple2(6.0, 0.800852),
            Tuple2(7.0, 0.864112),
            Tuple2(8.0, 0.908422),
            Tuple2(9.0, 0.938901),
          ],
          inverseCumulativeProbability: [
            Tuple2(0.0, 0.000000),
            Tuple2(0.1, 1.063623),
            Tuple2(0.2, 1.648777),
            Tuple2(0.3, 2.194698),
            Tuple2(0.4, 2.752843),
            Tuple2(0.5, 3.356694),
            Tuple2(0.6, 4.044626),
            Tuple2(0.7, 4.878433),
            Tuple2(0.8, 5.988617),
            Tuple2(0.9, 7.779440),
          ],
        );
      });
      group('gamma (shape = 3.0; scale = 2.0)', () {
        const distribution = GammaDistribution(3.0, 2.0);
        testDistribution(
          distribution,
          min: 0.0,
          mean: 6.0,
          mode: 4.0,
          variance: 12.0,
          probability: [
            Tuple2(1.0, 0.037908),
            Tuple2(2.0, 0.091970),
            Tuple2(3.0, 0.125511),
            Tuple2(4.0, 0.135335),
            Tuple2(5.0, 0.128258),
            Tuple2(6.0, 0.112021),
            Tuple2(7.0, 0.092479),
            Tuple2(8.0, 0.073263),
            Tuple2(9.0, 0.056239),
          ],
          cumulativeProbability: [
            Tuple2(1.0, 0.014388),
            Tuple2(2.0, 0.080301),
            Tuple2(3.0, 0.191153),
            Tuple2(4.0, 0.323324),
            Tuple2(5.0, 0.456187),
            Tuple2(6.0, 0.576810),
            Tuple2(7.0, 0.679153),
            Tuple2(8.0, 0.761897),
            Tuple2(9.0, 0.826422),
          ],
          inverseCumulativeProbability: [
            Tuple2(0.0, 0.000000),
            Tuple2(0.1, 2.204131),
            Tuple2(0.2, 3.070088),
            Tuple2(0.3, 3.827552),
            Tuple2(0.4, 4.570154),
            Tuple2(0.5, 5.348121),
            Tuple2(0.6, 6.210757),
            Tuple2(0.7, 7.231135),
            Tuple2(0.8, 8.558060),
            Tuple2(0.9, 10.644641),
          ],
        );
      });
      group('gamma (shape = 5.0; scale = 1.0)', () {
        const distribution = GammaDistribution(5.0, 1.0);
        testDistribution(
          distribution,
          min: 0.0,
          mean: 5.0,
          mode: 4.0,
          variance: 5.0,
          probability: [
            Tuple2(1.0, 0.015328),
            Tuple2(2.0, 0.090224),
            Tuple2(3.0, 0.168031),
            Tuple2(4.0, 0.195367),
            Tuple2(5.0, 0.175467),
            Tuple2(6.0, 0.133853),
            Tuple2(7.0, 0.091226),
            Tuple2(8.0, 0.057252),
            Tuple2(9.0, 0.033737),
          ],
          cumulativeProbability: [
            Tuple2(1.0, 0.003660),
            Tuple2(2.0, 0.052653),
            Tuple2(3.0, 0.184737),
            Tuple2(4.0, 0.371163),
            Tuple2(5.0, 0.559507),
            Tuple2(6.0, 0.714943),
            Tuple2(7.0, 0.827008),
            Tuple2(8.0, 0.900368),
            Tuple2(9.0, 0.945036),
          ],
          inverseCumulativeProbability: [
            Tuple2(0.0, 0.000000),
            Tuple2(0.1, 2.432591),
            Tuple2(0.2, 3.089540),
            Tuple2(0.3, 3.633609),
            Tuple2(0.4, 4.147736),
            Tuple2(0.5, 4.670909),
            Tuple2(0.6, 5.236618),
            Tuple2(0.7, 5.890361),
            Tuple2(0.8, 6.720979),
            Tuple2(0.9, 7.993590),
          ],
        );
      });
      group('gamma (shape = 9.0; scale = 0.5)', () {
        const distribution = GammaDistribution(9.0, 0.5);
        testDistribution(
          distribution,
          min: 0.0,
          mean: 4.5,
          mode: 4.0,
          variance: 2.25,
          probability: [
            Tuple2(1.0, 0.001719),
            Tuple2(2.0, 0.059540),
            Tuple2(3.0, 0.206515),
            Tuple2(4.0, 0.279173),
            Tuple2(5.0, 0.225198),
            Tuple2(6.0, 0.131047),
            Tuple2(7.0, 0.060871),
            Tuple2(8.0, 0.023975),
            Tuple2(9.0, 0.008325),
          ],
          cumulativeProbability: [
            Tuple2(1.0, 0.000237),
            Tuple2(2.0, 0.021363),
            Tuple2(3.0, 0.152763),
            Tuple2(4.0, 0.407453),
            Tuple2(5.0, 0.667180),
            Tuple2(6.0, 0.844972),
            Tuple2(7.0, 0.937945),
            Tuple2(8.0, 0.978013),
            Tuple2(9.0, 0.992944),
          ],
          inverseCumulativeProbability: [
            Tuple2(0.0, 0.000000),
            Tuple2(0.1, 2.716234),
            Tuple2(0.2, 3.214238),
            Tuple2(0.3, 3.609966),
            Tuple2(0.4, 3.973303),
            Tuple2(0.5, 4.334476),
            Tuple2(0.6, 4.716976),
            Tuple2(0.7, 5.150339),
            Tuple2(0.8, 5.689886),
            Tuple2(0.9, 6.497356),
          ],
        );
      });
      group('gamma (shape = 7.5; scale = 1.0)', () {
        const distribution = GammaDistribution(7.5, 1.0);
        testDistribution(
          distribution,
          min: 0.0,
          mean: 7.5,
          mode: 6.5,
          variance: 7.5,
          probability: [
            Tuple2(1.0, 0.000197),
            Tuple2(2.0, 0.006546),
            Tuple2(3.0, 0.033595),
            Tuple2(4.0, 0.080182),
            Tuple2(5.0, 0.125806),
            Tuple2(6.0, 0.151385),
            Tuple2(7.0, 0.151685),
            Tuple2(8.0, 0.132922),
            Tuple2(9.0, 0.105146),
          ],
          cumulativeProbability: [
            Tuple2(1.0, 0.000030),
            Tuple2(2.0, 0.002263),
            Tuple2(3.0, 0.020252),
            Tuple2(4.0, 0.076217),
            Tuple2(5.0, 0.180260),
            Tuple2(6.0, 0.320971),
            Tuple2(7.0, 0.474471),
            Tuple2(8.0, 0.617948),
            Tuple2(9.0, 0.737334),
          ],
          inverseCumulativeProbability: [
            Tuple2(0.0, 0.000000),
            Tuple2(0.1, 4.273378),
            Tuple2(0.2, 5.153480),
            Tuple2(0.3, 5.860584),
            Tuple2(0.4, 6.514875),
            Tuple2(0.5, 7.169430),
            Tuple2(0.6, 7.866611),
            Tuple2(0.7, 8.660847),
            Tuple2(0.8, 9.655329),
            Tuple2(0.9, 11.153565),
          ],
        );
      });
      group('gamma (shape = 0.5; scale = 1.0)', () {
        const distribution = GammaDistribution(0.5, 1.0);
        testDistribution(
          distribution,
          min: 0.0,
          mean: 0.5,
          mode: double.nan,
          variance: 0.5,
          probability: [
            Tuple2(1.0, 0.207554),
            Tuple2(2.0, 0.053991),
            Tuple2(3.0, 0.016217),
            Tuple2(4.0, 0.005167),
            Tuple2(5.0, 0.001700),
            Tuple2(6.0, 0.000571),
            Tuple2(7.0, 0.000194),
            Tuple2(8.0, 0.000067),
            Tuple2(9.0, 0.000023),
          ],
          cumulativeProbability: [
            Tuple2(1.0, 0.842701),
            Tuple2(2.0, 0.954500),
            Tuple2(3.0, 0.985694),
            Tuple2(4.0, 0.995322),
            Tuple2(5.0, 0.998435),
            Tuple2(6.0, 0.999468),
            Tuple2(7.0, 0.999817),
            Tuple2(8.0, 0.999937),
            Tuple2(9.0, 0.999978),
          ],
          inverseCumulativeProbability: [
            Tuple2(0.0, 0.000000),
            Tuple2(0.1, 0.007895),
            Tuple2(0.2, 0.032092),
            Tuple2(0.3, 0.074236),
            Tuple2(0.4, 0.137498),
            Tuple2(0.5, 0.227468),
            Tuple2(0.6, 0.354163),
            Tuple2(0.7, 0.537097),
            Tuple2(0.8, 0.821187),
            Tuple2(0.9, 1.352772),
          ],
        );
      });
      group('inverse gamma (shape = 1.0; scale = 1.0)', () {
        const distribution = InverseGammaDistribution(1.0, 1.0);
        testDistribution(
          distribution,
          min: 0.0,
          mean: double.nan,
          mode: 0.5,
          variance: double.nan,
          probability: [
            Tuple2(1.0, 0.367879),
            Tuple2(2.0, 0.151633),
            Tuple2(3.0, 0.0796146),
            Tuple2(4.0, 0.048675),
            Tuple2(5.0, 0.0327492),
            Tuple2(6.0, 0.0235134),
            Tuple2(7.0, 0.0176914),
            Tuple2(8.0, 0.013789),
            Tuple2(9.0, 0.0110474),
          ],
          cumulativeProbability: [
            Tuple2(1.0, 0.367879),
            Tuple2(2.0, 0.606531),
            Tuple2(3.0, 0.716531),
            Tuple2(4.0, 0.778801),
            Tuple2(5.0, 0.818731),
            Tuple2(6.0, 0.846482),
            Tuple2(7.0, 0.866878),
            Tuple2(8.0, 0.882497),
            Tuple2(9.0, 0.894839),
          ],
          // inverseCumulativeProbability: [
          //   Tuple2(0.0, 0.0),
          //   Tuple2(0.1, 0.434294),
          //   Tuple2(0.2, 0.621335),
          //   Tuple2(0.3, 0.830584),
          //   Tuple2(0.4, 1.09136),
          //   Tuple2(0.5, 1.4427),
          //   Tuple2(0.6, 1.95762),
          //   Tuple2(0.7, 2.80367),
          //   Tuple2(0.8, 4.48142),
          //   Tuple2(0.9, 9.49122),
          // ],
        );
        test('median', () {
          expect(() => distribution.median, throwsUnsupportedError);
        });
      });
      group('inverse gamma (shape = 2.0; scale = 1.0)', () {
        const distribution = InverseGammaDistribution(2.0, 1.0);
        testDistribution(
          distribution,
          min: 0.0,
          mean: 1.0,
          mode: 0.333333333,
          variance: double.nan,
          probability: [
            Tuple2(1.0, 0.367879),
            Tuple2(2.0, 0.0758163),
            Tuple2(3.0, 0.0265382),
            Tuple2(4.0, 0.0121688),
            Tuple2(5.0, 0.00654985),
            Tuple2(6.0, 0.0039189),
            Tuple2(7.0, 0.00252734),
            Tuple2(8.0, 0.00172363),
            Tuple2(9.0, 0.00122749),
          ],
          cumulativeProbability: [
            Tuple2(1.0, 0.735759),
            Tuple2(2.0, 0.909796),
            Tuple2(3.0, 0.955375),
            Tuple2(4.0, 0.973501),
            Tuple2(5.0, 0.982477),
            Tuple2(6.0, 0.987562),
            Tuple2(7.0, 0.990718),
            Tuple2(8.0, 0.992809),
            Tuple2(9.0, 0.994266),
          ],
          // inverseCumulativeProbability: [
          //   Tuple2(0.0, 0.0),
          //   Tuple2(0.1, 0.257088),
          //   Tuple2(0.2, 0.333967),
          //   Tuple2(0.3, 0.409968),
          //   Tuple2(0.4, 0.494483),
          //   Tuple2(0.5, 0.595824),
          //   Tuple2(0.6, 0.726522),
          //   Tuple2(0.7, 0.911287),
          //   Tuple2(0.8, 1.21302),
          //   Tuple2(0.9, 1.88037),
          // ],
        );
      });
      group('inverse gamma (shape = 3.0; scale = 1.0)', () {
        const distribution = InverseGammaDistribution(3.0, 1.0);
        testDistribution(
          distribution,
          min: 0.0,
          mean: 0.5,
          mode: 0.25,
          variance: 0.25,
          probability: [
            Tuple2(1.0, 0.18394),
            Tuple2(2.0, 0.0189541),
            Tuple2(3.0, 0.00442303),
            Tuple2(4.0, 0.0015211),
            Tuple2(5.0, 0.000654985),
            Tuple2(6.0, 0.000326575),
            Tuple2(7.0, 0.000180524),
            Tuple2(8.0, 0.000107727),
            Tuple2(9.0, 0.0000681938),
          ],
          cumulativeProbability: [
            Tuple2(1.0, 0.919699),
            Tuple2(2.0, 0.985612),
            Tuple2(3.0, 0.995182),
            Tuple2(4.0, 0.997839),
            Tuple2(5.0, 0.998852),
            Tuple2(6.0, 0.999319),
            Tuple2(7.0, 0.999563),
            Tuple2(8.0, 0.999704),
            Tuple2(9.0, 0.99979),
          ],
          // inverseCumulativeProbability: [
          //   Tuple2(0.0, 0.0),
          //   Tuple2(0.1, 0.187888),
          //   Tuple2(0.2, 0.233698),
          //   Tuple2(0.3, 0.276582),
          //   Tuple2(0.4, 0.322022),
          //   Tuple2(0.5, 0.373963),
          //   Tuple2(0.6, 0.437622),
          //   Tuple2(0.7, 0.522527),
          //   Tuple2(0.8, 0.651447),
          //   Tuple2(0.9, 0.907387),
          // ],
        );
      });
      group('inverse gamma (shape = 3.0; scale = 1.5)', () {
        const distribution = InverseGammaDistribution(3.0, 1.5);
        testDistribution(
          distribution,
          min: 0.0,
          mean: 0.75,
          mode: 0.375,
          variance: 0.5625,
          probability: [
            Tuple2(1.0, 0.376532),
            Tuple2(2.0, 0.0498199),
            Tuple2(3.0, 0.0126361),
            Tuple2(4.0, 0.00453047),
            Tuple2(5.0, 0.00200021),
            Tuple2(6.0, 0.00101406),
            Tuple2(7.0, 0.000567268),
            Tuple2(8.0, 0.000341549),
            Tuple2(9.0, 0.000217716),
          ],
          cumulativeProbability: [
            Tuple2(1.0, 0.808847),
            Tuple2(2.0, 0.959495),
            Tuple2(3.0, 0.985612),
            Tuple2(4.0, 0.993348),
            Tuple2(5.0, 0.996401),
            Tuple2(6.0, 0.997839),
            Tuple2(7.0, 0.998602),
            Tuple2(8.0, 0.999045),
            Tuple2(9.0, 0.999319),
          ],
          // inverseCumulativeProbability: [
          //   Tuple2(0.0, 0.0),
          //   Tuple2(0.1, 0.281832),
          //   Tuple2(0.2, 0.350547),
          //   Tuple2(0.3, 0.414873),
          //   Tuple2(0.4, 0.483033),
          //   Tuple2(0.5, 0.560945),
          //   Tuple2(0.6, 0.656433),
          //   Tuple2(0.7, 0.783791),
          //   Tuple2(0.8, 0.977171),
          //   Tuple2(0.9, 1.36108),
          // ],
        );
      });
      group('normal', () {
        const distribution = NormalDistribution(2.1, 1.4);
        testDistribution(distribution,
            mean: 2.1,
            median: 2.1,
            mode: 2.1,
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
        testDistribution(
          distribution,
          mean: 0.0,
          median: 0.0,
          mode: 0.0,
          variance: 1.0,
        );
      });
      group('student (v = 1, cauchy distribution)', () {
        const distribution = StudentDistribution(1);
        testDistribution(
          distribution,
          mean: double.nan,
          median: 0.0,
          mode: 0.0,
          variance: double.nan,
          probability: const [
            Tuple2(-4.0, 0.018724),
            Tuple2(-3.0, 0.031831),
            Tuple2(-2.0, 0.063662),
            Tuple2(-1.0, 0.159155),
            Tuple2(0.0, 0.318310),
            Tuple2(1.0, 0.159155),
            Tuple2(2.0, 0.063662),
            Tuple2(3.0, 0.031831),
            Tuple2(4.0, 0.018724),
          ],
          cumulativeProbability: [
            Tuple2(-4.0, 0.077979),
            Tuple2(-3.0, 0.102416),
            Tuple2(-2.0, 0.147584),
            Tuple2(-1.0, 0.250000),
            Tuple2(0.0, 0.500000),
            Tuple2(1.0, 0.750000),
            Tuple2(2.0, 0.852416),
            Tuple2(3.0, 0.897584),
            Tuple2(4.0, 0.922021),
          ],
          inverseCumulativeProbability: [
            Tuple2(0.0, -double.infinity),
            Tuple2(0.1, -3.077684),
            Tuple2(0.2, -1.376382),
            Tuple2(0.3, -0.726543),
            Tuple2(0.4, -0.324920),
            Tuple2(0.5, 0.000000),
            Tuple2(0.6, 0.324920),
            Tuple2(0.7, 0.726543),
            Tuple2(0.8, 1.376382),
            Tuple2(0.9, 3.077684),
            Tuple2(1.0, double.infinity),
          ],
        );
      });
      group('student (v = 2)', () {
        const distribution = StudentDistribution(2);
        testDistribution(
          distribution,
          mean: 0.0,
          median: 0.0,
          mode: 0.0,
          variance: double.infinity,
          probability: const [
            Tuple2(-4.0, 0.013095),
            Tuple2(-3.0, 0.027410),
            Tuple2(-2.0, 0.068041),
            Tuple2(-1.0, 0.192450),
            Tuple2(0.0, 0.353553),
            Tuple2(1.0, 0.192450),
            Tuple2(2.0, 0.068041),
            Tuple2(3.0, 0.027410),
            Tuple2(4.0, 0.013095),
          ],
          cumulativeProbability: [
            Tuple2(-4.0, 0.028595),
            Tuple2(-3.0, 0.047733),
            Tuple2(-2.0, 0.091752),
            Tuple2(-1.0, 0.211325),
            Tuple2(0.0, 0.500000),
            Tuple2(1.0, 0.788675),
            Tuple2(2.0, 0.908248),
            Tuple2(3.0, 0.952267),
            Tuple2(4.0, 0.971405),
          ],
          inverseCumulativeProbability: [
            Tuple2(0.0, -double.infinity),
            Tuple2(0.1, -1.885618),
            Tuple2(0.2, -1.060660),
            Tuple2(0.3, -0.617213),
            Tuple2(0.4, -0.288675),
            Tuple2(0.5, 0.000000),
            Tuple2(0.6, 0.288675),
            Tuple2(0.7, 0.617213),
            Tuple2(0.8, 1.060660),
            Tuple2(0.9, 1.885618),
            Tuple2(1.0, double.infinity),
          ],
        );
      });
      group('student (v = 3)', () {
        const distribution = StudentDistribution(3);
        testDistribution(
          distribution,
          mean: 0.0,
          median: 0.0,
          mode: 0.0,
          variance: 3.0,
          probability: const [
            Tuple2(-4.0, 0.009163),
            Tuple2(-3.0, 0.022972),
            Tuple2(-2.0, 0.067510),
            Tuple2(-1.0, 0.206748),
            Tuple2(0.0, 0.367553),
            Tuple2(1.0, 0.206748),
            Tuple2(2.0, 0.067510),
            Tuple2(3.0, 0.022972),
            Tuple2(4.0, 0.009163),
          ],
          cumulativeProbability: [
            Tuple2(-4.0, 0.014004),
            Tuple2(-3.0, 0.028834),
            Tuple2(-2.0, 0.069663),
            Tuple2(-1.0, 0.195501),
            Tuple2(0.0, 0.500000),
            Tuple2(1.0, 0.804499),
            Tuple2(2.0, 0.930337),
            Tuple2(3.0, 0.971166),
            Tuple2(4.0, 0.985996),
          ],
          inverseCumulativeProbability: [
            Tuple2(0.0, -double.infinity),
            Tuple2(0.1, -1.637744),
            Tuple2(0.2, -0.978472),
            Tuple2(0.3, -0.584390),
            Tuple2(0.4, -0.276671),
            Tuple2(0.5, 0.000000),
            Tuple2(0.6, 0.276671),
            Tuple2(0.7, 0.584390),
            Tuple2(0.8, 0.978472),
            Tuple2(0.9, 1.637744),
            Tuple2(1.0, double.infinity),
          ],
        );
      });
      group('student (v = 4)', () {
        const distribution = StudentDistribution(4);
        testDistribution(
          distribution,
          mean: 0.0,
          median: 0.0,
          mode: 0.0,
          variance: 2.0,
          probability: const [
            Tuple2(-4.0, 0.006708),
            Tuple2(-3.0, 0.019693),
            Tuple2(-2.0, 0.066291),
            Tuple2(-1.0, 0.214663),
            Tuple2(0.0, 0.375000),
            Tuple2(1.0, 0.214663),
            Tuple2(2.0, 0.066291),
            Tuple2(3.0, 0.019693),
            Tuple2(4.0, 0.006708),
          ],
          cumulativeProbability: [
            Tuple2(-4.0, 0.008065),
            Tuple2(-3.0, 0.019971),
            Tuple2(-2.0, 0.058058),
            Tuple2(-1.0, 0.186950),
            Tuple2(0.0, 0.500000),
            Tuple2(1.0, 0.813050),
            Tuple2(2.0, 0.941942),
            Tuple2(3.0, 0.980029),
            Tuple2(4.0, 0.991935),
          ],
          inverseCumulativeProbability: [
            Tuple2(0.0, -double.infinity),
            Tuple2(0.1, -1.533206),
            Tuple2(0.2, -0.940965),
            Tuple2(0.3, -0.568649),
            Tuple2(0.4, -0.270722),
            Tuple2(0.5, 0.000000),
            Tuple2(0.6, 0.270722),
            Tuple2(0.7, 0.568649),
            Tuple2(0.8, 0.940965),
            Tuple2(0.9, 1.533206),
            Tuple2(1.0, double.infinity),
          ],
        );
      });
      group('student (v = 5)', () {
        const distribution = StudentDistribution(5);
        testDistribution(
          distribution,
          mean: 0.0,
          median: 0.0,
          mode: 0.0,
          variance: 5 / 3,
          probability: const [
            Tuple2(-4.0, 0.005124),
            Tuple2(-3.0, 0.017293),
            Tuple2(-2.0, 0.065090),
            Tuple2(-1.0, 0.219680),
            Tuple2(0.0, 0.379607),
            Tuple2(1.0, 0.219680),
            Tuple2(2.0, 0.065090),
            Tuple2(3.0, 0.017293),
            Tuple2(4.0, 0.005124),
          ],
          cumulativeProbability: [
            Tuple2(-4.0, 0.005162),
            Tuple2(-3.0, 0.015050),
            Tuple2(-2.0, 0.050970),
            Tuple2(-1.0, 0.181609),
            Tuple2(0.0, 0.500000),
            Tuple2(1.0, 0.818391),
            Tuple2(2.0, 0.949030),
            Tuple2(3.0, 0.984950),
            Tuple2(4.0, 0.994838),
          ],
          inverseCumulativeProbability: [
            Tuple2(0.0, -double.infinity),
            Tuple2(0.1, -1.475884),
            Tuple2(0.2, -0.919544),
            Tuple2(0.3, -0.559430),
            Tuple2(0.4, -0.267181),
            Tuple2(0.5, 0.000000),
            Tuple2(0.6, 0.267181),
            Tuple2(0.7, 0.559430),
            Tuple2(0.8, 0.919544),
            Tuple2(0.9, 1.475884),
            Tuple2(1.0, double.infinity),
          ],
        );
      });
      group('student (v = 1234)', () {
        const distribution = StudentDistribution(1234);
        testDistribution(
          distribution,
          mean: 0.0,
          median: 0.0,
          mode: 0.0,
          variance: 1234 / 1232,
          probability: const [
            Tuple2(-4.0, 0.000140),
            Tuple2(-3.0, 0.004488),
            Tuple2(-2.0, 0.054067),
            Tuple2(-1.0, 0.241873),
            Tuple2(0.0, 0.398861),
            Tuple2(1.0, 0.241873),
            Tuple2(2.0, 0.054067),
            Tuple2(3.0, 0.004488),
            Tuple2(4.0, 0.000140),
          ],
          cumulativeProbability: [
            Tuple2(-4.0, 0.000034),
            Tuple2(-3.0, 0.001377),
            Tuple2(-2.0, 0.022860),
            Tuple2(-1.0, 0.158753),
            Tuple2(0.0, 0.500000),
            Tuple2(1.0, 0.841247),
            Tuple2(2.0, 0.977140),
            Tuple2(3.0, 0.998623),
            Tuple2(4.0, 0.999966),
          ],
          inverseCumulativeProbability: [
            Tuple2(0.0, -double.infinity),
            Tuple2(0.1, -1.282238),
            Tuple2(0.2, -0.841913),
            Tuple2(0.3, -0.524536),
            Tuple2(0.4, -0.253402),
            Tuple2(0.5, 0.000000),
            Tuple2(0.6, 0.253402),
            Tuple2(0.7, 0.524536),
            Tuple2(0.8, 0.841913),
            Tuple2(0.9, 1.282238),
            Tuple2(1.0, double.infinity),
          ],
        );
      });
      group('uniform', () {
        const distribution = UniformDistribution(-0.5, 1.25);
        testDistribution(
          distribution,
          min: -0.5,
          max: 1.25,
          mean: 0.375,
          median: 0.375,
          mode: double.nan,
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
          median: 0.5,
          mode: double.nan,
          variance: 0.08333333333,
        );
        test('samples with default random generator', () {
          expect(
              distribution.samples().take(1000),
              everyElement(
                  allOf(greaterThanOrEqualTo(0.0), lessThanOrEqualTo(1.0))));
        });
      });
      group('weibull (scale = 1, shape = 0.5)', () {
        const distribution = WeibullDistribution(1, 0.5);
        testDistribution(
          distribution,
          min: 0.0,
          mean: 2.00000000,
          median: 0.48045301,
          mode: 0.00000000,
          variance: 20.00000000,
          skewness: 6.61876121,
          probability: [
            Tuple2(0.0, double.infinity),
            Tuple2(0.5, 0.34865222),
            Tuple2(1.0, 0.18393972),
            Tuple2(1.5, 0.11995668),
            Tuple2(2.0, 0.08595475),
            Tuple2(2.5, 0.06506091),
            Tuple2(3.0, 0.05107275),
            Tuple2(3.5, 0.04115716),
            Tuple2(4.0, 0.03383382),
            Tuple2(4.5, 0.02825440),
            Tuple2(5.0, 0.02389863),
          ],
          cumulativeProbability: [
            Tuple2(0.0, 0.00000000),
            Tuple2(0.5, 0.50693131),
            Tuple2(1.0, 0.63212056),
            Tuple2(1.5, 0.70616734),
            Tuple2(2.0, 0.75688327),
            Tuple2(2.5, 0.79425934),
            Tuple2(3.0, 0.82307879),
            Tuple2(3.5, 0.84600401),
            Tuple2(4.0, 0.86466472),
            Tuple2(4.5, 0.88012675),
            Tuple2(5.0, 0.89312207),
          ],
          inverseCumulativeProbability: [
            Tuple2(0.0, 0.00000000),
            Tuple2(0.1, 0.01110084),
            Tuple2(0.2, 0.04979304),
            Tuple2(0.3, 0.12721702),
            Tuple2(0.4, 0.26094282),
            Tuple2(0.5, 0.48045301),
            Tuple2(0.6, 0.83958871),
            Tuple2(0.7, 1.44955051),
            Tuple2(0.8, 2.59029039),
            Tuple2(0.9, 5.30189811),
            Tuple2(1.0, double.infinity),
          ],
        );
      });
      group('weibull (scale = 1, shape = 1)', () {
        const distribution = WeibullDistribution(1, 1);
        testDistribution(
          distribution,
          min: 0.0,
          mean: 1.00000000,
          median: 0.69314718,
          mode: 0.00000000,
          variance: 1.00000000,
          skewness: 2.00000000,
          probability: [
            Tuple2(0.0, 1.00000000),
            Tuple2(0.5, 0.60653066),
            Tuple2(1.0, 0.36787944),
            Tuple2(1.5, 0.22313016),
            Tuple2(2.0, 0.13533528),
            Tuple2(2.5, 0.08208500),
            Tuple2(3.0, 0.04978707),
            Tuple2(3.5, 0.03019738),
            Tuple2(4.0, 0.01831564),
            Tuple2(4.5, 0.01110900),
            Tuple2(5.0, 0.00673795),
          ],
          cumulativeProbability: [
            Tuple2(0.0, 0.00000000),
            Tuple2(0.5, 0.39346934),
            Tuple2(1.0, 0.63212056),
            Tuple2(1.5, 0.77686984),
            Tuple2(2.0, 0.86466472),
            Tuple2(2.5, 0.91791500),
            Tuple2(3.0, 0.95021293),
            Tuple2(3.5, 0.96980262),
            Tuple2(4.0, 0.98168436),
            Tuple2(4.5, 0.98889100),
            Tuple2(5.0, 0.99326205),
          ],
          inverseCumulativeProbability: [
            Tuple2(0.0, 0.00000000),
            Tuple2(0.1, 0.10536052),
            Tuple2(0.2, 0.22314355),
            Tuple2(0.3, 0.35667494),
            Tuple2(0.4, 0.51082562),
            Tuple2(0.5, 0.69314718),
            Tuple2(0.6, 0.91629073),
            Tuple2(0.7, 1.20397280),
            Tuple2(0.8, 1.60943791),
            Tuple2(0.9, 2.30258509),
            Tuple2(1.0, double.infinity),
          ],
        );
      });
      group('weibull (scale = 1, shape = 1.5)', () {
        const distribution = WeibullDistribution(1, 1.5);
        testDistribution(
          distribution,
          min: 0.0,
          mean: 0.90274529,
          median: 0.78321977,
          mode: 0.48074986,
          variance: 0.37569028,
          skewness: 1.07198657,
          probability: [
            Tuple2(0.0, 0.00000000),
            Tuple2(0.5, 0.74478338),
            Tuple2(1.0, 0.55181916),
            Tuple2(1.5, 0.29260853),
            Tuple2(2.0, 0.12538222),
            Tuple2(2.5, 0.04553670),
            Tuple2(3.0, 0.01438771),
            Tuple2(3.5, 0.00402169),
            Tuple2(4.0, 0.00100639),
            Tuple2(4.5, 0.00022748),
            Tuple2(5.0, 0.00004678),
          ],
          cumulativeProbability: [
            Tuple2(0.0, 0.00000000),
            Tuple2(0.5, 0.29781150),
            Tuple2(1.0, 0.63212056),
            Tuple2(1.5, 0.84072409),
            Tuple2(2.0, 0.94089425),
            Tuple2(2.5, 0.98080004),
            Tuple2(3.0, 0.99446217),
            Tuple2(3.5, 0.99856688),
            Tuple2(4.0, 0.99966454),
            Tuple2(4.5, 0.99992851),
            Tuple2(5.0, 0.99998605),
          ],
          inverseCumulativeProbability: [
            Tuple2(0.0, 0.00000000),
            Tuple2(0.1, 0.22307553),
            Tuple2(0.2, 0.36789416),
            Tuple2(0.3, 0.50293871),
            Tuple2(0.4, 0.63902098),
            Tuple2(0.5, 0.78321977),
            Tuple2(0.6, 0.94338477),
            Tuple2(0.7, 1.13173423),
            Tuple2(0.8, 1.37335502),
            Tuple2(0.9, 1.74372151),
            Tuple2(1.0, double.infinity),
          ],
        );
      });
      group('weibull (scale = 1, shape = 2)', () {
        const distribution = WeibullDistribution(1, 2);
        testDistribution(
          distribution,
          min: 0.0,
          mean: 0.88622693,
          median: 0.83255461,
          mode: 0.70710678,
          variance: 0.21460184,
          skewness: 0.63111066,
          probability: [
            Tuple2(0.0, 0.00000000),
            Tuple2(0.5, 0.77880078),
            Tuple2(1.0, 0.73575888),
            Tuple2(1.5, 0.31619767),
            Tuple2(2.0, 0.07326256),
            Tuple2(2.5, 0.00965227),
            Tuple2(3.0, 0.00074046),
            Tuple2(3.5, 0.00003350),
            Tuple2(4.0, 0.00000090),
            Tuple2(4.5, 0.00000001),
            Tuple2(5.0, 0.00000000),
          ],
          cumulativeProbability: [
            Tuple2(0.0, 0.00000000),
            Tuple2(0.5, 0.22119922),
            Tuple2(1.0, 0.63212056),
            Tuple2(1.5, 0.89460078),
            Tuple2(2.0, 0.98168436),
            Tuple2(2.5, 0.99806955),
            Tuple2(3.0, 0.99987659),
            Tuple2(3.5, 0.99999521),
            Tuple2(4.0, 0.99999989),
            Tuple2(4.5, 1.00000000),
            Tuple2(5.0, 1.00000000),
          ],
          inverseCumulativeProbability: [
            Tuple2(0.0, 0.00000000),
            Tuple2(0.1, 0.32459285),
            Tuple2(0.2, 0.47238073),
            Tuple2(0.3, 0.59722269),
            Tuple2(0.4, 0.71472066),
            Tuple2(0.5, 0.83255461),
            Tuple2(0.6, 0.95723076),
            Tuple2(0.7, 1.09725695),
            Tuple2(0.8, 1.26863624),
            Tuple2(0.9, 1.51742713),
            Tuple2(1.0, double.infinity),
          ],
        );
      });
      group('weibull (scale = 1.5, shape = 1)', () {
        const distribution = WeibullDistribution(1.5, 1);
        testDistribution(
          distribution,
          min: 0.0,
          mean: 1.50000000,
          median: 1.03972077,
          mode: 0.00000000,
          variance: 2.25000000,
          skewness: 2.00000000,
          probability: [
            Tuple2(0.0, 0.66666667),
            Tuple2(0.5, 0.47768754),
            Tuple2(1.0, 0.34227808),
            Tuple2(1.5, 0.24525296),
            Tuple2(2.0, 0.17573143),
            Tuple2(2.5, 0.12591707),
            Tuple2(3.0, 0.09022352),
            Tuple2(3.5, 0.06464798),
            Tuple2(4.0, 0.04632230),
            Tuple2(4.5, 0.03319138),
            Tuple2(5.0, 0.02378266),
          ],
          cumulativeProbability: [
            Tuple2(0.0, 0.00000000),
            Tuple2(0.5, 0.28346869),
            Tuple2(1.0, 0.48658288),
            Tuple2(1.5, 0.63212056),
            Tuple2(2.0, 0.73640286),
            Tuple2(2.5, 0.81112440),
            Tuple2(3.0, 0.86466472),
            Tuple2(3.5, 0.90302803),
            Tuple2(4.0, 0.93051655),
            Tuple2(4.5, 0.95021293),
            Tuple2(5.0, 0.96432601),
          ],
          inverseCumulativeProbability: [
            Tuple2(0.0, 0.00000000),
            Tuple2(0.1, 0.15804077),
            Tuple2(0.2, 0.33471533),
            Tuple2(0.3, 0.53501242),
            Tuple2(0.4, 0.76623844),
            Tuple2(0.5, 1.03972077),
            Tuple2(0.6, 1.37443610),
            Tuple2(0.7, 1.80595921),
            Tuple2(0.8, 2.41415687),
            Tuple2(0.9, 3.45387764),
            Tuple2(1.0, double.infinity),
          ],
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
            mode: 1.0,
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
            mode: 7,
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
      group('negative bernoulli', () {
        const distribution = NegativeBinomialDistribution(5, 0.4);
        test('parameters', () {
          expect(distribution.r, isCloseTo(5));
          expect(distribution.p, isCloseTo(0.4));
          expect(distribution.q, isCloseTo(0.6));
        });
        testDistribution(
          distribution,
          min: 0,
          mean: 3.33333333333,
          mode: 2.0,
          variance: 5.55555555555,
          skewness: 0.98994949366,
          kurtosisExcess: 1.38,
          probability: const [
            Tuple2(-1, 0),
            Tuple2(0, 0.07776),
            Tuple2(1, 0.15552),
            Tuple2(2, 0.186624),
            Tuple2(3, 0.1741824),
            Tuple2(4, 0.13934592),
            Tuple2(5, 0.1003290624),
            Tuple2(6, 0.0668860416),
            Tuple2(7, 0.04204265472),
            Tuple2(8, 0.025225592832),
            Tuple2(9, 0.0145747869696),
          ],
          cumulativeProbability: const [
            Tuple2(-1, 0),
            Tuple2(0, 0.07776),
            Tuple2(1, 0.23328),
            Tuple2(2, 0.419904),
            Tuple2(3, 0.5940864),
            Tuple2(4, 0.73343232),
            Tuple2(5, 0.8337613824),
            Tuple2(6, 0.900647424),
            Tuple2(7, 0.9426900787),
            Tuple2(8, 0.9679156716),
            Tuple2(9, 0.9824904585),
          ],
          // // inverseCumulativeProbability: [
          //   Tuple2(0.0, 0),
          //   Tuple2(0.1, 2),
          //   Tuple2(0.2, 2),
          //   Tuple2(0.3, 3),
          //   Tuple2(0.4, 3),
          //   Tuple2(0.5, 4),
          //   Tuple2(0.6, 4),
          //   Tuple2(0.7, 5),
          //   Tuple2(0.8, 6),
          //   Tuple2(0.9, 7),
          //   Tuple2(1.0, maxSafeInteger),
          // ],
        );
      });
      group('poisson', () {
        const distribution = PoissonDistribution(4.0);
        testDistribution(
          distribution,
          min: 0,
          mean: 4.0,
          median: 4.0,
          mode: 4.0,
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
          cumulativeProbability: const [
            Tuple2(-1, 0),
            Tuple2(0, 0.0183156),
            Tuple2(1, 0.0915782),
            Tuple2(2, 0.238103),
            Tuple2(3, 0.43347),
            Tuple2(4, 0.628837),
            Tuple2(5, 0.78513),
            Tuple2(10, 0.99716),
            Tuple2(15, 0.999995),
            Tuple2(16, 0.999999),
            Tuple2(20, 1),
          ],
          inverseCumulativeProbability: [
            Tuple2(0.0, 0),
            Tuple2(0.1, 2),
            Tuple2(0.2, 2),
            Tuple2(0.3, 3),
            Tuple2(0.4, 3),
            Tuple2(0.5, 4),
            Tuple2(0.6, 4),
            Tuple2(0.7, 5),
            Tuple2(0.8, 6),
            Tuple2(0.9, 7),
            Tuple2(1.0, maxSafeInteger),
          ],
        );
      });
      group('uniform', () {
        const distribution = UniformDiscreteDistribution(-3, 5);
        testDistribution<int>(distribution,
            min: -3,
            max: 5,
            mean: 1,
            mode: double.nan,
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
      expect(<double>[].sum(), isCloseTo(0.0));
      expect([3, 2.25, 4.5, -0.5, 1.0].sum(), isCloseTo(10.25));
    });
    test('sum (int)', () {
      expect(<int>[].sum(), 0);
      expect([-1, 2, 3, 5, 7].sum(), 16);
    });
    test('product', () {
      expect(<double>[].product(), isCloseTo(1.0));
      expect([3, 2.25, 4.5, -0.5, 1.0].product(), isCloseTo(-15.1875));
    });
    test('product (int)', () {
      expect(<int>[].product(), 1);
      expect([-1, 2, 3, 5, 7].product(), -210);
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
  group('jackknife', () {
    test('mean', () {
      final samples = <int>[0, 1, 2, 3, 4, 5, 6, 7, 8, 9];
      final jackknife = Jackknife<int>(
        samples,
        (list) => list.arithmeticMean(),
      );
      expect(jackknife.samples, same(samples));
      expect(jackknife.confidenceLevel, 0.95);
      expect(jackknife.resamples, hasLength(10));
      for (var i = 0; i < 10; i++) {
        expect(jackknife.resamples[i], [
          ...IntegerRange(0, i),
          ...IntegerRange(i + 1, samples.length),
        ]);
        expect(() => jackknife.resamples[i][0] = 0, throwsUnsupportedError);
      }
      expect(jackknife.estimate, isCloseTo(4.5));
      expect(jackknife.bias, isCloseTo(0.0));
      expect(jackknife.standardError, isCloseTo(0.95742710));
      expect(jackknife.lowerBound, isCloseTo(2.62347735));
      expect(jackknife.upperBound, isCloseTo(6.37652265));
    });
    test('variance', () {
      final samples = <int>[0, 1, 2, 3, 4, 5, 6, 7, 8, 9];
      final jackknife = Jackknife<int>(
        samples,
        (list) => list.variance(population: true),
      );
      expect(jackknife.samples, same(samples));
      expect(jackknife.confidenceLevel, 0.95);
      expect(jackknife.resamples, hasLength(10));
      for (var i = 0; i < 10; i++) {
        expect(jackknife.resamples[i], [
          ...IntegerRange(0, i),
          ...IntegerRange(i + 1, samples.length),
        ]);
        expect(() => jackknife.resamples[i][0] = 0, throwsUnsupportedError);
      }
      expect(jackknife.estimate, isCloseTo(9.16666667));
      expect(jackknife.bias, isCloseTo(-0.91666667));
      expect(jackknife.standardError, isCloseTo(2.69124476));
      expect(jackknife.lowerBound, isCloseTo(3.89192387));
      expect(jackknife.upperBound, isCloseTo(14.44140947));
    });
    group('small samples', () {
      test('minimal', () {
        final samples = <int>[2];
        final jackknife = Jackknife<int>(
          samples,
          (list) => list.arithmeticMean(),
        );
        expect(jackknife.samples, same(samples));
        expect(jackknife.confidenceLevel, 0.95);
        expect(jackknife.resamples, [[]]);
        expect(jackknife.estimate, isNaN);
        expect(jackknife.bias, isNaN);
        expect(jackknife.standardError, isNaN);
        expect(jackknife.lowerBound, isNaN);
        expect(jackknife.upperBound, isNaN);
      });
      test('same numbers', () {
        final samples = <int>[2, 2];
        final jackknife = Jackknife<int>(
          samples,
          (list) => list.arithmeticMean(),
          confidenceLevel: 0.90,
        );
        expect(jackknife.samples, same(samples));
        expect(jackknife.confidenceLevel, 0.90);
        expect(jackknife.resamples, [
          [2],
          [2],
        ]);
        expect(jackknife.estimate, isCloseTo(2.0));
        expect(jackknife.bias, isCloseTo(0.0));
        expect(jackknife.standardError, isCloseTo(0.0));
        expect(jackknife.lowerBound, isCloseTo(2.0));
        expect(jackknife.upperBound, isCloseTo(2.0));
      });
      test('different numbers', () {
        final samples = <int>[2, 4];
        final jackknife = Jackknife<int>(
          samples,
          (list) => list.arithmeticMean(),
          confidenceLevel: 0.90,
        );
        expect(jackknife.samples, same(samples));
        expect(jackknife.confidenceLevel, 0.90);
        expect(jackknife.resamples, [
          [4],
          [2],
        ]);
        expect(jackknife.estimate, isCloseTo(3.0));
        expect(jackknife.bias, isCloseTo(0.0));
        expect(jackknife.standardError, isCloseTo(1.0));
        expect(jackknife.lowerBound, isCloseTo(1.355146387243735));
        expect(jackknife.upperBound, isCloseTo(4.644853612756265));
      });
    });
  });
}
