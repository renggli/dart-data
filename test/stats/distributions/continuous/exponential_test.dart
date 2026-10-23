import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/stats.dart';
import 'package:test/test.dart';

void main() {
  group('ExponentialDistribution moments and probabilities', () {
    test('moments, pdf, cdf, and quantile', () {
      final dist = ExponentialDistribution(2.0);
      check(dist.rate).equals(2.0);
      check(dist.lowerBound).equals(0.0);
      check(dist.mean).equals(0.5);
      check(dist.median).isCloseTo(math.ln2 / 2.0, 1e-6);
      check(dist.mode).equals(0.0);
      check(dist.variance).equals(0.25);
      check(dist.skewness).equals(2.0);
      check(dist.excessKurtosis).equals(6.0);

      check(dist.probability(-1.0)).equals(0.0);
      check(dist.probability(0.0)).equals(2.0);
      check(dist.cumulativeProbability(-1.0)).equals(0.0);
      check(dist.cumulativeProbability(0.0)).equals(0.0);
      check(dist.cumulativeProbability(0.5))
          .isCloseTo(1.0 - math.exp(-1.0), 1e-6);
      check(dist.inverseCumulativeProbability(0.5))
          .isCloseTo(dist.median, 1e-6);
      check(() => dist.inverseCumulativeProbability(-0.1))
          .throws<InvalidProbability>();
    });
  });

  group('ExponentialDistribution estimation and validation', () {
    test('samples, fit, errors, and equality', () {
      final dist = ExponentialDistribution(2.0);
      // Fit
      final samples = dist.samples(random: math.Random(42)).take(1000).toList();
      final fitted = ExponentialDistribution.fit(samples);
      check(fitted.rate).isCloseTo(2.0, 0.2);
      check(() => ExponentialDistribution.fit(const []))
          .throws<ArgumentError>();
      check(() => ExponentialDistribution.fit(const [-1.0]))
          .throws<ArgumentError>();

      // Constructor validation
      check(() => ExponentialDistribution(0.0)).throws<ArgumentError>();

      // Equality and toString
      check(dist == ExponentialDistribution(2.0)).isTrue();
      check(dist.hashCode).equals(ExponentialDistribution(2.0).hashCode);
      check(dist.toString()).contains('ExponentialDistribution');
    });
  });
}
