import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/stats.dart';
import 'package:test/scaffolding.dart';

void main() {
  const standard = LogNormalDistribution.standard();
  final shifted = LogNormalDistribution(1.0, 0.5);

  group('LogNormalDistribution moments and bounds', () {
    test('parameters, bounds, and moments', () {
      check(standard.mu).equals(0.0);
      check(standard.sigma).equals(1.0);
      check(standard.lowerBound).equals(0.0);
      check(standard.upperBound).equals(double.infinity);
      check(standard.isLowerBoundOpen).isFalse;
      check(standard.isUpperBoundOpen).isTrue;
      check(standard.mean).isCloseTo(math.exp(0.5), 1e-12);
      check(standard.median).equals(1.0);
      check(standard.mode).isCloseTo(math.exp(-1.0), 1e-12);
      check(standard.variance).isCloseTo((math.e - 1.0) * math.e, 1e-12);
      check(standard.standardDeviation)
          .isCloseTo(math.sqrt((math.e - 1.0) * math.e), 1e-12);
      check(standard.skewness)
          .isCloseTo((math.e + 2.0) * math.sqrt(math.e - 1.0), 1e-12);
      check(standard.excessKurtosis).isCloseTo(
        math.exp(4.0) + 2.0 * math.exp(3.0) + 3.0 * math.exp(2.0) - 6.0,
        1e-11,
      );
    });
  });

  group('LogNormalDistribution probabilities', () {
    test('probability and logProbability handle boundary and NaN', () {
      check(standard.probability(-1.0)).equals(0.0);
      check(standard.probability(0.0)).equals(0.0);
      check(standard.probability(double.infinity)).equals(0.0);
      check(standard.logProbability(-1.0)).equals(double.negativeInfinity);
      check(standard.logProbability(0.0)).equals(double.negativeInfinity);
      check(standard.logProbability(double.infinity))
          .equals(double.negativeInfinity);
      check(standard.probability(1.0))
          .isCloseTo(1.0 / math.sqrt(2.0 * math.pi), 1e-12);
      check(standard.logProbability(1.0))
          .isCloseTo(-0.5 * math.log(2.0 * math.pi), 1e-12);
      check(standard.probability(double.nan).isNaN).isTrue;
      check(standard.logProbability(double.nan).isNaN).isTrue;
    });

    test('cumulativeProbability and survival retain deep tail precision', () {
      check(standard.cumulativeProbability(-1.0)).equals(0.0);
      check(standard.cumulativeProbability(0.0)).equals(0.0);
      check(standard.cumulativeProbability(1.0)).isCloseTo(0.5, 1e-12);
      check(standard.survival(0.0)).equals(1.0);
      check(standard.survival(1.0)).isCloseTo(0.5, 1e-12);
      check(standard.survival(1e6)).isGreaterThan(0.0);
      check(shifted.cumulativeProbability(2.0) + shifted.survival(2.0))
          .isCloseTo(1.0, 1e-14);
      check(standard.cumulativeProbability(double.nan).isNaN).isTrue;
      check(standard.survival(double.nan).isNaN).isTrue;
    });

    test('inverseCumulativeProbability and inverseSurvival round-trips', () {
      check(standard.inverseCumulativeProbability(0.0)).equals(0.0);
      check(standard.inverseCumulativeProbability(0.5)).isCloseTo(1.0, 1e-12);
      check(standard.inverseCumulativeProbability(1.0)).equals(double.infinity);
      check(standard.inverseSurvival(1.0)).equals(0.0);
      check(standard.inverseSurvival(0.0)).equals(double.infinity);
      check(standard.inverseSurvival(1e-20).isFinite).isTrue;
      check(shifted.inverseSurvival(0.9))
          .isCloseTo(shifted.inverseCumulativeProbability(0.1), 1e-11);

      for (final p in const [1e-12, 0.1, 0.5, 0.9, 1.0 - 1e-12]) {
        final x = shifted.inverseCumulativeProbability(p);
        check(shifted.cumulativeProbability(x)).isCloseTo(p, 1e-11);
      }

      check(() => standard.inverseCumulativeProbability(-0.1))
          .throws<InvalidProbability>();
      check(() => standard.inverseSurvival(1.1)).throws<InvalidProbability>();
    });
  });

  group('LogNormalDistribution sampling, fitting, and validation', () {
    test('samples are positive and match median', () {
      check(standard.sample()).isGreaterThan(0.0);
      final samples =
          shifted.samples(random: math.Random(42)).take(2000).toList()..sort();
      check(samples.every((x) => x > 0.0 && x.isFinite)).isTrue;
      check(samples[samples.length ~/ 2]).isCloseTo(shifted.median, 0.2);
    });

    test('fit recovers parameters and handles invalid/constant samples', () {
      final fitted = LogNormalDistribution.fit(const [
        1.0,
        math.e,
        math.e * math.e,
      ]);
      check(fitted.mu).isCloseTo(1.0, 1e-12);
      check(fitted.sigma).isCloseTo(1.0, 1e-12);

      final constantFit = LogNormalDistribution.fit(const [2.0, 2.0]);
      check(constantFit.mu).isCloseTo(math.ln2, 1e-12);
      check(constantFit.sigma).equals(1.0);

      final singleFit = LogNormalDistribution.fit(const [1.0]);
      check(singleFit.mu).equals(0.0);
      check(singleFit.sigma).equals(1.0);

      check(() => LogNormalDistribution.fit(const [])).throws<ArgumentError>();
      check(() => LogNormalDistribution.fit(const [0.0, 1.0]))
          .throws<ArgumentError>();
      check(() => LogNormalDistribution.fit(const [-1.0, 2.0]))
          .throws<ArgumentError>();
    });

    test('constructor validation', () {
      check(() => LogNormalDistribution(double.infinity, 1.0))
          .throws<ArgumentError>();
      check(() => LogNormalDistribution(0.0, 0.0)).throws<ArgumentError>();
      check(() => LogNormalDistribution(0.0, -1.0)).throws<ArgumentError>();
      check(() => LogNormalDistribution(0.0, double.nan))
          .throws<ArgumentError>();
    });

    test('equality, hashCode, and string representation', () {
      check(standard == LogNormalDistribution(0.0, 1.0)).isTrue;
      check(standard.hashCode).equals(LogNormalDistribution(0.0, 1.0).hashCode);
      check(standard == shifted).isFalse;
      check(shifted.toString()).contains('LogNormalDistribution');
    });
  });
}
