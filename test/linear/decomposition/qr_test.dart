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
  group('QR Decomposition', () {
    test('square matrix decomposition A = Q * R', () {
      final a = Matrix<double>.fromRows([
        [12.0, -51.0, 4.0],
        [6.0, 167.0, -68.0],
        [-4.0, 24.0, -41.0],
      ], type: DataType.float64);

      final qr = a.qr;
      check(qr.isFullRank).isTrue();

      final qMat = qr.q;
      final rMat = qr.r;

      // Q must be orthogonal: Q^T * Q == I
      final qTq = qMat.transposed * qMat;
      for (var i = 0; i < 3; i++) {
        for (var j = 0; j < 3; j++) {
          check(qTq.get(i, j)).isCloseTo(i == j ? 1.0 : 0.0, 1e-6);
        }
      }

      // R must be upper triangular
      for (var i = 0; i < 3; i++) {
        for (var j = 0; j < i; j++) {
          check(rMat.get(i, j)).equals(0.0);
        }
      }

      // Q * R == A
      final qrProd = qMat * rMat;
      for (var i = 0; i < 3; i++) {
        for (var j = 0; j < 3; j++) {
          check(qrProd.get(i, j)).isCloseTo(a.get(i, j), 1e-6);
        }
      }
    });

    test('rectangular matrix least squares solve', () {
      // Overdetermined system: 4 equations, 2 unknowns
      final a = Matrix<double>.fromRows([
        [1.0, 1.0],
        [1.0, 2.0],
        [1.0, 3.0],
        [1.0, 4.0],
      ], type: DataType.float64);

      // y = 2 + 3*x
      final b = Vector<double>.fromList([
        5.0,
        8.0,
        11.0,
        14.0,
      ], type: DataType.float64);

      final qr = a.qr;
      final x = qr.solveVector(b);

      check(x.length).equals(2);
      check(x[0]).isCloseTo(2.0, 1e-6);
      check(x[1]).isCloseTo(3.0, 1e-6);
    });

    test('solveMatrix least squares solve', () {
      final a = Matrix<double>.fromRows([
        [1.0, 1.0],
        [1.0, 2.0],
        [1.0, 3.0],
        [1.0, 4.0],
      ], type: DataType.float64);

      final b = Matrix<double>.fromRows([
        [5.0, 10.0],
        [8.0, 16.0],
        [11.0, 22.0],
        [14.0, 28.0],
      ], type: DataType.float64);

      final qr = a.qr;
      final x = qr.solve(b);
      check(x.rowCount).equals(2);
      check(x.colCount).equals(2);
      check(x.get(0, 0)).isCloseTo(2.0, 1e-6);
      check(x.get(1, 0)).isCloseTo(3.0, 1e-6);
      check(x.get(0, 1)).isCloseTo(4.0, 1e-6);
      check(x.get(1, 1)).isCloseTo(6.0, 1e-6);

      // Dimension mismatch
      final bWrong = Matrix<double>.fromRows([
        [1.0, 2.0],
      ]);
      check(() => qr.solve(bWrong)).throws<ArgumentError>();
      final bVecWrong = Vector<double>.fromList([1.0]);
      check(() => qr.solveVector(bVecWrong)).throws<ArgumentError>();
    });

    test('rank deficient matrix solve throws StateError', () {
      final a = Matrix<double>.fromRows([
        [1.0, 2.0],
        [2.0, 4.0],
      ], type: DataType.float64);
      final qr = a.qr;
      check(qr.isFullRank).isFalse();
      final b = Vector<double>.fromList([1.0, 2.0]);
      check(() => qr.solveVector(b)).throws<StateError>();
      check(() => qr.solve(Matrix<double>.identity(2, type: DataType.float64)))
          .throws<StateError>();
    });

    test('invalid dimensions throw', () {
      final a = Matrix<double>.fromRows([
        [1.0, 2.0, 3.0],
        [4.0, 5.0, 6.0],
      ], type: DataType.float64);
      check(() => a.qr).throws<ArgumentError>();
    });

    test('scale invariance of isFullRank', () {
      final base = Matrix<double>.fromRows([
        [1.0, 2.0],
        [3.0, 4.0],
      ], type: DataType.float64);
      final small = Matrix<double>.generate(
        2,
        2,
        (r, c) => base.get(r, c) * 1e-15,
        type: DataType.float64,
      );
      check(small.qr.isFullRank).isTrue();

      final large = Matrix<double>.generate(
        2,
        2,
        (r, c) => base.get(r, c) * 1e15,
        type: DataType.float64,
      );
      check(large.qr.isFullRank).isTrue();

      final smallRankDef = Matrix<double>.fromRows([
        [1e-15, 2e-15],
        [2e-15, 4e-15],
      ], type: DataType.float64);
      check(smallRankDef.qr.isFullRank).isFalse();

      final largeRankDef = Matrix<double>.fromRows([
        [1e15, 2e15],
        [2e15, 4e15],
      ], type: DataType.float64);
      check(largeRankDef.qr.isFullRank).isFalse();
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

      final qHq = q.conjugateTranspose * q;
      for (var i = 0; i < 3; i++) {
        for (var j = 0; j < 3; j++) {
          final expected = i == j ? Complex.one : Complex.zero;
          check(qHq.get(i, j)).isCloseTo(expected, 1e-6);
        }
      }

      for (var i = 0; i < 3; i++) {
        for (var j = 0; j < i; j++) {
          check(r.get(i, j)).isCloseTo(Complex.zero, 1e-6);
        }
      }

      final qrProd = q * r;
      for (var i = 0; i < 3; i++) {
        for (var j = 0; j < 3; j++) {
          check(qrProd.get(i, j)).isCloseTo(a.get(i, j), 1e-6);
        }
      }

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

      final qHq = q.conjugateTranspose * q;
      for (var i = 0; i < 2; i++) {
        for (var j = 0; j < 2; j++) {
          final expected = i == j ? Complex.one : Complex.zero;
          check(qHq.get(i, j)).isCloseTo(expected, 1e-6);
        }
      }

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
}
