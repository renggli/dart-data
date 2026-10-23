import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/stats.dart';
import 'package:test/test.dart';

void main() {
  group('HypergeometricDistribution moments and probabilities', () {
    test('moments, pdf, cdf, and quantile', () {
      final dist = HypergeometricDistribution(50, 10, 5);
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
      check(dist.skewness).isA<double>();
      check(dist.excessKurtosis).isA<double>();

      check(dist.probability(-1)).equals(0.0);
      check(dist.probability(0)).isGreaterThan(0.3);
      check(dist.probability(6)).equals(0.0);

      check(dist.cumulativeProbability(-1)).equals(0.0);
      check(dist.cumulativeProbability(5)).equals(1.0);

      check(dist.inverseCumulativeProbability(0.0)).equals(0);
      check(dist.inverseCumulativeProbability(1.0)).equals(5);
      check(() => dist.inverseCumulativeProbability(-0.1))
          .throws<InvalidProbability>();
    });
  });

  group('HypergeometricDistribution estimation and validation', () {
    test('samples, fit, errors, and equality', () {
      final dist = HypergeometricDistribution(50, 10, 5);
      // Samples
      final samples = dist.samples(random: math.Random(42)).take(50).toList();
      check(samples.every((sample) => sample >= 0 && sample <= 5)).isTrue();

      // Constructor validation
      check(() => HypergeometricDistribution(0, 5, 2)).throws<ArgumentError>();
      check(() => HypergeometricDistribution(10, -1, 2))
          .throws<ArgumentError>();
      check(() => HypergeometricDistribution(10, 11, 2))
          .throws<ArgumentError>();
      check(() => HypergeometricDistribution(10, 5, -1))
          .throws<ArgumentError>();
      check(() => HypergeometricDistribution(10, 5, 11))
          .throws<ArgumentError>();

      check(dist.toString()).contains('HypergeometricDistribution');
    });
  });
}
