import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/stats.dart';
import 'package:test/test.dart';

void main() {
  group('InverseGammaDistribution moments and probabilities', () {
    test('moments, pdf, cdf, and quantile', () {
      final dist = InverseGammaDistribution(4.0, 6.0);
      check(dist.shape).equals(4.0);
      check(dist.scale).equals(6.0);
      check(dist.lowerBound).equals(0.0);
      check(dist.mean).isCloseTo(2.0, 1e-6);
      check(dist.cumulativeProbability(dist.median)).isCloseTo(0.5, 1e-4);
      check(dist.mode).isCloseTo(1.2, 1e-6);
      check(dist.variance).isCloseTo(2.0, 1e-6);
      check(dist.skewness).isCloseTo(4.0 * math.sqrt(2.0), 1e-6);
      check(dist.excessKurtosis).isA<double>();

      check(dist.probability(-1.0)).equals(0.0);
      check(dist.probability(0.0)).equals(0.0);
      check(dist.probability(1.2)).isGreaterThan(0.0);
      check(dist.cumulativeProbability(-1.0)).equals(0.0);
      check(dist.cumulativeProbability(0.0)).equals(0.0);

      // Moments edge cases for small shape
      final distSmall1 = InverseGammaDistribution(0.5, 1.0);
      check(distSmall1.mean.isNaN).isTrue();
      check(distSmall1.variance.isNaN).isTrue();
      check(distSmall1.skewness.isNaN).isTrue();
      check(distSmall1.excessKurtosis.isNaN).isTrue();

      final distSmall2 = InverseGammaDistribution(1.5, 1.0);
      check(distSmall2.mean).isGreaterThan(0.0);
      check(distSmall2.variance.isNaN).isTrue();

      final distSmall3 = InverseGammaDistribution(2.5, 1.0);
      check(distSmall3.variance).isGreaterThan(0.0);
      check(distSmall3.skewness.isNaN).isTrue();

      final distSmall4 = InverseGammaDistribution(3.5, 1.0);
      check(distSmall4.skewness).isGreaterThan(0.0);
      check(distSmall4.excessKurtosis.isNaN).isTrue();

      const prob = 0.5;
      final quant = dist.inverseCumulativeProbability(prob);
      check(dist.cumulativeProbability(quant)).isCloseTo(prob, 1e-5);
      check(() => dist.inverseCumulativeProbability(-0.1))
          .throws<InvalidProbability>();
    });
  });

  group('InverseGammaDistribution estimation and validation', () {
    test('samples, fit, errors, and equality', () {
      final dist = InverseGammaDistribution(4.0, 6.0);
      // Samples
      final samples = dist.samples(random: math.Random(42)).take(50).toList();
      check(samples.every((sample) => sample > 0)).isTrue();

      // Constructor validation
      check(() => InverseGammaDistribution(0.0, 1.0)).throws<ArgumentError>();
      check(() => InverseGammaDistribution(1.0, 0.0)).throws<ArgumentError>();

      // Equality and toString
      check(dist == InverseGammaDistribution(4.0, 6.0)).isTrue();
      check(dist.hashCode).equals(InverseGammaDistribution(4.0, 6.0).hashCode);
      check(dist.toString()).contains('InverseGammaDistribution');
    });
  });
}
