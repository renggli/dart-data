import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/stats.dart';
import 'package:test/test.dart';

void main() {
  group('CauchyDistribution moments and probabilities', () {
    test('moments, pdf, cdf, and quantile', () {
      final dist = CauchyDistribution(0.0, 1.0);
      check(dist.location).equals(0.0);
      check(dist.scale).equals(1.0);
      check(dist.mean.isNaN).isTrue();
      check(dist.median).equals(0.0);
      check(dist.mode).equals(0.0);
      check(dist.variance.isNaN).isTrue();
      check(dist.skewness.isNaN).isTrue();
      check(dist.excessKurtosis.isNaN).isTrue();

      check(dist.probability(0.0)).isCloseTo(1.0 / math.pi, 1e-6);
      check(dist.cumulativeProbability(0.0)).isCloseTo(0.5, 1e-6);
      check(dist.inverseCumulativeProbability(0.5)).isCloseTo(0.0, 1e-6);
      check(dist.inverseCumulativeProbability(0.0))
          .equals(double.negativeInfinity);
      check(dist.inverseCumulativeProbability(1.0)).equals(double.infinity);
      check(() => dist.inverseCumulativeProbability(-0.1))
          .throws<InvalidProbability>();

      // Default constructor
      const defaultCauchy = CauchyDistribution.standard();
      check(defaultCauchy.location).equals(0.0);
      check(defaultCauchy.scale).equals(1.0);
    });
  });

  group('CauchyDistribution estimation and validation', () {
    test('samples, fit, errors, and equality', () {
      final dist = CauchyDistribution(0.0, 1.0);
      // Samples
      final samples = dist.samples(random: math.Random(42)).take(50).toList();
      check(samples.isNotEmpty).isTrue();

      // Constructor validation
      check(() => CauchyDistribution(0.0, 0.0)).throws<ArgumentError>();

      // Equality and toString
      check(dist == CauchyDistribution(0.0, 1.0)).isTrue();
      check(dist.hashCode).equals(CauchyDistribution(0.0, 1.0).hashCode);
      check(dist.toString()).contains('CauchyDistribution');
    });
  });
}
