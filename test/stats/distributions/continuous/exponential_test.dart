import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/stats.dart';
import 'package:test/scaffolding.dart';

void main() {
  const standard = ExponentialDistribution.standard();
  final dist = ExponentialDistribution(2.0);

  group('ExponentialDistribution moments and bounds', () {
    test('parameters, bounds, and moments', () {
      check(standard.rate).equals(1.0);
      check(dist.rate).equals(2.0);
      check(dist.lowerBound).equals(0.0);
      check(dist.upperBound).equals(double.infinity);
      check(dist.isLowerBoundOpen).isFalse;
      check(dist.isUpperBoundOpen).isTrue;
      check(dist.mean).equals(0.5);
      check(dist.median).isCloseTo(math.ln2 / 2.0, 1e-12);
      check(dist.mode).equals(0.0);
      check(dist.variance).equals(0.25);
      check(dist.standardDeviation).equals(0.5);
      check(dist.skewness).equals(2.0);
      check(dist.excessKurtosis).equals(6.0);
    });
  });

  group('ExponentialDistribution probabilities', () {
    test('probability and logProbability', () {
      check(dist.probability(-0.1)).equals(0.0);
      check(dist.probability(0.0)).equals(2.0);
      check(dist.probability(1.0)).isCloseTo(2.0 * math.exp(-2.0), 1e-12);
      check(dist.probability(double.infinity)).equals(0.0);
      check(dist.probability(double.nan).isNaN).isTrue;

      check(dist.logProbability(-0.1)).equals(double.negativeInfinity);
      check(dist.logProbability(0.0)).isCloseTo(math.ln2, 1e-12);
      check(dist.logProbability(1.0)).isCloseTo(math.ln2 - 2.0, 1e-12);
      check(dist.logProbability(double.nan).isNaN).isTrue;
    });

    test('cumulativeProbability and survival retain upper-tail precision', () {
      check(dist.cumulativeProbability(-1.0)).equals(0.0);
      check(dist.cumulativeProbability(0.0)).equals(0.0);
      check(dist.cumulativeProbability(1.0))
          .isCloseTo(1.0 - math.exp(-2.0), 1e-12);
      check(dist.cumulativeProbability(1e-12)).isCloseTo(2e-12, 1e-22);
      check(dist.survival(-1.0)).equals(1.0);
      check(dist.survival(0.0)).equals(1.0);
      check(dist.survival(50.0)).isCloseTo(math.exp(-100.0), 1e-55);
      check(dist.cumulativeProbability(double.nan).isNaN).isTrue;
      check(dist.survival(double.nan).isNaN).isTrue;
    });

    test('inverseCumulativeProbability and inverseSurvival', () {
      check(dist.inverseCumulativeProbability(0.0)).equals(0.0);
      check(dist.inverseCumulativeProbability(0.5))
          .isCloseTo(dist.median, 1e-12);
      check(dist.inverseCumulativeProbability(1.0)).equals(double.infinity);
      check(dist.inverseSurvival(1.0)).equals(0.0);
      check(dist.inverseSurvival(0.0)).equals(double.infinity);
      check(dist.inverseSurvival(1e-20))
          .isCloseTo(-math.log(1e-20) / 2.0, 1e-12);

      check(() => dist.inverseCumulativeProbability(-0.1))
          .throws<InvalidProbability>();
      check(() => dist.inverseSurvival(1.1)).throws<InvalidProbability>();
    });
  });

  group('ExponentialDistribution sampling, fitting, and validation', () {
    test('samples match theoretical mean', () {
      final samples = dist.samples(random: math.Random(42)).take(2000).toList();
      final sampleMean = samples.reduce((a, b) => a + b) / samples.length;
      check(sampleMean).isCloseTo(0.5, 0.03);
      check(samples.every((x) => x.isFinite && x >= 0.0)).isTrue;
    });

    test('fit estimates MLE rate and rejects invalid samples', () {
      final fitted = ExponentialDistribution.fit(const [0.0, 1.0, 1.0]);
      check(fitted.rate).isCloseTo(1.5, 1e-12);
      final zeroFit = ExponentialDistribution.fit(const [0.0, 0.0]);
      check(zeroFit.rate).equals(1.0);

      check(() => ExponentialDistribution.fit(const []))
          .throws<ArgumentError>();
      check(() => ExponentialDistribution.fit(const [-0.1, 1.0]))
          .throws<ArgumentError>();
    });

    test('constructor validation', () {
      check(() => ExponentialDistribution(0.0)).throws<ArgumentError>();
      check(() => ExponentialDistribution(-1.0)).throws<ArgumentError>();
      check(() => ExponentialDistribution(double.infinity))
          .throws<ArgumentError>();
    });

    test('equality, hashCode, and string representation', () {
      check(standard == ExponentialDistribution(1.0)).isTrue;
      check(standard.hashCode).equals(ExponentialDistribution(1.0).hashCode);
      check(standard == dist).isFalse;
      check(dist.toString()).contains('ExponentialDistribution');
    });
  });
}
