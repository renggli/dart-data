import 'package:checks/checks.dart';
import 'package:data/linear.dart';
import 'package:data/type.dart';
import 'package:test/scaffolding.dart';

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
      check(svd.s.length).equals(4);
      check(svd.rank).equals(3);

      // Singular values should be ordered descending
      for (var i = 0; i < svd.s.length - 1; i++) {
        check(svd.s[i]).isGreaterOrEqual(svd.s[i + 1]);
      }

      // Reconstruct A = U * Sigma * V^T
      final u = svd.u;
      final sigma = svd.sigma;
      final vt = svd.vt;

      final reconstructed = u * sigma * vt;
      for (var i = 0; i < a.rowCount; i++) {
        for (var j = 0; j < a.colCount; j++) {
          check(reconstructed.get(i, j)).isCloseTo(a.get(i, j), 1e-6);
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
      check(x.length).equals(2);
      check(x[0]).isCloseTo(0.0, 1e-6);
      check(x[1]).isCloseTo(2.0, 1e-6);
    });
  });
}
