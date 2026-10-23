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
  group('Matrix<Complex> conjugateTranspose', () {
    test('conjugates and transposes elements', () {
      final a = Matrix<Complex>.fromRows([
        [const Complex(1.0, 2.0), const Complex(3.0, -4.0)],
        [const Complex(5.0, 0.0), const Complex(0.0, -6.0)],
      ], type: DataType.complex);

      final aH = a.conjugateTranspose;
      check(aH.rowCount).equals(2);
      check(aH.colCount).equals(2);

      check(aH.get(0, 0)).equals(const Complex(1.0, -2.0));
      check(aH.get(0, 1)).equals(const Complex(5.0, 0.0));
      check(aH.get(1, 0)).equals(const Complex(3.0, 4.0));
      check(aH.get(1, 1)).equals(const Complex(0.0, 6.0));

      // Involution: (A*)* == A
      final aHH = aH.conjugateTranspose;
      for (var r = 0; r < 2; r++) {
        for (var c = 0; c < 2; c++) {
          check(aHH.get(r, c)).equals(a.get(r, c));
        }
      }
    });

    test('conjugate transpose on rectangular matrix', () {
      final a = Matrix<Complex>.fromRows([
        [
          const Complex(1.0, 1.0),
          const Complex(2.0, 0.0),
          const Complex(0.0, -3.0),
        ],
        [
          const Complex(-1.0, 4.0),
          const Complex(5.0, -2.0),
          const Complex(6.0, 1.0),
        ],
      ], type: DataType.complex);

      final aH = a.conjugateTranspose;
      check(aH.rowCount).equals(3);
      check(aH.colCount).equals(2);

      check(aH.get(0, 0)).equals(const Complex(1.0, -1.0));
      check(aH.get(0, 1)).equals(const Complex(-1.0, -4.0));
      check(aH.get(2, 0)).equals(const Complex(0.0, 3.0));
      check(aH.get(2, 1)).equals(const Complex(6.0, -1.0));
    });
  });

  group('Complex Cholesky Decomposition', () {
    test('2x2 Hermitian positive definite matrix A = L * L*', () {
      // A = [[4, 1-i], [1+i, 3]]
      final a = Matrix<Complex>.fromRows([
        [const Complex(4.0, 0.0), const Complex(1.0, -1.0)],
        [const Complex(1.0, 1.0), const Complex(3.0, 0.0)],
      ], type: DataType.complex);

      final cholesky = a.cholesky;
      check(cholesky.isSymmetricPositiveDefinite).isTrue();

      final l = cholesky.l;
      // L must be lower triangular
      check(l.get(0, 1)).equals(Complex.zero);

      // Diagonal elements must be real and positive
      check(l.get(0, 0).imaginary).equals(0.0);
      check(l.get(0, 0).real).isGreaterThan(0.0);
      check(l.get(1, 1).imaginary).equals(0.0);
      check(l.get(1, 1).real).isGreaterThan(0.0);

      // L * L* == A
      final lH = l.conjugateTranspose;
      final aReconstructed = l * lH;
      for (var r = 0; r < 2; r++) {
        for (var c = 0; c < 2; c++) {
          check(aReconstructed.get(r, c)).isCloseTo(a.get(r, c), 1e-6);
        }
      }

      // det(A) = 4*3 - (1-i)(1+i) = 12 - 2 = 10
      check(cholesky.det).isCloseTo(const Complex(10.0, 0.0), 1e-6);

      // Solve A * x = b
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
      // Construct A = L0 * L0* where L0 is known lower triangular
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

      // Solve A * X = B
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
      // Non-Hermitian: A_01 != conj(A_10)
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

      // Hermitian but non-positive definite
      final nonPosDef = Matrix<Complex>.fromRows([
        [const Complex(-1.0, 0.0), const Complex(0.0, 0.0)],
        [const Complex(0.0, 0.0), const Complex(2.0, 0.0)],
      ], type: DataType.complex);
      check(nonPosDef.cholesky.isSymmetricPositiveDefinite).isFalse();
    });
  });

  group('Complex QR Decomposition', () {
    test('square complex matrix decomposition A = Q * R', () {
      final a = Matrix<Complex>.fromRows([
        [
          const Complex(1.0, 1.0),
          const Complex(-1.0, 2.0),
          const Complex(0.0, 1.0),
        ],
        [
          const Complex(2.0, 0.0),
          const Complex(3.0, -1.0),
          const Complex(1.0, 1.0),
        ],
        [
          const Complex(0.0, -1.0),
          const Complex(4.0, 0.0),
          const Complex(2.0, -1.0),
        ],
      ], type: DataType.complex);

      final qr = a.qr;
      check(qr.isFullRank).isTrue();

      final q = qr.q;
      final r = qr.r;

      // Q must be unitary: Q* * Q == I
      final qHq = q.conjugateTranspose * q;
      for (var i = 0; i < 3; i++) {
        for (var j = 0; j < 3; j++) {
          final expected = i == j ? Complex.one : Complex.zero;
          check(qHq.get(i, j)).isCloseTo(expected, 1e-6);
        }
      }

      // R must be upper triangular
      for (var i = 0; i < 3; i++) {
        for (var j = 0; j < i; j++) {
          check(r.get(i, j)).isCloseTo(Complex.zero, 1e-6);
        }
      }

      // Q * R == A
      final qrProd = q * r;
      for (var i = 0; i < 3; i++) {
        for (var j = 0; j < 3; j++) {
          check(qrProd.get(i, j)).isCloseTo(a.get(i, j), 1e-6);
        }
      }

      // Solve A * x = b
      final b = Vector<Complex>.fromList([
        const Complex(2.0, 3.0),
        const Complex(-1.0, 0.0),
        const Complex(4.0, -2.0),
      ], type: DataType.complex);
      final x = qr.solveVector(b);
      final ax = a.apply(x);
      for (var i = 0; i < 3; i++) {
        check(ax[i]).isCloseTo(b[i], 1e-6);
      }
    });

    test('rectangular complex least squares solve', () {
      final a = Matrix<Complex>.fromRows([
        [const Complex(1.0, 0.0), const Complex(0.0, 0.0)],
        [const Complex(0.0, 0.0), const Complex(1.0, 0.0)],
        [const Complex(1.0, 1.0), const Complex(1.0, -1.0)],
        [const Complex(2.0, 0.0), const Complex(0.0, -1.0)],
      ], type: DataType.complex);

      final qr = a.qr;
      check(qr.isFullRank).isTrue();

      final q = qr.q;
      final r = qr.r;

      // Q* * Q == I_2
      final qHq = q.conjugateTranspose * q;
      for (var i = 0; i < 2; i++) {
        for (var j = 0; j < 2; j++) {
          final expected = i == j ? Complex.one : Complex.zero;
          check(qHq.get(i, j)).isCloseTo(expected, 1e-6);
        }
      }

      // Q * R == A
      final qrProd = q * r;
      for (var i = 0; i < 4; i++) {
        for (var j = 0; j < 2; j++) {
          check(qrProd.get(i, j)).isCloseTo(a.get(i, j), 1e-6);
        }
      }

      final b = Matrix<Complex>.fromRows([
        [const Complex(1.0, 0.0), const Complex(2.0, 1.0)],
        [const Complex(2.0, 0.0), const Complex(0.0, -1.0)],
        [const Complex(3.0, 1.0), const Complex(2.0, 0.0)],
        [const Complex(2.0, -2.0), const Complex(4.0, 1.0)],
      ], type: DataType.complex);

      final x = qr.solve(b);
      check(x.rowCount).equals(2);
      check(x.colCount).equals(2);
    });

    test('rank deficient matrix solve throws StateError', () {
      final a = Matrix<Complex>.fromRows([
        [const Complex(1.0, 1.0), const Complex(2.0, 2.0)],
        [const Complex(2.0, 2.0), const Complex(4.0, 4.0)],
      ], type: DataType.complex);
      final qr = a.qr;
      check(qr.isFullRank).isFalse();
      final b = Vector<Complex>.fromList([
        const Complex(1.0, 0.0),
        const Complex(2.0, 0.0),
      ], type: DataType.complex);
      check(() => qr.solveVector(b)).throws<StateError>();
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

      // L must be unit lower triangular
      for (var i = 0; i < 3; i++) {
        check(l.get(i, i)).equals(Complex.one);
        for (var j = i + 1; j < 3; j++) {
          check(l.get(i, j)).equals(Complex.zero);
        }
      }

      // U must be upper triangular
      for (var i = 0; i < 3; i++) {
        for (var j = 0; j < i; j++) {
          check(u.get(i, j)).equals(Complex.zero);
        }
      }

      // P * A == L * U
      final luProd = l * u;
      for (var i = 0; i < 3; i++) {
        for (var j = 0; j < 3; j++) {
          final paVal = a.get(piv[i], j);
          check(luProd.get(i, j)).isCloseTo(paVal, 1e-6);
        }
      }

      // Solve A * x = b
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

      // Solve A * X = B
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
