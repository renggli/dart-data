import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/stats.dart';
import 'package:test/scaffolding.dart';

void main() {
  const standard = LogisticDistribution.standard();
  final shifted = LogisticDistribution(2.0, 3.0);

  group('LogisticDistribution moments and bounds', () {
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
      check(shifted.variance).isCloseTo(math.pi * math.pi * 3.0, 1e-12);
      check(shifted.skewness).equals(0.0);
      check(shifted.excessKurtosis).equals(1.2);
    });
  });

  group('LogisticDistribution probabilities', () {
    test('probability and logProbability stay finite in extreme tails', () {
      check(standard.probability(0.0)).equals(0.25);
      check(standard.logProbability(0.0)).isCloseTo(-2.0 * math.ln2, 1e-12);
      check(standard.probability(1000.0)).equals(0.0);
      check(standard.logProbability(1000.0)).isCloseTo(-1000.0, 1e-12);
      check(standard.logProbability(-1000.0)).isCloseTo(-1000.0, 1e-12);
      check(standard.probability(double.infinity)).equals(0.0);
      check(standard.logProbability(double.infinity))
          .equals(double.negativeInfinity);
      check(standard.probability(double.nan).isNaN).isTrue;
      check(standard.logProbability(double.nan).isNaN).isTrue;
    });

    test(
      'cumulativeProbability and survival preserve extreme tail accuracy',
      () {
        check(standard.cumulativeProbability(0.0)).equals(0.5);
        check(standard.survival(0.0)).equals(0.5);
        check(standard.cumulativeProbability(-100.0))
            .isCloseTo(math.exp(-100.0), 1e-55);
        check(standard.survival(100.0)).isCloseTo(math.exp(-100.0), 1e-55);
        check(shifted.cumulativeProbability(4.0) + shifted.survival(4.0))
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

      for (final p in const [1e-12, 0.25, 0.75, 1.0 - 1e-12]) {
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

  group('LogisticDistribution sampling, fitting, and validation', () {
    test('samples are finite and match theoretical mean', () {
      check(standard.sample().isFinite).isTrue;
      final samples = shifted
          .samples(random: math.Random(42))
          .take(2000)
          .toList();
      final sampleMean = samples.reduce((a, b) => a + b) / samples.length;
      check(sampleMean).isCloseTo(2.0, 0.4);
      check(samples.every((x) => x.isFinite)).isTrue;
    });

    test('fit estimates location and scale and validates inputs', () {
      final fitted = LogisticDistribution.fit(const [-2.0, 0.0, 2.0]);
      check(fitted.location).equals(0.0);
      check(fitted.scale).isCloseTo(2.0 * math.sqrt(3.0) / math.pi, 1e-12);

      final constantFit = LogisticDistribution.fit(const [1.0, 1.0]);
      check(constantFit.location).equals(1.0);
      check(constantFit.scale).isGreaterThan(0.0);

      final singleFit = LogisticDistribution.fit(const [1.0]);
      check(singleFit.location).equals(1.0);
      check(singleFit.scale).equals(1.0);

      check(() => LogisticDistribution.fit(const [])).throws<ArgumentError>();
      check(() => LogisticDistribution.fit(const [1.0, double.nan]))
          .throws<ArgumentError>();
    });

    test('constructor validation', () {
      check(() => LogisticDistribution(double.nan, 1.0))
          .throws<ArgumentError>();
      check(() => LogisticDistribution(0.0, 0.0)).throws<ArgumentError>();
      check(() => LogisticDistribution(0.0, -1.0)).throws<ArgumentError>();
      check(() => LogisticDistribution(0.0, double.infinity))
          .throws<ArgumentError>();
    });

    test('equality, hashCode, and string representation', () {
      check(standard == LogisticDistribution(0.0, 1.0)).isTrue;
      check(standard.hashCode).equals(LogisticDistribution(0.0, 1.0).hashCode);
      check(standard == shifted).isFalse;
      check(shifted.toString()).contains('LogisticDistribution');
    });
  });
}
