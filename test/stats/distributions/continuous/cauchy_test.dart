import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/stats.dart';
import 'package:test/test.dart';

void main() {
  group('CauchyDistribution moments and probabilities', () {
    final dist = CauchyDistribution(0.0, 1.0);

    test('moments and parameters', () {
      check(dist.location).equals(0.0);
      check(dist.scale).equals(1.0);
      check(dist.mean.isNaN).isTrue();
      check(dist.median).equals(0.0);
      check(dist.mode).equals(0.0);
      check(dist.variance.isNaN).isTrue();
      check(dist.skewness.isNaN).isTrue();
      check(dist.excessKurtosis.isNaN).isTrue();
    });

    test('probability density function', () {
      check(dist.probability(0.0)).isCloseTo(1.0 / math.pi, 1e-6);
    });

    test('cumulative probability', () {
      check(dist.cumulativeProbability(0.0)).isCloseTo(0.5, 1e-6);
    });

    test('inverse cumulative probability', () {
      check(dist.inverseCumulativeProbability(0.5)).isCloseTo(0.0, 1e-6);
      check(dist.inverseCumulativeProbability(0.0))
          .equals(double.negativeInfinity);
      check(dist.inverseCumulativeProbability(1.0)).equals(double.infinity);
      check(() => dist.inverseCumulativeProbability(-0.1))
          .throws<InvalidProbability>();
    });

    test('standard constructor', () {
      const defaultCauchy = CauchyDistribution.standard();
      check(defaultCauchy.location).equals(0.0);
      check(defaultCauchy.scale).equals(1.0);
    });
  });

  group('CauchyDistribution estimation and validation', () {
    final dist = CauchyDistribution(0.0, 1.0);

    test('samples', () {
      final samples = dist.samples(random: math.Random(42)).take(50).toList();
      check(samples.isNotEmpty).isTrue();
    });

    test('fit', () {
      final fitted = CauchyDistribution.fit(const [-1.0, 0.0, 1.0]);
      check(fitted.location).equals(0.0);
      check(fitted.scale).isGreaterThan(0.0);
    });

    test('fit errors', () {
      check(() => CauchyDistribution.fit(const [])).throws<ArgumentError>();
      check(() => CauchyDistribution.fit(const [double.nan]))
          .throws<ArgumentError>();
    });

    test('constructor validation', () {
      check(() => CauchyDistribution(0.0, 0.0)).throws<ArgumentError>();
    });

    test('equality and hashCode', () {
      check(dist == CauchyDistribution(0.0, 1.0)).isTrue();
      check(dist.hashCode).equals(CauchyDistribution(0.0, 1.0).hashCode);
    });

    test('string conversion', () {
      check(dist.toString()).contains('CauchyDistribution');
    });
  });
}
