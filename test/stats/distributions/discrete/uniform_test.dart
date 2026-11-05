import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/stats.dart';
import 'package:test/test.dart';

void main() {
  group('DiscreteUniformDistribution moments and probabilities', () {
    final dist = UniformDiscreteDistribution(1, 6);

    test('moments and parameters', () {
      check(dist.min).equals(1);
      check(dist.max).equals(6);
      check(dist.lowerBound).equals(1);
      check(dist.upperBound).equals(6);
      check(dist.isLowerBoundOpen).isFalse();
      check(dist.isUpperBoundOpen).isFalse();
      check(dist.mean).equals(3.5);
      check(dist.variance).isCloseTo(35.0 / 12.0, 1e-6);
      check(dist.standardDeviation).isCloseTo(math.sqrt(35.0 / 12.0), 1e-6);
      check(dist.median).equals(3.5);
      check(dist.mode.isNaN).isTrue();
      check(dist.skewness).equals(0.0);
      check(dist.excessKurtosis).isCloseTo(-1.2685714, 1e-4);
    });

    test('probability mass function', () {
      check(dist.probability(0)).equals(0.0);
      check(dist.probability(1)).isCloseTo(1.0 / 6.0, 1e-6);
      check(dist.probability(7)).equals(0.0);
    });

    test('cumulative probability', () {
      check(dist.cumulativeProbability(0)).equals(0.0);
      check(dist.cumulativeProbability(3)).isCloseTo(0.5, 1e-6);
      check(dist.cumulativeProbability(6)).equals(1.0);
      check(dist.cumulativeProbability(7)).equals(1.0);
    });

    test('inverse cumulative probability', () {
      check(dist.inverseCumulativeProbability(0.0)).equals(1);
      check(dist.inverseCumulativeProbability(0.5)).equals(3);
      check(dist.inverseCumulativeProbability(1.0)).equals(6);
      check(() => dist.inverseCumulativeProbability(-0.1))
          .throws<InvalidProbability>();
      check(() => dist.inverseCumulativeProbability(double.nan))
          .throws<InvalidProbability>();

      final u01 = UniformDiscreteDistribution(0, 1);
      check(u01.inverseCumulativeProbability(0.5)).equals(0);
      check(u01.inverseCumulativeProbability(0.51)).equals(1);
    });
  });

  group('DiscreteUniformDistribution estimation and validation', () {
    final dist = UniformDiscreteDistribution(1, 6);

    test('samples', () {
      final samples = dist.samples(random: math.Random(42)).take(50).toList();
      check(samples.every((sample) => sample >= 1 && sample <= 6)).isTrue();
    });

    test('fit', () {
      final samples = dist.samples(random: math.Random(42)).take(50).toList();
      final fitted = UniformDiscreteDistribution.fit(samples);
      check(fitted.min).isGreaterThan(0);
      check(fitted.max).isLessThan(7);
    });

    test('fit errors', () {
      check(() => UniformDiscreteDistribution.fit(const []))
          .throws<ArgumentError>();
    });

    test('constructor validation', () {
      check(() => UniformDiscreteDistribution(5, 3)).throws<ArgumentError>();
    });

    test('string conversion', () {
      check(dist.toString()).contains('UniformDiscreteDistribution');
    });
  });
}
