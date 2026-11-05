import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/stats.dart';
import 'package:test/test.dart';

void main() {
  group('ParetoDistribution moments and probabilities', () {
    final dist = ParetoDistribution(3.0, 1.0);

    test('moments and parameters', () {
      check(dist.scale).equals(1.0);
      check(dist.shape).equals(3.0);
      check(dist.lowerBound).equals(1.0);
      check(dist.mean).isCloseTo(1.5, 1e-6);
      check(dist.median).isCloseTo(math.pow(2.0, 1.0 / 3.0), 1e-6);
      check(dist.mode).equals(1.0);
      check(dist.variance).isCloseTo(3.0 / 4.0, 1e-6);
      check(dist.skewness.isNaN).isTrue(); // shape <= 3 gives nan
      check(dist.excessKurtosis.isNaN).isTrue(); // shape <= 4 gives nan
    });

    test('moments for varying shape thresholds', () {
      final distAlpha1 = ParetoDistribution(1.0, 1.0);
      check(distAlpha1.mean.isInfinite).isTrue();
      check(distAlpha1.variance.isNaN).isTrue();

      final distAlpha2 = ParetoDistribution(1.5, 1.0);
      check(distAlpha2.variance.isInfinite).isTrue();

      final distAlpha5 = ParetoDistribution(5.0, 1.0);
      check(distAlpha5.skewness).isGreaterThan(0.0);
      check(distAlpha5.excessKurtosis).isGreaterThan(0.0);
    });

    test('probability density function', () {
      check(dist.probability(0.5)).equals(0.0);
      check(dist.probability(1.0)).equals(3.0);
    });

    test('cumulative probability', () {
      check(dist.cumulativeProbability(0.5)).equals(0.0);
      check(dist.cumulativeProbability(1.0)).equals(0.0);
      check(dist.cumulativeProbability(2.0)).isCloseTo(1.0 - 1.0 / 8.0, 1e-6);
    });

    test('inverse cumulative probability', () {
      check(dist.inverseCumulativeProbability(0.5))
          .isCloseTo(math.pow(2.0, 1.0 / 3.0), 1e-6);
      check(() => dist.inverseCumulativeProbability(-0.1))
          .throws<InvalidProbability>();
    });

    test(
      'probability and logProbability with large shape do not evaluate to NaN',
      () {
        final distLarge = ParetoDistribution(500.0, 10.0);
        final p = distLarge.probability(15.0);
        check(p.isNaN).isFalse();
        final logP = distLarge.logProbability(15.0);
        check(logP.isNaN).isFalse();
      },
    );
  });

  group('ParetoDistribution estimation and validation', () {
    final dist = ParetoDistribution(3.0, 1.0);

    test('samples', () {
      final samples = dist.samples(random: math.Random(42)).take(50).toList();
      check(samples.every((sample) => sample >= 1.0)).isTrue();
    });

    test('fit', () {
      final fitted = ParetoDistribution.fit(const [2.0, 4.0, 8.0]);
      check(fitted.scale).equals(2.0);
      check(fitted.shape).isGreaterThan(0.0);
    });

    test('fit errors', () {
      check(() => ParetoDistribution.fit(const [])).throws<ArgumentError>();
      check(() => ParetoDistribution.fit(const [-1.0, 2.0]))
          .throws<ArgumentError>();
    });

    test('constructor validation', () {
      check(() => ParetoDistribution(0.0, 1.0)).throws<ArgumentError>();
      check(() => ParetoDistribution(1.0, 0.0)).throws<ArgumentError>();
    });

    test('equality and hashCode', () {
      check(dist == ParetoDistribution(3.0, 1.0)).isTrue();
      check(dist.hashCode).equals(ParetoDistribution(3.0, 1.0).hashCode);
    });

    test('string conversion', () {
      check(dist.toString()).contains('ParetoDistribution');
    });
  });
}
