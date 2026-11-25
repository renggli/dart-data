import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/stats.dart';
import 'package:test/scaffolding.dart';

void main() {
  const dist = RademacherDistribution();

  group('RademacherDistribution moments and bounds', () {
    test('bounds and moments', () {
      check(dist.lowerBound).equals(-1);
      check(dist.upperBound).equals(1);
      check(dist.isLowerBoundOpen).isFalse;
      check(dist.isUpperBoundOpen).isFalse;
      check(dist.mean).equals(0.0);
      check(dist.median).equals(0.0);
      check(dist.mode.isNaN).isTrue;
      check(dist.variance).equals(1.0);
      check(dist.standardDeviation).equals(1.0);
      check(dist.skewness).equals(0.0);
      check(dist.excessKurtosis).equals(-2.0);
    });
  });

  group('RademacherDistribution probabilities', () {
    test('probability and logProbability across support and outside', () {
      check(dist.probability(-2)).equals(0.0);
      check(dist.probability(-1)).equals(0.5);
      check(dist.probability(0)).equals(0.0);
      check(dist.probability(1)).equals(0.5);
      check(dist.probability(2)).equals(0.0);

      check(dist.logProbability(-2)).equals(double.negativeInfinity);
      check(dist.logProbability(-1)).isCloseTo(-math.ln2, 1e-12);
      check(dist.logProbability(0)).equals(double.negativeInfinity);
      check(dist.logProbability(1)).isCloseTo(-math.ln2, 1e-12);
      check(dist.logProbability(2)).equals(double.negativeInfinity);
    });

    test('cumulativeProbability and survival', () {
      check(dist.cumulativeProbability(-2)).equals(0.0);
      check(dist.cumulativeProbability(-1)).equals(0.5);
      check(dist.cumulativeProbability(0)).equals(0.5);
      check(dist.cumulativeProbability(1)).equals(1.0);
      check(dist.cumulativeProbability(2)).equals(1.0);

      check(dist.survival(-2)).equals(1.0);
      check(dist.survival(-1)).equals(0.5);
      check(dist.survival(0)).equals(0.5);
      check(dist.survival(1)).equals(0.0);
      check(dist.survival(2)).equals(0.0);
    });

    test('inverseCumulativeProbability and inverseSurvival', () {
      check(dist.inverseCumulativeProbability(0.0)).equals(-1);
      check(dist.inverseCumulativeProbability(0.5)).equals(-1);
      check(dist.inverseCumulativeProbability(0.51)).equals(1);
      check(dist.inverseCumulativeProbability(1.0)).equals(1);

      check(dist.inverseSurvival(1.0)).equals(-1);
      check(dist.inverseSurvival(0.5)).equals(-1);
      check(dist.inverseSurvival(0.49)).equals(1);
      check(dist.inverseSurvival(0.0)).equals(1);

      check(() => dist.inverseCumulativeProbability(-0.1))
          .throws<InvalidProbability>();
      check(() => dist.inverseSurvival(1.1)).throws<InvalidProbability>();
    });
  });

  group('RademacherDistribution sampling, fitting, and equality', () {
    test('samples emit -1 or 1', () {
      final single = dist.sample();
      check(single == -1 || single == 1).isTrue;
      final samples = dist.samples(random: math.Random(42)).take(100).toList();
      check(samples.every((x) => x == -1 || x == 1)).isTrue;
    });

    test('fit accepts +/-1 samples and rejects others', () {
      check(RademacherDistribution.fit(const [-1, 1, -1, 1])).equals(dist);
      check(() => RademacherDistribution.fit(const [])).throws<ArgumentError>();
      check(() => RademacherDistribution.fit(const [-1, 0, 1]))
          .throws<ArgumentError>();
    });

    test('equality, hashCode, and string representation', () {
      check(dist == const RademacherDistribution()).isTrue;
      check(dist.hashCode).equals(const RademacherDistribution().hashCode);
      check(dist.toString()).contains('RademacherDistribution');
    });
  });
}
