import 'package:checks/checks.dart';
import 'package:data/linear.dart';
import 'package:data/type.dart';
import 'package:test/test.dart';

void main() {
  group('solveTridiagonal base cases', () {
    test('N = 0 returns empty vector', () {
      final sub = Vector<double>.filled(0, 0.0);
      final diag = Vector<double>.filled(0, 0.0);
      final sup = Vector<double>.filled(0, 0.0);
      final rhs = Vector<double>.filled(0, 0.0);

      final x = solveTridiagonal(sub, diag, sup, rhs);
      check(x.length).equals(0);
    });

    test('N = 1 solves single equation', () {
      final sub = Vector<double>.filled(0, 0.0);
      final diag = Vector<double>.fromList([4.0]);
      final sup = Vector<double>.filled(0, 0.0);
      final rhs = Vector<double>.fromList([12.0]);

      final x = solveTridiagonal(sub, diag, sup, rhs);
      check(x.length).equals(1);
      check(x[0]).isCloseTo(3.0, 1e-12);
    });

    test('N = 2 solves 2x2 system', () {
      // 2 x_0 + 1 x_1 = 5
      // 1 x_0 + 3 x_1 = 5
      // => x_0 = 2, x_1 = 1
      final sub = Vector<double>.fromList([1.0]);
      final diag = Vector<double>.fromList([2.0, 3.0]);
      final sup = Vector<double>.fromList([1.0]);
      final rhs = Vector<double>.fromList([5.0, 5.0]);

      final x = solveTridiagonal(sub, diag, sup, rhs);
      check(x.length).equals(2);
      check(x[0]).isCloseTo(2.0, 1e-12);
      check(x[1]).isCloseTo(1.0, 1e-12);
    });
  });

  group('solveTridiagonal diagonally dominant and general systems', () {
    test('3x3 system matches exact algebraic solution', () {
      // [2, 1, 0] [x0] = [ 4]
      // [1, 4, 1] [x1] = [11]
      // [0, 2, 3] [x2] = [11]
      // Exact solution: x0 = 18/17, x1 = 32/17, x2 = 41/17
      final sub = Vector<double>.fromList([1.0, 2.0]);
      final diag = Vector<double>.fromList([2.0, 4.0, 3.0]);
      final sup = Vector<double>.fromList([1.0, 1.0]);
      final rhs = Vector<double>.fromList([4.0, 11.0, 11.0]);

      final x = solveTridiagonal(sub, diag, sup, rhs);
      check(x.length).equals(3);
      check(x[0]).isCloseTo(18.0 / 17.0, 1e-12);
      check(x[1]).isCloseTo(32.0 / 17.0, 1e-12);
      check(x[2]).isCloseTo(41.0 / 17.0, 1e-12);
    });

    test('5x5 diagonally dominant system reconstructs RHS', () {
      final sub = Vector<double>.fromList([-1.0, -1.0, -1.0, -1.0]);
      final diag = Vector<double>.fromList([4.0, 4.0, 4.0, 4.0, 4.0]);
      final sup = Vector<double>.fromList([-1.0, -1.0, -1.0, -1.0]);
      final rhs = Vector<double>.fromList([2.0, 5.0, -3.0, 4.0, 1.0]);

      final x = solveTridiagonal(sub, diag, sup, rhs);

      // Verify A * x == rhs
      check(diag[0] * x[0] + sup[0] * x[1]).isCloseTo(rhs[0], 1e-11);
      for (var i = 1; i < 4; i++) {
        check(sub[i - 1] * x[i - 1] + diag[i] * x[i] + sup[i] * x[i + 1])
            .isCloseTo(rhs[i], 1e-11);
      }
      check(sub[3] * x[3] + diag[4] * x[4]).isCloseTo(rhs[4], 1e-11);
    });

    test('symmetric tridiagonal system', () {
      final sub = Vector<double>.fromList([2.0, 3.0, 4.0]);
      final diag = Vector<double>.fromList([5.0, 6.0, 7.0, 8.0]);
      final sup = Vector<double>.fromList([2.0, 3.0, 4.0]);
      final rhs = Vector<double>.fromList([7.0, 11.0, 14.0, 12.0]);

      final x = solveTridiagonal(sub, diag, sup, rhs);

      check(diag[0] * x[0] + sup[0] * x[1]).isCloseTo(rhs[0], 1e-11);
      for (var i = 1; i < 3; i++) {
        check(sub[i - 1] * x[i - 1] + diag[i] * x[i] + sup[i] * x[i + 1])
            .isCloseTo(rhs[i], 1e-11);
      }
      check(sub[2] * x[2] + diag[3] * x[3]).isCloseTo(rhs[3], 1e-11);
    });

    test('accepts integer and mixed numeric vectors', () {
      final sub = Vector<int>.fromList([1, 2], type: DataType.int32);
      final diag = Vector<int>.fromList([2, 4, 3], type: DataType.int32);
      final sup = Vector<int>.fromList([1, 1], type: DataType.int32);
      final rhs = Vector<int>.fromList([4, 11, 11], type: DataType.int32);

      final x = solveTridiagonal(sub, diag, sup, rhs);
      check(x.type).equals(DataType.float64);
      check(x[0]).isCloseTo(18.0 / 17.0, 1e-12);
      check(x[1]).isCloseTo(32.0 / 17.0, 1e-12);
      check(x[2]).isCloseTo(41.0 / 17.0, 1e-12);
    });
  });

  group('solveTridiagonal non-contiguous and strided inputs', () {
    test('solves correctly with sliced subvectors', () {
      final subFull = Vector<double>.fromList([99.0, 1.0, 2.0, 99.0]);
      final diagFull = Vector<double>.fromList([99.0, 2.0, 4.0, 3.0, 99.0]);
      final supFull = Vector<double>.fromList([99.0, 1.0, 1.0, 99.0]);
      final rhsFull = Vector<double>.fromList([99.0, 4.0, 11.0, 11.0, 99.0]);

      final sub = subFull.subVector(1, 3);
      final diag = diagFull.subVector(1, 4);
      final sup = supFull.subVector(1, 3);
      final rhs = rhsFull.subVector(1, 4);

      final x = solveTridiagonal(sub, diag, sup, rhs);
      check(x[0]).isCloseTo(18.0 / 17.0, 1e-12);
      check(x[1]).isCloseTo(32.0 / 17.0, 1e-12);
      check(x[2]).isCloseTo(41.0 / 17.0, 1e-12);
    });
  });

  group('solveTridiagonal large system scalability', () {
    test('solves 10,000 node 1D Poisson problem accurately in O(N)', () {
      const n = 10000;
      final sub = Vector<double>.filled(n - 1, -1.0);
      final diag = Vector<double>.filled(n, 2.0);
      final sup = Vector<double>.filled(n - 1, -1.0);
      final rhs = Vector<double>.generate(n, (i) => 1.0 / ((i + 1) * (i + 1)));

      final stopwatch = Stopwatch()..start();
      final x = solveTridiagonal(sub, diag, sup, rhs);
      stopwatch.stop();

      check(x.length).equals(n);
      // Verify random checkpoints reconstruct A * x == rhs
      for (final i in [0, 1, 100, 500, 5000, n - 2, n - 1]) {
        if (i == 0) {
          check(diag[0] * x[0] + sup[0] * x[1]).isCloseTo(rhs[0], 1e-9);
        } else if (i == n - 1) {
          check(sub[n - 2] * x[n - 2] + diag[n - 1] * x[n - 1])
              .isCloseTo(rhs[n - 1], 1e-9);
        } else {
          check(sub[i - 1] * x[i - 1] + diag[i] * x[i] + sup[i] * x[i + 1])
              .isCloseTo(rhs[i], 1e-9);
        }
      }
    });
  });

  group('solveTridiagonal error handling', () {
    test('throws ArgumentError on rhs length mismatch', () {
      final sub = Vector<double>.fromList([1.0]);
      final diag = Vector<double>.fromList([2.0, 3.0]);
      final sup = Vector<double>.fromList([1.0]);
      final badRhs = Vector<double>.fromList([5.0]);

      check(() => solveTridiagonal(sub, diag, sup, badRhs))
          .throws<ArgumentError>();
    });

    test('throws ArgumentError on sub length mismatch', () {
      final badSub = Vector<double>.fromList([1.0, 2.0]);
      final diag = Vector<double>.fromList([2.0, 3.0]);
      final sup = Vector<double>.fromList([1.0]);
      final rhs = Vector<double>.fromList([5.0, 5.0]);

      check(() => solveTridiagonal(badSub, diag, sup, rhs))
          .throws<ArgumentError>();
    });

    test('throws ArgumentError on sup length mismatch', () {
      final sub = Vector<double>.fromList([1.0]);
      final diag = Vector<double>.fromList([2.0, 3.0]);
      final badSup = Vector<double>.filled(0, 0.0);
      final rhs = Vector<double>.fromList([5.0, 5.0]);

      check(() => solveTridiagonal(sub, diag, badSup, rhs))
          .throws<ArgumentError>();
    });

    test('throws ArgumentError when initial pivot is 0', () {
      final sub = Vector<double>.fromList([1.0]);
      final diag = Vector<double>.fromList([0.0, 3.0]);
      final sup = Vector<double>.fromList([1.0]);
      final rhs = Vector<double>.fromList([5.0, 5.0]);

      check(() => solveTridiagonal(sub, diag, sup, rhs))
          .throws<ArgumentError>();
    });

    test('throws ArgumentError when intermediate pivot becomes 0', () {
      // For N = 3: b = [2, 1, 3], a = [1, 2], c = [2, 1]
      // w0 = 2
      // cp0 = 2 / 2 = 1
      // w1 = b1 - a0 * cp0 = 1 - 1 * 1 = 0 (zero pivot!)
      final sub = Vector<double>.fromList([1.0, 2.0]);
      final diag = Vector<double>.fromList([2.0, 1.0, 3.0]);
      final sup = Vector<double>.fromList([2.0, 1.0]);
      final rhs = Vector<double>.fromList([1.0, 2.0, 3.0]);

      check(() => solveTridiagonal(sub, diag, sup, rhs))
          .throws<ArgumentError>();
    });
  });
}
