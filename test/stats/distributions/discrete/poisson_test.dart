import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/stats.dart';
import 'package:data/type.dart';
import 'package:test/test.dart';

void main() {
  group('PoissonDistribution moments and probabilities', () {
    test('moments, pdf, cdf, and quantile', () {
      final dist = PoissonDistribution(4.0);
      check(dist.rate).equals(4.0);
      check(dist.lowerBound).equals(0);
      check(dist.upperBound).equals(DataType.integer.safeMax);
      check(dist.isLowerBoundOpen).isFalse();
      check(dist.isUpperBoundOpen).isTrue();

      check(dist.mean).equals(4.0);
      check(dist.variance).equals(4.0);
      check(dist.standardDeviation).equals(2.0);
      check(dist.mode).equals(4.0);
      check(dist.skewness).equals(0.5);
      check(dist.excessKurtosis).equals(0.25);
      check(dist.median).isA<double>();

      check(dist.probability(-1)).equals(0.0);
      check(dist.probability(0)).isCloseTo(math.exp(-4.0), 1e-6);
      check(dist.cumulativeProbability(-1)).equals(0.0);
      check(dist.cumulativeProbability(0)).isCloseTo(math.exp(-4.0), 1e-6);
      check(dist.cumulativeProbability(4)).isGreaterThan(0.5);

      check(dist.inverseCumulativeProbability(0.0)).equals(0);
      check(dist.inverseCumulativeProbability(0.99)).isGreaterThan(5);
      check(() => dist.inverseCumulativeProbability(-0.1))
          .throws<InvalidProbability>();
    });
  });

  group('PoissonDistribution estimation and validation', () {
    test('samples, fit, errors, and equality', () {
      final dist = PoissonDistribution(4.0);
      // Samples
      final samples = dist.samples(random: math.Random(42)).take(50).toList();
      check(samples.every((sample) => sample >= 0)).isTrue();

      // Fit
      final fitted = PoissonDistribution.fit(samples);
      check(fitted.rate).isCloseTo(4.0, 0.5);
      check(() => PoissonDistribution.fit(const [])).throws<ArgumentError>();
      check(() => PoissonDistribution.fit(const [-1])).throws<ArgumentError>();

      // Constructor validation
      check(() => PoissonDistribution(0.0)).throws<ArgumentError>();
      check(() => PoissonDistribution(-2.0)).throws<ArgumentError>();

      check(dist.toString()).contains('PoissonDistribution');
    });
  });
}
