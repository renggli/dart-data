import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/stats.dart';
import 'package:test/test.dart';

void main() {
  group('LaplaceDistribution moments and probabilities', () {
    test('moments, pdf, cdf, and quantile', () {
      final dist = LaplaceDistribution(0.0, 1.0);
      check(dist.location).equals(0.0);
      check(dist.scale).equals(1.0);
      check(dist.mean).equals(0.0);
      check(dist.median).equals(0.0);
      check(dist.mode).equals(0.0);
      check(dist.variance).equals(2.0);
      check(dist.skewness).equals(0.0);
      check(dist.excessKurtosis).equals(3.0);

      check(dist.probability(0.0)).equals(0.5);
      check(dist.cumulativeProbability(0.0)).equals(0.5);
      check(dist.cumulativeProbability(-1.0))
          .isCloseTo(0.5 * math.exp(-1.0), 1e-6);
      check(dist.cumulativeProbability(1.0))
          .isCloseTo(1.0 - 0.5 * math.exp(-1.0), 1e-6);

      check(dist.inverseCumulativeProbability(0.5)).equals(0.0);
      check(dist.inverseCumulativeProbability(0.0))
          .equals(double.negativeInfinity);
      check(dist.inverseCumulativeProbability(1.0)).equals(double.infinity);
      check(dist.inverseCumulativeProbability(0.25)).isLessThan(0.0);
      check(dist.inverseCumulativeProbability(0.75)).isGreaterThan(0.0);
      check(() => dist.inverseCumulativeProbability(-0.1))
          .throws<InvalidProbability>();

      // Default constructor
      const defaultLaplace = LaplaceDistribution.standard();
      check(defaultLaplace.location).equals(0.0);
      check(defaultLaplace.scale).equals(1.0);
    });
  });

  group('LaplaceDistribution estimation and validation', () {
    test('samples, fit, errors, and equality', () {
      final dist = LaplaceDistribution(0.0, 1.0);
      // Samples
      final samples = dist.samples(random: math.Random(42)).take(50).toList();
      check(samples.isNotEmpty).isTrue();

      // Constructor validation
      check(() => LaplaceDistribution(0.0, 0.0)).throws<ArgumentError>();

      // Equality and toString
      check(dist == LaplaceDistribution(0.0, 1.0)).isTrue();
      check(dist.hashCode).equals(LaplaceDistribution(0.0, 1.0).hashCode);
      check(dist.toString()).contains('LaplaceDistribution');
    });
  });
}
