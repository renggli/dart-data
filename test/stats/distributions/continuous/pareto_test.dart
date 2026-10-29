import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/stats.dart';
import 'package:test/test.dart';

void main() {
  group('ParetoDistribution moments and probabilities', () {
    test('moments, pdf, cdf, and quantile', () {
      final dist = ParetoDistribution(3.0, 1.0);
      check(dist.scale).equals(1.0);
      check(dist.shape).equals(3.0);
      check(dist.lowerBound).equals(1.0);
      check(dist.mean).isCloseTo(1.5, 1e-6);
      check(dist.median).isCloseTo(math.pow(2.0, 1.0 / 3.0), 1e-6);
      check(dist.mode).equals(1.0);
      check(dist.variance).isCloseTo(3.0 / 4.0, 1e-6);
      check(dist.skewness.isNaN).isTrue(); // shape <= 3 gives nan
      check(dist.excessKurtosis.isNaN).isTrue(); // shape <= 4 gives nan

      // Edge moments
      final distAlpha1 = ParetoDistribution(1.0, 1.0);
      check(distAlpha1.mean.isInfinite).isTrue();
      check(distAlpha1.variance.isNaN).isTrue();

      final distAlpha2 = ParetoDistribution(1.5, 1.0);
      check(distAlpha2.variance.isInfinite).isTrue();

      final distAlpha5 = ParetoDistribution(5.0, 1.0);
      check(distAlpha5.skewness).isGreaterThan(0.0);
      check(distAlpha5.excessKurtosis).isGreaterThan(0.0);

      check(dist.probability(0.5)).equals(0.0);
      check(dist.probability(1.0)).equals(3.0);
      check(dist.cumulativeProbability(0.5)).equals(0.0);
      check(dist.cumulativeProbability(1.0)).equals(0.0);
      check(dist.cumulativeProbability(2.0)).isCloseTo(1.0 - 1.0 / 8.0, 1e-6);
      check(dist.inverseCumulativeProbability(0.5))
          .isCloseTo(math.pow(2.0, 1.0 / 3.0), 1e-6);
      check(() => dist.inverseCumulativeProbability(-0.1))
          .throws<InvalidProbability>();
    });

    test('Pareto probability and logProbability with large shape do not evaluate to NaN', () {
      final dist = ParetoDistribution(500.0, 10.0);
      final p = dist.probability(15.0);
      check(p.isNaN).isFalse();
      final logP = dist.logProbability(15.0);
      check(logP.isNaN).isFalse();
    });
  });

  group('ParetoDistribution estimation and validation', () {
    test('samples, fit, errors, and equality', () {
      final dist = ParetoDistribution(3.0, 1.0);
      // Samples
      final samples = dist.samples(random: math.Random(42)).take(50).toList();
      check(samples.every((sample) => sample >= 1.0)).isTrue();

      // Constructor validation
      check(() => ParetoDistribution(0.0, 1.0)).throws<ArgumentError>();
      check(() => ParetoDistribution(1.0, 0.0)).throws<ArgumentError>();

      // Equality and toString
      check(dist == ParetoDistribution(3.0, 1.0)).isTrue();
      check(dist.hashCode).equals(ParetoDistribution(3.0, 1.0).hashCode);
      check(dist.toString()).contains('ParetoDistribution');
    });
  });
}
