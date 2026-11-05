import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/stats.dart';
import 'package:test/test.dart';

void main() {
  group('GammaDistribution moments and probabilities', () {
    final dist = GammaDistribution(3.0, 2.0);

    test('moments and parameters', () {
      check(dist.shape).equals(3.0);
      check(dist.scale).equals(2.0);
      check(dist.lowerBound).equals(0.0);
      check(dist.mean).equals(6.0);
      check(dist.cumulativeProbability(dist.median)).isCloseTo(0.5, 1e-4);
      check(dist.mode).equals(4.0);
      check(dist.variance).equals(12.0);
      check(dist.skewness).isCloseTo(2.0 / math.sqrt(3.0), 1e-6);
      check(dist.excessKurtosis).isCloseTo(6.0 / 3.0, 1e-6);

      final distSmallShape = GammaDistribution(0.5, 2.0);
      check(distSmallShape.mode).equals(0.0);
    });

    test('probability density function', () {
      check(dist.probability(-1.0)).equals(0.0);
      check(dist.probability(4.0)).isGreaterThan(0.0);
    });

    test('cumulative probability', () {
      check(dist.cumulativeProbability(-1.0)).equals(0.0);
      check(dist.cumulativeProbability(0.0)).equals(0.0);
    });

    test('inverse cumulative probability', () {
      const prob = 0.8;
      final quant = dist.inverseCumulativeProbability(prob);
      check(dist.cumulativeProbability(quant)).isCloseTo(prob, 1e-5);
      check(() => dist.inverseCumulativeProbability(-0.1))
          .throws<InvalidProbability>();
    });
  });

  group('GammaDistribution estimation and validation', () {
    final dist = GammaDistribution(3.0, 2.0);

    test('samples', () {
      final distSmallShape = GammaDistribution(0.5, 2.0);
      final smallSamples = distSmallShape
          .samples(random: math.Random(42))
          .take(10)
          .toList();
      check(smallSamples.every((sample) => sample >= 0)).isTrue();
    });

    test('shape constructor', () {
      final distStd = GammaDistribution.shape(4.0);
      check(distStd.scale).equals(1.0);
    });

    test('sample generator and fit', () {
      final samples = dist.samples(random: math.Random(42)).take(1000).toList();
      final fitted = GammaDistribution.fit(samples);
      check(fitted.shape).isCloseTo(3.0, 0.5);
      check(fitted.scale).isCloseTo(2.0, 0.5);
    });

    test('fit errors', () {
      check(() => GammaDistribution.fit(const [1.0])).throws<ArgumentError>();
      check(() => GammaDistribution.fit(const [-1.0, 2.0]))
          .throws<ArgumentError>();
    });

    test('constructor validation', () {
      check(() => GammaDistribution(0.0, 1.0)).throws<ArgumentError>();
      check(() => GammaDistribution(1.0, 0.0)).throws<ArgumentError>();
    });

    test('equality and hashCode', () {
      check(dist == GammaDistribution(3.0, 2.0)).isTrue();
      check(dist.hashCode).equals(GammaDistribution(3.0, 2.0).hashCode);
    });

    test('string conversion', () {
      check(dist.toString()).contains('GammaDistribution');
    });
  });
}
