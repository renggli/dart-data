import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/stats.dart';
import 'package:test/scaffolding.dart';

void main() {
  const standard = ParetoDistribution.standard();
  final dist = ParetoDistribution(4.0, 2.0);

  group('ParetoDistribution moments and bounds', () {
    test('parameters, bounds, and moments across shape regimes', () {
      check(standard.shape).equals(1.0);
      check(standard.scale).equals(1.0);
      check(dist.shape).equals(4.0);
      check(dist.scale).equals(2.0);
      check(dist.lowerBound).equals(2.0);
      check(dist.upperBound).equals(double.infinity);
      check(dist.isLowerBoundOpen).isFalse;
      check(dist.isUpperBoundOpen).isTrue;
      check(dist.mean).isCloseTo(8.0 / 3.0, 1e-12);
      check(dist.median).isCloseTo(2.0 * math.pow(2.0, 0.25), 1e-12);
      check(dist.mode).equals(2.0);
      check(dist.variance).isCloseTo(4.0 * 4.0 / (9.0 * 2.0), 1e-12);
      check(dist.skewness).isGreaterThan(0.0);
      check(dist.excessKurtosis.isNaN).isTrue;
      check(ParetoDistribution(5.0, 2.0).excessKurtosis).isCloseTo(70.8, 1e-12);

      check(standard.mean).equals(double.infinity);
      check(standard.variance.isNaN).isTrue;
      check(ParetoDistribution(1.5, 1.0).variance).equals(double.infinity);
      check(standard.skewness.isNaN).isTrue;
      check(standard.excessKurtosis.isNaN).isTrue;
    });
  });

  group('ParetoDistribution probabilities', () {
    test(
      'probability and logProbability handle exact lower bound and tails',
      () {
        check(dist.probability(1.99)).equals(0.0);
        check(dist.logProbability(1.99)).equals(double.negativeInfinity);
        check(dist.probability(2.0)).equals(2.0);
        check(dist.logProbability(2.0)).isCloseTo(math.ln2, 1e-12);
        check(dist.probability(4.0)).isCloseTo(1.0 / 16.0, 1e-12);
        check(dist.logProbability(4.0)).isCloseTo(-4.0 * math.ln2, 1e-12);
        check(dist.probability(double.infinity)).equals(0.0);
        check(dist.logProbability(double.infinity))
            .equals(double.negativeInfinity);
        check(dist.probability(double.nan).isNaN).isTrue;
        check(dist.logProbability(double.nan).isNaN).isTrue;
      },
    );

    test(
      'cumulativeProbability and survival retain near-bound and tail precision',
      () {
        check(dist.cumulativeProbability(1.0)).equals(0.0);
        check(dist.cumulativeProbability(2.0)).equals(0.0);
        check(dist.survival(2.0)).equals(1.0);
        check(dist.cumulativeProbability(4.0))
            .isCloseTo(1.0 - 1.0 / 16.0, 1e-12);
        check(dist.survival(4.0)).isCloseTo(1.0 / 16.0, 1e-12);
        check(dist.cumulativeProbability(2.0 + 1e-12)).isGreaterThan(0.0);
        check(dist.survival(1e10)).isGreaterThan(0.0);
        check(dist.cumulativeProbability(double.nan).isNaN).isTrue;
        check(dist.survival(double.nan).isNaN).isTrue;
      },
    );

    test('inverseCumulativeProbability and inverseSurvival round-trips', () {
      check(dist.inverseCumulativeProbability(0.0)).equals(2.0);
      check(dist.inverseCumulativeProbability(0.5))
          .isCloseTo(dist.median, 1e-12);
      check(dist.inverseCumulativeProbability(1.0)).equals(double.infinity);
      check(dist.inverseSurvival(1.0)).equals(2.0);
      check(dist.inverseSurvival(0.0)).equals(double.infinity);
      check(dist.inverseSurvival(1.0 / 16.0)).isCloseTo(4.0, 1e-12);

      check(() => dist.inverseCumulativeProbability(-0.1))
          .throws<InvalidProbability>();
      check(() => dist.inverseSurvival(1.1)).throws<InvalidProbability>();
    });
  });

  group('ParetoDistribution sampling, fitting, and validation', () {
    test('samples stay above scale and fit recovers parameters', () {
      check(dist.sample()).isGreaterOrEqual(2.0);
      final samples = dist.samples(random: math.Random(42)).take(2000).toList();
      check(samples.every((x) => x >= 2.0 && x.isFinite)).isTrue;
      final fitted = ParetoDistribution.fit(samples);
      check(fitted.scale).isCloseTo(2.0, 0.05);
      check(fitted.shape).isCloseTo(4.0, 0.5);
    });

    test('fit handles constant samples and rejects non-positive inputs', () {
      final constantFit = ParetoDistribution.fit(const [2.0, 2.0, 2.0]);
      check(constantFit.scale).equals(2.0);
      check(constantFit.shape).equals(1.0);

      check(() => ParetoDistribution.fit(const [])).throws<ArgumentError>();
      check(() => ParetoDistribution.fit(const [0.0, 1.0]))
          .throws<ArgumentError>();
      check(() => ParetoDistribution.fit(const [1.0, double.infinity]))
          .throws<ArgumentError>();
    });

    test('constructor validation', () {
      check(() => ParetoDistribution(0.0, 1.0)).throws<ArgumentError>();
      check(() => ParetoDistribution(1.0, 0.0)).throws<ArgumentError>();
      check(() => ParetoDistribution(double.infinity, 1.0))
          .throws<ArgumentError>();
    });

    test('equality, hashCode, and string representation', () {
      check(standard == ParetoDistribution(1.0, 1.0)).isTrue;
      check(standard.hashCode).equals(ParetoDistribution(1.0, 1.0).hashCode);
      check(standard == dist).isFalse;
      check(dist.toString()).contains('ParetoDistribution');
    });
  });
}
