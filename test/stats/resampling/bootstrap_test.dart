import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/stats.dart';
import 'package:test/scaffolding.dart';

void main() {
  const sample = [
    48.2,
    51.5,
    49.8,
    52.3,
    47.9,
    50.1,
    51.2,
    49.0,
    50.8,
    52.0,
    48.7,
    50.5,
    51.9,
    49.3,
    50.0,
    48.5,
    52.7,
    49.6,
    50.4,
    51.1,
  ];

  group('Bootstrap confidence intervals and estimates', () {
    test('computes normal, basic, percentile, and BCa intervals', () {
      final result = Bootstrap<double>(
        sample,
        mean,
        resamples: 1000,
        confidenceLevel: 0.95,
        random: math.Random(42),
      );

      check(result.resamples).equals(1000);
      check(result.confidenceLevel).equals(0.95);
      check(result.estimate).isCloseTo(50.275, 1e-12);
      check(result.bias).isCloseTo(0.0, 0.1);
      check(result.standardError).isGreaterThan(0.2);
      check(result.standardError).isLessThan(0.5);

      final (lower: nLow, upper: nHigh) = result.normalInterval;
      check(nLow).isLessThan(result.estimate);
      check(nHigh).isGreaterThan(result.estimate);

      final (lower: bLow, upper: bHigh) = result.basicInterval;
      final (lower: pLow, upper: pHigh) = result.percentileInterval;
      check(bLow).isCloseTo(2.0 * result.estimate - pHigh, 1e-12);
      check(bHigh).isCloseTo(2.0 * result.estimate - pLow, 1e-12);

      final (lower: bcaLow, upper: bcaHigh) = result.bcaInterval;
      check(bcaLow).isLessThan(result.estimate);
      check(bcaHigh).isGreaterThan(result.estimate);
      check(result.lowerBound).equals(bcaLow);
      check(result.upperBound).equals(bcaHigh);
      check(result.toString()).contains('Bootstrap');
    });

    test('supports parametric and generic distribution bootstrap', () {
      final fittedDist = NormalDistribution.fit(sample);
      final distResult = Bootstrap.distribution<double>(
        samples: sample,
        statistic: mean,
        distribution: fittedDist,
        resamples: 300,
        confidenceLevel: 0.95,
        random: math.Random(42),
      );
      check(distResult.estimate).isCloseTo(50.275, 1e-12);
      check(distResult.bcaInterval.lower).isLessThan(distResult.estimate);
      check(distResult.bcaInterval.upper).isGreaterThan(distResult.estimate);

      // Works for integer distributions too via Bootstrap.distribution<int>.
      final poissonDist = PoissonDistribution(5.0);
      final intBoot = Bootstrap.distribution<int>(
        samples: const [3, 4, 5, 6, 7],
        statistic: mean,
        distribution: poissonDist,
        resamples: 100,
        random: math.Random(7),
      );
      check(intBoot.estimate).equals(5.0);

      final custom = Bootstrap<double>.parametric(
        samples: const [1.0, 2.0, 3.0, 4.0, 5.0],
        statistic: mean,
        sampler: (rng) => [for (var i = 0; i < 5; i++) rng.nextDouble() * 5.0],
        resamples: 200,
        confidenceLevel: 0.90,
        random: math.Random(42),
      );
      check(custom.bootstrapEstimates.length).equals(200);
      check(custom.confidenceLevel).equals(0.90);
    });

    test('handles constant samples and enforces immutability', () {
      final mutable = [3.0, 3.0, 3.0, 3.0];
      final constBoot = Bootstrap<double>(
        mutable,
        mean,
        resamples: 50,
        random: math.Random(1),
      );
      mutable[0] = 999.0;
      check(constBoot.samples[0]).equals(3.0);
      check(constBoot.bcaInterval.lower).equals(3.0);
      check(constBoot.bcaInterval.upper).equals(3.0);
      check(() => constBoot.samples[0] = 1.0).throws<UnsupportedError>();
      check(() => constBoot.bootstrapEstimates[0] = 1.0)
          .throws<UnsupportedError>();
    });

    test('validates samples, resamples, and confidenceLevel', () {
      check(() => Bootstrap<double>(const [1.0], mean)).throws<ArgumentError>();
      check(() => Bootstrap<double>(const [1.0, 2.0], mean, resamples: 5))
          .throws<ArgumentError>();
      check(
        () => Bootstrap<double>(const [1.0, 2.0], mean, confidenceLevel: 0.0),
      ).throws<ArgumentError>();
      check(
        () => Bootstrap<double>(
          const [1.0, 2.0],
          mean,
          confidenceLevel: double.nan,
        ),
      ).throws<ArgumentError>();
    });
  });
}
