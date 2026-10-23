import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/stats.dart';
import 'package:test/test.dart';

void main() {
  group('BetaDistribution moments and probabilities', () {
    test('moments, pdf, cdf, and quantile', () {
      final dist = BetaDistribution(2.0, 5.0);
      check(dist.alpha).equals(2.0);
      check(dist.beta).equals(5.0);
      check(dist.lowerBound).equals(0.0);
      check(dist.upperBound).equals(1.0);
      check(dist.isLowerBoundOpen).isFalse();
      check(dist.isUpperBoundOpen).isFalse();
      check(dist.mean).isCloseTo(2.0 / 7.0, 1e-6);
      check(dist.cumulativeProbability(dist.median)).isCloseTo(0.5, 1e-4);
      check(dist.mode).isCloseTo(1.0 / 5.0, 1e-6);
      check(dist.variance).isCloseTo(10.0 / (49.0 * 8.0), 1e-6);
      check(dist.skewness).isGreaterThan(0.0);
      check(dist.excessKurtosis).isA<double>();

      // Symmetric beta
      final distSym = BetaDistribution(3.0, 3.0);
      check(distSym.median).equals(0.5);

      // Mode when alpha <= 1 or beta <= 1
      final distFlat = BetaDistribution(0.5, 0.5);
      check(distFlat.mode.isNaN).isTrue();

      // PDF boundary checks
      check(dist.probability(-0.5)).equals(0.0);
      check(dist.probability(1.5)).equals(0.0);
      check(dist.probability(0.0)).equals(0.0);
      check(dist.probability(1.0)).equals(0.0);
      check(dist.probability(0.2)).isGreaterThan(0.0);

      final distAlpha1 = BetaDistribution(1.0, 2.0);
      check(distAlpha1.probability(0.0)).equals(2.0);
      final distBeta1 = BetaDistribution(2.0, 1.0);
      check(distBeta1.probability(1.0)).equals(2.0);

      final distAlphaSmall = BetaDistribution(0.5, 2.0);
      check(distAlphaSmall.probability(0.0).isInfinite).isTrue();
      final distBetaSmall = BetaDistribution(2.0, 0.5);
      check(distBetaSmall.probability(1.0).isInfinite).isTrue();

      check(dist.cumulativeProbability(-0.5)).equals(0.0);
      check(dist.cumulativeProbability(0.0)).equals(0.0);
      check(dist.cumulativeProbability(1.0)).equals(1.0);
      check(dist.cumulativeProbability(1.5)).equals(1.0);

      // Quantile roundtrip
      const prob = 0.75;
      final quant = dist.inverseCumulativeProbability(prob);
      check(dist.cumulativeProbability(quant)).isCloseTo(prob, 1e-5);
      check(() => dist.inverseCumulativeProbability(-0.1))
          .throws<InvalidProbability>();
    });
  });

  group('BetaDistribution estimation and validation', () {
    test('samples, fit, errors, and equality', () {
      final dist = BetaDistribution(2.0, 5.0);
      // Fit
      final samples = dist.samples(random: math.Random(42)).take(1000).toList();
      final fitted = BetaDistribution.fit(samples);
      check(fitted.alpha).isCloseTo(2.0, 0.4);
      check(fitted.beta).isCloseTo(5.0, 1.0);
      check(() => BetaDistribution.fit(const [0.5])).throws<ArgumentError>();
      check(() => BetaDistribution.fit(const [0.0, 0.5]))
          .throws<ArgumentError>();
      check(() => BetaDistribution.fit(const [0.5, 1.0]))
          .throws<ArgumentError>();

      // Constructor validation
      check(() => BetaDistribution(0.0, 1.0)).throws<ArgumentError>();
      check(() => BetaDistribution(1.0, 0.0)).throws<ArgumentError>();

      // Equality and toString
      check(dist == BetaDistribution(2.0, 5.0)).isTrue();
      check(dist.hashCode).equals(BetaDistribution(2.0, 5.0).hashCode);
      check(dist.toString()).contains('BetaDistribution');
    });
  });
}
