import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/stats.dart';
import 'package:test/test.dart';

void main() {
  group('FDistribution moments and probabilities', () {
    final dist = FDistribution(10.0, 20.0);

    test('moments and parameters', () {
      check(dist.d1).equals(10.0);
      check(dist.d2).equals(20.0);
      check(dist.lowerBound).equals(0.0);
      check(dist.mean).isCloseTo(20.0 / 18.0, 1e-6);
      check(dist.cumulativeProbability(dist.median)).isCloseTo(0.5, 1e-4);
      check(dist.mode).isGreaterThan(0.0);
      check(dist.variance).isGreaterThan(0.0);
      check(dist.skewness).isGreaterThan(0.0);
      check(dist.excessKurtosis).isGreaterThan(0.0);

      final distSmallD2 = FDistribution(1.0, 2.0);
      check(distSmallD2.mean.isNaN).isTrue();
      check(distSmallD2.variance.isNaN).isTrue();
      check(distSmallD2.skewness.isNaN).isTrue();
      check(distSmallD2.excessKurtosis.isNaN).isTrue();
      check(distSmallD2.mode).equals(0.0);
    });

    test('probability density function', () {
      check(dist.probability(-1.0)).equals(0.0);
      check(dist.probability(1.0)).isGreaterThan(0.0);
    });

    test('cumulative probability and survival', () {
      check(dist.cumulativeProbability(-1.0)).equals(0.0);
      check(dist.survival(-1.0)).equals(1.0);
      check(dist.cumulativeProbability(0.0)).equals(0.0);
      check(dist.survival(0.0)).equals(1.0);
      check(dist.survival(1.0) + dist.cumulativeProbability(1.0))
          .isCloseTo(1.0, 1e-12);
      check(dist.survival(100.0)).isGreaterThan(0.0);
      check(dist.survival(100.0)).isLessThan(1e-10);
      check(dist.cumulativeProbability(1.0)).isGreaterThan(0.4);
      check(dist.cumulativeProbability(1.0)).isLessThan(0.6);
    });

    test('inverse cumulative probability', () {
      const prob = 0.90;
      final quant = dist.inverseCumulativeProbability(prob);
      check(dist.cumulativeProbability(quant)).isCloseTo(prob, 1e-4);
      check(() => dist.inverseCumulativeProbability(-0.1))
          .throws<InvalidProbability>();
    });
  });

  group('FDistribution estimation and validation', () {
    final dist = FDistribution(10.0, 20.0);

    test('sample generator and fit', () {
      final samples = dist.samples(random: math.Random(42)).take(2000).toList();
      final fitted = FDistribution.fit(samples);
      check(fitted.d1).isCloseTo(10.0, 6.0);
      check(fitted.d2).isCloseTo(20.0, 8.0);
    });

    test('fit errors', () {
      check(() => FDistribution.fit(const [1.0, 2.0, 3.0]))
          .throws<ArgumentError>();
      check(() => FDistribution.fit(const [-1.0, 2.0, 3.0, 4.0]))
          .throws<ArgumentError>();
    });

    test('constructor validation', () {
      check(() => FDistribution(0.0, 5.0)).throws<ArgumentError>();
      check(() => FDistribution(5.0, 0.0)).throws<ArgumentError>();
    });

    test('equality and hashCode', () {
      check(dist == FDistribution(10.0, 20.0)).isTrue();
      check(dist.hashCode).equals(FDistribution(10.0, 20.0).hashCode);
    });

    test('string conversion', () {
      check(dist.toString()).contains('FDistribution');
    });
  });
}
