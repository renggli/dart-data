import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/stats.dart';
import 'package:test/test.dart';

void main() {
  group('BernoulliDistribution moments and probabilities', () {
    test('moments, pdf, cdf, and quantile', () {
      final dist = BernoulliDistribution(0.7);
      check(dist.p).equals(0.7);
      check(dist.lowerBound).equals(0);
      check(dist.upperBound).equals(1);
      check(dist.isLowerBoundOpen).isFalse();
      check(dist.isUpperBoundOpen).isFalse();

      check(dist.mean).equals(0.7);
      check(dist.median).equals(1.0);
      check(dist.mode).equals(1.0);
      check(dist.variance).isCloseTo(0.21, 1e-6);
      check(dist.standardDeviation).isCloseTo(math.sqrt(0.21), 1e-6);
      check(dist.skewness).isCloseTo((1 - 2 * 0.7) / math.sqrt(0.21), 1e-6);
      check(dist.excessKurtosis).isCloseTo((1 - 6 * 0.7 * 0.3) / 0.21, 1e-6);
      check(dist.excessKurtosis).equals(dist.excessKurtosis);

      // Quantile and CDF
      check(dist.inverseCumulativeProbability(0.0)).equals(0);
      check(dist.inverseCumulativeProbability(0.29)).equals(0);
      check(dist.inverseCumulativeProbability(0.31)).equals(1);
      check(dist.inverseCumulativeProbability(1.0)).equals(1);
      check(() => dist.inverseCumulativeProbability(-0.1))
          .throws<InvalidProbability>();
      check(() => dist.inverseCumulativeProbability(1.1))
          .throws<InvalidProbability>();

      check(dist.probability(-1)).equals(0.0);
      check(dist.probability(0)).isCloseTo(0.3, 1e-6);
      check(dist.probability(1)).isCloseTo(0.7, 1e-6);
      check(dist.probability(2)).equals(0.0);

      check(dist.cumulativeProbability(-1)).equals(0.0);
      check(dist.cumulativeProbability(0)).isCloseTo(0.3, 1e-6);
      check(dist.cumulativeProbability(1)).equals(1.0);
      check(dist.cumulativeProbability(2)).equals(1.0);

      // Median for p < 0.5 and p == 0.5
      final distLow = BernoulliDistribution(0.3);
      check(distLow.median).equals(0.0);
      check(distLow.mode).equals(0.0);

      final distHalf = BernoulliDistribution(0.5);
      check(distHalf.median).equals(0.5);
    });
  });

  group('BernoulliDistribution estimation and validation', () {
    test('samples, fit, errors, and equality', () {
      final dist = BernoulliDistribution(0.7);
      // Samples
      final samples = dist.samples(random: math.Random(42)).take(100).toList();
      check(samples.every((sample) => sample == 0 || sample == 1)).isTrue();

      // Fit
      final fitted = BernoulliDistribution.fit(const [
        1,
        1,
        1,
        0,
        1,
        0,
        1,
        1,
        0,
        1,
      ]);
      check(fitted.p).isCloseTo(0.7, 1e-6);
      check(() => BernoulliDistribution.fit(const [])).throws<ArgumentError>();
      check(() => BernoulliDistribution.fit(const [0, 2]))
          .throws<ArgumentError>();

      // Constructor validation
      check(() => BernoulliDistribution(-0.1)).throws<ArgumentError>();
      check(() => BernoulliDistribution(1.1)).throws<ArgumentError>();

      // toString
      check(dist.toString()).contains('BernoulliDistribution');
    });
  });
}
