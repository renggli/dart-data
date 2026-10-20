import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/stats.dart';
import 'package:test/test.dart';

void main() {
  group('bootstrap', () {
    test('bootstrap mean and confidence intervals', () {
      // Sample of 20 observations drawn around mean 50
      final sample = [
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

      final result = Bootstrap<double>(
        sample,
        (list) => list.mean(),
        resamples: 1000,
        confidenceLevel: 0.95,
        random: math.Random(42),
      );

      check(result.samples).identicalTo(sample);
      check(result.resamples).equals(1000);
      check(result.confidenceLevel).equals(0.95);
      check(result.estimate).isCloseTo(50.275, 1e-6);
      check(result.bias).isCloseTo(0.0, 0.1);
      check(result.standardError).isGreaterThan(0.2);
      check(result.standardError).isLessThan(0.5);

      final (pLow, pHigh) = result.percentileInterval;
      check(pLow).isLessThan(result.estimate);
      check(pHigh).isGreaterThan(result.estimate);
      check(pLow).isGreaterThan(49.0);
      check(pHigh).isLessThan(52.0);

      final (bcaLow, bcaHigh) = result.bcaInterval;
      check(bcaLow).isLessThan(result.estimate);
      check(bcaHigh).isGreaterThan(result.estimate);
      check(bcaLow).isGreaterThan(49.0);
      check(bcaHigh).isLessThan(52.0);

      check(result.lowerBound).equals(bcaLow);
      check(result.upperBound).equals(bcaHigh);
    });

    test('parametric bootstrap with fitted distribution', () {
      final sample = [
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
      ];

      final fittedDist = NormalDistribution.fit(sample);
      final result = Bootstrap.distribution(
        samples: sample,
        statistic: (list) => list.mean(),
        distribution: fittedDist,
        resamples: 500,
        confidenceLevel: 0.95,
        random: math.Random(42),
      );

      check(result.estimate).isCloseTo(50.28, 0.1);
      check(result.standardError).isGreaterThan(0.1);
      final (pLow, pHigh) = result.percentileInterval;
      final (bcaLow, bcaHigh) = result.bcaInterval;
      check(pLow).isLessThan(result.estimate);
      check(pHigh).isGreaterThan(result.estimate);
      check(bcaLow).isLessThan(result.estimate);
      check(bcaHigh).isGreaterThan(result.estimate);
      check(result.lowerBound).equals(bcaLow);
      check(result.upperBound).equals(bcaHigh);
      check(result.toString()).contains('estimate');
    });

    test('parametric bootstrap with custom sampler', () {
      final sample = [1.0, 2.0, 3.0, 4.0, 5.0];
      final result = Bootstrap<double>.parametric(
        samples: sample,
        statistic: (list) => list.mean(),
        sampler: (rng) => [for (var i = 0; i < 5; i++) rng.nextDouble() * 5.0],
        resamples: 200,
        confidenceLevel: 0.90,
        random: math.Random(42),
      );
      check(result.estimate).isCloseTo(3.0, 1e-6);
      check(result.bootstrapEstimates).length.equals(200);
      check(result.confidenceLevel).equals(0.90);
    });

    test('resampling assertions and string printing', () {
      final samples = [1.0, 2.0, 3.0];
      final bootstrap = Bootstrap<double>(samples, (list) => list.mean());
      check(bootstrap.toString()).contains('Bootstrap');

      check(() => Bootstrap<double>([1.0], (list) => list[0]))
          .throws<AssertionError>();
      check(() => Bootstrap<double>(samples, (list) => list[0], resamples: 5))
          .throws<AssertionError>();
      check(
        () =>
            Bootstrap<double>(samples, (list) => list[0], confidenceLevel: 0.0),
      ).throws<AssertionError>();
      check(
        () =>
            Bootstrap<double>(samples, (list) => list[0], confidenceLevel: 1.0),
      ).throws<AssertionError>();

      const norm = NormalDistribution(0.0, 1.0);
      check(
        () => Bootstrap.distribution(
          samples: [1.0],
          statistic: (list) => list[0].toDouble(),
          distribution: norm,
        ),
      ).throws<AssertionError>();
      check(
        () => Bootstrap.distribution(
          samples: samples,
          statistic: (list) => list[0].toDouble(),
          distribution: norm,
          resamples: 5,
        ),
      ).throws<AssertionError>();
      check(
        () => Bootstrap.distribution(
          samples: samples,
          statistic: (list) => list[0].toDouble(),
          distribution: norm,
          confidenceLevel: -0.1,
        ),
      ).throws<AssertionError>();
    });
  });
}
