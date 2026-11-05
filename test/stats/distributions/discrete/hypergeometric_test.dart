import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/stats.dart';
import 'package:test/test.dart';

void main() {
  group('HypergeometricDistribution moments and probabilities', () {
    final dist = HypergeometricDistribution(50, 10, 5);

    test('moments and parameters', () {
      check(dist.populationSize).equals(50);
      check(dist.successStates).equals(10);
      check(dist.draws).equals(5);
      check(dist.lowerBound).equals(0);
      check(dist.upperBound).equals(5);
      check(dist.isLowerBoundOpen).isFalse();
      check(dist.isUpperBoundOpen).isFalse();
      check(dist.mean).equals(1.0);
      check(dist.variance)
          .isCloseTo(5.0 * (10.0 / 50.0) * (40.0 / 50.0) * (45.0 / 49.0), 1e-6);
      check(dist.standardDeviation).isGreaterThan(0.0);
      check(dist.mode).isA<double>();
      check(dist.median).isA<double>();
      check(dist.median).equals(1.0);
      check(HypergeometricDistribution(100, 10, 5).median).equals(0.0);
      check(dist.skewness).isA<double>();
      check(dist.excessKurtosis).isA<double>();
    });

    test('probability mass function', () {
      check(dist.probability(-1)).equals(0.0);
      check(dist.probability(0)).isGreaterThan(0.3);
      check(dist.probability(6)).equals(0.0);
    });

    test('cumulative probability', () {
      check(dist.cumulativeProbability(-1)).equals(0.0);
      check(dist.cumulativeProbability(5)).equals(1.0);
    });

    test('inverse cumulative probability', () {
      check(dist.inverseCumulativeProbability(0.0)).equals(0);
      check(dist.inverseCumulativeProbability(1.0)).equals(5);
      check(() => dist.inverseCumulativeProbability(-0.1))
          .throws<InvalidProbability>();
    });
  });

  group('HypergeometricDistribution estimation and validation', () {
    final dist = HypergeometricDistribution(50, 10, 5);

    test('samples', () {
      final samples = dist.samples(random: math.Random(42)).take(50).toList();
      check(samples.every((sample) => sample >= 0 && sample <= 5)).isTrue();
    });

    test('fit', () {
      final fitted = HypergeometricDistribution.fit(
        const [1, 2, 1],
        populationSize: 50,
        draws: 5,
      );
      check(fitted.populationSize).equals(50);
      check(fitted.draws).equals(5);
      check(fitted.successStates).isGreaterThan(0);
    });

    test('fit errors', () {
      check(() => HypergeometricDistribution.fit(const [], populationSize: 50))
          .throws<ArgumentError>();
      check(
        () => HypergeometricDistribution.fit(const [-1], populationSize: 50),
      ).throws<ArgumentError>();
    });

    test('constructor validation', () {
      check(() => HypergeometricDistribution(0, 5, 2)).throws<ArgumentError>();
      check(() => HypergeometricDistribution(10, -1, 2))
          .throws<ArgumentError>();
      check(() => HypergeometricDistribution(10, 11, 2))
          .throws<ArgumentError>();
      check(() => HypergeometricDistribution(10, 5, -1))
          .throws<ArgumentError>();
      check(() => HypergeometricDistribution(10, 5, 11))
          .throws<ArgumentError>();
    });

    test('string conversion', () {
      check(dist.toString()).contains('HypergeometricDistribution');
    });
  });
}
