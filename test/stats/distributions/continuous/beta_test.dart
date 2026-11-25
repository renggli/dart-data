import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/stats.dart';
import 'package:test/scaffolding.dart';

void main() {
  final beta = BetaDistribution(2.0, 5.0);

  group('BetaDistribution moments and bounds', () {
    test('parameters and support bounds', () {
      check(beta.alpha).equals(2.0);
      check(beta.beta).equals(5.0);
      check(beta.lowerBound).equals(0.0);
      check(beta.upperBound).equals(1.0);
      check(beta.isLowerBoundOpen).isFalse;
      check(beta.isUpperBoundOpen).isFalse;
      check(BetaDistribution(1.0, 2.0).isLowerBoundOpen).isFalse;
      check(BetaDistribution(2.0, 1.0).isUpperBoundOpen).isFalse;
    });

    test('mean, variance, skewness, and excessKurtosis', () {
      check(beta.mean).isCloseTo(2.0 / 7.0, 1e-12);
      check(beta.variance).isCloseTo(10.0 / (49.0 * 8.0), 1e-12);
      check(beta.standardDeviation).isCloseTo(math.sqrt(10.0 / 392.0), 1e-12);
      check(beta.skewness).isCloseTo(0.5962847939999439, 1e-12);
      check(beta.excessKurtosis).isCloseTo(-0.12, 1e-12);
    });

    test('median across symmetric and asymmetric shapes', () {
      check(BetaDistribution(3.0, 3.0).median).equals(0.5);
      check(beta.median).isCloseTo(0.26444998329566, 1e-6);
    });

    test('mode across shape regimes and endpoints', () {
      check(beta.mode).isCloseTo(1.0 / 5.0, 1e-12);
      check(BetaDistribution(1.0, 1.0).mode.isNaN).isTrue;
      check(BetaDistribution(0.5, 0.5).mode.isNaN).isTrue;
      check(BetaDistribution(0.5, 2.0).mode).equals(0.0);
      check(BetaDistribution(1.0, 3.0).mode).equals(0.0);
      check(BetaDistribution(2.0, 0.5).mode).equals(1.0);
      check(BetaDistribution(3.0, 1.0).mode).equals(1.0);
    });
  });

  group('BetaDistribution probabilities', () {
    test('probability and logProbability on interior and boundaries', () {
      check(beta.probability(0.25)).isCloseTo(2.373046875, 1e-12);
      check(beta.logProbability(0.25))
          .isCloseTo(math.log(beta.probability(0.25)), 1e-12);
      check(beta.probability(-0.1)).equals(0.0);
      check(beta.probability(1.1)).equals(0.0);
      check(beta.logProbability(-0.1)).equals(double.negativeInfinity);
      check(beta.logProbability(1.1)).equals(double.negativeInfinity);
      check(beta.probability(double.nan).isNaN).isTrue;
      check(beta.logProbability(double.nan).isNaN).isTrue;

      final uniform = BetaDistribution(1.0, 1.0);
      check(uniform.probability(0.0)).equals(1.0);
      check(uniform.probability(1.0)).equals(1.0);

      final uShaped = BetaDistribution(0.5, 0.5);
      check(uShaped.probability(0.0)).equals(double.infinity);
      check(uShaped.logProbability(0.0)).equals(double.infinity);
      check(uShaped.probability(1.0)).equals(double.infinity);
      check(uShaped.logProbability(1.0)).equals(double.infinity);

      check(BetaDistribution(2.0, 2.0).probability(0.0)).equals(0.0);
      check(BetaDistribution(2.0, 2.0).probability(1.0)).equals(0.0);
    });

    test('cumulativeProbability and survival complementarity', () {
      check(beta.cumulativeProbability(-0.1)).equals(0.0);
      check(beta.cumulativeProbability(0.0)).equals(0.0);
      check(beta.cumulativeProbability(1.0)).equals(1.0);
      check(beta.cumulativeProbability(1.1)).equals(1.0);
      check(beta.cumulativeProbability(0.5)).isCloseTo(0.890625, 1e-12);
      check(beta.survival(0.5)).isCloseTo(0.109375, 1e-12);
      check(beta.cumulativeProbability(0.3) + beta.survival(0.3))
          .isCloseTo(1.0, 1e-14);
      check(beta.survival(0.9999)).isGreaterThan(0.0);
      check(beta.cumulativeProbability(double.nan).isNaN).isTrue;
      check(beta.survival(double.nan).isNaN).isTrue;
    });

    test('inverseCumulativeProbability and inverseSurvival round-trips', () {
      check(beta.inverseCumulativeProbability(0.0)).equals(0.0);
      check(beta.inverseCumulativeProbability(1.0)).equals(1.0);
      check(beta.inverseSurvival(1.0)).equals(0.0);
      check(beta.inverseSurvival(0.0)).equals(1.0);

      for (final p in const [0.001, 0.1, 0.5, 0.9, 0.999]) {
        final x = beta.inverseCumulativeProbability(p);
        check(beta.cumulativeProbability(x)).isCloseTo(p, 1e-10);
        final xs = beta.inverseSurvival(p);
        check(beta.survival(xs)).isCloseTo(p, 1e-10);
      }

      check(() => beta.inverseCumulativeProbability(-0.1))
          .throws<InvalidProbability>();
      check(() => beta.inverseSurvival(1.1)).throws<InvalidProbability>();
    });
  });

  group('BetaDistribution sampling, fitting, and validation', () {
    test('samples match theoretical moments across shape regimes', () {
      final rng = math.Random(42);
      final samples = beta.samples(random: rng).take(2000).toList();
      final sampleMean = samples.reduce((a, b) => a + b) / samples.length;
      check(sampleMean).isCloseTo(beta.mean, 0.02);
      check(samples.every((x) => x >= 0.0 && x <= 1.0)).isTrue;

      final tiny = BetaDistribution(0.05, 0.05);
      final tinySamples = tiny
          .samples(random: math.Random(7))
          .take(200)
          .toList();
      check(tinySamples.every((x) => x.isFinite && x >= 0.0 && x <= 1.0))
          .isTrue;

      final extremeSmall = BetaDistribution(1e-4, 1e-4);
      final extremeSamples = extremeSmall
          .samples(random: math.Random(1))
          .take(100)
          .toList();
      check(extremeSamples.every((x) => x.isFinite && x >= 0.0 && x <= 1.0))
          .isTrue;

      // High-variance Beta U-shaped samples (alpha + beta < 1 path in fit)
      final highVarFit = BetaDistribution.fit(const [0.01, 0.99]);
      check(highVarFit).equals(BetaDistribution(1.0, 1.0));
    });

    test('fit recovers parameters and handles constant samples', () {
      final fitted = BetaDistribution.fit(
        beta.samples(random: math.Random(123)).take(2000),
      );
      check(fitted.alpha).isCloseTo(beta.alpha, 0.4);
      check(fitted.beta).isCloseTo(beta.beta, 1.0);

      final constantFit = BetaDistribution.fit(const [0.4, 0.4, 0.4]);
      check(constantFit.alpha).equals(1.0);
      check(constantFit.beta).equals(1.0);
    });

    test('fit rejects empty, single, or out-of-unit-interval samples', () {
      check(() => BetaDistribution.fit(const [])).throws<ArgumentError>();
      check(() => BetaDistribution.fit(const [0.5])).throws<ArgumentError>();
      check(() => BetaDistribution.fit(const [-0.1, 0.5]))
          .throws<ArgumentError>();
      check(() => BetaDistribution.fit(const [0.5, 1.1]))
          .throws<ArgumentError>();
      check(() => BetaDistribution.fit(const [0.0, 0.5]))
          .throws<ArgumentError>();
      check(() => BetaDistribution.fit(const [0.5, 1.0]))
          .throws<ArgumentError>();
    });

    test('constructor rejects non-positive or non-finite parameters', () {
      check(() => BetaDistribution(0.0, 1.0)).throws<ArgumentError>();
      check(() => BetaDistribution(-1.0, 1.0)).throws<ArgumentError>();
      check(() => BetaDistribution(1.0, 0.0)).throws<ArgumentError>();
      check(() => BetaDistribution(1.0, double.nan)).throws<ArgumentError>();
      check(() => BetaDistribution(double.infinity, 1.0))
          .throws<ArgumentError>();
    });

    test('equality, hashCode, and string representation', () {
      final other = BetaDistribution(2.0, 5.0);
      check(beta == other).isTrue;
      check(beta.hashCode).equals(other.hashCode);
      check(beta == BetaDistribution(2.0, 4.0)).isFalse;
      check(beta.toString()).contains('BetaDistribution');
    });
  });
}
