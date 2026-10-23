import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/stats.dart';
import 'package:test/test.dart';

void main() {
  group('NormalDistribution moments and probabilities', () {
    test('moments, pdf, cdf, and quantile', () {
      const dist = NormalDistribution.standard();
      check(dist.mean).equals(0.0);
      check(dist.standardDeviation).equals(1.0);
      check(dist.variance).equals(1.0);
      check(dist.median).equals(0.0);
      check(dist.mode).equals(0.0);
      check(dist.skewness).equals(0.0);
      check(dist.excessKurtosis).equals(0.0);
      check(dist.excessKurtosis).equals(0.0);
      check(dist.lowerBound).equals(double.negativeInfinity);
      check(dist.upperBound).equals(double.infinity);
      check(dist.isLowerBoundOpen).isTrue();
      check(dist.isUpperBoundOpen).isTrue();

      // PDF at x = 0 is 1 / sqrt(2*pi) ≈ 0.39894228
      check(dist.probability(0.0))
          .isCloseTo(1.0 / math.sqrt(2 * math.pi), 1e-6);
      check(dist.cumulativeProbability(0.0)).isCloseTo(0.5, 1e-6);
      check(dist.cumulativeProbability(1.96))
          .isCloseTo(0.9750021048517795, 1e-12);
      check(dist.cumulativeProbability(-10.0)).isGreaterThan(0.0);
      check(dist.survival(0.0)).isCloseTo(0.5, 1e-6);
      check(dist.survival(1.96)).isCloseTo(1.0 - 0.9750021048517795, 1e-12);
      check(dist.survival(10.0)).isGreaterThan(0.0);
      check(dist.inverseCumulativeProbability(0.5)).isCloseTo(0.0, 1e-6);
      check(dist.inverseSurvival(0.5)).isCloseTo(0.0, 1e-6);
      check(dist.inverseCumulativeProbability(0.975)).isCloseTo(1.95996, 1e-4);
      check(dist.inverseCumulativeProbability(0.025)).isCloseTo(-1.95996, 1e-4);
      // Deep tail quantiles do not floor at -infinity
      check(dist.inverseCumulativeProbability(1e-20).isFinite).isTrue();
      check(dist.inverseCumulativeProbability(1e-20)).isLessThan(-8.0);
      check(dist.inverseSurvival(1e-20).isFinite).isTrue();
      check(dist.inverseSurvival(1e-20)).isGreaterThan(8.0);
      check(() => dist.inverseCumulativeProbability(-0.1))
          .throws<InvalidProbability>();
      check(() => dist.inverseCumulativeProbability(1.1))
          .throws<InvalidProbability>();
    });
  });

  group('NormalDistribution estimation and validation', () {
    test('samples, fit, errors, and equality', () {
      const dist = NormalDistribution.standard();
      // Sample & fit
      final samples = dist.samples(random: math.Random(42)).take(1000).toList();
      final fitted = NormalDistribution.fit(samples);
      check(fitted.mean).isCloseTo(0.0, 0.1);
      check(fitted.standardDeviation).isCloseTo(1.0, 0.1);

      // Fit identical samples
      final fittedSame = NormalDistribution.fit(const [5.0, 5.0]);
      check(fittedSame.mean).equals(5.0);

      // Fit error
      check(() => NormalDistribution.fit(const [1.0])).throws<ArgumentError>();

      // Constructor validation
      check(() => NormalDistribution(0.0, 0.0)).throws<ArgumentError>();
      check(() => NormalDistribution(0.0, -1.0)).throws<ArgumentError>();

      // Equality and toString
      final dist2 = NormalDistribution(0.0, 1.0);
      check(dist == dist2).isTrue();
      check(dist.hashCode).equals(dist2.hashCode);
      check(dist.toString()).contains('NormalDistribution');
    });
  });
}
