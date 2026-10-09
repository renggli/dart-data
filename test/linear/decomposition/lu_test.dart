import 'package:checks/checks.dart';
import 'package:data/linear.dart';
import 'package:data/type.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('LU Decomposition', () {
    test('square matrix decomposition P * A = L * U', () {
      final a = Matrix<double>.fromRows([
        [1.0, 2.0, 4.0],
        [3.0, 8.0, 14.0],
        [2.0, 6.0, 13.0],
      ], type: DataType.float64);

      final lu = a.lu;
      check(lu.isNonsingular).isTrue();

      final l = lu.lower;
      final u = lu.upper;
      final piv = lu.pivot;

      // L must be unit lower triangular
      for (var i = 0; i < 3; i++) {
        check(l.get(i, i)).equals(1.0);
        for (var j = i + 1; j < 3; j++) {
          check(l.get(i, j)).equals(0.0);
        }
      }

      // U must be upper triangular
      for (var i = 0; i < 3; i++) {
        for (var j = 0; j < i; j++) {
          check(u.get(i, j)).equals(0.0);
        }
      }

      // Check L * U == A(piv,:)
      final luProd = l * u;
      for (var i = 0; i < 3; i++) {
        for (var j = 0; j < 3; j++) {
          check(luProd.get(i, j)).isCloseTo(a.get(piv[i], j), 1e-6);
        }
      }

      // Determinant
      check(lu.det).isCloseTo(6.0, 1e-6);
    });

    test('solves linear system A * x = b', () {
      final a = Matrix<double>.fromRows([
        [2.0, 1.0, -1.0],
        [-3.0, -1.0, 2.0],
        [-2.0, 1.0, 2.0],
      ], type: DataType.float64);
      final b = Vector<double>.fromList([
        8.0,
        -11.0,
        -3.0,
      ], type: DataType.float64);

      final lu = a.lu;
      final x = lu.solveVector(b);

      check(x[0]).isCloseTo(2.0, 1e-6);
      check(x[1]).isCloseTo(3.0, 1e-6);
      check(x[2]).isCloseTo(-1.0, 1e-6);

      final ax = a.apply(x);
      check(ax[0]).isCloseTo(b[0], 1e-6);
      check(ax[1]).isCloseTo(b[1], 1e-6);
      check(ax[2]).isCloseTo(b[2], 1e-6);
    });

    test('singular matrix returns isNonsingular false', () {
      final a = Matrix<double>.fromRows([
        [1.0, 2.0],
        [2.0, 4.0],
      ], type: DataType.float64);

      final lu = a.lu;
      check(lu.isNonsingular).isFalse();
      check(() => lu.solve(a)).throws<ArgumentError>();
    });
  });
}
