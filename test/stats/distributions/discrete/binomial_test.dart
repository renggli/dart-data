import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/stats.dart';
import 'package:test/scaffolding.dart';

void main() {
  final dist = BinomialDistribution(10, 0.5);

  group('BinomialDistribution moments and bounds', () {
    test('parameters, bounds, and moments', () {
      check(dist.n).equals(10);
      check(dist.p).equals(0.5);
      check(dist.q).equals(0.5);
      check(dist.lowerBound).equals(0);
      check(dist.upperBound).equals(10);
      check(dist.isLowerBoundOpen).isFalse;
      check(dist.isUpperBoundOpen).isFalse;
      check(dist.mean).equals(5.0);
      check(dist.median).equals(5.0);
      check(BinomialDistribution(3, 0.2).median).equals(0.0);
      check(dist.mode).equals(5.0);
      check(BinomialDistribution(5, 1.0).mode).equals(5.0);
      check(BinomialDistribution(5, 0.0).mode).equals(0.0);
      check(dist.variance).equals(2.5);
      check(dist.standardDeviation).isCloseTo(math.sqrt(2.5), 1e-12);
      check(dist.skewness).equals(0.0);
      check(dist.excessKurtosis).isCloseTo(-0.2, 1e-12);

      final zeroTrials = BinomialDistribution(0, 0.5);
      check(zeroTrials.skewness.isNaN).isTrue;
      check(zeroTrials.excessKurtosis.isNaN).isTrue;
    });
  });

  group('BinomialDistribution probabilities', () {
    test('probability and logProbability across interior and boundaries', () {
      check(dist.probability(-1)).equals(0.0);
      check(dist.probability(5)).isCloseTo(252.0 / 1024.0, 1e-12);
      check(dist.probability(11)).equals(0.0);
      check(dist.logProbability(-1)).equals(double.negativeInfinity);
      check(dist.logProbability(5)).isCloseTo(math.log(252.0 / 1024.0), 1e-12);
      check(dist.logProbability(11)).equals(double.negativeInfinity);

      final deg0 = BinomialDistribution(5, 0.0);
      check(deg0.probability(0)).equals(1.0);
      check(deg0.logProbability(0)).equals(0.0);
      check(deg0.probability(1)).equals(0.0);
      check(deg0.logProbability(1)).equals(double.negativeInfinity);

      final deg1 = BinomialDistribution(5, 1.0);
      check(deg1.probability(5)).equals(1.0);
      check(deg1.logProbability(5)).equals(0.0);
      check(deg1.probability(4)).equals(0.0);
      check(deg1.logProbability(4)).equals(double.negativeInfinity);
    });

    test('cumulativeProbability and survival are complementary', () {
      check(dist.cumulativeProbability(-1)).equals(0.0);
      check(dist.cumulativeProbability(0)).isCloseTo(1.0 / 1024.0, 1e-12);
      check(dist.cumulativeProbability(10)).equals(1.0);
      check(dist.cumulativeProbability(11)).equals(1.0);

      check(dist.survival(-1)).equals(1.0);
      check(dist.survival(9)).isCloseTo(1.0 / 1024.0, 1e-12);
      check(dist.survival(10)).equals(0.0);
      check(dist.cumulativeProbability(3) + dist.survival(3))
          .isCloseTo(1.0, 1e-14);
    });

    test('inverseCumulativeProbability and inverseSurvival', () {
      check(dist.inverseCumulativeProbability(0.0)).equals(0);
      check(dist.inverseCumulativeProbability(0.5)).equals(5);
      check(dist.inverseCumulativeProbability(1.0)).equals(10);
      check(dist.inverseSurvival(1.0)).equals(0);
      check(dist.inverseSurvival(0.0)).equals(10);
      check(dist.inverseSurvival(1.0 / 1024.0)).equals(9);

      check(() => dist.inverseCumulativeProbability(-0.1))
          .throws<InvalidProbability>();
      check(() => dist.inverseSurvival(1.1)).throws<InvalidProbability>();
    });
  });

  group('BinomialDistribution sampling, fitting, and validation', () {
    test(
      'Bernoulli, geometric-gap, and BTRS samplers match theoretical moments',
      () {
        // Edge cases n = 0, p = 1.0, and no-random call
        check(BinomialDistribution(0, 0.5).sample()).equals(0);
        check(BinomialDistribution(5, 1.0).sample()).equals(5);

        // Bernoulli branch (n <= 20)
        final small = BinomialDistribution(10, 0.5);
        final smallSamples = small
            .samples(random: math.Random(1))
            .take(1000)
            .toList();
        check(smallSamples.every((x) => x >= 0 && x <= 10)).isTrue;

        // Geometric waiting-time branch (n * min(p, q) < 10 and n > 20)
        final sparse = BinomialDistribution(1000, 0.005);
        final sparseSamples = sparse
            .samples(random: math.Random(2))
            .take(2000)
            .toList();
        final sparseMean =
            sparseSamples.reduce((a, b) => a + b) / sparseSamples.length;
        check(sparseMean).isCloseTo(sparse.mean, 0.3);

        // Hörmann BTRS rejection branch (p <= 0.5 and p > 0.5)
        for (final p in const [0.3, 0.7]) {
          final large = BinomialDistribution(1000, p);
          final samples = large
              .samples(random: math.Random(42))
              .take(4000)
              .toList();
          final nSamples = samples.length;
          final sampleMean = samples.reduce((a, b) => a + b) / nSamples;
          var sqDiff = 0.0;
          for (final x in samples) {
            final d = x - sampleMean;
            sqDiff += d * d;
          }
          final sampleVar = sqDiff / (nSamples - 1);
          check(sampleMean).isCloseTo(large.mean, 1.5);
          check(sampleVar).isCloseTo(large.variance, 25.0);
        }
      },
    );

    test('fit estimates p and infers n when omitted', () {
      final fittedKnown = BinomialDistribution.fit(const [4, 5, 6], n: 10);
      check(fittedKnown.n).equals(10);
      check(fittedKnown.p).isCloseTo(0.5, 1e-12);

      final fittedInferred = BinomialDistribution.fit(const [
        0,
        1,
        2,
        1,
        0,
        1,
        2,
        1,
      ]);
      check(fittedInferred.n).isGreaterOrEqual(2);
      check(fittedInferred.p).isGreaterThan(0.0);

      check(() => BinomialDistribution.fit(const [], n: 10))
          .throws<ArgumentError>();
      check(() => BinomialDistribution.fit(const [-1], n: 10))
          .throws<ArgumentError>();
      check(() => BinomialDistribution.fit(const [11], n: 10))
          .throws<ArgumentError>();
      check(() => BinomialDistribution.fit(const [1.5], n: 10))
          .throws<ArgumentError>();
      check(() => BinomialDistribution.fit(const [1, 2], n: -1))
          .throws<ArgumentError>();
    });

    test('constructor validation', () {
      check(() => BinomialDistribution(-1, 0.5)).throws<ArgumentError>();
      check(() => BinomialDistribution(10, -0.1)).throws<ArgumentError>();
      check(() => BinomialDistribution(10, 1.1)).throws<ArgumentError>();
      check(() => BinomialDistribution(10, double.nan)).throws<ArgumentError>();
    });

    test('equality, hashCode, and string representation', () {
      check(dist == BinomialDistribution(10, 0.5)).isTrue;
      check(dist.hashCode).equals(BinomialDistribution(10, 0.5).hashCode);
      check(dist == BinomialDistribution(10, 0.4)).isFalse;
      check(dist.toString()).contains('BinomialDistribution');
    });
  });
}
