import 'package:data/linear.dart';
import 'package:data/type.dart';
import 'package:test/test.dart';

void main() {
  group('QR Decomposition', () {
    test('square matrix decomposition A = Q * R', () {
      final a = Matrix<double>.fromRows([
        [12.0, -51.0, 4.0],
        [6.0, 167.0, -68.0],
        [-4.0, 24.0, -41.0],
      ], type: DataType.float64);

      final qr = a.qr;
      expect(qr.isFullRank, isTrue);

      final q = qr.q;
      final r = qr.r;

      // Q must be orthogonal: Q^T * Q == I
      final qTq = q.transposed * q;
      for (var i = 0; i < 3; i++) {
        for (var j = 0; j < 3; j++) {
          expect(qTq.get(i, j), closeTo(i == j ? 1.0 : 0.0, 1e-6));
        }
      }

      // R must be upper triangular
      for (var i = 0; i < 3; i++) {
        for (var j = 0; j < i; j++) {
          expect(r.get(i, j), 0.0);
        }
      }

      // Q * R == A
      final qrProd = q * r;
      for (var i = 0; i < 3; i++) {
        for (var j = 0; j < 3; j++) {
          expect(qrProd.get(i, j), closeTo(a.get(i, j), 1e-6));
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
      final b = Vector<double>.fromList([5.0, 8.0, 11.0, 14.0],
          type: DataType.float64);

      final qr = a.qr;
      final x = qr.solveVector(b);

      expect(x.length, 2);
      expect(x[0], closeTo(2.0, 1e-6));
      expect(x[1], closeTo(3.0, 1e-6));
    });

    test('invalid dimensions throw', () {
      final a = Matrix<double>.fromRows([
        [1.0, 2.0, 3.0],
        [4.0, 5.0, 6.0],
      ], type: DataType.float64);
      expect(() => a.qr, throwsArgumentError);
    });
  });
}
