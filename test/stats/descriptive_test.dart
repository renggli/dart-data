import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/linear.dart';
import 'package:data/stats.dart';
import 'package:data/tensor.dart';
import 'package:data/type.dart';
import 'package:test/scaffolding.dart';

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
      check(vec1.percentile(50)).isCloseTo(3.0, 1e-10);
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
      final corrM = matrix.pearsonCorrelationMatrix();
      check(corrM.get(0, 1)).isCloseTo(1.0, 1e-10);
      final spearmanM = matrix.spearmanCorrelationMatrix();
      check(spearmanM.get(0, 1)).isCloseTo(1.0, 1e-10);
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
      final m = Matrix<double>.fromRows([
        [1.0, 2.0],
        [2.0, 4.0],
        [3.0, 6.0],
      ], type: DataType.float64);

      final cov = covarianceMatrix(m);
      check(cov.rowCount).equals(2);
      check(cov.colCount).equals(2);
      check(cov.get(0, 0)).isCloseTo(1.0, 1e-10);
      check(cov.get(1, 1)).isCloseTo(4.0, 1e-10);
      check(cov.get(0, 1)).isCloseTo(2.0, 1e-10);
      check(cov.get(1, 0)).isCloseTo(2.0, 1e-10);

      final corr = pearsonCorrelationMatrix(m);
      check(corr.get(0, 0)).isCloseTo(1.0, 1e-10);
      check(corr.get(1, 1)).isCloseTo(1.0, 1e-10);
      check(corr.get(0, 1)).isCloseTo(1.0, 1e-10);
      check(corr.get(1, 0)).isCloseTo(1.0, 1e-10);

      final spearman = spearmanCorrelationMatrix(m);
      check(spearman.get(0, 1)).isCloseTo(1.0, 1e-10);
    });
  });

  group('Principal Component Analysis (PCA)', () {
    test('PCA dimension reduction and reconstruction', () {
      // Synthetic data along y = 2*x line
      final rows = [
        [1.0, 2.05],
        [2.0, 3.95],
        [3.0, 6.05],
        [4.0, 7.95],
        [5.0, 10.05],
        [6.0, 11.95],
      ];
      final data = Matrix<double>.fromRows(rows, type: DataType.float64);

      final model = pca(data, nComponents: 1);
      check(model.components.rowCount).equals(1);
      check(model.components.colCount).equals(2);
      // First component should explain > 99.9% of variance
      check(model.explainedVarianceRatio[0]).isGreaterThan(0.999);

      // Transform to 1D
      final transformed = model.transform(data);
      check(transformed.rowCount).equals(6);
      check(transformed.colCount).equals(1);

      // Reconstruct back to 2D
      final reconstructed = model.inverseTransform(transformed);
      check(reconstructed.rowCount).equals(6);
      check(reconstructed.colCount).equals(2);

      for (var i = 0; i < 6; i++) {
        check(reconstructed.get(i, 0)).isCloseTo(data.get(i, 0), 0.1);
        check(reconstructed.get(i, 1)).isCloseTo(data.get(i, 1), 0.1);
      }
    });

    test('Standardized PCA', () {
      final rows = [
        [100.0, 1.0],
        [200.0, 2.0],
        [300.0, 3.0],
        [400.0, 4.0],
        [500.0, 5.0],
      ];
      final data = Matrix<double>.fromRows(rows, type: DataType.float64);

      final model = pca(data, nComponents: 2, standardize: true);
      check(model.standardize).isTrue();
      check(model.std).isNotNull();
      // Both features are perfectly linearly correlated, so PC1 explains 100% of variance
      check(model.explainedVarianceRatio[0]).isCloseTo(1.0, 1e-10);
    });
  });
}
