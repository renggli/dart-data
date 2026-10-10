import 'package:checks/checks.dart';
import 'package:data/linear.dart';
import 'package:data/type.dart';
import 'package:test/test.dart';

void main() {
  group('Cholesky Decomposition', () {
    test('symmetric positive definite matrix A = L * L^T', () {
      final a = Matrix<double>.fromRows([
        [4.0, 12.0, -16.0],
        [12.0, 37.0, -43.0],
        [-16.0, -43.0, 98.0],
      ], type: DataType.float64);

      final cholesky = a.cholesky;
      check(cholesky.isSymmetricPositiveDefinite).isTrue();

      final lower = cholesky.l;
      // L must be lower triangular
      for (var i = 0; i < 3; i++) {
        for (var j = i + 1; j < 3; j++) {
          check(lower.get(i, j)).equals(0.0);
        }
      }

      // L * L^T == A
      final lLt = lower * lower.transpose();
      for (var i = 0; i < 3; i++) {
        for (var j = 0; j < 3; j++) {
          check(lLt.get(i, j)).isCloseTo(a.get(i, j), 1e-6);
        }
      }

      // Check determinant: det(A) = 4*(37*98 - 43*43) - ...
      check(cholesky.det).isCloseTo(36.0, 1e-6);
    });

    test('solves linear system A * x = b', () {
      final a = Matrix<double>.fromRows([
        [4.0, 2.0],
        [2.0, 5.0],
      ], type: DataType.float64);
      final b = Vector<double>.fromList([2.0, -1.0], type: DataType.float64);

      final cholesky = a.cholesky;
      final x = cholesky.solveVector(b);

      check(x[0]).isCloseTo(0.75, 1e-6);
      check(x[1]).isCloseTo(-0.5, 1e-6);

      // Verify A * x == b
      final ax = a.apply(x);
      check(ax[0]).isCloseTo(b[0], 1e-6);
      check(ax[1]).isCloseTo(b[1], 1e-6);
    });

    test('non-positive definite matrix fails check', () {
      final a = Matrix<double>.fromRows([
        [-1.0, 2.0],
        [2.0, 3.0],
      ], type: DataType.float64);

      final cholesky = a.cholesky;
      check(cholesky.isSymmetricPositiveDefinite).isFalse();
      check(() => cholesky.solve(a)).throws<ArgumentError>();
    });
  });
}
