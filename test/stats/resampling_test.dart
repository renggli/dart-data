import 'dart:math' as math;

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
        expect(jackknife.samples, same(samples));
        expect(jackknife.confidenceLevel, 0.95);
        expect(jackknife.resamples, hasLength(10));
        for (var i = 0; i < 10; i++) {
          expect(jackknife.resamples[i], [
            ...IntegerRange(0, i),
            ...IntegerRange(i + 1, samples.length),
          ]);
          expect(() => jackknife.resamples[i][0] = 0, throwsUnsupportedError);
        }
        expect(jackknife.estimate, closeTo(4.5, 1e-6));
        expect(jackknife.bias, closeTo(0.0, 1e-6));
        expect(jackknife.standardError, closeTo(0.95742710, 1e-6));
        expect(jackknife.lowerBound, closeTo(2.62347735, 1e-6));
        expect(jackknife.upperBound, closeTo(6.37652265, 1e-6));
      });

      test('variance', () {
        final samples = <int>[0, 1, 2, 3, 4, 5, 6, 7, 8, 9];
        final jackknife = Jackknife<int>(
          samples,
          (list) => list.variance(population: true),
        );
        expect(jackknife.samples, same(samples));
        expect(jackknife.confidenceLevel, 0.95);
        expect(jackknife.resamples, hasLength(10));
        for (var i = 0; i < 10; i++) {
          expect(jackknife.resamples[i], [
            ...IntegerRange(0, i),
            ...IntegerRange(i + 1, samples.length),
          ]);
          expect(() => jackknife.resamples[i][0] = 0, throwsUnsupportedError);
        }
        expect(jackknife.estimate, closeTo(9.16666667, 1e-6));
        expect(jackknife.bias, closeTo(-0.91666667, 1e-6));
        expect(jackknife.standardError, closeTo(2.69124476, 1e-6));
        expect(jackknife.lowerBound, closeTo(3.89192387, 1e-6));
        expect(jackknife.upperBound, closeTo(14.44140947, 1e-6));
      });

      test('small samples', () {
        final samples = <int>[2, 4];
        final jackknife = Jackknife<int>(
          samples,
          (list) => list.arithmeticMean(),
          confidenceLevel: 0.90,
        );
        expect(jackknife.estimate, closeTo(3.0, 1e-6));
        expect(jackknife.bias, closeTo(0.0, 1e-6));
        expect(jackknife.standardError, closeTo(1.0, 1e-6));
        expect(jackknife.lowerBound, closeTo(1.35514638, 1e-6));
        expect(jackknife.upperBound, closeTo(4.64485361, 1e-6));
      });
    });

    group('bootstrap', () {
      test('bootstrap mean and confidence intervals', () {
        // Sample of 20 observations drawn around mean 50
        final sample = [
          48.2, 51.5, 49.8, 52.3, 47.9, 50.1, 51.2, 49.0, 50.8, 52.0,
          48.7, 50.5, 51.9, 49.3, 50.0, 48.5, 52.7, 49.6, 50.4, 51.1,
        ];

        final result = bootstrap<double>(
          sample,
          (list) => list.arithmeticMean(),
          resamples: 1000,
          confidenceLevel: 0.95,
          random: math.Random(42),
        );

        expect(result.estimate, closeTo(50.275, 1e-6));
        expect(result.bias, closeTo(0.0, 0.1));
        expect(result.standardError, greaterThan(0.2));
        expect(result.standardError, lessThan(0.5));

        final (pLow, pHigh) = result.percentileInterval;
        expect(pLow, lessThan(result.estimate));
        expect(pHigh, greaterThan(result.estimate));
        expect(pLow, greaterThan(49.0));
        expect(pHigh, lessThan(52.0));

        final (bcaLow, bcaHigh) = result.bcaInterval;
        expect(bcaLow, lessThan(result.estimate));
        expect(bcaHigh, greaterThan(result.estimate));
        expect(bcaLow, greaterThan(49.0));
        expect(bcaHigh, lessThan(52.0));
      });
    });
  });
}
