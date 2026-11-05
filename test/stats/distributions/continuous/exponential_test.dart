import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/stats.dart';
import 'package:test/test.dart';

void main() {
  group('ExponentialDistribution moments and probabilities', () {
    final dist = ExponentialDistribution(2.0);

    test('moments and parameters', () {
      check(dist.rate).equals(2.0);
      check(dist.lowerBound).equals(0.0);
      check(dist.mean).equals(0.5);
      check(dist.median).isCloseTo(math.ln2 / 2.0, 1e-6);
      check(dist.mode).equals(0.0);
      check(dist.variance).equals(0.25);
      check(dist.skewness).equals(2.0);
      check(dist.excessKurtosis).equals(6.0);
    });

    test('probability density function', () {
      check(dist.probability(-1.0)).equals(0.0);
      check(dist.probability(0.0)).equals(2.0);
    });

    test('cumulative probability', () {
      check(dist.cumulativeProbability(-1.0)).equals(0.0);
      check(dist.cumulativeProbability(0.0)).equals(0.0);
      check(dist.cumulativeProbability(0.5))
          .isCloseTo(1.0 - math.exp(-1.0), 1e-6);
    });

    test('inverse cumulative probability', () {
      check(dist.inverseCumulativeProbability(0.5))
          .isCloseTo(dist.median, 1e-6);
      check(() => dist.inverseCumulativeProbability(-0.1))
          .throws<InvalidProbability>();
    });
  });

  group('ExponentialDistribution estimation and validation', () {
    final dist = ExponentialDistribution(2.0);

    test('sample generator and fit', () {
      final samples = dist.samples(random: math.Random(42)).take(1000).toList();
      final fitted = ExponentialDistribution.fit(samples);
      check(fitted.rate).isCloseTo(2.0, 0.2);
    });

    test('fit errors', () {
      check(() => ExponentialDistribution.fit(const []))
          .throws<ArgumentError>();
      check(() => ExponentialDistribution.fit(const [-1.0]))
          .throws<ArgumentError>();
    });

    test('constructor validation', () {
      check(() => ExponentialDistribution(0.0)).throws<ArgumentError>();
    });

    test('equality and hashCode', () {
      check(dist == ExponentialDistribution(2.0)).isTrue();
      check(dist.hashCode).equals(ExponentialDistribution(2.0).hashCode);
    });

    test('string conversion', () {
      check(dist.toString()).contains('ExponentialDistribution');
    });
  });
}
