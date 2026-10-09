import 'dart:math' as math;

import 'package:data/linear.dart';
import 'package:data/stats.dart';
import 'package:data/type.dart';
import 'package:test/test.dart';

void main() {
  group('descriptive', () {
    test('mean, variance, and standard deviation', () {
      final data = [2.0, 4.0, 4.0, 4.0, 5.0, 5.0, 7.0, 9.0];
      expect(mean(data), closeTo(5.0, 1e-10));
      // Sample variance: 32 / 7, sample std: sqrt(32 / 7)
      expect(variance(data), closeTo(32.0 / 7.0, 1e-10));
      expect(standardDeviation(data), closeTo(math.sqrt(32.0 / 7.0), 1e-10));
      // Population variance: 4.0, population std: 2.0
      expect(variance(data, population: true), closeTo(4.0, 1e-10));
      expect(
        standardDeviation(data, population: true),
        closeTo(2.0, 1e-10),
      );
    });

    test('median, quantiles, and IQR', () {
      final data = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0];
      expect(median(data), closeTo(5.0, 1e-10));
      expect(quantile(data, 0.0), closeTo(1.0, 1e-10));
      expect(quantile(data, 0.25), closeTo(3.0, 1e-10));
      expect(quantile(data, 0.5), closeTo(5.0, 1e-10));
      expect(quantile(data, 0.75), closeTo(7.0, 1e-10));
      expect(quantile(data, 1.0), closeTo(9.0, 1e-10));
      expect(iqr(data), closeTo(4.0, 1e-10));
    });

    test('skewness and kurtosis of symmetric vs skewed data', () {
      final symmetric = [1.0, 2.0, 3.0, 4.0, 5.0];
      expect(skewness(symmetric), closeTo(0.0, 1e-10));

      final skewed = [1.0, 1.0, 1.0, 2.0, 10.0];
      expect(skewness(skewed), greaterThan(1.0));
      expect(kurtosis(skewed, excess: true), greaterThan(0.0));
    });

    test('geometric and harmonic means', () {
      final values = [2.0, 8.0];
      expect(values.geometricMean(), closeTo(4.0, 1e-10));

      final hValues = [2.5, 3.0, 10.0];
      expect(hValues.harmonicMean(), closeTo(3.6, 1e-10));
    });

    test('vector extensions', () {
      final vec = Vector<double>.fromList([1.0, 2.0, 3.0, 4.0, 5.0],
          type: DataType.float64);
      expect(vec.mean(), closeTo(3.0, 1e-10));
      expect(vec.variance(), closeTo(2.5, 1e-10));
      expect(vec.standardDeviation(), closeTo(math.sqrt(2.5), 1e-10));
      expect(vec.median(), closeTo(3.0, 1e-10));
    });

    test('Pearson and Spearman correlations', () {
      final x = [1.0, 2.0, 3.0, 4.0, 5.0];
      final yLinear = [2.0, 4.0, 6.0, 8.0, 10.0];
      expect(pearsonCorrelation(x, yLinear), closeTo(1.0, 1e-10));
      expect(spearmanCorrelation(x, yLinear), closeTo(1.0, 1e-10));

      // Monotonic non-linear: y = exp(x)
      final yExp = x.map(math.exp).toList();
      expect(spearmanCorrelation(x, yExp), closeTo(1.0, 1e-10));
      expect(pearsonCorrelation(x, yExp), lessThan(1.0));
      expect(pearsonCorrelation(x, yExp), greaterThan(0.8));

      // Negative correlation
      final yNeg = [5.0, 4.0, 3.0, 2.0, 1.0];
      expect(pearsonCorrelation(x, yNeg), closeTo(-1.0, 1e-10));
    });

    test('covariance matrix and correlation matrices', () {
      // 3 observations, 2 features
      // f1: [1, 2, 3], f2: [2, 4, 6]
      final m = Matrix<double>.fromRows(
        [
          [1.0, 2.0],
          [2.0, 4.0],
          [3.0, 6.0],
        ],
        type: DataType.float64,
      );

      final cov = covarianceMatrix(m);
      expect(cov.rowCount, 2);
      expect(cov.colCount, 2);
      expect(cov.get(0, 0), closeTo(1.0, 1e-10));
      expect(cov.get(1, 1), closeTo(4.0, 1e-10));
      expect(cov.get(0, 1), closeTo(2.0, 1e-10));
      expect(cov.get(1, 0), closeTo(2.0, 1e-10));

      final corr = pearsonCorrelationMatrix(m);
      expect(corr.get(0, 0), closeTo(1.0, 1e-10));
      expect(corr.get(1, 1), closeTo(1.0, 1e-10));
      expect(corr.get(0, 1), closeTo(1.0, 1e-10));
      expect(corr.get(1, 0), closeTo(1.0, 1e-10));

      final spearman = spearmanCorrelationMatrix(m);
      expect(spearman.get(0, 1), closeTo(1.0, 1e-10));
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
      expect(model.components.rowCount, 1);
      expect(model.components.colCount, 2);
      // First component should explain > 99.9% of variance
      expect(model.explainedVarianceRatio[0], greaterThan(0.999));

      // Transform to 1D
      final transformed = model.transform(data);
      expect(transformed.rowCount, 6);
      expect(transformed.colCount, 1);

      // Reconstruct back to 2D
      final reconstructed = model.inverseTransform(transformed);
      expect(reconstructed.rowCount, 6);
      expect(reconstructed.colCount, 2);

      for (var i = 0; i < 6; i++) {
        expect(reconstructed.get(i, 0), closeTo(data.get(i, 0), 0.1));
        expect(reconstructed.get(i, 1), closeTo(data.get(i, 1), 0.1));
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
      expect(model.standardize, isTrue);
      expect(model.std, isNotNull);
      // Both features are perfectly linearly correlated, so PC1 explains 100% of variance
      expect(model.explainedVarianceRatio[0], closeTo(1.0, 1e-10));
    });
  });
}
