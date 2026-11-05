import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/stats.dart';
import 'package:test/test.dart';

void main() {
  group('LogisticDistribution moments and probabilities', () {
    final dist = LogisticDistribution(0.0, 1.0);

    test('moments and parameters', () {
      check(dist.location).equals(0.0);
      check(dist.scale).equals(1.0);
      check(dist.mean).equals(0.0);
      check(dist.median).equals(0.0);
      check(dist.mode).equals(0.0);
      check(dist.variance).isCloseTo(math.pi * math.pi / 3.0, 1e-6);
      check(dist.skewness).equals(0.0);
      check(dist.excessKurtosis).equals(1.2);
    });

    test('probability density function', () {
      check(dist.probability(0.0)).equals(0.25);
    });

    test('cumulative probability', () {
      check(dist.cumulativeProbability(0.0)).equals(0.5);
    });

    test('inverse cumulative probability', () {
      check(dist.inverseCumulativeProbability(0.5)).equals(0.0);
      check(dist.inverseCumulativeProbability(0.0))
          .equals(double.negativeInfinity);
      check(dist.inverseCumulativeProbability(1.0)).equals(double.infinity);
      check(() => dist.inverseCumulativeProbability(-0.1))
          .throws<InvalidProbability>();
    });

    test('standard constructor', () {
      const defaultLogistic = LogisticDistribution.standard();
      check(defaultLogistic.location).equals(0.0);
      check(defaultLogistic.scale).equals(1.0);
    });
  });

  group('LogisticDistribution estimation and validation', () {
    final dist = LogisticDistribution(0.0, 1.0);

    test('samples', () {
      final samples = dist.samples(random: math.Random(42)).take(50).toList();
      check(samples.isNotEmpty).isTrue();
    });

    test('fit', () {
      final fitted = LogisticDistribution.fit(const [-2.0, 0.0, 2.0]);
      check(fitted.location).equals(0.0);
      check(fitted.scale).isGreaterThan(0.0);
    });

    test('fit errors', () {
      check(() => LogisticDistribution.fit(const [])).throws<ArgumentError>();
      check(() => LogisticDistribution.fit(const [double.nan]))
          .throws<ArgumentError>();
    });

    test('constructor validation', () {
      check(() => LogisticDistribution(0.0, 0.0)).throws<ArgumentError>();
    });

    test('equality and hashCode', () {
      check(dist == LogisticDistribution(0.0, 1.0)).isTrue();
      check(dist.hashCode).equals(LogisticDistribution(0.0, 1.0).hashCode);
    });

    test('string conversion', () {
      check(dist.toString()).contains('LogisticDistribution');
    });
  });
}
