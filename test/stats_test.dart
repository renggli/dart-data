import 'dart:math' as math;

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

void testDistribution<T extends num>(
  Distribution<T> distribution, {
  T? min,
  T? max,
  double? mean,
  double? median,
  double? mode,
  double? variance,
  List<Tuple2<T, double>>? probability,
  List<Tuple2<T, double>>? cumulativeProbability,
  List<Tuple2<double, T>>? inverseCumulativeProbability,
}) {
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
    final samples = 20000;
    final histogram = Multiset<int>();
    final random = math.Random(distribution.hashCode);
    if (distribution is DiscreteDistribution) {
      for (var i = 0; i < samples; i++) {
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
      for (var i = 0; i < samples; i++) {
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
    StudentDistribution(42),
    GammaDistribution(1.2, 2.3),
    InverseGammaDistribution(1.2, 2.3),
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
      group('gamma (shape = 1.0; scale = 2.0)', () {
        const distribution = GammaDistribution(1.0, 2.0);
        testDistribution(
          distribution,
          min: 0.0,
          mean: 2.0,
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
      });
      group('gamma (shape = 2.0; scale = 2.0)', () {
        const distribution = GammaDistribution(2.0, 2.0);
        testDistribution(
          distribution,
          min: 0.0,
          mean: 4.0,
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
      });
      group('inverse gamma (shape = 2.0; scale = 1.0)', () {
        const distribution = InverseGammaDistribution(2.0, 1.0);
        testDistribution(
          distribution,
          min: 0.0,
          mean: 1.0,
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
        test('samples with default random generator', () {
          expect(
              distribution.samples().take(1000),
              everyElement(
                  allOf(greaterThanOrEqualTo(0.0), lessThanOrEqualTo(1.0))));
        });
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
      }
      expect(jackknife.estimate, isCloseTo(9.16666667));
      expect(jackknife.bias, isCloseTo(-0.91666667));
      expect(jackknife.standardError, isCloseTo(2.69124476));
      expect(jackknife.lowerBound, isCloseTo(3.89192387));
      expect(jackknife.upperBound, isCloseTo(14.44140947));
    });
  });
}
