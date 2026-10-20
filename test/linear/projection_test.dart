import 'package:checks/checks.dart';
import 'package:data/linear.dart';
import 'package:data/tensor.dart';
import 'package:data/type.dart';
import 'package:test/test.dart';

void main() {
  group('Vector project and reject', () {
    test('orthogonal projection and rejection on coordinate axes', () {
      final u = Vector<double>.fromList([3.0, 4.0], type: DataType.float64);
      final v = Vector<double>.fromList([1.0, 0.0], type: DataType.float64);

      final proj = u.project(v);
      final rej = u.reject(v);

      check(proj.length).equals(2);
      check(proj[0]).isCloseTo(3.0, 1e-10);
      check(proj[1]).isCloseTo(0.0, 1e-10);

      check(rej.length).equals(2);
      check(rej[0]).isCloseTo(0.0, 1e-10);
      check(rej[1]).isCloseTo(4.0, 1e-10);

      // Reconstructed sum: proj + rej == u
      check(proj[0] + rej[0]).isCloseTo(u[0], 1e-10);
      check(proj[1] + rej[1]).isCloseTo(u[1], 1e-10);

      // Orthogonality: rej . v == 0
      check(rej.dot(v)).isCloseTo(0.0, 1e-10);
      // Orthogonality: proj . rej == 0
      check(proj.dot(rej)).isCloseTo(0.0, 1e-10);
    });

    test('projection and rejection on general 3D vectors', () {
      final u = Vector<double>.fromList([
        1.0,
        2.0,
        3.0,
      ], type: DataType.float64);
      final v = Vector<double>.fromList([
        2.0,
        -1.0,
        2.0,
      ], type: DataType.float64);

      // <u, v> = 2 - 2 + 6 = 6
      // ||v||^2 = 4 + 1 + 4 = 9
      // scale = 6 / 9 = 2/3
      // proj = (2/3) * [2, -1, 2] = [4/3, -2/3, 4/3]
      // rej = [1, 2, 3] - [4/3, -2/3, 4/3] = [-1/3, 8/3, 5/3]
      final proj = u.project(v);
      final rej = u.reject(v);

      check(proj[0]).isCloseTo(4.0 / 3.0, 1e-10);
      check(proj[1]).isCloseTo(-2.0 / 3.0, 1e-10);
      check(proj[2]).isCloseTo(4.0 / 3.0, 1e-10);

      check(rej[0]).isCloseTo(-1.0 / 3.0, 1e-10);
      check(rej[1]).isCloseTo(8.0 / 3.0, 1e-10);
      check(rej[2]).isCloseTo(5.0 / 3.0, 1e-10);

      // Orthogonality checks
      check(rej.dot(v)).isCloseTo(0.0, 1e-10);
      check(proj.dot(rej)).isCloseTo(0.0, 1e-10);

      // Reconstruction
      for (var i = 0; i < 3; i++) {
        check(proj[i] + rej[i]).isCloseTo(u[i], 1e-10);
      }
    });

    test('projection of integer vectors onto integer vectors', () {
      final u = Vector<int>.fromList([3, 4], type: DataType.int32);
      final v = Vector<int>.fromList([1, 0], type: DataType.int32);

      final proj = u.project(v);
      final rej = u.reject(v);

      check(proj.type).equals(DataType.float64);
      check(proj[0]).isCloseTo(3.0, 1e-10);
      check(proj[1]).isCloseTo(0.0, 1e-10);

      check(rej.type).equals(DataType.float64);
      check(rej[0]).isCloseTo(0.0, 1e-10);
      check(rej[1]).isCloseTo(4.0, 1e-10);
    });

    test('projection of integer vectors onto double vectors', () {
      final u = Vector<int>.fromList([2, 2], type: DataType.int32);
      final v = Vector<double>.fromList([0.0, 3.0], type: DataType.float64);

      final proj = u.project(v);
      final rej = u.reject(v);

      check(proj[0]).isCloseTo(0.0, 1e-10);
      check(proj[1]).isCloseTo(2.0, 1e-10);

      check(rej[0]).isCloseTo(2.0, 1e-10);
      check(rej[1]).isCloseTo(0.0, 1e-10);
    });

    test('projection and rejection with non-contiguous vectors', () {
      final u = Vector<double>(Tensor<double>.fromIterable([4.0, 3.0]).flip());
      final v = Vector<double>(Tensor<double>.fromIterable([0.0, 1.0]).flip());
      check(u.tensor.isContiguous).isFalse();
      check(v.tensor.isContiguous).isFalse();

      final proj = u.project(v);
      final rej = u.reject(v);

      check(proj[0]).isCloseTo(3.0, 1e-10);
      check(proj[1]).isCloseTo(0.0, 1e-10);
      check(rej[0]).isCloseTo(0.0, 1e-10);
      check(rej[1]).isCloseTo(4.0, 1e-10);
    });

    test('parallel vectors have full projection and zero rejection', () {
      final u = Vector<double>.fromList([
        2.0,
        4.0,
        6.0,
      ], type: DataType.float64);
      final v = Vector<double>.fromList([
        1.0,
        2.0,
        3.0,
      ], type: DataType.float64);

      final proj = u.project(v);
      final rej = u.reject(v);

      for (var i = 0; i < 3; i++) {
        check(proj[i]).isCloseTo(u[i], 1e-10);
        check(rej[i]).isCloseTo(0.0, 1e-10);
      }
      check(rej.norm()).isCloseTo(0.0, 1e-10);
    });

    test('orthogonal vectors have zero projection and full rejection', () {
      final u = Vector<double>.fromList([0.0, 5.0], type: DataType.float64);
      final v = Vector<double>.fromList([3.0, 0.0], type: DataType.float64);

      final proj = u.project(v);
      final rej = u.reject(v);

      check(proj[0]).isCloseTo(0.0, 1e-10);
      check(proj[1]).isCloseTo(0.0, 1e-10);

      check(rej[0]).isCloseTo(u[0], 1e-10);
      check(rej[1]).isCloseTo(u[1], 1e-10);
    });

    test('non-contiguous subVector projection and rejection', () {
      final uFull = Vector<double>.fromList([
        99.0,
        1.0,
        2.0,
        3.0,
        99.0,
      ], type: DataType.float64);
      final vFull = Vector<double>.fromList([
        88.0,
        2.0,
        -1.0,
        2.0,
        88.0,
      ], type: DataType.float64);
      final u = uFull.subVector(1, 4);
      final v = vFull.subVector(1, 4);

      final proj = u.project(v);
      final rej = u.reject(v);

      check(proj[0]).isCloseTo(4.0 / 3.0, 1e-10);
      check(proj[1]).isCloseTo(-2.0 / 3.0, 1e-10);
      check(proj[2]).isCloseTo(4.0 / 3.0, 1e-10);

      check(rej[0]).isCloseTo(-1.0 / 3.0, 1e-10);
      check(rej[1]).isCloseTo(8.0 / 3.0, 1e-10);
      check(rej[2]).isCloseTo(5.0 / 3.0, 1e-10);
    });

    test('throws ArgumentError on vector length mismatch', () {
      final u = Vector<double>.fromList([1.0, 2.0], type: DataType.float64);
      final v = Vector<double>.fromList([
        1.0,
        2.0,
        3.0,
      ], type: DataType.float64);

      check(() => u.project(v)).throws<ArgumentError>();
      check(() => u.reject(v)).throws<ArgumentError>();
    });

    test('throws ArgumentError on zero or near-zero target vector norm', () {
      final u = Vector<double>.fromList([1.0, 2.0], type: DataType.float64);
      final vZero = Vector<double>.fromList([0.0, 0.0], type: DataType.float64);
      final vNearZero = Vector<double>.fromList([
        1e-8,
        0.0,
      ], type: DataType.float64); // normSq = 1e-16 < 1e-15

      check(() => u.project(vZero)).throws<ArgumentError>();
      check(() => u.reject(vZero)).throws<ArgumentError>();

      check(() => u.project(vNearZero)).throws<ArgumentError>();
      check(() => u.reject(vNearZero)).throws<ArgumentError>();
    });
  });
}
