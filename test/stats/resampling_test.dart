import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/stats.dart';
import 'package:more/collection.dart' show IntegerRange;
import 'package:test/test.dart';

void main() {
  group('resampling', () {
    group('jackknife', () {
      test('mean', () {
        final samples = <int>[0, 1, 2, 3, 4, 5, 6, 7, 8, 9];
        final jackknife = Jackknife<int>(
          samples,
          (list) => list.arithmeticMean(),
        );
        check(jackknife.samples).identicalTo(samples);
        check(jackknife.confidenceLevel).equals(0.95);
        check(jackknife.resamples).length.equals(10);
        for (var i = 0; i < 10; i++) {
          check(jackknife.resamples[i]).deepEquals([
            ...IntegerRange(0, i),
            ...IntegerRange(i + 1, samples.length),
          ]);
          check(() => jackknife.resamples[i][0] = 0).throws<UnsupportedError>();
        }
        check(jackknife.estimate).isCloseTo(4.5, 1e-6);
        check(jackknife.bias).isCloseTo(0.0, 1e-6);
        check(jackknife.standardError).isCloseTo(0.95742710, 1e-6);
        check(jackknife.lowerBound).isCloseTo(2.62347735, 1e-6);
        check(jackknife.upperBound).isCloseTo(6.37652265, 1e-6);
      });

      test('variance', () {
        final samples = <int>[0, 1, 2, 3, 4, 5, 6, 7, 8, 9];
        final jackknife = Jackknife<int>(
          samples,
          (list) => list.variance(population: true),
        );
        check(jackknife.samples).identicalTo(samples);
        check(jackknife.confidenceLevel).equals(0.95);
        check(jackknife.resamples).length.equals(10);
        for (var i = 0; i < 10; i++) {
          check(jackknife.resamples[i]).deepEquals([
            ...IntegerRange(0, i),
            ...IntegerRange(i + 1, samples.length),
          ]);
          check(() => jackknife.resamples[i][0] = 0).throws<UnsupportedError>();
        }
        check(jackknife.estimate).isCloseTo(9.16666667, 1e-6);
        check(jackknife.bias).isCloseTo(-0.91666667, 1e-6);
        check(jackknife.standardError).isCloseTo(2.69124476, 1e-6);
        check(jackknife.lowerBound).isCloseTo(3.89192387, 1e-6);
        check(jackknife.upperBound).isCloseTo(14.44140947, 1e-6);
      });

      test('small samples', () {
        final samples = <int>[2, 4];
        final jackknife = Jackknife<int>(
          samples,
          (list) => list.arithmeticMean(),
          confidenceLevel: 0.90,
        );
        check(jackknife.estimate).isCloseTo(3.0, 1e-6);
        check(jackknife.bias).isCloseTo(0.0, 1e-6);
        check(jackknife.standardError).isCloseTo(1.0, 1e-6);
        check(jackknife.lowerBound).isCloseTo(1.35514638, 1e-6);
        check(jackknife.upperBound).isCloseTo(4.64485361, 1e-6);
      });
    });

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

        final result = bootstrap<double>(
          sample,
          (list) => list.arithmeticMean(),
          resamples: 1000,
          confidenceLevel: 0.95,
          random: math.Random(42),
        );

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
        final result = parametricBootstrapDistribution(
          sample: sample,
          statistic: (list) => list.arithmeticMean(),
          distribution: fittedDist,
          resamples: 500,
          confidenceLevel: 0.95,
          random: math.Random(42),
        );

        check(result.estimate).isCloseTo(50.28, 0.1);
        check(result.standardError).isGreaterThan(0.1);
        check(result.percentileInterval.$1).isLessThan(result.estimate);
        check(result.percentileInterval.$2).isGreaterThan(result.estimate);
        check(result.bcaInterval.$1).isLessThan(result.estimate);
        check(result.bcaInterval.$2).isGreaterThan(result.estimate);
        check(result.toString()).contains('estimate');
      });

      test('resampling errors and string printing', () {
        final samples = [1.0, 2.0, 3.0];
        final jackknife = Jackknife<double>(
          samples,
          (list) => list.arithmeticMean(),
        );
        check(jackknife.toString()).contains('Jackknife');

        check(() => bootstrap([1.0], (list) => list[0]))
            .throws<ArgumentError>();
        check(() => bootstrap(samples, (list) => list[0], resamples: 5))
            .throws<ArgumentError>();
        check(() => bootstrap(samples, (list) => list[0], confidenceLevel: 0.0))
            .throws<ArgumentError>();
        check(() => bootstrap(samples, (list) => list[0], confidenceLevel: 1.0))
            .throws<ArgumentError>();

        const norm = NormalDistribution(0.0, 1.0);
        check(
          () => parametricBootstrapDistribution(
            sample: [1.0],
            statistic: (list) => list[0].toDouble(),
            distribution: norm,
          ),
        ).throws<ArgumentError>();
        check(
          () => parametricBootstrapDistribution(
            sample: samples,
            statistic: (list) => list[0].toDouble(),
            distribution: norm,
            resamples: 5,
          ),
        ).throws<ArgumentError>();
        check(
          () => parametricBootstrapDistribution(
            sample: samples,
            statistic: (list) => list[0].toDouble(),
            distribution: norm,
            confidenceLevel: -0.1,
          ),
        ).throws<ArgumentError>();
      });
    });
  });
}
