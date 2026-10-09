import 'package:data/linear.dart';
import 'package:data/type.dart';
import 'package:test/test.dart';

void main() {
  group('Singular Value Decomposition (SVD)', () {
    test('diagonal factorization A = U * S * V^T', () {
      final a = Matrix<double>.fromRows([
        [1.0, 0.0, 0.0, 0.0, 2.0],
        [0.0, 0.0, 3.0, 0.0, 0.0],
        [0.0, 0.0, 0.0, 0.0, 0.0],
        [0.0, 4.0, 0.0, 0.0, 0.0],
      ], type: DataType.float64);

      final svd = a.svd;
      expect(svd.s.length, 4);
      expect(svd.rank, 3);

      // Singular values should be ordered descending
      for (var i = 0; i < svd.s.length - 1; i++) {
        expect(svd.s[i], greaterThanOrEqualTo(svd.s[i + 1]));
      }

      // Reconstruct A = U * Sigma * V^T
      final u = svd.u;
      final sigma = svd.sigma;
      final vt = svd.vt;

      final reconstructed = u * sigma * vt;
      for (var i = 0; i < a.rowCount; i++) {
        for (var j = 0; j < a.colCount; j++) {
          expect(reconstructed.get(i, j), closeTo(a.get(i, j), 1e-6));
        }
      }
    });

    test('least squares solve with SVD', () {
      final a = Matrix<double>.fromRows([
        [1.0, 1.0],
        [1.0, 2.0],
        [1.0, 3.0],
      ], type: DataType.float64);
      final b = Vector<double>.fromList([
        2.0,
        4.0,
        6.0,
      ], type: DataType.float64);

      final x = a.svd.solveVector(b);
      expect(x.length, 2);
      expect(x[0], closeTo(0.0, 1e-6));
      expect(x[1], closeTo(2.0, 1e-6));
    });
  });
}
