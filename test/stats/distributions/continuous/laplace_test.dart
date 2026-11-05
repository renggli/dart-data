import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/stats.dart';
import 'package:test/test.dart';

void main() {
  group('LaplaceDistribution moments and probabilities', () {
    final dist = LaplaceDistribution(0.0, 1.0);

    test('moments and parameters', () {
      check(dist.location).equals(0.0);
      check(dist.scale).equals(1.0);
      check(dist.mean).equals(0.0);
      check(dist.median).equals(0.0);
      check(dist.mode).equals(0.0);
      check(dist.variance).equals(2.0);
      check(dist.skewness).equals(0.0);
      check(dist.excessKurtosis).equals(3.0);
    });

    test('probability density function', () {
      check(dist.probability(0.0)).equals(0.5);
    });

    test('cumulative probability', () {
      check(dist.cumulativeProbability(0.0)).equals(0.5);
      check(dist.cumulativeProbability(-1.0))
          .isCloseTo(0.5 * math.exp(-1.0), 1e-6);
      check(dist.cumulativeProbability(1.0))
          .isCloseTo(1.0 - 0.5 * math.exp(-1.0), 1e-6);
    });

    test('inverse cumulative probability', () {
      check(dist.inverseCumulativeProbability(0.5)).equals(0.0);
      check(dist.inverseCumulativeProbability(0.0))
          .equals(double.negativeInfinity);
      check(dist.inverseCumulativeProbability(1.0)).equals(double.infinity);
      check(dist.inverseCumulativeProbability(0.25)).isLessThan(0.0);
      check(dist.inverseCumulativeProbability(0.75)).isGreaterThan(0.0);
      check(() => dist.inverseCumulativeProbability(-0.1))
          .throws<InvalidProbability>();
    });

    test('standard constructor', () {
      const defaultLaplace = LaplaceDistribution.standard();
      check(defaultLaplace.location).equals(0.0);
      check(defaultLaplace.scale).equals(1.0);
    });
  });

  group('LaplaceDistribution estimation and validation', () {
    final dist = LaplaceDistribution(0.0, 1.0);

    test('samples', () {
      final samples = dist.samples(random: math.Random(42)).take(50).toList();
      check(samples.isNotEmpty).isTrue();
    });

    test('fit', () {
      final fitted = LaplaceDistribution.fit(const [-1.0, 0.0, 1.0]);
      check(fitted.location).equals(0.0);
      check(fitted.scale).isCloseTo(2.0 / 3.0, 1e-6);
    });

    test('fit errors', () {
      check(() => LaplaceDistribution.fit(const [])).throws<ArgumentError>();
      check(() => LaplaceDistribution.fit(const [double.nan]))
          .throws<ArgumentError>();
    });

    test('constructor validation', () {
      check(() => LaplaceDistribution(0.0, 0.0)).throws<ArgumentError>();
    });

    test('equality and hashCode', () {
      check(dist == LaplaceDistribution(0.0, 1.0)).isTrue();
      check(dist.hashCode).equals(LaplaceDistribution(0.0, 1.0).hashCode);
    });

    test('string conversion', () {
      check(dist.toString()).contains('LaplaceDistribution');
    });
  });
}
