import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/stats.dart';
import 'package:test/scaffolding.dart';

void main() {
  const standard = NormalDistribution.standard();
  final shifted = NormalDistribution(3.0, 2.0);

  group('NormalDistribution moments and bounds', () {
    test('parameters, bounds, and moments', () {
      check(standard.mean).equals(0.0);
      check(standard.standardDeviation).equals(1.0);
      check(standard.variance).equals(1.0);
      check(standard.median).equals(0.0);
      check(standard.mode).equals(0.0);
      check(standard.skewness).equals(0.0);
      check(standard.excessKurtosis).equals(0.0);
      check(standard.lowerBound).equals(double.negativeInfinity);
      check(standard.upperBound).equals(double.infinity);
      check(standard.isLowerBoundOpen).isTrue;
      check(standard.isUpperBoundOpen).isTrue;
      check(shifted.variance).equals(4.0);
    });
  });

  group('NormalDistribution probabilities', () {
    test('probability and logProbability at center, tails, and NaN', () {
      check(standard.probability(0.0))
          .isCloseTo(1.0 / math.sqrt(2.0 * math.pi), 1e-12);
      check(standard.logProbability(0.0))
          .isCloseTo(-0.5 * math.log(2.0 * math.pi), 1e-12);
      check(
        shifted.logProbability(5.0),
      ).isCloseTo(-math.log(2.0) - 0.5 * math.log(2.0 * math.pi) - 0.5, 1e-12);
      check(standard.probability(double.infinity)).equals(0.0);
      check(standard.logProbability(double.infinity))
          .equals(double.negativeInfinity);
      check(standard.probability(double.nan).isNaN).isTrue;
      check(standard.logProbability(double.nan).isNaN).isTrue;
    });

    test('cumulativeProbability and survival retain deep tail accuracy', () {
      check(standard.cumulativeProbability(0.0)).isCloseTo(0.5, 1e-12);
      check(standard.survival(0.0)).isCloseTo(0.5, 1e-12);
      check(standard.cumulativeProbability(1.96))
          .isCloseTo(0.9750021048517795, 1e-12);
      check(standard.survival(1.96)).isCloseTo(1.0 - 0.9750021048517795, 1e-12);
      check(standard.cumulativeProbability(-10.0)).isGreaterThan(0.0);
      check(standard.survival(10.0)).isGreaterThan(0.0);
      check(standard.cumulativeProbability(double.nan).isNaN).isTrue;
      check(standard.survival(double.nan).isNaN).isTrue;
    });

    test('inverseCumulativeProbability and inverseSurvival stay accurate in deep tails', () {
      check(standard.inverseCumulativeProbability(0.0))
          .equals(double.negativeInfinity);
      check(standard.inverseCumulativeProbability(0.5)).isCloseTo(0.0, 1e-12);
      check(standard.inverseCumulativeProbability(1.0)).equals(double.infinity);
      check(standard.inverseSurvival(0.0)).equals(double.infinity);
      check(standard.inverseSurvival(0.5)).isCloseTo(0.0, 1e-12);
      check(standard.inverseSurvival(1.0)).equals(double.negativeInfinity);
      check(standard.inverseCumulativeProbability(1e-20)).isLessThan(-8.0);
      check(standard.inverseSurvival(1e-20)).isGreaterThan(8.0);
      check(shifted.inverseSurvival(0.025))
          .isCloseTo(3.0 + 2.0 * 1.959963984540054, 1e-9);

      check(() => standard.inverseCumulativeProbability(-0.1))
          .throws<InvalidProbability>();
      check(() => standard.inverseSurvival(1.1)).throws<InvalidProbability>();
    });
  });

  group('NormalDistribution sampling, fitting, and validation', () {
    test('samples match theoretical moments', () {
      check(standard.sample().isFinite).isTrue;
      check(standard.samples().take(5).every((x) => x.isFinite)).isTrue;
      final samples = shifted
          .samples(random: math.Random(42))
          .take(2000)
          .toList();
      final fitted = NormalDistribution.fit(samples);
      check(fitted.mean).isCloseTo(3.0, 0.15);
      check(fitted.standardDeviation).isCloseTo(2.0, 0.15);
    });

    test('fit recovers parameters and handles invalid samples', () {
      final fittedSame = NormalDistribution.fit(const [5.0, 5.0]);
      check(fittedSame.mean).equals(5.0);
      check(fittedSame.standardDeviation).equals(1e-15);

      check(() => NormalDistribution.fit(const [1.0])).throws<ArgumentError>();
      check(() => NormalDistribution.fit(const [1.0, double.nan]))
          .throws<ArgumentError>();
      check(() => NormalDistribution.fit(const [1.0, double.infinity]))
          .throws<ArgumentError>();
    });

    test('constructor validation', () {
      check(() => NormalDistribution(double.nan, 1.0)).throws<ArgumentError>();
      check(() => NormalDistribution(0.0, 0.0)).throws<ArgumentError>();
      check(() => NormalDistribution(0.0, -1.0)).throws<ArgumentError>();
      check(() => NormalDistribution(0.0, double.infinity))
          .throws<ArgumentError>();
    });

    test('equality, hashCode, and string representation', () {
      check(standard == NormalDistribution(0.0, 1.0)).isTrue;
      check(standard.hashCode).equals(NormalDistribution(0.0, 1.0).hashCode);
      check(standard == shifted).isFalse;
      check(shifted.toString()).contains('NormalDistribution');
    });
  });
}
