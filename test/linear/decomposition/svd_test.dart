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

      final svd = a.svd;
      check(svd.norm2).isCloseTo(svd.s[0], 1e-6);
      check(svd.cond).isGreaterThan(1.0);
      check(svd.v.rowCount).equals(2);

      final x = svd.solveVector(b);
      check(x.length).equals(2);
      check(x[0]).isCloseTo(0.0, 1e-6);
      check(x[1]).isCloseTo(2.0, 1e-6);

      // Errors
      check(() => svd.solveVector(Vector<double>.fromList([1.0, 2.0])))
          .throws<ArgumentError>();

      final noVectors = SingularValueDecomposition(a, computeVectors: false);
      check(noVectors.vectorsComputed).equals(false);
      check(() => noVectors.solveVector(b)).throws<StateError>();
    });

    test('wide matrix SVD (rowCount < colCount)', () {
      final a = Matrix<double>.fromRows([
        [1.0, 2.0, 3.0],
        [4.0, 5.0, 6.0],
      ], type: DataType.float64);
      final svd = a.svd;
      check(svd.s.length).equals(2);
      check(svd.u.rowCount).equals(2);
      check(svd.vt.colCount).equals(3);

      final reconstructed = svd.u * svd.sigma * svd.vt;
      for (var i = 0; i < 2; i++) {
        for (var j = 0; j < 3; j++) {
          check(reconstructed.get(i, j)).isCloseTo(a.get(i, j), 1e-6);
        }
      }
    });

    test('rank-deficient matrix triggering internal zero paths', () {
      final a = Matrix<double>.fromRows([
        [0.0, 0.0, 0.0],
        [0.0, 2.0, 0.0],
        [0.0, 0.0, 3.0],
      ], type: DataType.float64);
      final svd = a.svd;
      check(svd.rank).equals(2);
      check(svd.cond).equals(double.infinity);
    });
  });
}
