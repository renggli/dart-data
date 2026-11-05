import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/stats.dart';
import 'package:test/test.dart';

void main() {
  group('WeibullDistribution moments and probabilities', () {
    final dist = WeibullDistribution(1.0, 1.0);

    test('moments and parameters', () {
      check(dist.scale).equals(1.0);
      check(dist.shape).equals(1.0);
      check(dist.lowerBound).equals(0.0);
      check(dist.mean).isCloseTo(1.0, 1e-6);
      check(dist.median).isCloseTo(math.ln2, 1e-6);
      check(dist.mode).equals(0.0);
      check(dist.variance).isCloseTo(1.0, 1e-6);
      check(dist.skewness).isCloseTo(2.0, 1e-5);
      check(dist.excessKurtosis).isCloseTo(6.0, 1e-5);

      final distShape2 = WeibullDistribution(2.0, 1.0);
      check(distShape2.mode).isGreaterThan(0.0);
    });

    test('probability density function', () {
      check(dist.probability(-1.0)).equals(0.0);
      check(dist.probability(1.0)).isGreaterThan(0.0);
      check(dist.probability(0.0)).equals(1.0);
      check(dist.logProbability(0.0)).equals(0.0);

      final distShape2 = WeibullDistribution(2.0, 2.0);
      check(distShape2.probability(0.0)).equals(0.0);
      check(distShape2.logProbability(0.0)).equals(double.negativeInfinity);

      final distShapeHalf = WeibullDistribution(0.5, 2.0);
      check(distShapeHalf.probability(0.0)).equals(double.infinity);
      check(distShapeHalf.logProbability(0.0)).equals(double.infinity);
    });

    test('cumulative probability', () {
      check(dist.cumulativeProbability(-1.0)).equals(0.0);
      check(dist.cumulativeProbability(0.0)).equals(0.0);
      check(dist.cumulativeProbability(1.0))
          .isCloseTo(1.0 - math.exp(-1.0), 1e-6);
    });

    test('inverse cumulative probability', () {
      check(dist.inverseCumulativeProbability(0.5))
          .isCloseTo(dist.median, 1e-6);
      check(() => dist.inverseCumulativeProbability(-0.1))
          .throws<InvalidProbability>();
    });

    test(
      'probability and logProbability in extreme tail do not evaluate to NaN',
      () {
        final distShape15 = WeibullDistribution(1.5, 1.0);
        final pTail = distShape15.probability(1e200);
        check(pTail.isNaN).isFalse();
        check(pTail).equals(0.0);
        final logPTail = distShape15.logProbability(1e200);
        check(logPTail.isNaN).isFalse();
        check(logPTail.isNegative).isTrue();
      },
    );
  });

  group('WeibullDistribution estimation and validation', () {
    final dist = WeibullDistribution(1.0, 1.0);

    test('samples', () {
      final samples = dist.samples(random: math.Random(42)).take(50).toList();
      check(samples.every((sample) => sample >= 0.0)).isTrue();
    });

    test('fit', () {
      final fitted = WeibullDistribution.fit(const [0.5, 1.0, 2.0]);
      check(fitted.shape).isGreaterThan(0.0);
      check(fitted.scale).isGreaterThan(0.0);
    });

    test('fit errors', () {
      check(() => WeibullDistribution.fit(const [])).throws<ArgumentError>();
      check(() => WeibullDistribution.fit(const [-1.0, 1.0]))
          .throws<ArgumentError>();
    });

    test('constructor validation', () {
      check(() => WeibullDistribution(0.0, 1.0)).throws<ArgumentError>();
      check(() => WeibullDistribution(1.0, 0.0)).throws<ArgumentError>();
    });

    test('equality and hashCode', () {
      check(dist == WeibullDistribution(1.0, 1.0)).isTrue();
      check(dist.hashCode).equals(WeibullDistribution(1.0, 1.0).hashCode);
    });

    test('string conversion', () {
      check(dist.toString()).contains('WeibullDistribution');
    });
  });
}
