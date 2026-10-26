import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/stats.dart';
import 'package:test/test.dart';

void main() {
  group('LogNormalDistribution moments and probabilities', () {
    test('moments, pdf, cdf, and quantile', () {
      final dist = LogNormalDistribution(0.0, 1.0);
      check(dist.mu).equals(0.0);
      check(dist.sigma).equals(1.0);
      check(dist.lowerBound).equals(0.0);
      check(dist.mean).isCloseTo(math.exp(0.5), 1e-6);
      check(dist.median).equals(1.0);
      check(dist.mode).isCloseTo(math.exp(-1.0), 1e-6);
      check(dist.variance).isCloseTo((math.e - 1.0) * math.e, 1e-6);
      check(dist.skewness).isGreaterThan(0.0);
      check(dist.excessKurtosis).isGreaterThan(0.0);

      check(dist.probability(-1.0)).equals(0.0);
      check(dist.probability(0.0)).equals(0.0);
      check(dist.probability(1.0)).isGreaterThan(0.0);
      check(dist.cumulativeProbability(-1.0)).equals(0.0);
      check(dist.cumulativeProbability(1.0)).isCloseTo(0.5, 1e-6);
      check(dist.inverseCumulativeProbability(0.5)).isCloseTo(1.0, 1e-6);
      check(() => dist.inverseCumulativeProbability(-0.1))
          .throws<InvalidProbability>();
    });
  });

  group('LogNormalDistribution estimation and validation', () {
    test('samples, fit, errors, and equality', () {
      final dist = LogNormalDistribution(0.0, 1.0);
      // Samples
      final sample = dist.sample(random: math.Random(42));
      check(sample).isGreaterThan(0.0);

      // Constructor validation
      check(() => LogNormalDistribution(0.0, 0.0)).throws<ArgumentError>();

      // Equality and toString
      check(dist == LogNormalDistribution(0.0, 1.0)).isTrue();
      check(dist.hashCode).equals(LogNormalDistribution(0.0, 1.0).hashCode);
      check(dist.toString()).contains('LogNormalDistribution');
    });
  });
}
