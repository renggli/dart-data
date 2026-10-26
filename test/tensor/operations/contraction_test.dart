import 'package:checks/checks.dart';
import 'package:data/tensor.dart';
import 'package:data/type.dart';
import 'package:test/test.dart';

void main() {
  group('tensordot contraction', () {
    test('matrix multiplication equivalence (axes = 1)', () {
      // A: [2, 3], B: [3, 4] -> C: [2, 4]
      final a = Tensor<double>.fromIterable(
        [1.0, 2.0, 3.0, 4.0, 5.0, 6.0],
        shape: [2, 3],
        type: DataType.float64,
      );

      final b = Tensor<double>.fromIterable(
        [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0, 11.0, 12.0],
        shape: [3, 4],
        type: DataType.float64,
      );

      final c = a.tensordot(b, axes: 1);
      check(c.shape).deepEquals([2, 4]);

      final expectedMatmul = a.matmul(b);
      for (var i = 0; i < 2; i++) {
        for (var j = 0; j < 4; j++) {
          check(c.getValue([i, j])).equals(expectedMatmul.getValue([i, j]));
        }
      }
    });

    test('3D tensor contraction over multiple axes', () {
      // A: [2, 3, 4], B: [3, 4, 5] contracted along axes ([1, 2], [0, 1]) ->
      // [2, 5]
      final a = Tensor<double>.generate(
        (idx) => idx[0] + 2.0 * idx[1] + 3.0 * idx[2],
        shape: [2, 3, 4],
        type: DataType.float64,
      );

      final b = Tensor<double>.generate(
        (idx) => 2.0 * idx[0] + idx[1] + 4.0 * idx[2],
        shape: [3, 4, 5],
        type: DataType.float64,
      );

      final res = a.tensordot(b, contractAxes: (self: [1, 2], other: [0, 1]));
      check(res.shape).deepEquals([2, 5]);

      // Verify analytical element [0, 0]
      var expected00 = 0.0;
      for (var j = 0; j < 3; j++) {
        for (var k = 0; k < 4; k++) {
          expected00 += a.getValue([0, j, k]) * b.getValue([j, k, 0]);
        }
      }
      check(res.getValue([0, 0])).isCloseTo(expected00, 1e-9);

      // Verify element [1, 3]
      var expected13 = 0.0;
      for (var j = 0; j < 3; j++) {
        for (var k = 0; k < 4; k++) {
          expected13 += a.getValue([1, j, k]) * b.getValue([j, k, 3]);
        }
      }
      check(res.getValue([1, 3])).isCloseTo(expected13, 1e-9);
    });

    test('integer axes parameter contracts trailing vs leading axes', () {
      // A: [2, 3, 4], B: [3, 4, 5]
      // axes: 2 -> contracts last 2 of A ([1, 2]) with first 2 of B ([0, 1])
      final a = Tensor<double>.filled(
        1.0,
        shape: [2, 3, 4],
        type: DataType.float64,
      );
      final b = Tensor<double>.filled(
        2.0,
        shape: [3, 4, 5],
        type: DataType.float64,
      );

      final res = a.tensordot(b, axes: 2);
      check(res.shape).deepEquals([2, 5]);
      // Each cell sums 3 * 4 = 12 terms of 1.0 * 2.0 = 24.0
      check(res.getValue([0, 0])).equals(24.0);
      check(res.getValue([1, 4])).equals(24.0);
    });
  });

  group('inner and outer products', () {
    test('innerProduct produces rank-0 scalar tensor', () {
      final a = Tensor<double>.fromIterable(
        [1.0, 2.0, 3.0],
        shape: [3],
        type: DataType.float64,
      );
      final b = Tensor<double>.fromIterable(
        [4.0, 5.0, 6.0],
        shape: [3],
        type: DataType.float64,
      );

      final inner = a.innerProduct(b);
      check(inner.rank).equals(0);
      // 1*4 + 2*5 + 3*6 = 32
      check(inner.getValue([])).equals(32.0);

      // 2D Frobenius inner product
      final m1 = Tensor<double>.fromIterable(
        [1.0, 2.0, 3.0, 4.0],
        shape: [2, 2],
        type: DataType.float64,
      );
      final m2 = Tensor<double>.fromIterable(
        [2.0, 0.0, 1.0, 3.0],
        shape: [2, 2],
        type: DataType.float64,
      );
      final inner2D = m1.innerProduct(m2);
      // 1*2 + 2*0 + 3*1 + 4*3 = 2 + 0 + 3 + 12 = 17
      check(inner2D.getValue([])).equals(17.0);
    });

    test('outerProduct combines all axes', () {
      final a = Tensor<double>.fromIterable(
        [1.0, 2.0],
        shape: [2],
        type: DataType.float64,
      );
      final b = Tensor<double>.fromIterable(
        [3.0, 4.0, 5.0],
        shape: [3],
        type: DataType.float64,
      );

      final outer = a.outerProduct(b);
      check(outer.shape).deepEquals([2, 3]);
      check(outer.getValue([0, 0])).equals(3.0);
      check(outer.getValue([0, 1])).equals(4.0);
      check(outer.getValue([1, 2])).equals(10.0);

      // Contract specific axes with contractAxes
      final a2D = a.reshape([2, 1]);
      final b2D = b.reshape([1, 3]);
      check(a2D.tensordot(b2D, contractAxes: (self: [1], other: [0])).shape)
          .deepEquals([2, 3]);
    });
  });

  group('contraction validation and errors', () {
    test('error validation', () {
      final a = Tensor<double>.filled(
        1.0,
        shape: [2, 3],
        type: DataType.float64,
      );
      final b = Tensor<double>.filled(
        1.0,
        shape: [4, 5],
        type: DataType.float64,
      );

      // Dimension mismatch along contracted axis
      check(() => a.tensordot(b, axes: 1)).throws<ArgumentError>();

      // Axis count exceeds rank
      check(() => a.tensordot(b, axes: 3)).throws<ArgumentError>();

      // Out of bounds axis
      check(() => a.tensordot(b, contractAxes: (self: [5], other: [0])))
          .throws<RangeError>();

      // Unequal axes lists length
      check(() => a.tensordot(b, contractAxes: (self: [0, 1], other: [0])))
          .throws<ArgumentError>();

      // Duplicate axis in contraction list
      check(() => a.tensordot(b, contractAxes: (self: [1, 1], other: [0, 1])))
          .throws<ArgumentError>();
      check(() => a.tensordot(b, axes: -1)).throws<ArgumentError>();
    });
  });
}
