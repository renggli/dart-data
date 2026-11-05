import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/stats.dart';
import 'package:test/test.dart';

void main() {
  group('RademacherDistribution moments and probabilities', () {
    const dist = RademacherDistribution();

    test('moments and parameters', () {
      check(dist.lowerBound).equals(-1);
      check(dist.upperBound).equals(1);
      check(dist.isLowerBoundOpen).isFalse();
      check(dist.isUpperBoundOpen).isFalse();
      check(dist.mean).equals(0.0);
      check(dist.median).equals(0.0);
      check(dist.mode.isNaN).isTrue();
      check(dist.variance).equals(1.0);
      check(dist.standardDeviation).equals(1.0);
      check(dist.skewness).equals(0.0);
      check(dist.excessKurtosis).equals(-2.0);
    });

    test('probability mass function', () {
      check(dist.probability(-2)).equals(0.0);
      check(dist.probability(-1)).equals(0.5);
      check(dist.probability(0)).equals(0.0);
      check(dist.probability(1)).equals(0.5);
      check(dist.probability(2)).equals(0.0);
    });

    test('cumulative probability', () {
      check(dist.cumulativeProbability(-2)).equals(0.0);
      check(dist.cumulativeProbability(-1)).equals(0.5);
      check(dist.cumulativeProbability(0)).equals(0.5);
      check(dist.cumulativeProbability(1)).equals(1.0);
      check(dist.cumulativeProbability(2)).equals(1.0);
    });

    test('inverse cumulative probability', () {
      check(dist.inverseCumulativeProbability(0.0)).equals(-1);
      check(dist.inverseCumulativeProbability(0.49)).equals(-1);
      check(dist.inverseCumulativeProbability(0.51)).equals(1);
      check(dist.inverseCumulativeProbability(1.0)).equals(1);
      check(() => dist.inverseCumulativeProbability(-0.1))
          .throws<InvalidProbability>();
    });
  });

  group('RademacherDistribution estimation and validation', () {
    const dist = RademacherDistribution();

    test('samples', () {
      final samples = dist.samples(random: math.Random(42)).take(50).toList();
      check(samples.every((sample) => sample == -1 || sample == 1)).isTrue();
    });

    test('fit', () {
      final fitted = RademacherDistribution.fit(const [-1, 1, -1, 1]);
      check(fitted).equals(const RademacherDistribution());
    });

    test('fit errors', () {
      check(() => RademacherDistribution.fit(const [])).throws<ArgumentError>();
      check(() => RademacherDistribution.fit(const [-1, 0, 1]))
          .throws<ArgumentError>();
    });

    test('string conversion', () {
      check(dist.toString()).contains('RademacherDistribution');
    });
  });
}
