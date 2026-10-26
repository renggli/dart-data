import 'package:checks/checks.dart';
import 'package:data/linear.dart';
import 'package:data/type.dart';
import 'package:test/scaffolding.dart';

extension on Subject<Complex> {
  void isCloseTo(Complex other, double delta) {
    has((c) => c.a, 'real').isCloseTo(other.a, delta);
    has((c) => c.b, 'imaginary').isCloseTo(other.b, delta);
  }
}

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

      final lower = lu.lower;
      final upper = lu.upper;
      final piv = lu.pivot;

      // L must be unit lower triangular
      for (var i = 0; i < 3; i++) {
        check(lower.get(i, i)).equals(1.0);
        for (var j = i + 1; j < 3; j++) {
          check(lower.get(i, j)).equals(0.0);
        }
      }

      // U must be upper triangular
      for (var i = 0; i < 3; i++) {
        for (var j = 0; j < i; j++) {
          check(upper.get(i, j)).equals(0.0);
        }
      }

      // Check L * U == A(piv,:)
      final luProd = lower * upper;
      for (var i = 0; i < 3; i++) {
        for (var j = 0; j < 3; j++) {
          check(luProd.get(i, j)).isCloseTo(a.get(piv[i], j), 1e-6);
        }
      }

      // Determinant
      check(lu.det).isCloseTo(6.0, 1e-6);
    });

    test('DataType.float32 matrix LU decomposition and solve', () {
      final a = Matrix<double>.fromRows([
        [2.0, 1.0],
        [1.0, 3.0],
      ], type: DataType.float32);
      final b = Vector<double>.fromList([4.0, 7.0], type: DataType.float32);
      final lu = LUDecomposition<double>(a);
      check(lu.det).isCloseTo(5.0, 1e-5);
      final x = lu.solveVector(b);
      check(x[0]).isCloseTo(1.0, 1e-5);
      check(x[1]).isCloseTo(2.0, 1e-5);
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

    test('solves multi-RHS linear system A * X = B', () {
      final a = Matrix<double>.fromRows([
        [2.0, 1.0, 0.0, 0.0],
        [1.0, 2.0, 1.0, 0.0],
        [0.0, 1.0, 2.0, 1.0],
        [0.0, 0.0, 1.0, 2.0],
      ], type: DataType.float64);

      final b = Matrix<double>.fromRows([
        [4.0, 5.0, 6.0],
        [4.0, 4.0, 4.0],
        [3.0, 0.0, 4.0],
        [5.0, -2.0, 5.0],
      ], type: DataType.float64);

      final lu = a.lu;
      check(lu.isNonsingular).isTrue();
      final x = lu.solve(b);

      final ax = a * x;
      for (var r = 0; r < 4; r++) {
        for (var c = 0; c < 3; c++) {
          check(ax.get(r, c)).isCloseTo(b.get(r, c), 1e-6);
        }
      }

      check(x.get(0, 0)).isCloseTo(1.0, 1e-6);
      check(x.get(0, 1)).isCloseTo(2.0, 1e-6);
      check(x.get(0, 2)).isCloseTo(3.0, 1e-6);
      check(x.get(1, 0)).isCloseTo(2.0, 1e-6);
      check(x.get(1, 1)).isCloseTo(1.0, 1e-6);
      check(x.get(1, 2)).isCloseTo(0.0, 1e-6);
      check(x.get(2, 0)).isCloseTo(-1.0, 1e-6);
      check(x.get(2, 1)).isCloseTo(0.0, 1e-6);
      check(x.get(2, 2)).isCloseTo(1.0, 1e-6);
      check(x.get(3, 0)).isCloseTo(3.0, 1e-6);
      check(x.get(3, 1)).isCloseTo(-1.0, 1e-6);
      check(x.get(3, 2)).isCloseTo(2.0, 1e-6);
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

    test('rectangular matrix decomposition 2x3 (m < n)', () {
      final a = Matrix<double>.fromRows([
        [1.0, 2.0, 4.0],
        [3.0, 8.0, 14.0],
      ], type: DataType.float64);

      final lu = a.lu;
      check(lu.m).equals(2);
      check(lu.n).equals(3);
      check(lu.isNonsingular).isFalse();
      check(() => lu.det).throws<ArgumentError>();

      final lower = lu.lower;
      final upper = lu.upper;
      final piv = lu.pivot;

      check(lower.rowCount).equals(2);
      check(lower.colCount).equals(2);
      check(lower.get(0, 0)).equals(1.0);
      check(lower.get(1, 1)).equals(1.0);
      check(lower.get(0, 1)).equals(0.0);

      check(upper.rowCount).equals(2);
      check(upper.colCount).equals(3);
      check(upper.get(1, 0)).equals(0.0);

      final luProd = lower * upper;
      check(luProd.rowCount).equals(2);
      check(luProd.colCount).equals(3);
      for (var i = 0; i < 2; i++) {
        for (var j = 0; j < 3; j++) {
          check(luProd.get(i, j)).isCloseTo(a.get(piv[i], j), 1e-6);
        }
      }
    });

    test('rectangular matrix decomposition 3x2 (m > n)', () {
      final a = Matrix<double>.fromRows([
        [1.0, 2.0],
        [3.0, 8.0],
        [2.0, 6.0],
      ], type: DataType.float64);

      final lu = a.lu;
      check(lu.m).equals(3);
      check(lu.n).equals(2);
      check(lu.isNonsingular).isFalse();
      check(() => lu.det).throws<ArgumentError>();

      final lower = lu.lower;
      final upper = lu.upper;
      final piv = lu.pivot;

      check(lower.rowCount).equals(3);
      check(lower.colCount).equals(2);
      check(lower.get(0, 0)).equals(1.0);
      check(lower.get(1, 1)).equals(1.0);
      check(lower.get(0, 1)).equals(0.0);

      check(upper.rowCount).equals(2);
      check(upper.colCount).equals(2);
      check(upper.get(1, 0)).equals(0.0);

      final luProd = lower * upper;
      check(luProd.rowCount).equals(3);
      check(luProd.colCount).equals(2);
      for (var i = 0; i < 3; i++) {
        for (var j = 0; j < 2; j++) {
          check(luProd.get(i, j)).isCloseTo(a.get(piv[i], j), 1e-6);
        }
      }
    });
  });

  group('Complex LU Decomposition', () {
    test('3x3 complex matrix decomposition P * A = L * U', () {
      final a = Matrix<Complex>.fromRows([
        [
          const Complex(1.0, 1.0),
          const Complex(2.0, -1.0),
          const Complex(3.0, 0.0),
        ],
        [
          const Complex(0.0, 0.0),
          const Complex(4.0, 2.0),
          const Complex(1.0, -1.0),
        ],
        [
          const Complex(2.0, 0.0),
          const Complex(-1.0, 1.0),
          const Complex(0.0, 5.0),
        ],
      ], type: DataType.complex);

      final lu = a.lu;
      check(lu.isNonsingular).isTrue();

      final l = lu.lower;
      final u = lu.upper;
      final piv = lu.pivot;

      for (var i = 0; i < 3; i++) {
        check(l.get(i, i)).equals(Complex.one);
        for (var j = i + 1; j < 3; j++) {
          check(l.get(i, j)).equals(Complex.zero);
        }
      }

      for (var i = 0; i < 3; i++) {
        for (var j = 0; j < i; j++) {
          check(u.get(i, j)).equals(Complex.zero);
        }
      }

      final luProd = l * u;
      for (var i = 0; i < 3; i++) {
        for (var j = 0; j < 3; j++) {
          final paVal = a.get(piv[i], j);
          check(luProd.get(i, j)).isCloseTo(paVal, 1e-6);
        }
      }

      final b = Vector<Complex>.fromList([
        const Complex(1.0, 2.0),
        const Complex(-3.0, 1.0),
        const Complex(4.0, 0.0),
      ], type: DataType.complex);
      final x = lu.solveVector(b);
      final ax = a.apply(x);
      for (var i = 0; i < 3; i++) {
        check(ax[i]).isCloseTo(b[i], 1e-6);
      }

      final bMat = Matrix<Complex>.fromRows([
        [const Complex(1.0, 0.0), const Complex(0.0, 1.0)],
        [const Complex(0.0, 2.0), const Complex(2.0, 0.0)],
        [const Complex(-1.0, 1.0), const Complex(3.0, -1.0)],
      ], type: DataType.complex);
      final xMat = lu.solve(bMat);
      final aX = a * xMat;
      for (var r = 0; r < 3; r++) {
        for (var c = 0; c < 2; c++) {
          check(aX.get(r, c)).isCloseTo(bMat.get(r, c), 1e-6);
        }
      }
    });

    test('singular complex matrix', () {
      final a = Matrix<Complex>.fromRows([
        [const Complex(1.0, 2.0), const Complex(2.0, 4.0)],
        [const Complex(2.0, 4.0), const Complex(4.0, 8.0)],
      ], type: DataType.complex);
      final lu = a.lu;
      check(lu.isNonsingular).isFalse();
      final b = Vector<Complex>.fromList([
        const Complex(1.0, 0.0),
        const Complex(2.0, 0.0),
      ], type: DataType.complex);
      check(() => lu.solveVector(b)).throws<ArgumentError>();
    });

    test('rectangular complex matrix decomposition 2x3 (m < n)', () {
      final a = Matrix<Complex>.fromRows([
        [
          const Complex(1.0, 1.0),
          const Complex(2.0, -1.0),
          const Complex(3.0, 0.0),
        ],
        [
          const Complex(4.0, 2.0),
          const Complex(5.0, 0.0),
          const Complex(6.0, -2.0),
        ],
      ], type: DataType.complex);

      final lu = a.lu;
      check(lu.m).equals(2);
      check(lu.n).equals(3);
      check(lu.isNonsingular).isFalse();

      final l = lu.lower;
      final u = lu.upper;
      final piv = lu.pivot;

      check(l.rowCount).equals(2);
      check(l.colCount).equals(2);
      check(u.rowCount).equals(2);
      check(u.colCount).equals(3);

      final luProd = l * u;
      for (var i = 0; i < 2; i++) {
        for (var j = 0; j < 3; j++) {
          final paVal = a.get(piv[i], j);
          check(luProd.get(i, j)).isCloseTo(paVal, 1e-6);
        }
      }
    });

    test('rectangular complex matrix decomposition 3x2 (m > n)', () {
      final a = Matrix<Complex>.fromRows([
        [const Complex(1.0, 1.0), const Complex(2.0, -1.0)],
        [const Complex(4.0, 2.0), const Complex(5.0, 0.0)],
        [const Complex(0.0, 3.0), const Complex(-1.0, 2.0)],
      ], type: DataType.complex);

      final lu = a.lu;
      check(lu.m).equals(3);
      check(lu.n).equals(2);
      check(lu.isNonsingular).isFalse();

      final l = lu.lower;
      final u = lu.upper;
      final piv = lu.pivot;

      check(l.rowCount).equals(3);
      check(l.colCount).equals(2);
      check(u.rowCount).equals(2);
      check(u.colCount).equals(2);

      final luProd = l * u;
      for (var i = 0; i < 3; i++) {
        for (var j = 0; j < 2; j++) {
          final paVal = a.get(piv[i], j);
          check(luProd.get(i, j)).isCloseTo(paVal, 1e-6);
        }
      }
    });
  });
}
