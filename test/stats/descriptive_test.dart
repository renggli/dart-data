import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/linear.dart';
import 'package:data/stats.dart';
import 'package:data/tensor.dart';
import 'package:data/type.dart';
import 'package:test/test.dart';

void main() {
  group('descriptive', () {
    test('mean, variance, and standard deviation', () {
      final data = [2.0, 4.0, 4.0, 4.0, 5.0, 5.0, 7.0, 9.0];
      check(mean(data)).isCloseTo(5.0, 1e-10);
      // Sample variance: 32 / 7, sample std: sqrt(32 / 7)
      check(variance(data)).isCloseTo(32.0 / 7.0, 1e-10);
      check(standardDeviation(data)).isCloseTo(math.sqrt(32.0 / 7.0), 1e-10);
      // Population variance: 4.0, population std: 2.0
      check(variance(data, population: true)).isCloseTo(4.0, 1e-10);
      check(standardDeviation(data, population: true)).isCloseTo(2.0, 1e-10);
    });

    test('median, quantiles, and IQR', () {
      final data = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0];
      check(median(data)).isCloseTo(5.0, 1e-10);
      check(quantile(data, 0.0)).isCloseTo(1.0, 1e-10);
      check(quantile(data, 0.25)).isCloseTo(3.0, 1e-10);
      check(quantile(data, 0.5)).isCloseTo(5.0, 1e-10);
      check(quantile(data, 0.75)).isCloseTo(7.0, 1e-10);
      check(quantile(data, 1.0)).isCloseTo(9.0, 1e-10);
      check(iqr(data)).isCloseTo(4.0, 1e-10);
    });

    test('skewness and kurtosis of symmetric vs skewed data', () {
      final symmetric = [1.0, 2.0, 3.0, 4.0, 5.0];
      check(skewness(symmetric)).isCloseTo(0.0, 1e-10);

      final skewed = [1.0, 1.0, 1.0, 2.0, 10.0];
      check(skewness(skewed)).isGreaterThan(1.0);
      check(kurtosis(skewed, excess: true)).isGreaterThan(0.0);
      check(kurtosis(skewed, excess: false))
          .isCloseTo(kurtosis(skewed, excess: true) + 3.0, 1e-10);
    });

    test('geometric and harmonic means', () {
      final values = [2.0, 8.0];
      check(values.geometricMean()).isCloseTo(4.0, 1e-10);

      final hValues = [2.5, 3.0, 10.0];
      check(hValues.harmonicMean()).isCloseTo(3.6, 1e-10);
    });

    test('vector extensions', () {
      final vec1 = Vector<double>.fromList([
        1.0,
        2.0,
        3.0,
        4.0,
        5.0,
      ], type: DataType.float64);
      final vec2 = Vector<double>.fromList([
        2.0,
        4.0,
        6.0,
        8.0,
        10.0,
      ], type: DataType.float64);

      check(vec1.mean()).isCloseTo(3.0, 1e-10);
      check(vec1.variance()).isCloseTo(2.5, 1e-10);
      check(vec1.standardDeviation()).isCloseTo(math.sqrt(2.5), 1e-10);
      check(vec1.median()).isCloseTo(3.0, 1e-10);
      check(vec1.quantile(0.5)).isCloseTo(3.0, 1e-10);
      check(vec1.iqr()).isCloseTo(2.0, 1e-10);
      check(vec1.skewness()).isCloseTo(0.0, 1e-10);
      check(vec1.kurtosis()).isCloseTo(-1.2, 1e-10);

      // Bivariate
      check(vec1.covariance(vec2)).isCloseTo(5.0, 1e-10);
      check(vec1.pearsonCorrelation(vec2)).isCloseTo(1.0, 1e-10);
      check(vec1.spearmanCorrelation(vec2)).isCloseTo(1.0, 1e-10);
    });

    test('tensor and matrix descriptive extensions', () {
      final tensor = Tensor<double>.fromObject([
        [1.0, 2.0],
        [2.0, 4.0],
        [3.0, 6.0],
      ], type: DataType.float64);

      check(DescriptiveTensorNumExtension(tensor).mean()).isCloseTo(3.0, 1e-10);
      check(tensor.median()).isCloseTo(2.5, 1e-10);
      check(tensor.iqr()).isCloseTo(1.75, 1e-10);

      final covT = tensor.covarianceMatrix();
      check(covT.rowCount).equals(2);
      check(covT.colCount).equals(2);
      check(covT.get(0, 0)).isCloseTo(1.0, 1e-10);
      check(covT.get(1, 1)).isCloseTo(4.0, 1e-10);

      final corrT = tensor.pearsonCorrelationMatrix();
      check(corrT.get(0, 1)).isCloseTo(1.0, 1e-10);

      final spearmanT = tensor.spearmanCorrelationMatrix();
      check(spearmanT.get(0, 1)).isCloseTo(1.0, 1e-10);

      final matrix = Matrix<double>.fromRows([
        [1.0, 2.0],
        [2.0, 4.0],
        [3.0, 6.0],
      ], type: DataType.float64);

      check(matrix.mean()).isCloseTo(3.0, 1e-10);
      final covM = matrix.covarianceMatrix();
      check(covM.get(0, 0)).isCloseTo(1.0, 1e-10);
      final covRow = matrix.covarianceMatrix(rowVar: true);
      check(covRow.rowCount).equals(3);
      final corrM = matrix.pearsonCorrelationMatrix();
      check(corrM.get(0, 1)).isCloseTo(1.0, 1e-10);
      final spearmanM = matrix.spearmanCorrelationMatrix();
      check(spearmanM.get(0, 1)).isCloseTo(1.0, 1e-10);

      // Large contiguous vector accelerated statistics
      final Vector<num> largeVec = Vector<double>.generate(
        100,
        (i) => i.toDouble(),
        type: DataType.float64,
      );
      check(DescriptiveVectorNumExtension(largeVec).sum())
          .isCloseTo(4950.0, 1e-10);
      check(largeVec.mean()).isCloseTo(49.5, 1e-10);
      check(largeVec.variance()).isGreaterThan(0.0);

      // Invalid matrix data error checking
      check(() => covarianceMatrix('invalid')).throws<ArgumentError>();
      check(() => spearmanCorrelationMatrix('invalid')).throws<ArgumentError>();
    });

    test('Pearson and Spearman correlations', () {
      final x = [1.0, 2.0, 3.0, 4.0, 5.0];
      final yLinear = [2.0, 4.0, 6.0, 8.0, 10.0];
      check(pearsonCorrelation(x, yLinear)).isCloseTo(1.0, 1e-10);
      check(spearmanCorrelation(x, yLinear)).isCloseTo(1.0, 1e-10);

      // Monotonic non-linear: y = exp(x)
      final yExp = x.map(math.exp).toList();
      check(spearmanCorrelation(x, yExp)).isCloseTo(1.0, 1e-10);
      check(pearsonCorrelation(x, yExp)).isLessThan(1.0);
      check(pearsonCorrelation(x, yExp)).isGreaterThan(0.8);

      // Negative correlation
      final yNeg = [5.0, 4.0, 3.0, 2.0, 1.0];
      check(pearsonCorrelation(x, yNeg)).isCloseTo(-1.0, 1e-10);
    });

    test('covariance matrix and correlation matrices', () {
      // 3 observations, 2 features
      // f1: [1, 2, 3], f2: [2, 4, 6]
      final matrix = Matrix<double>.fromRows([
        [1.0, 2.0],
        [2.0, 4.0],
        [3.0, 6.0],
      ], type: DataType.float64);

      final cov = covarianceMatrix(matrix);
      check(cov.rowCount).equals(2);
      check(cov.colCount).equals(2);
      check(cov.get(0, 0)).isCloseTo(1.0, 1e-10);
      check(cov.get(1, 1)).isCloseTo(4.0, 1e-10);
      check(cov.get(0, 1)).isCloseTo(2.0, 1e-10);
      check(cov.get(1, 0)).isCloseTo(2.0, 1e-10);

      final corr = pearsonCorrelationMatrix(matrix);
      check(corr.get(0, 0)).isCloseTo(1.0, 1e-10);
      check(corr.get(1, 1)).isCloseTo(1.0, 1e-10);
      check(corr.get(0, 1)).isCloseTo(1.0, 1e-10);
      check(corr.get(1, 0)).isCloseTo(1.0, 1e-10);

      final spearman = spearmanCorrelationMatrix(matrix);
      check(spearman.get(0, 1)).isCloseTo(1.0, 1e-10);
    });
  });

  group('Descriptive Statistics Utilities and Extensions', () {
    test(
      'top-level functions, tied ranks, and iterable/tensor/matrix extensions',
      () {
        final data = [1.0, 2.0, 2.0, 3.0, 4.0];
        check(quantile(data, 0.5)).isCloseTo(2.0, 1e-10);
        check(covariance(data, data)).isCloseTo(variance(data), 1e-10);

        // Tied ranks
        final ranks = rankData([10.0, 20.0, 20.0, 30.0]);
        check(ranks).deepEquals([1.0, 2.5, 2.5, 4.0]);

        // Iterable<num> extensions
        check(data.product()).isCloseTo(48.0, 1e-10);
        check(data.mean()).isCloseTo(mean(data), 1e-10);
        check(data.variance()).isCloseTo(variance(data), 1e-10);
        check(data.standardDeviation())
            .isCloseTo(standardDeviation(data), 1e-10);
        check(data.median()).isCloseTo(2.0, 1e-10);
        check(data.quantile(0.5)).isCloseTo(2.0, 1e-10);
        check(data.iqr()).isCloseTo(1.0, 1e-10);
        check(data.skewness()).isNotNull();
        check(data.kurtosis(bias: true, excess: false)).isNotNull();

        // Iterable<int> extensions
        final intList = [1, 2, 3, 4];
        check(intList.sum()).equals(10);
        check(intList.product()).equals(24);

        // Tensor extensions
        final tensor = Tensor<double>.fromIterable([1.0, 2.0, 3.0, 4.0]);
        check(tensor.variance()).isCloseTo(5.0 / 3.0, 1e-10);
        check(tensor.standardDeviation())
            .isCloseTo(math.sqrt(5.0 / 3.0), 1e-10);
        check(tensor.quantile(0.5)).isCloseTo(2.5, 1e-10);
        check(tensor.skewness()).isCloseTo(0.0, 1e-10);
        check(tensor.kurtosis()).isNotNull();

        // Matrix extensions
        final matrix = Matrix<double>.fromRows([
          [1.0, 2.0],
          [3.0, 4.0],
        ]);
        check(matrix.mean()).isCloseTo(2.5, 1e-10);
        check(matrix.variance()).isCloseTo(5.0 / 3.0, 1e-10);
        check(matrix.standardDeviation())
            .isCloseTo(math.sqrt(5.0 / 3.0), 1e-10);
        check(matrix.median()).isCloseTo(2.5, 1e-10);
        check(matrix.quantile(0.5)).isCloseTo(2.5, 1e-10);
        check(matrix.iqr()).isCloseTo(1.5, 1e-10);
        check(matrix.skewness()).isCloseTo(0.0, 1e-10);
        check(matrix.kurtosis()).isNotNull();
        check(matrix.spearmanCorrelationMatrix().rowCount).equals(2);

        // Covariance errors
        check(() => covariance([1.0], [1.0, 2.0])).throws<ArgumentError>();
        check(() => pearsonCorrelation([1.0], [1.0, 2.0]))
            .throws<ArgumentError>();
        check(
          () => Matrix<double>.fromRows([
            [1.0, 2.0],
          ]).covarianceMatrix(),
        ).throws<ArgumentError>();
      },
    );

    test('weighted mean and weighted variance', () {
      final values = [10.0, 20.0, 30.0];
      final weights = [1.0, 2.0, 1.0];

      // Weighted mean: (10*1 + 20*2 + 30*1) / 4 = 20.0
      check(weightedMean(values, weights)).isCloseTo(20.0, 1e-10);
      check(values.weightedMean(weights)).isCloseTo(20.0, 1e-10);

      final vValues = Vector<double>.fromList(values, type: DataType.float64);
      final vWeights = Vector<double>.fromList(weights, type: DataType.float64);
      check(vValues.weightedMean(vWeights)).isCloseTo(20.0, 1e-10);

      // Weighted variance (sample / unbiased with reliability weights):
      // V1 = 4, V2 = 1 + 4 + 1 = 6. V1 - V2/V1 = 4 - 1.5 = 2.5.
      // Diffs: (10-20)^2 = 100, (20-20)^2 = 0, (30-20)^2 = 100.
      // Weighted SS: 1*100 + 2*0 + 1*100 = 200.
      // Unbiased variance: 200 / 2.5 = 80.0
      // Biased variance: 200 / 4 = 50.0
      check(weightedVariance(values, weights)).isCloseTo(80.0, 1e-10);
      check(values.weightedVariance(weights)).isCloseTo(80.0, 1e-10);
      check(vValues.weightedVariance(vWeights)).isCloseTo(80.0, 1e-10);

      check(weightedVariance(values, weights, unbiased: false))
          .isCloseTo(50.0, 1e-10);

      // Equal weights matches standard unweighted variance
      final equalWeights = [1.0, 1.0, 1.0];
      check(weightedVariance(values, equalWeights))
          .isCloseTo(variance(values), 1e-10);

      // Error validation
      check(() => weightedMean([1.0], [1.0, 2.0])).throws<ArgumentError>();
      check(() => weightedMean([1.0, 2.0], [1.0])).throws<ArgumentError>();
      check(() => weightedMean([1.0], [-1.0])).throws<ArgumentError>();
      check(() => weightedVariance([1.0], [1.0, 2.0])).throws<ArgumentError>();
      check(() => weightedVariance([1.0], [-0.5])).throws<ArgumentError>();
      check(weightedMean([], []).isNaN).isTrue();
      check(weightedVariance([], []).isNaN).isTrue();
    });

    test('simple moving average (SMA)', () {
      final data = [1.0, 2.0, 3.0, 4.0, 5.0];
      final sma3 = movingAverage(data, 3);
      check(sma3.length).equals(3);
      check(sma3[0]).isCloseTo(2.0, 1e-10); // (1+2+3)/3
      check(sma3[1]).isCloseTo(3.0, 1e-10); // (2+3+4)/3
      check(sma3[2]).isCloseTo(4.0, 1e-10); // (3+4+5)/3

      // Extensions
      check(data.movingAverage(3)).deepEquals(sma3);
      final vec = Vector<double>.fromList(data, type: DataType.float64);
      final vecSma = vec.movingAverage(3);
      check(vecSma.toList()).deepEquals(sma3);

      // Window size == 1
      check(movingAverage(data, 1)).deepEquals(data);

      // Window size == length
      final fullWindow = movingAverage(data, 5);
      check(fullWindow.length).equals(1);
      check(fullWindow[0]).isCloseTo(3.0, 1e-10);

      // Errors
      check(() => movingAverage(data, 0)).throws<ArgumentError>();
      check(() => movingAverage(data, -2)).throws<ArgumentError>();
      check(() => movingAverage(data, 6)).throws<ArgumentError>();
    });

    test('exponential moving average (EMA)', () {
      final data = [10.0, 20.0, 30.0];
      final ema = exponentialMovingAverage(data, 0.5);
      check(ema.length).equals(3);
      check(ema[0]).isCloseTo(10.0, 1e-10);
      check(ema[1]).isCloseTo(15.0, 1e-10); // 0.5*20 + 0.5*10
      check(ema[2]).isCloseTo(22.5, 1e-10); // 0.5*30 + 0.5*15

      // Extensions
      check(data.exponentialMovingAverage(0.5)).deepEquals(ema);
      final vec = Vector<double>.fromList(data, type: DataType.float64);
      check(vec.exponentialMovingAverage(0.5).toList()).deepEquals(ema);

      // Alpha == 1.0 is identity
      check(exponentialMovingAverage(data, 1.0)).deepEquals(data);

      // Empty collection
      check(exponentialMovingAverage([], 0.5)).isEmpty();

      // Errors
      check(() => exponentialMovingAverage(data, 0.0)).throws<ArgumentError>();
      check(() => exponentialMovingAverage(data, -0.5)).throws<ArgumentError>();
      check(() => exponentialMovingAverage(data, 1.5)).throws<ArgumentError>();
    });
  });
}
