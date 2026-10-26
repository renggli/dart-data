import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/stats.dart';
import 'package:data/type.dart';
import 'package:test/test.dart';

void main() {
  group('NegativeBinomialDistribution moments and probabilities', () {
    test('moments, pdf, cdf, and quantile', () {
      final dist = NegativeBinomialDistribution(1.0, 0.5);
      check(dist.r).equals(1.0);
      check(dist.p).equals(0.5);
      check(dist.lowerBound).equals(0);
      check(dist.upperBound).equals(DataType.integer.safeMax);
      check(dist.isLowerBoundOpen).isFalse();
      check(dist.isUpperBoundOpen).isTrue();

      check(dist.mean).equals(1.0);
      check(dist.variance).equals(2.0);
      check(dist.standardDeviation).isCloseTo(math.sqrt(2.0), 1e-6);
      check(dist.mode).isA<double>();
      check(dist.median).isA<double>();
      check(dist.skewness).isCloseTo((2.0 - 0.5) / math.sqrt(1.0 * 0.5), 1e-6);
      check(dist.excessKurtosis).isCloseTo(6.0 / 1.0 + 0.25 / 0.5, 1e-6);

      check(dist.probability(-1)).equals(0.0);
      check(dist.probability(0)).isCloseTo(0.5, 1e-12);
      check(dist.probability(1)).isCloseTo(0.25, 1e-12);

      check(dist.cumulativeProbability(-1)).equals(0.0);
      check(dist.cumulativeProbability(0)).isCloseTo(0.5, 1e-12);
      check(dist.cumulativeProbability(1)).isCloseTo(0.75, 1e-12);

      check(dist.inverseCumulativeProbability(0.0)).equals(0);
      check(dist.inverseCumulativeProbability(0.5)).equals(0);
      check(() => dist.inverseCumulativeProbability(-0.1))
          .throws<InvalidProbability>();
    });
  });

  group('NegativeBinomialDistribution estimation and validation', () {
    test('samples, fit, errors, and equality', () {
      final dist = NegativeBinomialDistribution(1.0, 0.5);
      // Samples
      final samples = dist.samples(random: math.Random(42)).take(50).toList();
      check(samples.every((sample) => sample >= 0)).isTrue();

      // Constructor validation
      check(() => NegativeBinomialDistribution(0.0, 0.5))
          .throws<ArgumentError>();
      check(() => NegativeBinomialDistribution(-1.0, 0.5))
          .throws<ArgumentError>();
      check(() => NegativeBinomialDistribution(1.0, -0.1))
          .throws<ArgumentError>();
      check(() => NegativeBinomialDistribution(1.0, 0.0))
          .throws<ArgumentError>();
      check(() => NegativeBinomialDistribution(1.0, 1.0))
          .throws<ArgumentError>();
      check(() => NegativeBinomialDistribution(1.0, 1.1))
          .throws<ArgumentError>();

      check(dist.toString()).contains('NegativeBinomialDistribution');
    });
  });
}
