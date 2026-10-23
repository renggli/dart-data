import 'package:checks/checks.dart';
import 'package:data/linear.dart';
import 'package:data/type.dart';
import 'package:more/number.dart';
import 'package:test/test.dart';

void main() {
  group('Conjugate Gradient', () {
    test('symmetric positive-definite system', () {
      // 3x3 SPD matrix:
      // [4, 1, 0]
      // [1, 3, 1]
      // [0, 1, 2]
      final a = Matrix<double>.fromRows([
        [4.0, 1.0, 0.0],
        [1.0, 3.0, 1.0],
        [0.0, 1.0, 2.0],
      ]);
      // True solution x = [1, 2, 3]
      // b = A * x = [4*1 + 1*2, 1*1 + 3*2 + 1*3, 1*2 + 2*3] = [6, 10, 8]
      final b = Vector<double>.fromList([6.0, 10.0, 8.0]);

      final x = solveIterative(a, b, method: IterativeMethod.conjugateGradient);
      check(x[0]).isCloseTo(1.0, 1e-6);
      check(x[1]).isCloseTo(2.0, 1e-6);
      check(x[2]).isCloseTo(3.0, 1e-6);

      // Test with CSR sparse representation
      final csr = CooMatrix.fromDense(a).toCsr();
      final xSparse = solveIterative(
        csr,
        b,
        method: IterativeMethod.conjugateGradient,
      );
      check(xSparse[0]).isCloseTo(1.0, 1e-6);
      check(xSparse[1]).isCloseTo(2.0, 1e-6);
      check(xSparse[2]).isCloseTo(3.0, 1e-6);
    });

    test('fast return when initial residual is zero', () {
      final square2 = Matrix<double>.identity(2);
      final xExact = Vector<double>.fromList([1.0, 2.0]);
      final bExact = square2.apply(xExact);
      final xSolved = solveIterative(
        square2,
        bExact,
        x0: xExact,
        method: IterativeMethod.conjugateGradient,
      );
      check(xSolved.toList()).deepEquals(xExact.toList());
    });
  });

  group('GMRES', () {
    test('non-symmetric system', () {
      // Non-symmetric 3x3 matrix:
      // [2, 1, 0]
      // [0, 3, 2]
      // [1, 0, 4]
      final a = Matrix<double>.fromRows([
        [2.0, 1.0, 0.0],
        [0.0, 3.0, 2.0],
        [1.0, 0.0, 4.0],
      ]);
      // True solution x = [1, 2, 3]
      // b = [2*1 + 1*2, 3*2 + 2*3, 1*1 + 4*3] = [4, 12, 13]
      final b = Vector<double>.fromList([4.0, 12.0, 13.0]);

      final x = solveIterative(a, b);
      check(x[0]).isCloseTo(1.0, 1e-6);
      check(x[1]).isCloseTo(2.0, 1e-6);
      check(x[2]).isCloseTo(3.0, 1e-6);
    });

    test('non-symmetric system with negative entries', () {
      final a = Matrix<double>.fromRows([
        [-2.0, 1.0, 0.0],
        [1.0, -3.0, 2.0],
        [0.0, 1.0, -4.0],
      ]);
      // True solution x = [1, 2, 3]
      // b = [-2*1 + 1*2 = 0, 1*1 - 3*2 + 2*3 = 1, 1*2 - 4*3 = -10]
      final b = Vector<double>.fromList([0.0, 1.0, -10.0]);

      final x = solveIterative(a, b);
      check(x[0]).isCloseTo(1.0, 1e-5);
      check(x[1]).isCloseTo(2.0, 1e-5);
      check(x[2]).isCloseTo(3.0, 1e-5);
    });

    test('fast return when initial residual is zero', () {
      final square2 = Matrix<double>.identity(2);
      final xExact = Vector<double>.fromList([1.0, 2.0]);
      final bExact = square2.apply(xExact);
      final xSolved = solveIterative(
        square2,
        bExact,
        x0: xExact,
        method: IterativeMethod.gmres,
      );
      check(xSolved.toList()).deepEquals(xExact.toList());
    });

    test('small restart parameter', () {
      final a = Matrix<double>.fromRows([
        [4.0, 1.0],
        [1.0, 3.0],
      ]);
      final b = Vector<double>.fromList([5.0, 4.0]);
      final xRestart = solveIterative(
        a,
        b,
        restart: 1,
        method: IterativeMethod.gmres,
      );
      check(xRestart[0]).isCloseTo(1.0, 1e-5);
      check(xRestart[1]).isCloseTo(1.0, 1e-5);
    });
  });

  group('Iterative solver error validation', () {
    test('dimension mismatches and non-square operators', () {
      final nonSquare = Matrix<double>.filled(2, 3, 1.0);
      final b2 = Vector<double>.fromList([1.0, 2.0]);
      final b3 = Vector<double>.fromList([1.0, 2.0, 3.0]);

      // Conjugate gradient errors
      check(
        () => solveIterative(
          nonSquare,
          b2,
          method: IterativeMethod.conjugateGradient,
        ),
      ).throws<ArgumentError>();
      final square2 = Matrix<double>.identity(2);
      check(
        () => solveIterative(
          square2,
          b3,
          method: IterativeMethod.conjugateGradient,
        ),
      ).throws<ArgumentError>();

      // GMRES errors
      check(() => solveIterative(nonSquare, b2, method: IterativeMethod.gmres))
          .throws<ArgumentError>();
      check(() => solveIterative(square2, b3, method: IterativeMethod.gmres))
          .throws<ArgumentError>();

      // Non-real type rejected
      final complexMat = Matrix<Complex>.fromRows([
        [Complex(1, 0), Complex(0, 0)],
        [Complex(0, 0), Complex(1, 0)],
      ], type: DataType.complex);
      final complexVec = Vector<Complex>.fromList([
        Complex(1, 0),
        Complex(2, 0),
      ], type: DataType.complex);
      check(() => solveIterative(complexMat, complexVec))
          .throws<ArgumentError>();
    });

    test('GMRES handles early breakdown without RangeError', () {
      // Matrix where vector is an eigenvector:
      // A = [2, 1; 0, 3], v = [1, 1] => A*v = [3, 3] = 3*v
      // b = [3, 3], x0 = [0, 0] => initial residual is eigenvector of A
      final a = Matrix<double>.fromRows([
        [2.0, 1.0],
        [0.0, 3.0],
      ]);
      final b = Vector<double>.fromList([3.0, 3.0]);
      final x = solveIterative(a, b);
      check(x[0]).isCloseTo(1.0, 1e-6);
      check(x[1]).isCloseTo(1.0, 1e-6);
    });
  });
}
