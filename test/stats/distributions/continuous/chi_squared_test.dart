import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/stats.dart';
import 'package:test/test.dart';

void main() {
  group('ChiSquaredDistribution moments and probabilities', () {
    final dist = ChiSquaredDistribution(5.0);

    test('moments and bounds', () {
      check(dist.dof).equals(5.0);
      check(dist.lowerBound).equals(0.0);
      check(dist.isLowerBoundOpen).isFalse();
      check(dist.mean).equals(5.0);
      check(dist.median).isGreaterThan(4.0);
      check(dist.mode).equals(3.0);
      check(dist.variance).equals(10.0);
      check(dist.skewness).isCloseTo(math.sqrt(8.0 / 5.0), 1e-6);
      check(dist.excessKurtosis).isCloseTo(12.0 / 5.0, 1e-6);

      final distSmall = ChiSquaredDistribution(1.0);
      check(distSmall.mode).equals(0.0);
    });

    test('probability density function', () {
      check(dist.probability(-1.0)).equals(0.0);
      check(dist.probability(2.0)).isGreaterThan(0.0);
    });

    test('cumulative probability', () {
      check(dist.cumulativeProbability(0.0)).equals(0.0);
      check(dist.cumulativeProbability(-1.0)).equals(0.0);
      check(dist.cumulativeProbability(5.0)).isGreaterThan(0.4);
      check(dist.cumulativeProbability(5.0)).isLessThan(0.6);
    });

    test('inverse cumulative probability', () {
      const prob = 0.95;
      final quant = dist.inverseCumulativeProbability(prob);
      check(dist.cumulativeProbability(quant)).isCloseTo(prob, 1e-5);
      check(() => dist.inverseCumulativeProbability(-0.1))
          .throws<InvalidProbability>();
    });
  });

  group('ChiSquaredDistribution estimation and validation', () {
    final dist = ChiSquaredDistribution(5.0);

    test('sample generator and fit', () {
      final samples = dist.samples(random: math.Random(42)).take(1000).toList();
      final fitted = ChiSquaredDistribution.fit(samples);
      check(fitted.dof).isCloseTo(5.0, 0.5);
    });

    test('fit errors', () {
      check(() => ChiSquaredDistribution.fit(const [])).throws<ArgumentError>();
      check(() => ChiSquaredDistribution.fit(const [-1.0]))
          .throws<ArgumentError>();
    });

    test('constructor validation', () {
      check(() => ChiSquaredDistribution(0.0)).throws<ArgumentError>();
    });

    test('equality and hashCode', () {
      check(dist == ChiSquaredDistribution(5.0)).isTrue();
      check(dist.hashCode).equals(ChiSquaredDistribution(5.0).hashCode);
    });

    test('string conversion', () {
      check(dist.toString()).contains('ChiSquaredDistribution');
    });
  });
}
