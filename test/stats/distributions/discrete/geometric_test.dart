import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/stats.dart';
import 'package:data/type.dart';
import 'package:test/scaffolding.dart';

void main() {
  final dist = GeometricDistribution(0.5);
  final tinyP = GeometricDistribution(1e-12);
  final degenerate = GeometricDistribution(1.0);

  group('GeometricDistribution moments and bounds', () {
    test('parameters, bounds, and moments', () {
      check(dist.p).equals(0.5);
      check(dist.lowerBound).equals(0);
      check(dist.upperBound).equals(DataType.integer.safeMax);
      check(dist.isLowerBoundOpen).isFalse;
      check(dist.isUpperBoundOpen).isTrue;
      check(dist.mean).equals(1.0);
      check(dist.variance).equals(2.0);
      check(dist.standardDeviation).isCloseTo(math.sqrt(2.0), 1e-12);
      check(dist.mode).equals(0.0);
      check(dist.median).equals(0.0);
      check(dist.skewness).isCloseTo(1.5 / math.sqrt(0.5), 1e-12);
      check(dist.excessKurtosis).equals(6.5);

      check(degenerate.mean).equals(0.0);
      check(degenerate.median).equals(0.0);
      check(degenerate.variance).equals(0.0);
      check(degenerate.skewness.isNaN).isTrue;
      check(degenerate.excessKurtosis.isNaN).isTrue;
    });
  });

  group('GeometricDistribution probabilities', () {
    test(
      'probability and logProbability preserve accuracy across extreme p',
      () {
        check(dist.probability(-1)).equals(0.0);
        check(dist.probability(0)).equals(0.5);
        check(dist.probability(1)).equals(0.25);
        check(dist.logProbability(-1)).equals(double.negativeInfinity);
        check(dist.logProbability(0)).isCloseTo(-math.ln2, 1e-12);
        check(dist.logProbability(1)).isCloseTo(-2.0 * math.ln2, 1e-12);

        check(tinyP.probability(0)).equals(1e-12);
        check(tinyP.logProbability(100))
            .isCloseTo(math.log(1e-12) - 1e-10, 1e-12);
      },
    );

    test('cumulativeProbability and survival retain tiny-p accuracy', () {
      check(dist.cumulativeProbability(-1)).equals(0.0);
      check(dist.cumulativeProbability(0)).equals(0.5);
      check(dist.cumulativeProbability(1)).equals(0.75);
      check(dist.survival(-1)).equals(1.0);
      check(dist.survival(0)).equals(0.5);
      check(dist.survival(1)).equals(0.25);

      check(tinyP.cumulativeProbability(0)).isCloseTo(1e-12, 1e-22);
      check(tinyP.survival(0)).isCloseTo(1.0 - 1e-12, 1e-15);
    });

    test('inverseCumulativeProbability and inverseSurvival stay accurate for tiny p', () {
      check(dist.inverseCumulativeProbability(0.0)).equals(0);
      check(dist.inverseCumulativeProbability(0.5)).equals(0);
      check(dist.inverseCumulativeProbability(0.75)).equals(1);
      check(dist.inverseCumulativeProbability(1.0))
          .equals(DataType.integer.safeMax);

      check(dist.inverseSurvival(1.0)).equals(0);
      check(dist.inverseSurvival(0.5)).equals(0);
      check(dist.inverseSurvival(0.25)).equals(1);
      check(dist.inverseSurvival(0.0)).equals(DataType.integer.safeMax);

      final smallP = GeometricDistribution(1e-6);
      final qSmall = smallP.inverseCumulativeProbability(0.5);
      final expectedMedian = (-math.ln2 / math.log(1.0 - 1e-6)).ceil() - 1;
      check(qSmall).isCloseTo(expectedMedian, 2);
      check(smallP.inverseSurvival(0.5)).isCloseTo(qSmall, 2);
      check(tinyP.inverseCumulativeProbability(0.5))
          .equals(DataType.integer.safeMax);

      check(() => dist.inverseCumulativeProbability(-0.1))
          .throws<InvalidProbability>();
      check(() => dist.inverseSurvival(1.1)).throws<InvalidProbability>();
    });
  });

  group('GeometricDistribution sampling, fitting, and validation', () {
    test('samples match theoretical mean', () {
      check(degenerate.sample()).equals(0);
      final samples = dist.samples(random: math.Random(42)).take(2000).toList();
      check(samples.every((x) => x >= 0)).isTrue;
      final sampleMean = samples.reduce((a, b) => a + b) / samples.length;
      check(sampleMean).isCloseTo(1.0, 0.1);
    });

    test('fit estimates MLE parameter and rejects invalid samples', () {
      final fitted = GeometricDistribution.fit(const [0, 1, 2]);
      check(fitted.p).equals(0.5);

      check(() => GeometricDistribution.fit(const [])).throws<ArgumentError>();
      check(() => GeometricDistribution.fit(const [-1, 2]))
          .throws<ArgumentError>();
      check(() => GeometricDistribution.fit(const [0.5, 1]))
          .throws<ArgumentError>();
    });

    test('constructor validation', () {
      check(() => GeometricDistribution(0.0)).throws<ArgumentError>();
      check(() => GeometricDistribution(-0.5)).throws<ArgumentError>();
      check(() => GeometricDistribution(1.5)).throws<ArgumentError>();
      check(() => GeometricDistribution(double.nan)).throws<ArgumentError>();
    });

    test('equality, hashCode, and string representation', () {
      check(dist == GeometricDistribution(0.5)).isTrue;
      check(dist.hashCode).equals(GeometricDistribution(0.5).hashCode);
      check(dist == tinyP).isFalse;
      check(dist.toString()).contains('GeometricDistribution');
    });
  });
}
