import 'package:checks/checks.dart';
import 'package:data/linear.dart';
import 'package:data/type.dart';
import 'package:test/scaffolding.dart';

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
      final v = eig.v;

      // For symmetric matrix, imaginary parts are 0
      for (final im in eig.imagEigenvalues) {
        check(im).isCloseTo(0.0, 1e-9);
      }

      // V * D * V^T == A
      final d = eig.d;
      final reconstructed = v * d * v.transposed;
      for (var i = 0; i < 3; i++) {
        for (var j = 0; j < 3; j++) {
          check(reconstructed.get(i, j)).isCloseTo(a.get(i, j), 1e-6);
        }
      }

      // A * v_i == lambda_i * v_i
      for (var i = 0; i < 3; i++) {
        final colI = v.col(i);
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
      final v = eig.v;
      final d = eig.d;
      check(v.rowCount).equals(2);
      check(d.rowCount).equals(2);

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
  });
}
