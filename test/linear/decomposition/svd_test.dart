import 'package:checks/checks.dart';
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
      check(svd.s.length).equals(4);
      check(svd.rank).equals(3);

      // Singular values should be ordered descending
      for (var i = 0; i < svd.s.length - 1; i++) {
        check(svd.s[i]).isGreaterOrEqual(svd.s[i + 1]);
      }

      // Reconstruct A = U * Sigma * V^T
      final uMat = svd.u;
      final sigma = svd.sigma;
      final vtMat = svd.vt;

      final reconstructed = uMat * sigma * vtMat;
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

      final bMat = Matrix<double>.fromRows([
        [2.0, 3.0],
        [4.0, 5.0],
        [6.0, 7.0],
      ], type: DataType.float64);
      final xMat = svd.solve(bMat);
      check(xMat.rowCount).equals(2);
      check(xMat.colCount).equals(2);
      check(xMat.get(0, 0)).isCloseTo(0.0, 1e-6);
      check(xMat.get(1, 0)).isCloseTo(2.0, 1e-6);
      check(xMat.get(0, 1)).isCloseTo(1.0, 1e-6);
      check(xMat.get(1, 1)).isCloseTo(2.0, 1e-6);

      // Errors
      check(() => svd.solveVector(Vector<double>.fromList([1.0, 2.0])))
          .throws<ArgumentError>();
      check(() => svd.solve(Matrix<double>.filled(2, 1, 1.0)))
          .throws<ArgumentError>();

      final noVectors = SingularValueDecomposition(a, computeVectors: false);
      check(noVectors.vectorsComputed).equals(false);
      check(() => noVectors.solveVector(b)).throws<StateError>();
      check(() => noVectors.solve(bMat)).throws<StateError>();
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

      // Bidiagonal matrix with zero interior diagonal entry (triggers kase = 2 QR step)
      final bidiagZero = Matrix<double>.fromRows([
        [2.0, 3.0, 0.0, 0.0],
        [0.0, 0.0, 4.0, 0.0],
        [0.0, 0.0, 5.0, 6.0],
        [0.0, 0.0, 0.0, 7.0],
      ], type: DataType.float64);
      final svdZero = bidiagZero.svd;
      check(svdZero.s.length).equals(4);
      check(svdZero.rank).equals(3);

      final svdZeroNoVectors = SingularValueDecomposition(
        bidiagZero,
        computeVectors: false,
      );
      check(svdZeroNoVectors.s.length).equals(4);
      check(svdZeroNoVectors.rank).equals(3);
    });

    test('scale invariance of solveVector', () {
      final aSmall = Matrix<double>.fromRows([
        [1e-12, 0.0],
        [0.0, 2e-12],
      ], type: DataType.float64);
      final bSmall = Vector<double>.fromList([2e-12, 6e-12]);
      final xSmall = aSmall.svd.solveVector(bSmall);
      check(xSmall[0]).isCloseTo(2.0, 1e-6);
      check(xSmall[1]).isCloseTo(3.0, 1e-6);

      final aLarge = Matrix<double>.fromRows([
        [1e12, 0.0],
        [0.0, 2e12],
      ], type: DataType.float64);
      final bLarge = Vector<double>.fromList([2e12, 6e12]);
      final xLarge = aLarge.svd.solveVector(bLarge);
      check(xLarge[0]).isCloseTo(2.0, 1e-6);
      check(xLarge[1]).isCloseTo(3.0, 1e-6);
    });
  });
}
