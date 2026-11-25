import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/linear.dart';
import 'package:data/stats.dart';
import 'package:data/tensor.dart';
import 'package:data/type.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('descriptive location and spread', () {
    test('mean, variance, and standardDeviation', () {
      const data = [2.0, 4.0, 4.0, 4.0, 5.0, 5.0, 7.0, 9.0];
      check(mean(data)).isCloseTo(5.0, 1e-12);
      check(variance(data)).isCloseTo(32.0 / 7.0, 1e-12);
      check(standardDeviation(data)).isCloseTo(math.sqrt(32.0 / 7.0), 1e-12);
      check(variance(data, population: true)).isCloseTo(4.0, 1e-12);
      check(standardDeviation(data, population: true)).isCloseTo(2.0, 1e-12);
      check(mean(const <double>[]).isNaN).isTrue;
      check(variance(const [1.0]).isNaN).isTrue;
      check(variance(const [1.0], population: true)).equals(0.0);
    });

    test(
      'geometricMean and harmonicMean handle interior and boundary cases',
      () {
        check(geometricMean(const [2.0, 8.0])).isCloseTo(4.0, 1e-12);
        check(geometricMean(const [1e200, 1e200])).isCloseTo(1e200, 1e188);
        check(geometricMean(const [0.0, 5.0])).equals(0.0);
        check(geometricMean(const [1.0, double.infinity]))
            .equals(double.infinity);
        check(geometricMean(const [0.0, double.infinity]).isNaN).isTrue;
        check(geometricMean(const [-1.0, 4.0]).isNaN).isTrue;
        check(geometricMean(const <double>[]).isNaN).isTrue;

        check(harmonicMean(const [2.5, 3.0, 10.0])).isCloseTo(3.6, 1e-12);
        check(harmonicMean(const [0.0, 5.0])).equals(0.0);
        check(harmonicMean(const [double.infinity, double.infinity]))
            .equals(double.infinity);
        check(harmonicMean(const [-1.0, 4.0]).isNaN).isTrue;
        check(harmonicMean(const <double>[]).isNaN).isTrue;
      },
    );

    test('quantile, quantiles, median, iqr, and medianAbsoluteDeviation', () {
      const data = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0];
      check(median(data)).isCloseTo(5.0, 1e-12);
      check(quantile(data, 0.0)).equals(1.0);
      check(quantile(data, 0.25)).equals(3.0);
      check(quantile(data, 0.5)).equals(5.0);
      check(quantile(data, 0.75)).equals(7.0);
      check(quantile(data, 1.0)).equals(9.0);
      check(iqr(data)).equals(4.0);
      check(quantiles(data, const [0.0, 0.25, 0.5, 0.75, 1.0]))
          .deepEquals([1.0, 3.0, 5.0, 7.0, 9.0]);
      check(quantiles(data, const <double>[])).isEmpty;
      check(quantiles(const <double>[], const [0.5]).single.isNaN).isTrue;

      const madSample = [1.0, 1.0, 2.0, 2.0, 4.0, 6.0, 9.0];
      check(medianAbsoluteDeviation(madSample)).equals(1.0);
      check(medianAbsoluteDeviation(madSample, scale: true))
          .isCloseTo(1.482602218505602, 1e-12);
      check(medianAbsoluteDeviation(const <double>[]).isNaN).isTrue;
      check(medianAbsoluteDeviation(const [double.infinity]).isNaN).isTrue;

      check(() => quantile(data, -0.1)).throws<ArgumentError>();
      check(() => quantile(data, 1.1)).throws<ArgumentError>();
      check(() => quantile(data, double.nan)).throws<ArgumentError>();
      check(() => quantiles(data, const [0.5, 1.2])).throws<ArgumentError>();
      check(quantile(const [1.0, double.nan, 3.0], 0.5).isNaN).isTrue;
    });
  });

  group('descriptive moments and stability', () {
    test(
      'skewness and kurtosis handle symmetry, bias options, and extreme scales',
      () {
        const symmetric = [1.0, 2.0, 3.0, 4.0, 5.0];
        check(skewness(symmetric)).isCloseTo(0.0, 1e-12);

        const skewed = [1.0, 1.0, 1.0, 2.0, 10.0];
        check(skewness(skewed)).isGreaterThan(1.0);
        check(kurtosis(skewed, excess: true)).isGreaterThan(0.0);
        check(kurtosis(skewed, excess: false))
            .isCloseTo(kurtosis(skewed, excess: true) + 3.0, 1e-12);
        check(kurtosis(skewed, bias: true, excess: false))
            .isCloseTo(kurtosis(skewed, bias: true, excess: true) + 3.0, 1e-12);

        // Scale invariance at 1e100 without overflow.
        final huge = [for (final v in skewed) v * 1e100];
        check(skewness(huge)).isCloseTo(skewness(skewed), 1e-12);
        check(kurtosis(huge)).isCloseTo(kurtosis(skewed), 1e-12);

        const constant = [5.0, 5.0, 5.0, 5.0];
        check(skewness(constant).isNaN).isTrue;
        check(kurtosis(constant).isNaN).isTrue;
        check(skewness(const [1.0, 2.0]).isNaN).isTrue;
        check(kurtosis(const [1.0, 2.0, 3.0]).isNaN).isTrue;
      },
    );
  });

  group('descriptive correlation and association', () {
    test(
      'covariance and pearsonCorrelation operate accurately in single pass',
      () {
        const x = [1.0, 2.0, 3.0, 4.0, 5.0];
        const y = [2.0, 4.0, 6.0, 8.0, 10.0];
        check(covariance(x, y)).isCloseTo(5.0, 1e-12);
        check(covariance(x, y, population: true)).isCloseTo(4.0, 1e-12);
        check(pearsonCorrelation(x, y)).isCloseTo(1.0, 1e-12);

        // Avoid ssX * ssY overflow at 1e160 and underflow at 1e-200.
        const hugeX = [1e160, 2e160, 3e160];
        const hugeY = [3e160, 2e160, 1e160];
        check(pearsonCorrelation(hugeX, hugeY)).isCloseTo(-1.0, 1e-12);
        const tinyX = [1e-200, 2e-200, 3e-200];
        const tinyY = [2e-200, 4e-200, 6e-200];
        check(pearsonCorrelation(tinyX, tinyY)).isCloseTo(1.0, 1e-12);

        check(covariance(const [1.0], const [2.0]).isNaN).isTrue;
        check(pearsonCorrelation(const [1.0], const [2.0]).isNaN).isTrue;
        check(pearsonCorrelation(const [1.0, 1.0], const [1.0, 2.0]).isNaN)
            .isTrue;
        check(() => covariance(const [1.0], const [1.0, 2.0]))
            .throws<ArgumentError>();
        check(() => covariance(const [1.0, 2.0], const [1.0]))
            .throws<ArgumentError>();
        check(() => pearsonCorrelation(const [1.0], const [1.0, 2.0]))
            .throws<ArgumentError>();
        check(() => pearsonCorrelation(const [1.0, 2.0], const [1.0]))
            .throws<ArgumentError>();
      },
    );

    test('rankData, spearmanCorrelation, and kendallCorrelation', () {
      check(rankData(const [10.0, 20.0, 20.0, 30.0]))
          .deepEquals([1.0, 2.5, 2.5, 4.0]);
      check(rankData(const [1.0, double.nan, 3.0]).any((r) => r.isNaN)).isTrue;

      const x = [1.0, 2.0, 3.0, 4.0, 5.0];
      final yExp = x.map(math.exp).toList();
      check(spearmanCorrelation(x, yExp)).isCloseTo(1.0, 1e-12);
      check(kendallCorrelation(x, yExp)).isCloseTo(1.0, 1e-12);
      check(kendallCorrelation(x, const [5.0, 4.0, 3.0, 2.0, 1.0]))
          .isCloseTo(-1.0, 1e-12);

      // Kendall tau-b exact formula with ties: [1, 2, 2, 3] vs [1, 2, 3, 2].
      // Pairs: 3 concordant, 1 discordant, 1 tie in x, 1 tie in y => (3 - 1) / sqrt(5 * 5) = 0.4.
      check(
        kendallCorrelation(
          const [1.0, 2.0, 2.0, 3.0],
          const [1.0, 2.0, 3.0, 2.0],
        ),
      ).isCloseTo(0.4, 1e-12);
      // Joint (x, y) tie: [1, 2, 2, 3] vs [1, 2, 2, 3] => 5 concordant, 0 discordant => 1.0.
      check(
        kendallCorrelation(
          const [1.0, 2.0, 2.0, 3.0],
          const [1.0, 2.0, 2.0, 3.0],
        ),
      ).isCloseTo(1.0, 1e-12);
      // Asymmetric ties: [1, 2, 2, 3] (1 x-tie) vs [1, 2, 2, 2] (3 y-ties, 1 joint).
      // P = 3, Q = 0, denom = sqrt(5 * 3) = sqrt(15).
      check(
        kendallCorrelation(
          const [1.0, 2.0, 2.0, 3.0],
          const [1.0, 2.0, 2.0, 2.0],
        ),
      ).isCloseTo(3.0 / math.sqrt(15.0), 1e-12);

      check(
        spearmanCorrelation(const [1.0, 2.0], const [double.nan, 2.0]).isNaN,
      ).isTrue;
      check(kendallCorrelation(const [1.0, 2.0], const [double.nan, 2.0]).isNaN)
          .isTrue;
      check(
        kendallCorrelation(const [5.0, 5.0, 5.0], const [1.0, 2.0, 3.0]).isNaN,
      ).isTrue;
      check(() => kendallCorrelation(const [1.0], const [1.0, 2.0]))
          .throws<ArgumentError>();
    });
  });

  group('descriptive covariance and correlation matrices', () {
    test('computes covariance, Pearson, Spearman, and Kendall matrices', () {
      final matrix = Matrix<double>.fromRows(const [
        [1.0, 2.0, 3.0],
        [2.0, 4.0, 1.0],
        [3.0, 6.0, 2.0],
      ], type: DataType.float64);

      final cov = covarianceMatrix(matrix);
      check(cov.get(0, 0)).isCloseTo(1.0, 1e-12);
      check(cov.get(1, 1)).isCloseTo(4.0, 1e-12);
      check(cov.get(0, 1)).isCloseTo(2.0, 1e-12);

      final popCov = covarianceMatrix(matrix, population: true);
      check(popCov.get(0, 0)).isCloseTo(2.0 / 3.0, 1e-12);
      check(covarianceMatrix(matrix, rowVar: true).rowCount).equals(3);

      final pearson = pearsonCorrelationMatrix(matrix);
      check(pearson.get(0, 1)).isCloseTo(1.0, 1e-12);

      final spearman = spearmanCorrelationMatrix(matrix);
      check(spearman.get(0, 1)).isCloseTo(1.0, 1e-12);
      check(spearmanCorrelationMatrix(matrix, rowVar: true).get(0, 1))
          .isCloseTo(-0.5, 1e-12);

      final kendall = kendallCorrelationMatrix(matrix);
      check(kendall.get(0, 0)).equals(1.0);
      check(kendall.get(0, 1)).isCloseTo(1.0, 1e-12);
      check(kendall.get(0, 2)).isCloseTo(-1.0 / 3.0, 1e-12);
      check(kendall.get(2, 0)).equals(kendall.get(0, 2));
      check(kendallCorrelationMatrix(matrix, rowVar: true).get(0, 1))
          .isCloseTo(-1.0 / 3.0, 1e-12);
    });

    test('handles constant columns and validates observation counts', () {
      final constMatrix = Matrix<double>.fromRows(const [
        [1.0, 5.0],
        [2.0, 5.0],
        [3.0, 5.0],
      ]);
      final pearson = constMatrix.pearsonCorrelationMatrix();
      check(pearson.get(0, 0)).isCloseTo(1.0, 1e-12);
      check(pearson.get(1, 1).isNaN).isTrue;
      check(pearson.get(0, 1).isNaN).isTrue;

      final kendall = constMatrix.kendallCorrelationMatrix();
      check(kendall.get(0, 0)).equals(1.0);
      check(kendall.get(1, 1).isNaN).isTrue;
      check(kendall.get(0, 1).isNaN).isTrue;

      final singleRow = Matrix<double>.fromRows(const [
        [1.0, 2.0],
      ]);
      check(singleRow.covarianceMatrix).throws<ArgumentError>();
      check(singleRow.covarianceMatrix(population: true).get(0, 0)).equals(0.0);
      check(singleRow.pearsonCorrelationMatrix).throws<ArgumentError>();
      check(singleRow.spearmanCorrelationMatrix).throws<ArgumentError>();
      check(singleRow.kendallCorrelationMatrix).throws<ArgumentError>();
      check(() => covarianceMatrix(Matrix<double>.filled(3, 0, 0.0)))
          .throws<ArgumentError>();
    });
  });

  group('weighted statistics and moving averages', () {
    test('weightedMean, weightedVariance, and weightedStandardDeviation', () {
      const values = [10.0, 20.0, 30.0];
      const weights = [1.0, 2.0, 1.0];

      check(weightedMean(values, weights)).isCloseTo(20.0, 1e-12);
      check(weightedVariance(values, weights)).isCloseTo(80.0, 1e-12);
      check(weightedStandardDeviation(values, weights))
          .isCloseTo(math.sqrt(80.0), 1e-12);
      check(weightedVariance(values, weights, unbiased: false))
          .isCloseTo(50.0, 1e-12);

      // Weight scaling invariance even at extreme weight magnitudes (1e200).
      const hugeWeights = [1e200, 2e200, 1e200];
      check(weightedVariance(values, hugeWeights)).isCloseTo(80.0, 1e-10);

      check(weightedMean(const <double>[], const <double>[]).isNaN).isTrue;
      check(weightedVariance(const <double>[], const <double>[]).isNaN).isTrue;
      check(() => weightedMean(const [1.0], const [1.0, 2.0]))
          .throws<ArgumentError>();
      check(() => weightedMean(const [1.0, 2.0], const [1.0]))
          .throws<ArgumentError>();
      check(weightedMean(const [double.nan, 2.0], const [0.0, 1.0]).isNaN)
          .isTrue;
      check(() => weightedMean(const [1.0], const [-1.0]))
          .throws<ArgumentError>();
      check(() => weightedMean(const [1.0], const [double.nan]))
          .throws<ArgumentError>();
      check(() => weightedVariance(const [1.0], const [1.0, 2.0]))
          .throws<ArgumentError>();
      check(() => weightedVariance(const [1.0, 2.0], const [1.0]))
          .throws<ArgumentError>();
      check(() => weightedVariance(const [1.0], const [double.infinity]))
          .throws<ArgumentError>();
    });

    test('movingAverage resists spike cancellation and NaN poisoning', () {
      const data = [1.0, 2.0, 3.0, 4.0, 5.0];
      check(movingAverage(data, 3)).deepEquals([2.0, 3.0, 4.0]);
      check(movingAverage(data, 1)).deepEquals(data);
      check(movingAverage(data, 5)).deepEquals([3.0]);

      // Spike of 1e16 leaving window must not wipe out subsequent unit sums.
      final spiked = [1e16, 1.0, 1.0, 1.0, 1.0];
      final smaSpike = movingAverage(spiked, 3);
      check(smaSpike[1]).isCloseTo(1.0, 1e-12);
      check(smaSpike[2]).isCloseTo(1.0, 1e-12);

      // NaN exiting window must recover clean subsequent window averages.
      final nanSeries = [double.nan, 2.0, 4.0, 6.0];
      final smaNan = movingAverage(nanSeries, 2);
      check(smaNan[0].isNaN).isTrue;
      check(smaNan[1]).equals(3.0);
      check(smaNan[2]).equals(5.0);

      check(() => movingAverage(data, 0)).throws<ArgumentError>();
      check(() => movingAverage(data, 6)).throws<ArgumentError>();
    });

    test('exponentialMovingAverage validates alpha including NaN', () {
      const data = [10.0, 20.0, 30.0];
      check(exponentialMovingAverage(data, 0.5)).deepEquals([10.0, 15.0, 22.5]);
      check(exponentialMovingAverage(data, 1.0)).deepEquals(data);
      check(exponentialMovingAverage(const <double>[], 0.5)).isEmpty;

      check(() => exponentialMovingAverage(data, 0.0)).throws<ArgumentError>();
      check(() => exponentialMovingAverage(data, 1.5)).throws<ArgumentError>();
      check(() => exponentialMovingAverage(data, double.nan))
          .throws<ArgumentError>();
    });
  });

  group('descriptive extensions', () {
    test('Iterable<num> and Iterable<int> extensions', () {
      const data = [1.0, 2.0, 2.0, 3.0, 4.0];
      check(data.sum()).equals(12.0);
      check(data.product()).equals(48.0);
      check(data.mean()).equals(2.4);
      check(data.geometricMean()).isCloseTo(math.pow(48.0, 0.2), 1e-12);
      check(data.harmonicMean()).isCloseTo(
        mean([1.0, 2.0, 2.0, 3.0, 4.0]) > 0
            ? 5.0 / (1 + 0.5 + 0.5 + 1 / 3 + 0.25)
            : 0,
        1e-12,
      );
      check(data.variance()).isCloseTo(variance(data), 1e-12);
      check(data.standardDeviation()).isCloseTo(standardDeviation(data), 1e-12);
      check(data.median()).equals(2.0);
      check(data.quantile(0.5)).equals(2.0);
      check(data.quantiles(const [0.0, 1.0])).deepEquals([1.0, 4.0]);
      check(data.iqr()).equals(1.0);
      check(data.medianAbsoluteDeviation()).equals(1.0);
      check(data.skewness().isFinite).isTrue;
      check(data.kurtosis(bias: true, excess: false).isFinite).isTrue;
      check(data.weightedMean(const [1, 1, 1, 1, 1]))
          .isCloseTo(data.mean(), 1e-12);
      check(data.weightedVariance(const [1, 1, 1, 1, 1]))
          .isCloseTo(data.variance(), 1e-12);
      check(data.weightedStandardDeviation(const [1, 1, 1, 1, 1]))
          .isCloseTo(data.standardDeviation(), 1e-12);
      check(data.movingAverage(2).length).equals(4);
      check(data.exponentialMovingAverage(0.5).length).equals(5);

      const ints = [1, 2, 3, 4];
      check(ints.sum()).equals(10);
      check(ints.product()).equals(24);
    });

    test('Vector<num> extensions including contiguous vForce slice path', () {
      final vec1 = Vector<double>.fromList(const [
        1.0,
        2.0,
        3.0,
        4.0,
        5.0,
      ], type: DataType.float64);
      final vec2 = Vector<double>.fromList(const [
        2.0,
        4.0,
        6.0,
        8.0,
        10.0,
      ], type: DataType.float64);
      check(DescriptiveVectorNumExtension(vec1).sum()).equals(15.0);
      check(vec1.mean()).equals(3.0);
      check(vec1.geometricMean()).isCloseTo(math.pow(120.0, 0.2), 1e-12);
      check(vec1.harmonicMean())
          .isCloseTo(5.0 / (1 + 0.5 + 1 / 3 + 0.25 + 0.2), 1e-12);
      check(vec1.variance()).isCloseTo(2.5, 1e-12);
      check(vec1.standardDeviation()).isCloseTo(math.sqrt(2.5), 1e-12);
      check(vec1.median()).equals(3.0);
      check(vec1.quantile(0.5)).equals(3.0);
      check(vec1.quantiles(const [0.0, 1.0])).deepEquals([1.0, 5.0]);
      check(vec1.iqr()).equals(2.0);
      check(vec1.medianAbsoluteDeviation()).equals(1.0);
      check(vec1.skewness()).isCloseTo(0.0, 1e-12);
      check(vec1.kurtosis()).isCloseTo(-1.2, 1e-12);
      check(vec1.covariance(vec2)).isCloseTo(5.0, 1e-12);
      check(vec1.pearsonCorrelation(vec2)).isCloseTo(1.0, 1e-12);
      check(vec1.spearmanCorrelation(vec2)).isCloseTo(1.0, 1e-12);
      check(vec1.kendallCorrelation(vec2)).isCloseTo(1.0, 1e-12);

      final w = Vector<double>.fromList(const [
        1.0,
        2.0,
        1.0,
        2.0,
        1.0,
      ], type: DataType.float64);
      check(vec1.weightedMean(w)).equals(3.0);
      check(vec1.weightedStandardDeviation(w))
          .isCloseTo(math.sqrt(vec1.weightedVariance(w)), 1e-12);
      check(vec1.movingAverage(3).length).equals(3);
      check(vec1.exponentialMovingAverage(0.5).length).equals(5);

      final largeVec = Vector<double>.generate(
        100,
        (i) => i.toDouble(),
        type: DataType.float64,
      );
      final sliceVec = largeVec.subVector(20, 90);
      check(DescriptiveVectorNumExtension(sliceVec).sum())
          .isCloseTo(3815.0, 1e-10);
      check(sliceVec.mean()).isCloseTo(54.5, 1e-10);
      check(sliceVec.variance())
          .isCloseTo(variance([for (var i = 20; i < 90; i++) i]), 1e-10);
    });

    test('Tensor<num> and Matrix<num> extensions', () {
      final tensor = Tensor<double>.fromObject(const [
        [1.0, 2.0],
        [2.0, 4.0],
        [3.0, 6.0],
      ], type: DataType.float64);
      check(DescriptiveTensorNumExtension(tensor).mean()).isCloseTo(3.0, 1e-12);
      check(tensor.geometricMean()).isGreaterThan(0.0);
      check(tensor.harmonicMean()).isGreaterThan(0.0);
      check(DescriptiveTensorNumExtension(tensor).variance())
          .isGreaterThan(0.0);
      check(tensor.standardDeviation()).isCloseTo(
        math.sqrt(DescriptiveTensorNumExtension(tensor).variance()),
        1e-12,
      );
      check(tensor.median()).isCloseTo(2.5, 1e-12);
      check(tensor.quantile(0.5)).isCloseTo(2.5, 1e-12);
      check(tensor.quantiles(const [0.0, 1.0])).deepEquals([1.0, 6.0]);
      check(tensor.iqr()).isCloseTo(1.75, 1e-12);
      check(tensor.medianAbsoluteDeviation()).isCloseTo(1.0, 1e-12);
      check(tensor.skewness().isFinite).isTrue;
      check(tensor.kurtosis().isFinite).isTrue;
      check(tensor.kendallCorrelationMatrix().get(0, 1)).isCloseTo(1.0, 1e-12);

      final rank1 = Tensor<double>.fromIterable(const [1.0, 2.0, 3.0]);
      check(rank1.covarianceMatrix).throws<ArgumentError>();
      check(rank1.pearsonCorrelationMatrix).throws<ArgumentError>();
      check(rank1.spearmanCorrelationMatrix).throws<ArgumentError>();
      check(rank1.kendallCorrelationMatrix).throws<ArgumentError>();

      final matrix = Matrix<double>.fromRows(const [
        [1.0, 2.0],
        [3.0, 4.0],
      ]);
      check(matrix.mean()).isCloseTo(2.5, 1e-12);
      check(matrix.geometricMean()).isCloseTo(math.pow(24.0, 0.25), 1e-12);
      check(matrix.harmonicMean()).isCloseTo(48.0 / 25.0, 1e-12);
      check(matrix.variance()).isCloseTo(5.0 / 3.0, 1e-12);
      check(matrix.standardDeviation()).isCloseTo(math.sqrt(5.0 / 3.0), 1e-12);
      check(matrix.median()).isCloseTo(2.5, 1e-12);
      check(matrix.quantile(0.5)).isCloseTo(2.5, 1e-12);
      check(matrix.quantiles(const [0.0, 1.0])).deepEquals([1.0, 4.0]);
      check(matrix.iqr()).isCloseTo(1.5, 1e-12);
      check(matrix.medianAbsoluteDeviation()).equals(1.0);
      check(matrix.skewness().isFinite).isTrue;
      check(matrix.kurtosis().isFinite).isTrue;
      check(matrix.kendallCorrelationMatrix().get(0, 1)).equals(1.0);
    });
  });
}
