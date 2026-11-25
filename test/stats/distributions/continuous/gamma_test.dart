import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/stats.dart';
import 'package:test/scaffolding.dart';

void main() {
  final gammaDist = GammaDistribution(2.0, 2.0);
  final subUnit = GammaDistribution(0.5, 1.0);

  group('GammaDistribution moments and bounds', () {
    test('parameters, bounds, and moments', () {
      final unitScale = GammaDistribution.shape(3.0);
      check(unitScale.scale).equals(1.0);
      check(gammaDist.shape).equals(2.0);
      check(gammaDist.scale).equals(2.0);
      check(gammaDist.lowerBound).equals(0.0);
      check(gammaDist.upperBound).equals(double.infinity);
      check(gammaDist.isLowerBoundOpen).isFalse;
      check(GammaDistribution(1.0, 2.0).isLowerBoundOpen).isFalse;
      check(gammaDist.isUpperBoundOpen).isTrue;
      check(gammaDist.mean).equals(4.0);
      check(gammaDist.mode).equals(2.0);
      check(subUnit.mode).equals(0.0);
      check(gammaDist.variance).equals(8.0);
      check(gammaDist.standardDeviation).isCloseTo(math.sqrt(8.0), 1e-12);
      check(gammaDist.skewness).isCloseTo(math.sqrt(2.0), 1e-12);
      check(gammaDist.excessKurtosis).equals(3.0);
      check(gammaDist.median).isCloseTo(3.35669398, 1e-6);
    });
  });

  group('GammaDistribution probabilities', () {
    test('probability and logProbability on boundary and interior', () {
      check(gammaDist.probability(-1.0)).equals(0.0);
      check(gammaDist.probability(0.0)).equals(0.0);
      check(gammaDist.logProbability(0.0)).equals(double.negativeInfinity);
      check(GammaDistribution(1.0, 2.0).probability(0.0)).equals(0.5);
      check(subUnit.probability(0.0)).equals(double.infinity);
      check(gammaDist.probability(2.0)).isCloseTo(0.5 * math.exp(-1.0), 1e-12);
      check(gammaDist.logProbability(2.0))
          .isCloseTo(math.log(gammaDist.probability(2.0)), 1e-12);
      check(gammaDist.probability(double.nan).isNaN).isTrue;
    });

    test('cumulativeProbability and survival retain upper-tail precision', () {
      check(gammaDist.cumulativeProbability(-1.0)).equals(0.0);
      check(gammaDist.cumulativeProbability(0.0)).equals(0.0);
      check(gammaDist.survival(-1.0)).equals(1.0);
      check(gammaDist.survival(0.0)).equals(1.0);
      check(gammaDist.survival(100.0)).isGreaterThan(0.0);
      check(gammaDist.cumulativeProbability(5.0) + gammaDist.survival(5.0))
          .isCloseTo(1.0, 1e-14);
      check(gammaDist.cumulativeProbability(double.nan).isNaN).isTrue;
      check(gammaDist.survival(double.nan).isNaN).isTrue;
    });

    test('inverseCumulativeProbability and inverseSurvival round-trips', () {
      check(gammaDist.inverseCumulativeProbability(0.0)).equals(0.0);
      check(gammaDist.inverseCumulativeProbability(1.0))
          .equals(double.infinity);
      check(gammaDist.inverseSurvival(1.0)).equals(0.0);
      check(gammaDist.inverseSurvival(0.0)).equals(double.infinity);

      for (final p in const [1e-6, 0.05, 0.5, 0.95]) {
        final x = gammaDist.inverseCumulativeProbability(p);
        check(gammaDist.cumulativeProbability(x)).isCloseTo(p, 1e-10);
        final xs = gammaDist.inverseSurvival(p);
        check(gammaDist.survival(xs)).isCloseTo(p, 1e-10);
      }

      check(() => gammaDist.inverseCumulativeProbability(-0.1))
          .throws<InvalidProbability>();
      check(() => gammaDist.inverseSurvival(1.1)).throws<InvalidProbability>();
    });
  });

  group('GammaDistribution sampling, fitting, and validation', () {
    test('samples match theoretical mean for shape < 1 and shape >= 1', () {
      final s1 = gammaDist.samples(random: math.Random(42)).take(2000).toList();
      check(s1.reduce((a, b) => a + b) / s1.length).isCloseTo(4.0, 0.25);

      final s2 = subUnit.samples(random: math.Random(7)).take(2000).toList();
      check(s2.reduce((a, b) => a + b) / s2.length).isCloseTo(0.5, 0.08);
      check(s2.every((x) => x > 0.0 && x.isFinite)).isTrue;
    });

    test(
      'fit estimates shape and scale and handles constant/invalid samples',
      () {
        final fitted = GammaDistribution.fit(const [1.0, 2.0, 3.0, 4.0]);
        check(fitted.shape).isCloseTo(3.75, 1e-12);
        check(fitted.scale).isCloseTo(2.5 / 3.75, 1e-12);

        final constantFit = GammaDistribution.fit(const [5.0, 5.0, 5.0]);
        check(constantFit.mean).isCloseTo(5.0, 1e-12);

        check(() => GammaDistribution.fit(const [])).throws<ArgumentError>();
        check(() => GammaDistribution.fit(const [1.0])).throws<ArgumentError>();
        check(() => GammaDistribution.fit(const [0.0, 1.0]))
            .throws<ArgumentError>();
      },
    );

    test('constructor validation', () {
      check(() => GammaDistribution(0.0, 1.0)).throws<ArgumentError>();
      check(() => GammaDistribution(1.0, 0.0)).throws<ArgumentError>();
      check(() => GammaDistribution.shape(0.0)).throws<ArgumentError>();
      check(() => GammaDistribution.shape(-1.0)).throws<ArgumentError>();
    });

    test('equality, hashCode, and string representation', () {
      check(gammaDist == GammaDistribution(2.0, 2.0)).isTrue;
      check(gammaDist.hashCode).equals(GammaDistribution(2.0, 2.0).hashCode);
      check(gammaDist == subUnit).isFalse;
      check(gammaDist.toString()).contains('GammaDistribution');
    });
  });
}
