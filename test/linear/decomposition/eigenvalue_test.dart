import 'package:checks/checks.dart';
import 'package:data/hardware.dart';
import 'package:data/linear.dart';
import 'package:data/type.dart';
import 'package:test/test.dart';

void main() {
  group('Eigenvalue Decomposition', () {
    test('symmetric matrix eigenvalues and eigenvectors', () {
      final a = Matrix<double>.fromRows([
        [4.0, 1.0, -2.0],
        [1.0, 2.0, 0.0],
        [-2.0, 0.0, 3.0],
      ], type: DataType.float64);

      final eig = a.eigenvalue;
      final vals = eig.realEigenvalues;
      final vMat = eig.v;

      // For symmetric matrix, imaginary parts are 0
      for (final im in eig.imagEigenvalues) {
        check(im).isCloseTo(0.0, 1e-9);
      }

      // V * D * V^T == A
      final dMat = eig.d;
      final reconstructed = vMat * dMat * vMat.transposed;
      for (var i = 0; i < 3; i++) {
        for (var j = 0; j < 3; j++) {
          check(reconstructed.get(i, j)).isCloseTo(a.get(i, j), 1e-6);
        }
      }

      // A * v_i == lambda_i * v_i
      for (var i = 0; i < 3; i++) {
        final colI = vMat.col(i);
        final aCol = a.apply(colI);
        final lambdaCol = colI.scale(vals[i]);
        for (var k = 0; k < 3; k++) {
          check(aCol[k]).isCloseTo(lambdaCol[k], 1e-6);
        }
      }
    });

    test('non-symmetric matrix eigenvalues', () {
      // Rotation-like matrix with complex eigenvalues
      final a = Matrix<double>.fromRows([
        [0.0, -1.0],
        [1.0, 0.0],
      ], type: DataType.float64);

      final eig = a.eigenvalue;
      final complexEigs = eig.eigenvalues;

      check(complexEigs.length).equals(2);
      check(complexEigs[0].a).isCloseTo(0.0, 1e-9); // real
      check(complexEigs[0].b.abs()).isCloseTo(1.0, 1e-9); // imag
      check(complexEigs[1].a).isCloseTo(0.0, 1e-9);
      check(complexEigs[1].b.abs()).isCloseTo(1.0, 1e-9);

      // Accessing V and D on non-symmetric matrix
      final vMat = eig.v;
      final dMat = eig.d;
      check(vMat.rowCount).equals(2);
      check(dMat.rowCount).equals(2);

      // 3x3 and 4x4 non-symmetric matrices with real and complex eigenvalues
      final m3 = Matrix<double>.fromRows([
        [1.0, -2.0, 0.0],
        [2.0, 1.0, 0.0],
        [0.0, 0.0, 3.0],
      ], type: DataType.float64);
      final eig3 = m3.eigenvalue;
      check(eig3.v.rowCount).equals(3);
      check(eig3.d.rowCount).equals(3);

      final m4 = Matrix<double>.fromRows([
        [0.0, 1.0, 0.0, 0.0],
        [-1.0, 0.0, 0.0, 0.0],
        [0.0, 0.0, 2.0, -3.0],
        [0.0, 0.0, 3.0, 2.0],
      ], type: DataType.float64);
      final eig4 = m4.eigenvalue;
      check(eig4.v.rowCount).equals(4);
      check(eig4.d.rowCount).equals(4);
    });

    test('non-square matrix throws', () {
      final a = Matrix<double>.fromRows([
        [1.0, 2.0, 3.0],
        [4.0, 5.0, 6.0],
      ], type: DataType.float64);
      check(() => a.eigenvalue).throws<ArgumentError>();
    });

    test('symmetric diagonal matrix (scale == 0 branch)', () {
      final diag = Matrix<double>.fromRows([
        [2.0, 0.0, 0.0],
        [0.0, 5.0, 0.0],
        [0.0, 0.0, 7.0],
      ], type: DataType.float64);
      final eig = diag.eigenvalue;
      check(eig.realEigenvalues.length).equals(3);
      check(eig.v.rowCount).equals(3);
    });

    test('symmetric matrix with hardware enabled vs disabled', () {
      final a = Matrix<double>.fromRows([
        [5.0, 2.0, -1.0, 0.0],
        [2.0, 4.0, 1.0, -2.0],
        [-1.0, 1.0, 6.0, 3.0],
        [0.0, -2.0, 3.0, 7.0],
      ], type: DataType.float64);

      for (final hw in [true, false]) {
        HardwareManager.isEnabled = hw;
        final eig = a.eigenvalue;
        final d = eig.d;
        final v = eig.v;
        final vals = eig.realEigenvalues;

        // 1. Check eigenvalue ordering: ascending
        for (var i = 0; i < vals.length - 1; i++) {
          check(vals[i] <= vals[i + 1]).isTrue();
        }

        // 2. Check orthonormality: V^T * V = I
        final vTv = v.transposed * v;
        for (var i = 0; i < 4; i++) {
          for (var j = 0; j < 4; j++) {
            check(vTv.get(i, j)).isCloseTo(i == j ? 1.0 : 0.0, 1e-8);
          }
        }

        // 3. Check reconstruction: A * V = V * D
        final av = a * v;
        final vd = v * d;
        for (var i = 0; i < 4; i++) {
          for (var j = 0; j < 4; j++) {
            check(av.get(i, j)).isCloseTo(vd.get(i, j), 1e-7);
          }
        }
      }
      HardwareManager.isEnabled = true;
    });

    test('non-float64 symmetric matrices use pure Dart fallback', () {
      final aInt = Matrix<int>.fromRows([
        [2, 1],
        [1, 2],
      ], type: DataType.int32);
      final eig = aInt.eigenvalue;
      check(eig.realEigenvalues.length).equals(2);
      check(eig.realEigenvalues[0]).isCloseTo(1.0, 1e-9);
      check(eig.realEigenvalues[1]).isCloseTo(3.0, 1e-9);
    });

    test('non-square matrix with rowCount > colCount throws', () {
      final a = Matrix<double>.fromRows([
        [1.0, 2.0],
        [3.0, 4.0],
        [5.0, 6.0],
      ], type: DataType.float64);
      check(() => a.eigenvalue).throws<ArgumentError>();
    });

    test('float32 symmetric matrix uses pure Dart fallback', () {
      final a32 = Matrix<double>.fromRows([
        [2.0, 1.0],
        [1.0, 2.0],
      ], type: DataType.float32);
      final eig = a32.eigenvalue;
      check(eig.realEigenvalues.length).equals(2);
      check(eig.realEigenvalues[0]).isCloseTo(1.0, 1e-6);
      check(eig.realEigenvalues[1]).isCloseTo(3.0, 1e-6);
    });

    test('0x0 and 1x1 matrix eigenvalue decompositions', () {
      final empty = Matrix<double>.fromRows([], type: DataType.float64);
      final emptyEig = empty.eigenvalue;
      check(emptyEig.realEigenvalues.length).equals(0);
      check(emptyEig.v.rowCount).equals(0);

      final single = Matrix<double>.fromRows([
        [42.0],
      ], type: DataType.float64);
      final singleEig = single.eigenvalue;
      check(singleEig.realEigenvalues[0]).equals(42.0);
      check(singleEig.v.get(0, 0)).equals(1.0);
    });
  });
}
