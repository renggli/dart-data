import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/stats.dart';
import 'package:test/scaffolding.dart';

void main() {
  final dist = FDistribution(10.0, 12.0);

  group('FDistribution moments and bounds', () {
    test('parameters and support bounds across d1 <= 2 and d1 > 2', () {
      check(dist.d1).equals(10.0);
      check(dist.d2).equals(12.0);
      check(dist.lowerBound).equals(0.0);
      check(dist.upperBound).equals(double.infinity);
      check(dist.isLowerBoundOpen).isFalse;
      check(dist.isUpperBoundOpen).isTrue;
      check(FDistribution(2.0, 5.0).isLowerBoundOpen).isFalse;
      check(dist.mode).isCloseTo((8.0 / 10.0) * (12.0 / 14.0), 1e-12);
      check(FDistribution(2.0, 12.0).mode).equals(0.0);
      check(dist.median).isCloseTo(0.988563, 1e-5);
    });

    test('moments across degree-of-freedom thresholds', () {
      check(dist.mean).isCloseTo(12.0 / 10.0, 1e-12);
      check(dist.variance).isCloseTo(0.72, 1e-12);
      check(dist.standardDeviation).isCloseTo(math.sqrt(0.72), 1e-12);
      check(dist.skewness).isCloseTo(2.0 * math.sqrt(2.0), 1e-12);
      check(dist.excessKurtosis).isCloseTo(21.0, 1e-12);

      check(FDistribution(5.0, 2.0).mean.isNaN).isTrue;
      check(FDistribution(5.0, 4.0).variance.isNaN).isTrue;
      check(FDistribution(5.0, 6.0).skewness.isNaN).isTrue;
      check(FDistribution(5.0, 8.0).excessKurtosis.isNaN).isTrue;
    });
  });

  group('FDistribution probabilities', () {
    test('probability and logProbability handle boundary and huge x', () {
      check(dist.probability(-1.0)).equals(0.0);
      check(dist.probability(0.0)).equals(0.0);
      check(dist.logProbability(0.0)).equals(double.negativeInfinity);
      check(FDistribution(2.0, 5.0).probability(0.0)).equals(1.0);
      check(FDistribution(1.0, 5.0).probability(0.0)).equals(double.infinity);
      check(dist.probability(1.0)).isCloseTo(0.6438853328592812, 1e-12);
      check(dist.logProbability(1.0))
          .isCloseTo(math.log(dist.probability(1.0)), 1e-12);

      // Overflow-safe evaluation when d1 * x is huge.
      check(dist.probability(1e100)).equals(0.0);
      final logHuge = dist.logProbability(1e100);
      check(logHuge.isFinite).isTrue;
      check(logHuge.isNegative).isTrue;
      check(dist.probability(double.nan).isNaN).isTrue;
    });

    test('cumulativeProbability and survival remain overflow-safe and complementary', () {
      check(dist.cumulativeProbability(-1.0)).equals(0.0);
      check(dist.cumulativeProbability(0.0)).equals(0.0);
      check(dist.survival(0.0)).equals(1.0);
      check(dist.cumulativeProbability(1e100)).equals(1.0);
      check(dist.survival(1e100)).equals(0.0);
      check(dist.survival(20.0)).isGreaterThan(0.0);
      check(dist.cumulativeProbability(2.0) + dist.survival(2.0))
          .isCloseTo(1.0, 1e-13);
      check(dist.cumulativeProbability(double.nan).isNaN).isTrue;
      check(dist.survival(double.nan).isNaN).isTrue;
    });

    test('inverseCumulativeProbability and inverseSurvival round-trips', () {
      check(dist.inverseCumulativeProbability(0.0)).equals(0.0);
      check(dist.inverseCumulativeProbability(1.0)).equals(double.infinity);
      check(dist.inverseSurvival(1.0)).equals(0.0);
      check(dist.inverseSurvival(0.0)).equals(double.infinity);

      for (final p in const [1e-4, 0.05, 0.5, 0.95]) {
        final x = dist.inverseCumulativeProbability(p);
        check(dist.cumulativeProbability(x)).isCloseTo(p, 1e-10);
        final xs = dist.inverseSurvival(p);
        check(dist.survival(xs)).isCloseTo(p, 1e-10);
      }

      check(() => dist.inverseCumulativeProbability(-0.1))
          .throws<InvalidProbability>();
      check(() => dist.inverseSurvival(1.1)).throws<InvalidProbability>();
    });
  });

  group('FDistribution sampling, fitting, and validation', () {
    test('samples match theoretical mean', () {
      final samples = dist.samples(random: math.Random(42)).take(2000).toList();
      final sampleMean = samples.reduce((a, b) => a + b) / samples.length;
      check(sampleMean).isCloseTo(dist.mean, 0.1);
      check(samples.every((x) => x > 0.0)).isTrue;
    });

    test('fit estimates degrees of freedom and validates inputs', () {
      final fitted = FDistribution.fit(
        dist.samples(random: math.Random(7)).take(3000),
      );
      check(fitted.d1).isCloseTo(10.0, 4.0);
      check(fitted.d2).isCloseTo(12.0, 4.0);

      check(() => FDistribution.fit(const [])).throws<ArgumentError>();
      check(() => FDistribution.fit(const [1.0])).throws<ArgumentError>();
      check(() => FDistribution.fit(const [-1.0, 2.0])).throws<ArgumentError>();
      // Mean <= 1.0 causes d2 <= 2 fallback failure.
      check(() => FDistribution.fit(const [0.2, 0.5, 0.8]))
          .throws<ArgumentError>();
      // Constant samples > 1 produce huge d2 and negative variance ratio.
      check(() => FDistribution.fit(const [2.0, 2.0, 2.0]))
          .throws<ArgumentError>();
    });

    test('constructor validation', () {
      check(() => FDistribution(0.0, 5.0)).throws<ArgumentError>();
      check(() => FDistribution(5.0, 0.0)).throws<ArgumentError>();
      check(() => FDistribution(-1.0, 5.0)).throws<ArgumentError>();
      check(() => FDistribution(5.0, double.infinity)).throws<ArgumentError>();
    });

    test('equality, hashCode, and string representation', () {
      check(dist == FDistribution(10.0, 12.0)).isTrue;
      check(dist.hashCode).equals(FDistribution(10.0, 12.0).hashCode);
      check(dist == FDistribution(10.0, 10.0)).isFalse;
      check(dist.toString()).contains('FDistribution');
    });
  });
}
