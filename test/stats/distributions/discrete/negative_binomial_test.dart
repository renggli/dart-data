import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/stats.dart';
import 'package:data/type.dart';
import 'package:test/scaffolding.dart';

void main() {
  final dist = NegativeBinomialDistribution(2.0, 0.5);

  group('NegativeBinomialDistribution moments and bounds', () {
    test('parameters, bounds, and moments', () {
      check(dist.r).equals(2.0);
      check(dist.p).equals(0.5);
      check(dist.q).equals(0.5);
      check(dist.lowerBound).equals(0);
      check(dist.upperBound).equals(DataType.integer.safeMax);
      check(dist.isLowerBoundOpen).isFalse;
      check(dist.isUpperBoundOpen).isTrue;
      check(dist.mean).equals(2.0);
      check(dist.variance).equals(4.0);
      check(dist.standardDeviation).equals(2.0);
      check(dist.mode).equals(1.0);
      check(NegativeBinomialDistribution(0.5, 0.5).mode).equals(0.0);
      check(dist.median).equals(1.0);
      check(dist.skewness).isCloseTo(1.5, 1e-12);
      check(dist.excessKurtosis).isCloseTo(3.25, 1e-12);
    });
  });

  group('NegativeBinomialDistribution probabilities', () {
    test('probability and logProbability across support and outside', () {
      check(dist.probability(-1)).equals(0.0);
      check(dist.probability(0)).isCloseTo(0.25, 1e-12);
      check(dist.probability(1)).isCloseTo(0.25, 1e-12);
      check(dist.logProbability(-1)).equals(double.negativeInfinity);
      check(dist.logProbability(0)).isCloseTo(math.log(0.25), 1e-12);
      check(dist.logProbability(1)).isCloseTo(math.log(0.25), 1e-12);
    });

    test('cumulativeProbability and survival are complementary', () {
      check(dist.cumulativeProbability(-1)).equals(0.0);
      check(dist.cumulativeProbability(0)).isCloseTo(0.25, 1e-12);
      check(dist.cumulativeProbability(1)).isCloseTo(0.5, 1e-12);
      check(dist.survival(-1)).equals(1.0);
      check(dist.survival(0)).isCloseTo(0.75, 1e-12);
      check(dist.survival(1)).isCloseTo(0.5, 1e-12);
      check(dist.cumulativeProbability(4) + dist.survival(4))
          .isCloseTo(1.0, 1e-13);
    });

    test('inverseCumulativeProbability and inverseSurvival', () {
      check(dist.inverseCumulativeProbability(0.0)).equals(0);
      check(dist.inverseCumulativeProbability(0.25)).equals(0);
      check(dist.inverseCumulativeProbability(0.5)).equals(1);
      check(dist.inverseCumulativeProbability(1.0))
          .equals(DataType.integer.safeMax);

      check(dist.inverseSurvival(1.0)).equals(0);
      check(dist.inverseSurvival(0.5)).equals(1);
      check(dist.inverseSurvival(0.0)).equals(DataType.integer.safeMax);

      check(() => dist.inverseCumulativeProbability(-0.1))
          .throws<InvalidProbability>();
      check(() => dist.inverseSurvival(1.1)).throws<InvalidProbability>();
    });
  });

  group('NegativeBinomialDistribution sampling, fitting, and validation', () {
    test('samples stay non-negative and match theoretical mean', () {
      check(dist.sample() >= 0).isTrue;
      final samples = dist.samples(random: math.Random(42)).take(2000).toList();
      check(samples.every((x) => x >= 0)).isTrue;
      final sampleMean = samples.reduce((a, b) => a + b) / samples.length;
      check(sampleMean).isCloseTo(2.0, 0.2);
    });

    test('fit handles both specified r and method-of-moments estimation', () {
      // Overdispersed samples (variance > mean) for method-of-moments fit.
      final momFit = NegativeBinomialDistribution.fit(const [0, 0, 1, 5, 10]);
      check(momFit.r).isGreaterThan(0.0);
      check(momFit.p).isGreaterThan(0.0);
      check(momFit.p).isLessThan(1.0);

      // Underdispersed samples trigger variance <= mean fallback to r = 1.0.
      final underFit = NegativeBinomialDistribution.fit(const [1, 2, 3]);
      check(underFit.r).equals(1.0);
      check(underFit.p).isCloseTo(2.0 / 3.0, 1e-12);

      // Fixed r fit.
      final fixedFit = NegativeBinomialDistribution.fit(const [
        1,
        2,
        3,
      ], r: 4.0);
      check(fixedFit.r).equals(4.0);
      check(fixedFit.p).isCloseTo(2.0 / 6.0, 1e-12);

      check(() => NegativeBinomialDistribution.fit(const []))
          .throws<ArgumentError>();
      check(() => NegativeBinomialDistribution.fit(const [-1, 2]))
          .throws<ArgumentError>();
      check(() => NegativeBinomialDistribution.fit(const [0.5, 2]))
          .throws<ArgumentError>();
      check(() => NegativeBinomialDistribution.fit(const [1, 2], r: 0))
          .throws<ArgumentError>();

      final zeroFit = NegativeBinomialDistribution.fit(const [0, 0]);
      check(zeroFit.r).equals(1.0);
      check(zeroFit.p).equals(1e-6);
    });

    test('constructor validation', () {
      check(() => NegativeBinomialDistribution(0.0, 0.5))
          .throws<ArgumentError>();
      check(() => NegativeBinomialDistribution(-1.0, 0.5))
          .throws<ArgumentError>();
      check(() => NegativeBinomialDistribution(1.0, 0.0))
          .throws<ArgumentError>();
      check(() => NegativeBinomialDistribution(1.0, 1.0))
          .throws<ArgumentError>();
      check(() => NegativeBinomialDistribution(1.0, double.nan))
          .throws<ArgumentError>();
    });

    test('equality, hashCode, and string representation', () {
      check(dist == NegativeBinomialDistribution(2.0, 0.5)).isTrue;
      check(dist.hashCode)
          .equals(NegativeBinomialDistribution(2.0, 0.5).hashCode);
      check(dist == NegativeBinomialDistribution(1.0, 0.5)).isFalse;
      check(dist.toString()).contains('NegativeBinomialDistribution');
    });
  });
}
