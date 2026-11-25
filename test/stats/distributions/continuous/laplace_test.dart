import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/stats.dart';
import 'package:test/scaffolding.dart';

void main() {
  const standard = LaplaceDistribution.standard();
  final shifted = LaplaceDistribution(2.0, 3.0);

  group('LaplaceDistribution moments and bounds', () {
    test('parameters, bounds, and moments', () {
      check(standard.location).equals(0.0);
      check(standard.scale).equals(1.0);
      check(shifted.location).equals(2.0);
      check(shifted.scale).equals(3.0);
      check(shifted.lowerBound).equals(double.negativeInfinity);
      check(shifted.upperBound).equals(double.infinity);
      check(shifted.isLowerBoundOpen).isTrue;
      check(shifted.isUpperBoundOpen).isTrue;
      check(shifted.mean).equals(2.0);
      check(shifted.median).equals(2.0);
      check(shifted.mode).equals(2.0);
      check(shifted.variance).equals(18.0);
      check(shifted.standardDeviation).isCloseTo(math.sqrt(18.0), 1e-12);
      check(shifted.skewness).equals(0.0);
      check(shifted.excessKurtosis).equals(3.0);
    });
  });

  group('LaplaceDistribution probabilities', () {
    test('probability and logProbability handle center, tails, and NaN', () {
      check(standard.probability(0.0)).equals(0.5);
      check(standard.logProbability(0.0)).isCloseTo(-math.ln2, 1e-12);
      check(shifted.probability(2.0)).isCloseTo(1.0 / 6.0, 1e-12);
      check(shifted.logProbability(5.0)).isCloseTo(-math.log(6.0) - 1.0, 1e-12);
      check(standard.probability(double.infinity)).equals(0.0);
      check(standard.logProbability(double.infinity))
          .equals(double.negativeInfinity);
      check(standard.probability(double.nan).isNaN).isTrue;
      check(standard.logProbability(double.nan).isNaN).isTrue;
    });

    test(
      'cumulativeProbability and survival are symmetric and complementary',
      () {
        check(standard.cumulativeProbability(0.0)).equals(0.5);
        check(standard.survival(0.0)).equals(0.5);
        check(standard.cumulativeProbability(-100.0)).isGreaterThan(0.0);
        check(standard.survival(100.0)).isGreaterThan(0.0);
        check(standard.cumulativeProbability(-100.0))
            .equals(standard.survival(100.0));
        check(shifted.cumulativeProbability(3.0) + shifted.survival(3.0))
            .isCloseTo(1.0, 1e-14);
        check(standard.cumulativeProbability(double.nan).isNaN).isTrue;
        check(standard.survival(double.nan).isNaN).isTrue;
      },
    );

    test('inverseCumulativeProbability and inverseSurvival round-trips', () {
      check(standard.inverseCumulativeProbability(0.0))
          .equals(double.negativeInfinity);
      check(standard.inverseCumulativeProbability(0.5)).equals(0.0);
      check(standard.inverseCumulativeProbability(1.0)).equals(double.infinity);
      check(standard.inverseSurvival(0.0)).equals(double.infinity);
      check(standard.inverseSurvival(0.5)).equals(0.0);
      check(standard.inverseSurvival(1.0)).equals(double.negativeInfinity);

      for (final p in const [1e-12, 0.2, 0.8, 1.0 - 1e-12]) {
        final x = shifted.inverseCumulativeProbability(p);
        check(shifted.cumulativeProbability(x)).isCloseTo(p, 1e-12);
        final xs = shifted.inverseSurvival(p);
        check(shifted.survival(xs)).isCloseTo(p, 1e-12);
      }

      check(() => standard.inverseCumulativeProbability(-0.1))
          .throws<InvalidProbability>();
      check(() => standard.inverseSurvival(1.1)).throws<InvalidProbability>();
    });
  });

  group('LaplaceDistribution sampling, fitting, and validation', () {
    test('samples are finite and match theoretical mean', () {
      check(standard.sample().isFinite).isTrue;
      final samples = shifted
          .samples(random: math.Random(42))
          .take(2000)
          .toList();
      final sampleMean = samples.reduce((a, b) => a + b) / samples.length;
      check(sampleMean).isCloseTo(2.0, 0.3);
      check(samples.every((x) => x.isFinite)).isTrue;
    });

    test('fit estimates MLE location and scale for odd, even, and constant samples', () {
      final odd = LaplaceDistribution.fit(const [0.0, 1.0, 2.0, 3.0, 4.0]);
      check(odd.location).equals(2.0);
      check(odd.scale).equals(1.2);

      final even = LaplaceDistribution.fit(const [0.0, 1.0, 3.0, 4.0]);
      check(even.location).equals(2.0);
      check(even.scale).equals(1.5);

      final constantFit = LaplaceDistribution.fit(const [3.0, 3.0]);
      check(constantFit.location).equals(3.0);
      check(constantFit.scale).isGreaterThan(0.0);

      check(() => LaplaceDistribution.fit(const [])).throws<ArgumentError>();
      check(() => LaplaceDistribution.fit(const [1.0, double.nan]))
          .throws<ArgumentError>();
    });

    test('constructor validation', () {
      check(() => LaplaceDistribution(double.nan, 1.0)).throws<ArgumentError>();
      check(() => LaplaceDistribution(0.0, 0.0)).throws<ArgumentError>();
      check(() => LaplaceDistribution(0.0, -1.0)).throws<ArgumentError>();
      check(() => LaplaceDistribution(0.0, double.infinity))
          .throws<ArgumentError>();
    });

    test('equality, hashCode, and string representation', () {
      check(standard == LaplaceDistribution(0.0, 1.0)).isTrue;
      check(standard.hashCode).equals(LaplaceDistribution(0.0, 1.0).hashCode);
      check(standard == shifted).isFalse;
      check(shifted.toString()).contains('LaplaceDistribution');
    });
  });
}
