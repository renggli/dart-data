import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/stats.dart';
import 'package:test/scaffolding.dart';

void main() {
  const standard = WeibullDistribution.standard();
  final dist = WeibullDistribution(2.0, 3.0);

  group('WeibullDistribution moments and bounds', () {
    test('parameters, bounds, and scale-invariant shape moments', () {
      check(standard.shape).equals(1.0);
      check(standard.scale).equals(1.0);
      check(dist.shape).equals(2.0);
      check(dist.scale).equals(3.0);
      check(dist.lowerBound).equals(0.0);
      check(dist.upperBound).equals(double.infinity);
      check(dist.isLowerBoundOpen).isFalse;
      check(dist.isUpperBoundOpen).isTrue;
      check(standard.mean).isCloseTo(1.0, 1e-12);
      check(standard.median).isCloseTo(math.ln2, 1e-12);
      check(standard.mode).equals(0.0);
      check(dist.mode).isCloseTo(3.0 * math.sqrt(0.5), 1e-12);
      check(standard.variance).isCloseTo(1.0, 1e-12);
      check(standard.skewness).isCloseTo(2.0, 1e-5);
      check(standard.excessKurtosis).isCloseTo(6.0, 1e-5);

      // Scale-free skewness and excessKurtosis avoid overflow on extreme scales.
      final hugeScale = WeibullDistribution(1.5, 1e100);
      check(hugeScale.skewness.isFinite).isTrue;
      check(hugeScale.excessKurtosis.isFinite).isTrue;
    });
  });

  group('WeibullDistribution probabilities', () {
    test(
      'probability and logProbability at 0, interior, and extreme tails',
      () {
        check(standard.probability(-1.0)).equals(0.0);
        check(standard.logProbability(-1.0)).equals(double.negativeInfinity);
        check(standard.probability(0.0)).equals(1.0);
        check(standard.logProbability(0.0)).equals(0.0);

        check(dist.probability(0.0)).equals(0.0);
        check(dist.logProbability(0.0)).equals(double.negativeInfinity);
        check(dist.probability(2.0))
            .isCloseTo((4.0 / 9.0) * math.exp(-4.0 / 9.0), 1e-12);
        check(WeibullDistribution(0.5, 2.0).probability(0.0))
            .equals(double.infinity);
        check(WeibullDistribution(0.5, 2.0).logProbability(0.0))
            .equals(double.infinity);

        check(standard.probability(double.nan).isNaN).isTrue;
        check(standard.logProbability(double.nan).isNaN).isTrue;

        final subExp = WeibullDistribution(1.5, 1.0);
        check(subExp.probability(1e200)).equals(0.0);
        final logTail = subExp.logProbability(1e200);
        check(logTail.isFinite || logTail == double.negativeInfinity).isTrue;
        check(logTail.isNegative).isTrue;
      },
    );

    test('cumulativeProbability and survival retain near-zero and upper-tail precision', () {
      check(dist.cumulativeProbability(-1.0)).equals(0.0);
      check(dist.cumulativeProbability(0.0)).equals(0.0);
      check(dist.cumulativeProbability(1e-12)).isGreaterThan(0.0);
      check(dist.survival(-1.0)).equals(1.0);
      check(dist.survival(0.0)).equals(1.0);
      check(dist.survival(3.0)).isCloseTo(math.exp(-1.0), 1e-12);
      check(dist.cumulativeProbability(2.0) + dist.survival(2.0))
          .isCloseTo(1.0, 1e-14);
      check(dist.cumulativeProbability(double.nan).isNaN).isTrue;
      check(dist.survival(double.nan).isNaN).isTrue;
    });

    test('inverseCumulativeProbability and inverseSurvival round-trips', () {
      check(dist.inverseCumulativeProbability(0.0)).equals(0.0);
      check(dist.inverseCumulativeProbability(0.5))
          .isCloseTo(dist.median, 1e-12);
      check(dist.inverseCumulativeProbability(1.0)).equals(double.infinity);
      check(dist.inverseSurvival(1.0)).equals(0.0);
      check(dist.inverseSurvival(0.0)).equals(double.infinity);
      check(dist.inverseSurvival(math.exp(-1.0))).isCloseTo(3.0, 1e-12);

      check(() => dist.inverseCumulativeProbability(-0.1))
          .throws<InvalidProbability>();
      check(() => dist.inverseSurvival(1.1)).throws<InvalidProbability>();
    });
  });

  group('WeibullDistribution sampling, fitting, and validation', () {
    test('samples stay non-negative and match mean', () {
      check(dist.sample()).isGreaterOrEqual(0.0);
      final samples = dist.samples(random: math.Random(42)).take(2000).toList();
      final sampleMean = samples.reduce((a, b) => a + b) / samples.length;
      check(sampleMean).isCloseTo(dist.mean, 0.15);
      check(samples.every((x) => x >= 0.0 && x.isFinite)).isTrue;
    });

    test('fit estimates shape and scale and rejects invalid samples', () {
      final samples = dist.samples(random: math.Random(7)).take(2000);
      final fitted = WeibullDistribution.fit(samples);
      check(fitted.shape).isCloseTo(2.0, 0.25);
      check(fitted.scale).isCloseTo(3.0, 0.25);

      final constantFit = WeibullDistribution.fit(const [2.0, 2.0, 2.0]);
      check(constantFit.shape).equals(1.0);
      check(constantFit.scale).isGreaterThan(0.0);

      final singleFit = WeibullDistribution.fit(const [1.0]);
      check(singleFit.shape).equals(1.0);
      check(singleFit.scale).isCloseTo(1.781072417990198, 1e-12);

      check(() => WeibullDistribution.fit(const [])).throws<ArgumentError>();
      check(() => WeibullDistribution.fit(const [0.0, 1.0]))
          .throws<ArgumentError>();
    });

    test('constructor validation', () {
      check(() => WeibullDistribution(0.0, 1.0)).throws<ArgumentError>();
      check(() => WeibullDistribution(1.0, 0.0)).throws<ArgumentError>();
      check(() => WeibullDistribution(double.infinity, 1.0))
          .throws<ArgumentError>();
    });

    test('equality, hashCode, and string representation', () {
      check(standard == WeibullDistribution(1.0, 1.0)).isTrue;
      check(standard.hashCode).equals(WeibullDistribution(1.0, 1.0).hashCode);
      check(standard == dist).isFalse;
      check(dist.toString()).contains('WeibullDistribution');
    });
  });
}
