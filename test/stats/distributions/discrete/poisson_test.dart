import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/stats.dart';
import 'package:data/type.dart';
import 'package:test/scaffolding.dart';

void main() {
  final dist = PoissonDistribution(4.0);

  group('PoissonDistribution moments and bounds', () {
    test('parameters, bounds, and moments including exact median', () {
      check(dist.rate).equals(4.0);
      check(dist.lowerBound).equals(0);
      check(dist.upperBound).equals(DataType.integer.safeMax);
      check(dist.isLowerBoundOpen).isFalse;
      check(dist.isUpperBoundOpen).isTrue;
      check(dist.mean).equals(4.0);
      check(dist.mode).equals(4.0);
      check(dist.variance).equals(4.0);
      check(dist.standardDeviation).equals(2.0);
      check(dist.skewness).equals(0.5);
      check(dist.excessKurtosis).equals(0.25);

      check(PoissonDistribution(0.01).median).equals(0.0);
      check(PoissonDistribution(0.5).median).equals(0.0);
      check(PoissonDistribution(0.694).median).equals(1.0);
      check(dist.median).equals(4.0);
    });
  });

  group('PoissonDistribution probabilities', () {
    test('probability and logProbability across interior and boundaries', () {
      check(dist.probability(-1)).equals(0.0);
      check(dist.probability(0)).isCloseTo(math.exp(-4.0), 1e-12);
      check(dist.probability(4))
          .isCloseTo(math.exp(-4.0) * 256.0 / 24.0, 1e-12);
      check(dist.logProbability(-1)).equals(double.negativeInfinity);
      check(dist.logProbability(0)).equals(-4.0);
      check(dist.logProbability(4))
          .isCloseTo(math.log(dist.probability(4)), 1e-12);
    });

    test('cumulativeProbability and survival are complementary', () {
      check(dist.cumulativeProbability(-1)).equals(0.0);
      check(dist.cumulativeProbability(0)).isCloseTo(math.exp(-4.0), 1e-12);
      check(dist.survival(-1)).equals(1.0);
      check(dist.survival(0)).isCloseTo(1.0 - math.exp(-4.0), 1e-12);
      check(dist.cumulativeProbability(4) + dist.survival(4))
          .isCloseTo(1.0, 1e-13);
      check(dist.survival(50)).isGreaterThan(0.0);
    });

    test('inverseCumulativeProbability and inverseSurvival', () {
      check(dist.inverseCumulativeProbability(0.0)).equals(0);
      check(dist.inverseCumulativeProbability(0.5)).equals(4);
      check(dist.inverseCumulativeProbability(1.0))
          .equals(DataType.integer.safeMax);
      check(dist.inverseSurvival(1.0)).equals(0);
      check(dist.inverseSurvival(0.0)).equals(DataType.integer.safeMax);
      check(dist.survival(dist.inverseSurvival(1e-6)))
          .isLessOrEqual(1e-6 * (1.0 + 1e-12));

      check(() => dist.inverseCumulativeProbability(-0.1))
          .throws<InvalidProbability>();
      check(() => dist.inverseSurvival(1.1)).throws<InvalidProbability>();
    });
  });

  group('PoissonDistribution sampling, fitting, and validation', () {
    test('Knuth and PTRD samplers match theoretical moments', () {
      check(dist.sample() >= 0).isTrue;
      final smallSamples = dist
          .samples(random: math.Random(42))
          .take(2000)
          .toList();
      check(smallSamples.every((x) => x >= 0)).isTrue;
      check(smallSamples.reduce((a, b) => a + b) / smallSamples.length)
          .isCloseTo(4.0, 0.25);

      for (final rate in const [50.0, 100.0]) {
        final large = PoissonDistribution(rate);
        final samples = large
            .samples(random: math.Random(7))
            .take(4000)
            .toList();
        final nSamples = samples.length;
        final sampleMean = samples.reduce((a, b) => a + b) / nSamples;
        var sqDiff = 0.0;
        var cubeDiff = 0.0;
        for (final x in samples) {
          final d = x - sampleMean;
          sqDiff += d * d;
          cubeDiff += d * d * d;
        }
        final sampleVar = sqDiff / (nSamples - 1);
        final sampleSkew = (cubeDiff / nSamples) / math.pow(sampleVar, 1.5);
        check(sampleMean).isCloseTo(rate, 0.8);
        check(sampleVar).isCloseTo(rate, rate * 0.12);
        check(sampleSkew).isCloseTo(large.skewness, 0.15);
      }
    });

    test('fit estimates rate and rejects invalid samples', () {
      final fitted = PoissonDistribution.fit(const [2, 3, 4, 5, 6]);
      check(fitted.rate).equals(4.0);

      final zeroFit = PoissonDistribution.fit(const [0, 0]);
      check(zeroFit.rate).equals(1e-6);

      check(() => PoissonDistribution.fit(const [])).throws<ArgumentError>();
      check(() => PoissonDistribution.fit(const [-1, 2]))
          .throws<ArgumentError>();
      check(() => PoissonDistribution.fit(const [1.5, 2]))
          .throws<ArgumentError>();
    });

    test('constructor validation', () {
      check(() => PoissonDistribution(0.0)).throws<ArgumentError>();
      check(() => PoissonDistribution(-1.0)).throws<ArgumentError>();
      check(() => PoissonDistribution(double.infinity)).throws<ArgumentError>();
    });

    test('equality, hashCode, and string representation', () {
      check(dist == PoissonDistribution(4.0)).isTrue;
      check(dist.hashCode).equals(PoissonDistribution(4.0).hashCode);
      check(dist == PoissonDistribution(2.0)).isFalse;
      check(dist.toString()).contains('PoissonDistribution');
    });
  });
}
