import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/stats.dart';
import 'package:test/test.dart';

void main() {
  group('BinomialDistribution moments and probabilities', () {
    test('moments, pdf, cdf, and quantile', () {
      final dist = BinomialDistribution(10, 0.5);
      check(dist.n).equals(10);
      check(dist.p).equals(0.5);
      check(dist.lowerBound).equals(0);
      check(dist.upperBound).equals(10);
      check(dist.isLowerBoundOpen).isFalse();
      check(dist.isUpperBoundOpen).isFalse();

      check(dist.mean).equals(5.0);
      check(dist.median).equals(5.0);
      check(dist.mode).equals(5.0);
      check(dist.variance).equals(2.5);
      check(dist.standardDeviation).isCloseTo(math.sqrt(2.5), 1e-6);
      check(dist.skewness).equals(0.0);
      check(dist.excessKurtosis).isCloseTo((1.0 - 6.0 * 0.5 * 0.5) / 2.5, 1e-6);

      check(dist.probability(-1)).equals(0.0);
      check(dist.probability(5)).isCloseTo(252.0 / 1024.0, 1e-6);
      check(dist.probability(11)).equals(0.0);

      check(dist.cumulativeProbability(-1)).equals(0.0);
      check(dist.cumulativeProbability(0)).isCloseTo(1.0 / 1024.0, 1e-6);
      check(dist.cumulativeProbability(10)).equals(1.0);
      check(dist.cumulativeProbability(11)).equals(1.0);

      check(dist.inverseCumulativeProbability(0.0)).equals(0);
      check(dist.inverseCumulativeProbability(0.5)).equals(5);
      check(dist.inverseCumulativeProbability(1.0)).equals(10);
      check(() => dist.inverseCumulativeProbability(-0.1))
          .throws<InvalidProbability>();

      // Degenerate p = 0 and p = 1
      final dist0 = BinomialDistribution(5, 0.0);
      check(dist0.probability(0)).equals(1.0);
      check(dist0.probability(1)).equals(0.0);

      final dist1 = BinomialDistribution(5, 1.0);
      check(dist1.probability(5)).equals(1.0);
      check(dist1.probability(4)).equals(0.0);
    });
  });

  group('BinomialDistribution estimation and validation', () {
    test('samples, fit, errors, and equality', () {
      final dist = BinomialDistribution(10, 0.5);
      // Samples
      final samples = dist.samples(random: math.Random(42)).take(50).toList();
      check(samples.every((sample) => sample >= 0 && sample <= 10)).isTrue();

      // Fit
      final fitted = BinomialDistribution.fit(samples, n: 10);
      check(fitted.n).equals(10);
      check(fitted.p).isCloseTo(0.5, 0.1);
      check(() => BinomialDistribution.fit(const [], n: 10))
          .throws<ArgumentError>();
      check(() => BinomialDistribution.fit(const [-1], n: 10))
          .throws<ArgumentError>();
      check(() => BinomialDistribution.fit(const [1.5], n: 10))
          .throws<ArgumentError>();

      // Constructor validation
      check(() => BinomialDistribution(-1, 0.5)).throws<ArgumentError>();
      check(() => BinomialDistribution(10, -0.1)).throws<ArgumentError>();
      check(() => BinomialDistribution(10, 1.1)).throws<ArgumentError>();

      check(dist.toString()).contains('BinomialDistribution');
    });
  });
}
