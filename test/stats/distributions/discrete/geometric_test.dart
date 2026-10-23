import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/stats.dart';
import 'package:data/type.dart';
import 'package:test/test.dart';

void main() {
  group('GeometricDistribution moments and probabilities', () {
    test('moments, pdf, cdf, and quantile', () {
      final dist = GeometricDistribution(0.5);
      check(dist.p).equals(0.5);
      check(dist.lowerBound).equals(0);
      check(dist.upperBound).equals(DataType.integer.safeMax);
      check(dist.isLowerBoundOpen).isFalse();
      check(dist.isUpperBoundOpen).isTrue();

      check(dist.mean).equals(1.0);
      check(dist.variance).equals(2.0);
      check(dist.standardDeviation).isCloseTo(math.sqrt(2.0), 1e-6);
      check(dist.mode).equals(0.0);
      check(dist.median).isA<double>();
      check(dist.skewness).isCloseTo((2.0 - 0.5) / math.sqrt(0.5), 1e-6);
      check(dist.excessKurtosis).isCloseTo(6.0 + 0.25 / 0.5, 1e-6);

      check(dist.probability(-1)).equals(0.0);
      check(dist.probability(0)).equals(0.5);
      check(dist.probability(1)).equals(0.25);

      check(dist.cumulativeProbability(-1)).equals(0.0);
      check(dist.cumulativeProbability(0)).equals(0.5);
      check(dist.cumulativeProbability(1)).equals(0.75);

      check(dist.inverseCumulativeProbability(0.0)).equals(0);
      check(dist.inverseCumulativeProbability(0.5)).equals(0);
      check(dist.inverseCumulativeProbability(0.75)).equals(1);
      check(() => dist.inverseCumulativeProbability(-0.1))
          .throws<InvalidProbability>();
    });
  });

  group('GeometricDistribution estimation and validation', () {
    test('samples, fit, errors, and equality', () {
      final dist = GeometricDistribution(0.5);
      // Samples
      final samples = dist.samples(random: math.Random(42)).take(50).toList();
      check(samples.every((sample) => sample >= 0)).isTrue();

      // Constructor validation
      check(() => GeometricDistribution(0.0)).throws<ArgumentError>();
      check(() => GeometricDistribution(-0.5)).throws<ArgumentError>();
      check(() => GeometricDistribution(1.5)).throws<ArgumentError>();

      check(dist.toString()).contains('GeometricDistribution');
    });
  });
}
