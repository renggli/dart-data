import 'package:checks/checks.dart';
import 'package:data/linear.dart';
import 'package:data/stats.dart';
import 'package:data/type.dart';
import 'package:test/test.dart';

void main() {
  group('Principal Component Analysis (PCA)', () {
    test('PCA dimension reduction and reconstruction', () {
      // 6 points roughly along the line y = 2x
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

      // Reconstruct with standardized model
      final transformed = model.transform(data);
      final recon = model.inverseTransform(transformed);
      check(recon.get(0, 0)).isCloseTo(100.0, 1e-4);

      // PCA errors
      check(
        () => pca(
          Matrix<double>.fromRows([
            [1.0, 2.0],
          ]),
        ),
      ).throws<ArgumentError>();
      check(() => model.transform(Matrix<double>.filled(2, 3, 1.0)))
          .throws<ArgumentError>();
      check(() => model.inverseTransform(Matrix<double>.filled(2, 5, 1.0)))
          .throws<ArgumentError>();
    });
  });
}
