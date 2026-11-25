import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/stats.dart';
import 'package:test/scaffolding.dart';

void main() {
  final dist = HypergeometricDistribution(50, 10, 5);

  group('HypergeometricDistribution moments and bounds', () {
    test('parameters, bounds, and moments', () {
      check(dist.populationSize).equals(50);
      check(dist.successStates).equals(10);
      check(dist.draws).equals(5);
      check(dist.lowerBound).equals(0);
      check(dist.upperBound).equals(5);
      check(dist.isLowerBoundOpen).isFalse;
      check(dist.isUpperBoundOpen).isFalse;
      check(dist.mean).equals(1.0);
      check(dist.median).equals(1.0);
      check(dist.mode).equals(1.0);
      check(dist.variance).isCloseTo(5 * 10 * 40 * 45 / (50 * 50 * 49), 1e-12);
      check(dist.standardDeviation).isCloseTo(math.sqrt(dist.variance), 1e-12);
      check(dist.skewness).isGreaterThan(0.0);
      check(dist.excessKurtosis).isLessThan(0.0);
    });

    test('exact excessKurtosis and zero-variance NaN guards', () {
      // N=4, K=2, n=2 => known exact excess kurtosis = 0.0
      final h422 = HypergeometricDistribution(4, 2, 2);
      check(h422.skewness).equals(0.0);
      check(h422.excessKurtosis).isCloseTo(0.0, 1e-12);

      // N=5, K=2, n=2 => exact excess kurtosis = -4/9
      final h522 = HypergeometricDistribution(5, 2, 2);
      check(h522.excessKurtosis).isCloseTo(-4.0 / 9.0, 1e-12);

      // Degenerate zero-variance cases return NaN skewness & excessKurtosis.
      final allSuccess = HypergeometricDistribution(10, 10, 4);
      check(allSuccess.variance).equals(0.0);
      check(allSuccess.skewness.isNaN).isTrue;
      check(allSuccess.excessKurtosis.isNaN).isTrue;

      final popOne = HypergeometricDistribution(1, 1, 1);
      check(popOne.variance).equals(0.0);
      check(popOne.skewness.isNaN).isTrue;
      check(popOne.excessKurtosis.isNaN).isTrue;
    });
  });

  group('HypergeometricDistribution probabilities', () {
    test('probability and logProbability across interior and boundaries', () {
      check(dist.probability(-1)).equals(0.0);
      check(dist.probability(0)).isCloseTo(658008 / 2118760, 1e-12);
      check(dist.probability(1)).isCloseTo(913900 / 2118760, 1e-12);
      check(dist.probability(6)).equals(0.0);

      check(dist.logProbability(-1)).equals(double.negativeInfinity);
      check(dist.logProbability(1))
          .isCloseTo(math.log(dist.probability(1)), 1e-12);
      check(dist.logProbability(6)).equals(double.negativeInfinity);
    });

    test('cumulativeProbability and survival match recurrence sums', () {
      check(dist.cumulativeProbability(-1)).equals(0.0);
      check(dist.cumulativeProbability(0))
          .isCloseTo(dist.probability(0), 1e-12);
      check(dist.cumulativeProbability(2)).isCloseTo(
        dist.probability(0) + dist.probability(1) + dist.probability(2),
        1e-12,
      );
      check(dist.cumulativeProbability(5)).equals(1.0);
      check(dist.cumulativeProbability(6)).equals(1.0);

      check(dist.survival(-1)).equals(1.0);
      check(dist.survival(5)).equals(0.0);
      for (var k = 0; k <= 5; k++) {
        check(dist.cumulativeProbability(k) + dist.survival(k))
            .isCloseTo(1.0, 1e-12);
      }

      // Exercise shorter-tail switch near upperBound on large support.
      final large = HypergeometricDistribution(200, 100, 60);
      check(large.cumulativeProbability(35) + large.survival(35))
          .isCloseTo(1.0, 1e-12);
    });

    test('inverseCumulativeProbability and inverseSurvival', () {
      check(dist.inverseCumulativeProbability(0.0)).equals(0);
      check(dist.inverseCumulativeProbability(0.5)).equals(1);
      check(dist.inverseCumulativeProbability(1.0)).equals(5);
      check(dist.inverseSurvival(1.0)).equals(0);
      check(dist.inverseSurvival(0.5)).equals(1);
      check(dist.inverseSurvival(0.0)).equals(5);

      check(() => dist.inverseCumulativeProbability(-0.1))
          .throws<InvalidProbability>();
      check(() => dist.inverseSurvival(1.1)).throws<InvalidProbability>();
    });
  });

  group('HypergeometricDistribution sampling, fitting, and validation', () {
    test('samples stay within [lowerBound, upperBound] and match mean', () {
      final samples = dist.samples(random: math.Random(42)).take(2000).toList();
      check(samples.every((x) => x >= dist.lowerBound && x <= dist.upperBound))
          .isTrue;
      check(HypergeometricDistribution(4, 3, 4).sample()).equals(3);
      final sampleMean = samples.reduce((a, b) => a + b) / samples.length;
      check(sampleMean).isCloseTo(dist.mean, 0.06);
    });

    test('fit estimates successStates and validates samples and bounds', () {
      final fitted = HypergeometricDistribution.fit(
        const [1, 2, 1, 0, 2],
        populationSize: 50,
        draws: 5,
      );
      check(fitted.populationSize).equals(50);
      check(fitted.draws).equals(5);
      check(fitted.successStates).equals(12);

      final fittedInferredDraws = HypergeometricDistribution.fit(const [
        1,
        2,
        3,
        2,
      ], populationSize: 20);
      check(fittedInferredDraws.draws).equals(3);

      final zeroDrawsFit = HypergeometricDistribution.fit(const [
        0,
        0,
      ], populationSize: 10);
      check(zeroDrawsFit.draws).equals(0);

      check(
        () => HypergeometricDistribution.fit(const [11], populationSize: 10),
      ).throws<ArgumentError>();
      check(
        () => HypergeometricDistribution.fit(
          const [],
          populationSize: 10,
          draws: 5,
        ),
      ).throws<ArgumentError>();
      check(
        () => HypergeometricDistribution.fit(
          const [1, 2],
          populationSize: 0,
          draws: 5,
        ),
      ).throws<ArgumentError>();
      check(
        () => HypergeometricDistribution.fit(
          const [1, 2],
          populationSize: 5,
          draws: 6,
        ),
      ).throws<ArgumentError>();
      check(
        () => HypergeometricDistribution.fit(
          const [-1, 2],
          populationSize: 10,
          draws: 5,
        ),
      ).throws<ArgumentError>();
      check(
        () => HypergeometricDistribution.fit(
          const [1, 6],
          populationSize: 10,
          draws: 5,
        ),
      ).throws<ArgumentError>();
      check(
        () => HypergeometricDistribution.fit(
          const [1.5],
          populationSize: 10,
          draws: 5,
        ),
      ).throws<ArgumentError>();
    });

    test('constructor validation', () {
      check(() => HypergeometricDistribution(0, 0, 0)).throws<ArgumentError>();
      check(() => HypergeometricDistribution(10, -1, 5))
          .throws<ArgumentError>();
      check(() => HypergeometricDistribution(10, 11, 5))
          .throws<ArgumentError>();
      check(() => HypergeometricDistribution(10, 5, -1))
          .throws<ArgumentError>();
      check(() => HypergeometricDistribution(10, 5, 11))
          .throws<ArgumentError>();
    });

    test('equality, hashCode, and string representation', () {
      check(dist == HypergeometricDistribution(50, 10, 5)).isTrue;
      check(dist.hashCode)
          .equals(HypergeometricDistribution(50, 10, 5).hashCode);
      check(dist == HypergeometricDistribution(50, 10, 6)).isFalse;
      check(dist.toString()).contains('HypergeometricDistribution');
    });
  });
}
