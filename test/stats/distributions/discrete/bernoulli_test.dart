import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/stats.dart';
import 'package:test/scaffolding.dart';

void main() {
  final dist = BernoulliDistribution(0.7);
  final fair = BernoulliDistribution(0.5);
  final zero = BernoulliDistribution(0.0);
  final one = BernoulliDistribution(1.0);

  group('BernoulliDistribution moments and bounds', () {
    test('parameters, bounds, and moments', () {
      check(dist.p).equals(0.7);
      check(dist.q).isCloseTo(0.3, 1e-12);
      check(dist.lowerBound).equals(0);
      check(dist.upperBound).equals(1);
      check(dist.isLowerBoundOpen).isFalse;
      check(dist.isUpperBoundOpen).isFalse;
      check(dist.mean).equals(0.7);
      check(dist.median).equals(1.0);
      check(dist.mode).equals(1.0);
      check(dist.variance).isCloseTo(0.21, 1e-12);
      check(dist.standardDeviation).isCloseTo(math.sqrt(0.21), 1e-12);
      check(dist.skewness).isCloseTo((0.3 - 0.7) / math.sqrt(0.21), 1e-12);
      check(dist.excessKurtosis).isCloseTo((1.0 - 6.0 * 0.21) / 0.21, 1e-12);
    });

    test('median, mode, and degenerate moments at boundary p', () {
      final low = BernoulliDistribution(0.3);
      check(low.median).equals(0.0);
      check(low.mode).equals(0.0);

      check(fair.median).equals(0.5);
      check(fair.mode.isNaN).isTrue;
      check(fair.skewness).equals(0.0);
      check(fair.excessKurtosis).equals(-2.0);

      check(zero.skewness.isNaN).isTrue;
      check(zero.excessKurtosis.isNaN).isTrue;
      check(one.skewness.isNaN).isTrue;
      check(one.excessKurtosis.isNaN).isTrue;
    });
  });

  group('BernoulliDistribution probabilities', () {
    test('probability and logProbability across support and outside', () {
      check(dist.probability(-1)).equals(0.0);
      check(dist.probability(0)).isCloseTo(0.3, 1e-12);
      check(dist.probability(1)).isCloseTo(0.7, 1e-12);
      check(dist.probability(2)).equals(0.0);

      check(dist.logProbability(-1)).equals(double.negativeInfinity);
      check(dist.logProbability(0)).isCloseTo(math.log(0.3), 1e-12);
      check(dist.logProbability(1)).isCloseTo(math.log(0.7), 1e-12);
      check(dist.logProbability(2)).equals(double.negativeInfinity);
    });

    test('cumulativeProbability and survival are complementary', () {
      check(dist.cumulativeProbability(-1)).equals(0.0);
      check(dist.cumulativeProbability(0)).isCloseTo(0.3, 1e-12);
      check(dist.cumulativeProbability(1)).equals(1.0);
      check(dist.cumulativeProbability(2)).equals(1.0);

      check(dist.survival(-1)).equals(1.0);
      check(dist.survival(0)).isCloseTo(0.7, 1e-12);
      check(dist.survival(1)).equals(0.0);
      check(dist.survival(2)).equals(0.0);
    });

    test('inverseCumulativeProbability and inverseSurvival', () {
      check(dist.inverseCumulativeProbability(0.0)).equals(0);
      check(dist.inverseCumulativeProbability(0.29)).equals(0);
      check(dist.inverseCumulativeProbability(0.31)).equals(1);
      check(dist.inverseCumulativeProbability(1.0)).equals(1);

      check(dist.inverseSurvival(1.0)).equals(0);
      check(dist.inverseSurvival(0.71)).equals(0);
      check(dist.inverseSurvival(0.69)).equals(1);
      check(dist.inverseSurvival(0.0)).equals(1);

      check(() => dist.inverseCumulativeProbability(-0.1))
          .throws<InvalidProbability>();
      check(() => dist.inverseSurvival(1.1)).throws<InvalidProbability>();
    });
  });

  group('BernoulliDistribution sampling, fitting, and validation', () {
    test('samples emit 0/1 with matching empirical mean', () {
      final single = dist.sample();
      check(single == 0 || single == 1).isTrue;
      final samples = dist.samples(random: math.Random(42)).take(2000).toList();
      check(samples.every((x) => x == 0 || x == 1)).isTrue;
      final empiricalMean = samples.reduce((a, b) => a + b) / samples.length;
      check(empiricalMean).isCloseTo(0.7, 0.04);
    });

    test('fit estimates p and validates binary samples', () {
      final fitted = BernoulliDistribution.fit(const [
        1,
        1,
        1,
        0,
        1,
        0,
        1,
        1,
        0,
        1,
      ]);
      check(fitted.p).isCloseTo(0.7, 1e-12);

      check(() => BernoulliDistribution.fit(const [])).throws<ArgumentError>();
      check(() => BernoulliDistribution.fit(const [0, 2]))
          .throws<ArgumentError>();
      check(() => BernoulliDistribution.fit(const [0.5, 1]))
          .throws<ArgumentError>();
    });

    test('constructor validation', () {
      check(() => BernoulliDistribution(-0.1)).throws<ArgumentError>();
      check(() => BernoulliDistribution(1.1)).throws<ArgumentError>();
      check(() => BernoulliDistribution(double.nan)).throws<ArgumentError>();
    });

    test('equality, hashCode, and string representation', () {
      check(dist == BernoulliDistribution(0.7)).isTrue;
      check(dist.hashCode).equals(BernoulliDistribution(0.7).hashCode);
      check(dist == fair).isFalse;
      check(dist.toString()).contains('BernoulliDistribution');
    });
  });
}
