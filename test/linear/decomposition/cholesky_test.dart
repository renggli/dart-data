import 'package:checks/checks.dart';
import 'package:data/linear.dart';
import 'package:data/type.dart';
import 'package:test/test.dart';

extension on Subject<Complex> {
  void isCloseTo(Complex other, double delta) {
    has((c) => c.a, 'real').isCloseTo(other.a, delta);
    has((c) => c.b, 'imaginary').isCloseTo(other.b, delta);
  }
}

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
      final lLt = lower * lower.transposed;
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

  group('Complex Cholesky Decomposition', () {
    test('2x2 Hermitian positive definite matrix A = L * L*', () {
      final a = Matrix<Complex>.fromRows([
        [const Complex(4.0, 0.0), const Complex(1.0, -1.0)],
        [const Complex(1.0, 1.0), const Complex(3.0, 0.0)],
      ], type: DataType.complex);

      final cholesky = a.cholesky;
      check(cholesky.isSymmetricPositiveDefinite).isTrue();

      final l = cholesky.l;
      check(l.get(0, 1)).equals(Complex.zero);
      check(l.get(0, 0).imaginary).equals(0.0);
      check(l.get(0, 0).real).isGreaterThan(0.0);
      check(l.get(1, 1).imaginary).equals(0.0);
      check(l.get(1, 1).real).isGreaterThan(0.0);

      final lH = l.conjugateTranspose;
      final aReconstructed = l * lH;
      for (var r = 0; r < 2; r++) {
        for (var c = 0; c < 2; c++) {
          check(aReconstructed.get(r, c)).isCloseTo(a.get(r, c), 1e-6);
        }
      }

      check(cholesky.det).isCloseTo(const Complex(10.0, 0.0), 1e-6);

      final b = Vector<Complex>.fromList([
        const Complex(1.0, 2.0),
        const Complex(-1.0, 1.0),
      ], type: DataType.complex);
      final x = cholesky.solveVector(b);
      final ax = a.apply(x);
      for (var i = 0; i < 2; i++) {
        check(ax[i]).isCloseTo(b[i], 1e-6);
      }
    });

    test('3x3 Hermitian positive definite matrix reconstruction and solve', () {
      final l0 = Matrix<Complex>.fromRows([
        [const Complex(2.0, 0.0), Complex.zero, Complex.zero],
        [const Complex(1.0, 1.0), const Complex(3.0, 0.0), Complex.zero],
        [
          const Complex(2.0, -1.0),
          const Complex(1.0, 2.0),
          const Complex(4.0, 0.0),
        ],
      ], type: DataType.complex);

      final a = l0 * l0.conjugateTranspose;
      final cholesky = a.cholesky;
      check(cholesky.isSymmetricPositiveDefinite).isTrue();

      final l = cholesky.l;
      final aRec = l * l.conjugateTranspose;
      for (var r = 0; r < 3; r++) {
        for (var c = 0; c < 3; c++) {
          check(aRec.get(r, c)).isCloseTo(a.get(r, c), 1e-6);
        }
      }

      final b = Matrix<Complex>.fromRows([
        [const Complex(1.0, 0.0), const Complex(0.0, 2.0)],
        [const Complex(3.0, -1.0), const Complex(4.0, 1.0)],
        [const Complex(0.0, 5.0), const Complex(-2.0, 0.0)],
      ], type: DataType.complex);

      final x = cholesky.solve(b);
      final ax = a * x;
      for (var r = 0; r < 3; r++) {
        for (var c = 0; c < 2; c++) {
          check(ax.get(r, c)).isCloseTo(b.get(r, c), 1e-6);
        }
      }
    });

    test('non-Hermitian and non-positive-definite matrices', () {
      final nonHermitian = Matrix<Complex>.fromRows([
        [const Complex(4.0, 0.0), const Complex(1.0, 2.0)],
        [const Complex(1.0, 2.0), const Complex(4.0, 0.0)],
      ], type: DataType.complex);
      final cholNonHerm = nonHermitian.cholesky;
      check(cholNonHerm.isSymmetricPositiveDefinite).isFalse();
      check(() => cholNonHerm.det).throws<ArgumentError>();
      check(
        () => cholNonHerm.solve(
          Matrix<Complex>.identity(2, type: DataType.complex),
        ),
      ).throws<ArgumentError>();

      final nonPosDef = Matrix<Complex>.fromRows([
        [const Complex(-1.0, 0.0), const Complex(0.0, 0.0)],
        [const Complex(0.0, 0.0), const Complex(2.0, 0.0)],
      ], type: DataType.complex);
      check(nonPosDef.cholesky.isSymmetricPositiveDefinite).isFalse();
    });
  });
}
