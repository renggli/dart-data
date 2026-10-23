import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/stats.dart';
import 'package:test/test.dart';

void main() {
  group('WeibullDistribution moments and probabilities', () {
    test('moments, pdf, cdf, and quantile', () {
      final dist = WeibullDistribution(1.0, 1.0);
      check(dist.scale).equals(1.0);
      check(dist.shape).equals(1.0);
      check(dist.lowerBound).equals(0.0);
      check(dist.mean).isCloseTo(1.0, 1e-6);
      check(dist.median).isCloseTo(math.ln2, 1e-6);
      check(dist.mode).equals(0.0);
      check(dist.variance).isCloseTo(1.0, 1e-6);
      check(dist.skewness).isCloseTo(2.0, 1e-5);
      check(dist.excessKurtosis).isCloseTo(6.0, 1e-5);

      final distShape2 = WeibullDistribution(2.0, 1.0);
      check(distShape2.mode).isGreaterThan(0.0);

      check(dist.probability(-1.0)).equals(0.0);
      check(dist.probability(1.0)).isGreaterThan(0.0);
      check(dist.cumulativeProbability(-1.0)).equals(0.0);
      check(dist.cumulativeProbability(0.0)).equals(0.0);
      check(dist.cumulativeProbability(1.0))
          .isCloseTo(1.0 - math.exp(-1.0), 1e-6);
      check(dist.inverseCumulativeProbability(0.5))
          .isCloseTo(dist.median, 1e-6);
      check(() => dist.inverseCumulativeProbability(-0.1))
          .throws<InvalidProbability>();
    });
  });

  group('WeibullDistribution estimation and validation', () {
    test('samples, fit, errors, and equality', () {
      final dist = WeibullDistribution(1.0, 1.0);
      // Samples
      final samples = dist.samples(random: math.Random(42)).take(50).toList();
      check(samples.every((sample) => sample >= 0.0)).isTrue();

      // Constructor validation
      check(() => WeibullDistribution(0.0, 1.0)).throws<ArgumentError>();
      check(() => WeibullDistribution(1.0, 0.0)).throws<ArgumentError>();

      // Equality and toString
      check(dist == WeibullDistribution(1.0, 1.0)).isTrue();
      check(dist.hashCode).equals(WeibullDistribution(1.0, 1.0).hashCode);
      check(dist.toString()).contains('WeibullDistribution');
    });
  });
}
