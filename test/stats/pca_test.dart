import 'package:checks/checks.dart';
import 'package:data/linear.dart';
import 'package:data/stats.dart';
import 'package:data/type.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('pca decomposition and reconstruction', () {
    test('reduces dimension and reconstructs correlated data via SVD', () {
      final data = Matrix<double>.fromRows(const [
        [1.0, 2.05],
        [2.0, 3.95],
        [3.0, 6.05],
        [4.0, 7.95],
        [5.0, 10.05],
        [6.0, 11.95],
      ], type: DataType.float64);

      final model = pca(data, nComponents: 1);
      check(model.components.rowCount).equals(1);
      check(model.components.colCount).equals(2);
      check(model.singularValues.length).equals(1);
      check(model.explainedVarianceRatio[0]).isGreaterThan(0.999);
      check(model.cumulativeExplainedVarianceRatio[0])
          .equals(model.explainedVarianceRatio[0]);

      final transformed = model.transform(data);
      check(transformed.rowCount).equals(6);
      check(transformed.colCount).equals(1);

      final reconstructed = model.inverseTransform(transformed);
      check(reconstructed.rowCount).equals(6);
      check(reconstructed.colCount).equals(2);
      for (var i = 0; i < 6; i++) {
        check(reconstructed.get(i, 0)).isCloseTo(data.get(i, 0), 0.1);
        check(reconstructed.get(i, 1)).isCloseTo(data.get(i, 1), 0.1);
      }
    });

    test('handles wide matrices when nFeatures > nSamples', () {
      final data = Matrix<double>.fromRows(const [
        [1.0, 2.0, 3.0, 4.0],
        [2.0, 4.0, 5.0, 7.0],
        [3.0, 5.0, 8.0, 9.0],
      ], type: DataType.float64);

      final defaultModel = pca(data);
      check(defaultModel.components.rowCount).equals(3);
      check(defaultModel.cumulativeExplainedVarianceRatio[2])
          .isCloseTo(1.0, 1e-12);

      // Requesting all 4 components includes the null-space singular value 0.
      final fullModel = pca(data, nComponents: 4);
      check(fullModel.components.rowCount).equals(4);
      check(fullModel.singularValues[3]).equals(0.0);
    });

    test('handles tall matrices (nSamples > 512) via covariance path', () {
      final tall = Matrix<double>.generate(
        600,
        2,
        (r, c) => c == 0
            ? r.toDouble()
            : 2.0 * r.toDouble() + (r.isEven ? 0.1 : -0.1),
        type: DataType.float64,
      );
      final model = pca(tall, nComponents: 2);
      check(model.explainedVarianceRatio[0]).isGreaterThan(0.999);
      check(model.cumulativeExplainedVarianceRatio[1]).isCloseTo(1.0, 1e-12);
      final recon = model.inverseTransform(model.transform(tall));
      check(recon.get(10, 0)).isCloseTo(tall.get(10, 0), 1e-8);
      check(recon.get(10, 1)).isCloseTo(tall.get(10, 1), 1e-8);
    });
  });

  group('pca standardization and sign convention', () {
    test('standardizes features before extracting components', () {
      final data = Matrix<double>.fromRows(const [
        [100.0, 1.0],
        [200.0, 2.0],
        [300.0, 3.0],
        [400.0, 4.0],
        [500.0, 5.0],
      ], type: DataType.float64);

      final model = pca(data, nComponents: 2, standardize: true);
      check(model.standardize).isTrue;
      check(model.std).isNotNull();
      check(model.explainedVarianceRatio[0]).isCloseTo(1.0, 1e-10);

      final recon = model.inverseTransform(model.transform(data));
      check(recon.get(0, 0)).isCloseTo(100.0, 1e-4);
    });

    test('handles constant zero-variance features under standardization', () {
      final data = Matrix<double>.fromRows(const [
        [1.0, 5.0],
        [2.0, 5.0],
        [3.0, 5.0],
        [4.0, 5.0],
        [5.0, 5.0],
      ], type: DataType.float64);

      final model = pca(data, nComponents: 2, standardize: true);
      check(model.explainedVarianceRatio[0]).isCloseTo(1.0, 1e-10);
      check(model.explainedVarianceRatio[1]).isCloseTo(0.0, 1e-10);
    });

    test('enforces deterministic sign flip for negated dominant axes', () {
      // Feature 0 clearly dominates PC1 with negative values on first pass.
      final data = Matrix<double>.fromRows(const [
        [-10.0, 0.0],
        [10.0, 0.0],
        [-5.0, 1.0],
        [5.0, -1.0],
      ], type: DataType.float64);
      final model = pca(data);
      check(model.components.get(0, 0)).isGreaterOrEqual(0.0);
    });
  });

  group('pca validation, equality, and formatting', () {
    test('rejects invalid sample/feature counts, nComponents, non-finite inputs, and wrong transform shapes', () {
      check(
        () => pca(
          Matrix<double>.fromRows(const [
            [1.0, 2.0],
          ]),
        ),
      ).throws<ArgumentError>();
      check(() => pca(Matrix<double>.filled(3, 0, 0.0)))
          .throws<ArgumentError>();
      check(
        () => pca(
          Matrix<double>.fromRows(const [
            [1.0, double.nan],
            [2.0, 3.0],
          ]),
        ),
      ).throws<ArgumentError>();

      final valid = Matrix<double>.fromRows(const [
        [1.0, 2.0],
        [3.0, 4.0],
        [5.0, 6.0],
      ], type: DataType.float64);
      check(() => pca(valid, nComponents: 0)).throws<RangeError>();
      check(() => pca(valid, nComponents: 3)).throws<RangeError>();

      final model = pca(valid, nComponents: 1);
      check(() => model.transform(Matrix<double>.filled(2, 3, 1.0)))
          .throws<ArgumentError>();
      check(() => model.inverseTransform(Matrix<double>.filled(2, 5, 1.0)))
          .throws<ArgumentError>();
    });

    test('equality, hashCode, and string representation', () {
      final data = Matrix<double>.fromRows(const [
        [1.0, 2.0],
        [2.0, 4.0],
        [3.0, 5.0],
      ], type: DataType.float64);
      final a = pca(data);
      final b = pca(data);
      final c = pca(data, standardize: true);
      check(a == b).isTrue;
      check(a.hashCode).equals(b.hashCode);
      check(a == c).isFalse;
      check(a.toString()).contains('PcaResult');
    });
  });
}
