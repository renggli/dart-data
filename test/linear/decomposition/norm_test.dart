import 'package:checks/checks.dart';
import 'package:data/linear.dart';
import 'package:data/type.dart';
import 'package:test/test.dart';

void main() {
  group('MatrixNormExtension', () {
    test('normFrobenius computes Euclidean length across elements', () {
      final m = Matrix<double>.fromRows([
        [3.0, 0.0],
        [0.0, 4.0],
      ], type: DataType.float64);
      check(m.normFrobenius).isCloseTo(5.0, 1e-10);

      final zero = Matrix<double>.fromRows([
        [0.0, 0.0],
        [0.0, 0.0],
      ], type: DataType.float64);
      check(zero.normFrobenius).equals(0.0);
    });

    test('norm1 computes maximum absolute column sum', () {
      final m = Matrix<double>.fromRows([
        [1.0, 2.0],
        [3.0, 4.0],
      ], type: DataType.float64);
      // col 0: |1| + |3| = 4, col 1: |2| + |4| = 6
      check(m.norm1).isCloseTo(6.0, 1e-10);
    });

    test('norm2 computes spectral norm (largest singular value)', () {
      final m = Matrix<double>.fromRows([
        [2.0, 0.0],
        [0.0, 5.0],
      ], type: DataType.float64);
      check(m.norm2).isCloseTo(5.0, 1e-10);

      final empty = Matrix<double>.fromRows(const [], type: DataType.float64);
      check(empty.norm2).equals(0.0);
    });

    test('normInfinity computes maximum absolute row sum', () {
      final m = Matrix<double>.fromRows([
        [1.0, 2.0],
        [3.0, 4.0],
      ], type: DataType.float64);
      // row 0: |1| + |2| = 3, row 1: |3| + |4| = 7
      check(m.normInfinity).isCloseTo(7.0, 1e-10);
    });

    test('cond computes 2-norm condition number', () {
      final id = Matrix<double>.identity(3, type: DataType.float64);
      check(id.cond).isCloseTo(1.0, 1e-10);

      final singular = Matrix<double>.fromRows([
        [1.0, 2.0],
        [2.0, 4.0],
      ], type: DataType.float64);
      check(singular.cond).equals(double.infinity);

      final empty = Matrix<double>.fromRows(const [], type: DataType.float64);
      check(empty.cond).equals(0.0);
    });

    test('rank computes effective numerical rank via SVD', () {
      final fullRank = Matrix<double>.identity(4, type: DataType.float64);
      check(fullRank.rank).equals(4);

      final rankDeficient = Matrix<double>.fromRows([
        [1.0, 2.0, 3.0],
        [2.0, 4.0, 6.0],
        [0.0, 0.0, 1.0],
      ], type: DataType.float64);
      check(rankDeficient.rank).equals(2);

      final zero = Matrix<double>.fromRows([
        [0.0, 0.0],
        [0.0, 0.0],
      ], type: DataType.float64);
      check(zero.rank).equals(0);

      final empty = Matrix<double>.fromRows(const [], type: DataType.float64);
      check(empty.rank).equals(0);
    });
  });
}
