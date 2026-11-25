import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/stats.dart';
import 'package:test/scaffolding.dart';

void main() {
  final dist = InverseGammaDistribution(5.0, 2.0);

  group('InverseGammaDistribution moments and bounds', () {
    test('parameters, bounds, and mode', () {
      check(dist.shape).equals(5.0);
      check(dist.scale).equals(2.0);
      check(dist.lowerBound).equals(0.0);
      check(dist.upperBound).equals(double.infinity);
      check(dist.isLowerBoundOpen).isFalse;
      check(dist.isUpperBoundOpen).isTrue;
      check(dist.mode).isCloseTo(2.0 / 6.0, 1e-12);
      check(dist.median).isCloseTo(0.428182191129, 1e-10);
      check(dist.cumulativeProbability(dist.median)).isCloseTo(0.5, 1e-12);
    });

    test('moments across shape thresholds', () {
      check(dist.mean).equals(0.5);
      check(dist.variance).isCloseTo(1.0 / 12.0, 1e-12);
      check(dist.standardDeviation).isCloseTo(math.sqrt(1.0 / 12.0), 1e-12);
      check(dist.skewness).isCloseTo(2.0 * math.sqrt(3.0), 1e-12);
      check(dist.excessKurtosis).equals(42.0);

      check(InverseGammaDistribution(1.0, 1.0).mean.isNaN).isTrue;
      check(InverseGammaDistribution(2.0, 1.0).variance.isNaN).isTrue;
      check(InverseGammaDistribution(3.0, 1.0).skewness.isNaN).isTrue;
      check(InverseGammaDistribution(4.0, 1.0).excessKurtosis.isNaN).isTrue;
    });
  });

  group('InverseGammaDistribution probabilities', () {
    test(
      'probability and logProbability handle boundary, infinity, and NaN',
      () {
        check(dist.probability(-1.0)).equals(0.0);
        check(dist.probability(0.0)).equals(0.0);
        check(dist.probability(double.infinity)).equals(0.0);
        check(dist.logProbability(0.0)).equals(double.negativeInfinity);
        check(dist.logProbability(double.infinity))
            .equals(double.negativeInfinity);
        check(dist.probability(double.nan).isNaN).isTrue;
        check(dist.logProbability(double.nan).isNaN).isTrue;
        check(dist.probability(0.5))
            .isCloseTo((32.0 / 24.0) * 64.0 * math.exp(-4.0), 1e-12);
        check(dist.logProbability(0.5))
            .isCloseTo(math.log(dist.probability(0.5)), 1e-12);
      },
    );

    test('cumulativeProbability and survival are complementary', () {
      check(dist.cumulativeProbability(-1.0)).equals(0.0);
      check(dist.cumulativeProbability(0.0)).equals(0.0);
      check(dist.cumulativeProbability(double.infinity)).equals(1.0);
      check(dist.survival(0.0)).equals(1.0);
      check(dist.survival(double.infinity)).equals(0.0);
      check(dist.cumulativeProbability(1.0) + dist.survival(1.0))
          .isCloseTo(1.0, 1e-14);
      check(dist.cumulativeProbability(0.01)).isGreaterThan(0.0);
      check(dist.survival(100.0)).isGreaterThan(0.0);
      check(dist.cumulativeProbability(double.nan).isNaN).isTrue;
      check(dist.survival(double.nan).isNaN).isTrue;
    });

    test('inverseCumulativeProbability and inverseSurvival remain accurate in deep tails', () {
      check(dist.inverseCumulativeProbability(0.0)).equals(0.0);
      check(dist.inverseCumulativeProbability(1.0)).equals(double.infinity);
      check(dist.inverseSurvival(1.0)).equals(0.0);
      check(dist.inverseSurvival(0.0)).equals(double.infinity);

      for (final p in const [1e-10, 0.05, 0.5, 0.95, 1.0 - 1e-10]) {
        final x = dist.inverseCumulativeProbability(p);
        check(dist.cumulativeProbability(x)).isCloseTo(p, 1e-9);
      }
      for (final q in const [1e-10, 0.05, 0.5, 0.95]) {
        final x = dist.inverseSurvival(q);
        check(dist.survival(x)).isCloseTo(q, 1e-9);
      }

      check(() => dist.inverseCumulativeProbability(-0.1))
          .throws<InvalidProbability>();
      check(() => dist.inverseSurvival(1.1)).throws<InvalidProbability>();
    });
  });

  group('InverseGammaDistribution sampling, fitting, and validation', () {
    test('samples match theoretical mean', () {
      final samples = dist.samples(random: math.Random(42)).take(2000).toList();
      final sampleMean = samples.reduce((a, b) => a + b) / samples.length;
      check(sampleMean).isCloseTo(0.5, 0.03);
      check(samples.every((x) => x > 0.0 && x.isFinite)).isTrue;
    });

    test('fit estimates shape and scale and rejects invalid samples', () {
      final fitted = InverseGammaDistribution.fit(const [0.25, 0.5, 0.5, 1.0]);
      check(fitted.shape).isGreaterThan(2.0);
      check(fitted.scale).isGreaterThan(0.0);

      final constantFit = InverseGammaDistribution.fit(const [1.0, 1.0]);
      check(constantFit.shape).equals(3.0);
      check(constantFit.scale).equals(2.0);

      check(() => InverseGammaDistribution.fit(const []))
          .throws<ArgumentError>();
      check(() => InverseGammaDistribution.fit(const [1.0]))
          .throws<ArgumentError>();
      check(() => InverseGammaDistribution.fit(const [0.0, 1.0]))
          .throws<ArgumentError>();
    });

    test('constructor validation', () {
      check(() => InverseGammaDistribution(0.0, 1.0)).throws<ArgumentError>();
      check(() => InverseGammaDistribution(1.0, 0.0)).throws<ArgumentError>();
      check(() => InverseGammaDistribution(double.infinity, 1.0))
          .throws<ArgumentError>();
    });

    test('equality, hashCode, and string representation', () {
      check(dist == InverseGammaDistribution(5.0, 2.0)).isTrue;
      check(dist.hashCode).equals(InverseGammaDistribution(5.0, 2.0).hashCode);
      check(dist == InverseGammaDistribution(3.0, 2.0)).isFalse;
      check(dist.toString()).contains('InverseGammaDistribution');
    });
  });
}
