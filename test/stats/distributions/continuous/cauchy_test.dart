import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/stats.dart';
import 'package:test/scaffolding.dart';

void main() {
  const standard = CauchyDistribution.standard();
  final shifted = CauchyDistribution(2.0, 3.0);

  group('CauchyDistribution moments and bounds', () {
    test('parameters, bounds, and defined vs undefined moments', () {
      check(shifted.location).equals(2.0);
      check(shifted.scale).equals(3.0);
      check(shifted.lowerBound).equals(double.negativeInfinity);
      check(shifted.upperBound).equals(double.infinity);
      check(shifted.isLowerBoundOpen).isTrue;
      check(shifted.isUpperBoundOpen).isTrue;
      check(shifted.mean.isNaN).isTrue;
      check(shifted.median).equals(2.0);
      check(shifted.mode).equals(2.0);
      check(shifted.variance.isNaN).isTrue;
      check(shifted.standardDeviation.isNaN).isTrue;
      check(shifted.skewness.isNaN).isTrue;
      check(shifted.excessKurtosis.isNaN).isTrue;
    });
  });

  group('CauchyDistribution probabilities', () {
    test('probability and logProbability handle center, tails, and NaN', () {
      check(standard.probability(0.0)).isCloseTo(1.0 / math.pi, 1e-12);
      check(standard.logProbability(0.0)).isCloseTo(-math.log(math.pi), 1e-12);
      check(shifted.probability(2.0)).isCloseTo(1.0 / (3.0 * math.pi), 1e-12);

      // Overflow-safe extreme evaluation.
      check(standard.probability(1e200)).equals(0.0);
      final logTail = standard.logProbability(1e200);
      check(logTail.isFinite).isTrue;
      check(logTail).isLessThan(-900.0);
      check(standard.probability(double.infinity)).equals(0.0);
      check(standard.logProbability(double.infinity))
          .equals(double.negativeInfinity);
      check(standard.probability(double.nan).isNaN).isTrue;
      check(standard.logProbability(double.nan).isNaN).isTrue;
    });

    test('cumulativeProbability and survival retain deep tail precision', () {
      check(standard.cumulativeProbability(0.0)).equals(0.5);
      check(standard.survival(0.0)).equals(0.5);
      check(shifted.cumulativeProbability(5.0)).isCloseTo(0.75, 1e-12);
      check(shifted.survival(5.0)).isCloseTo(0.25, 1e-12);
      check(standard.cumulativeProbability(double.negativeInfinity))
          .equals(0.0);
      check(standard.cumulativeProbability(double.infinity)).equals(1.0);
      check(standard.survival(double.negativeInfinity)).equals(1.0);
      check(standard.survival(double.infinity)).equals(0.0);
      check(standard.survival(1e12)).isCloseTo(1.0 / (math.pi * 1e12), 1e-16);
      check(standard.cumulativeProbability(-1e12))
          .isCloseTo(1.0 / (math.pi * 1e12), 1e-16);
      check(standard.cumulativeProbability(double.nan).isNaN).isTrue;
      check(standard.survival(double.nan).isNaN).isTrue;
    });

    test('inverseCumulativeProbability and inverseSurvival round-trips', () {
      check(standard.inverseCumulativeProbability(0.0))
          .equals(double.negativeInfinity);
      check(standard.inverseCumulativeProbability(0.5)).equals(0.0);
      check(standard.inverseCumulativeProbability(1.0)).equals(double.infinity);
      check(standard.inverseSurvival(0.0)).equals(double.infinity);
      check(standard.inverseSurvival(0.5)).equals(0.0);
      check(standard.inverseSurvival(1.0)).equals(double.negativeInfinity);
      check(shifted.inverseCumulativeProbability(0.75)).isCloseTo(5.0, 1e-12);
      check(shifted.inverseSurvival(0.25)).isCloseTo(5.0, 1e-12);
      check(standard.inverseCumulativeProbability(0.1))
          .isCloseTo(-1.0 / math.tan(math.pi * 0.1), 1e-12);
      check(standard.inverseSurvival(0.1))
          .isCloseTo(1.0 / math.tan(math.pi * 0.1), 1e-12);

      check(() => standard.inverseCumulativeProbability(-0.1))
          .throws<InvalidProbability>();
      check(() => standard.inverseSurvival(1.1)).throws<InvalidProbability>();
    });
  });

  group('CauchyDistribution sampling, fitting, and validation', () {
    test('sample produces finite values with centered sample median', () {
      check(standard.sample().isFinite).isTrue;
      final samples =
          shifted.samples(random: math.Random(42)).take(500).toList()..sort();
      check(samples.every((x) => x.isFinite)).isTrue;
      check(samples[samples.length ~/ 2]).isCloseTo(2.0, 0.5);
    });

    test('fit estimates location and scale for odd and even sample counts', () {
      final fittedEven = CauchyDistribution.fit(const [-3.0, -1.0, 1.0, 3.0]);
      check(fittedEven.location).equals(0.0);
      check(fittedEven.scale).isGreaterThan(0.0);

      final fittedOdd = CauchyDistribution.fit(const [1.0, 2.0, 3.0, 4.0, 5.0]);
      check(fittedOdd.location).equals(3.0);
      check(fittedOdd.scale).equals(1.0);

      final fittedConstant = CauchyDistribution.fit(const [4.0, 4.0, 4.0]);
      check(fittedConstant.location).equals(4.0);
      check(fittedConstant.scale).equals(1.0);
    });

    test('fit rejects empty or non-finite samples', () {
      check(() => CauchyDistribution.fit(const [])).throws<ArgumentError>();
      check(() => CauchyDistribution.fit(const [1.0, double.nan]))
          .throws<ArgumentError>();
      check(() => CauchyDistribution.fit(const [1.0, double.infinity]))
          .throws<ArgumentError>();
    });

    test('constructor validation', () {
      check(() => CauchyDistribution(double.nan, 1.0)).throws<ArgumentError>();
      check(() => CauchyDistribution(0.0, 0.0)).throws<ArgumentError>();
      check(() => CauchyDistribution(0.0, -1.0)).throws<ArgumentError>();
      check(() => CauchyDistribution(0.0, double.infinity))
          .throws<ArgumentError>();
    });

    test('equality, hashCode, and string representation', () {
      check(standard == CauchyDistribution(0.0, 1.0)).isTrue;
      check(standard.hashCode).equals(CauchyDistribution(0.0, 1.0).hashCode);
      check(standard == shifted).isFalse;
      check(shifted.toString()).contains('CauchyDistribution');
    });
  });
}
