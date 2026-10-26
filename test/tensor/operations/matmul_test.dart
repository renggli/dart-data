import 'package:checks/checks.dart';
import 'package:data/tensor.dart';
import 'package:data/type.dart';
import 'package:test/test.dart';

import '../../acceleration/test_utils.dart';

void main() {
  group('matmul', () {
    accelerationTest('2D Float64 matrix multiplication', () {
      final a = Tensor<double>.fromIterable(
        [1.0, 2.0, 3.0, 4.0, 5.0, 6.0],
        shape: [2, 3],
        type: DataType.float64,
      );
      final b = Tensor<double>.fromIterable(
        [7.0, 8.0, 9.0, 10.0, 11.0, 12.0],
        shape: [3, 2],
        type: DataType.float64,
      );

      final c = a.matmul(b);
      check(c.shape).deepEquals([2, 2]);
      // [1*7 + 2*9 + 3*11, 1*8 + 2*10 + 3*12] = [58, 64]
      // [4*7 + 5*9 + 6*11, 4*8 + 5*10 + 6*12] = [139, 154]
      check(c.getValue([0, 0])).isCloseTo(58.0, 1e-10);
      check(c.getValue([0, 1])).isCloseTo(64.0, 1e-10);
      check(c.getValue([1, 0])).isCloseTo(139.0, 1e-10);
      check(c.getValue([1, 1])).isCloseTo(154.0, 1e-10);
    });

    accelerationTest('2D Float32 matrix multiplication', () {
      final a = Tensor<double>.fromIterable(
        [1.0, 2.0, 3.0, 4.0],
        shape: [2, 2],
        type: DataType.float32,
      );
      final b = Tensor<double>.fromIterable(
        [2.0, 0.0, 1.0, 2.0],
        shape: [2, 2],
        type: DataType.float32,
      );

      final c = a.matmul(b);
      check(c.shape).deepEquals([2, 2]);
      check(c.getValue([0, 0])).isCloseTo(4.0, 1e-5);
      check(c.getValue([0, 1])).isCloseTo(4.0, 1e-5);
      check(c.getValue([1, 0])).isCloseTo(10.0, 1e-5);
      check(c.getValue([1, 1])).isCloseTo(8.0, 1e-5);
    });

    test('generic int matrix multiplication', () {
      final a = Tensor<int>.fromIterable(
        [1, 2, 3, 4],
        shape: [2, 2],
        type: DataType.int32,
      );
      final b = Tensor<int>.fromIterable(
        [2, 0, 1, 2],
        shape: [2, 2],
        type: DataType.int32,
      );

      final c = a.matmul(b);
      check(c.shape).deepEquals([2, 2]);
      check(c.getValue([0, 0])).equals(4);
      check(c.getValue([0, 1])).equals(4);
      check(c.getValue([1, 0])).equals(10);
      check(c.getValue([1, 1])).equals(8);
    });

    accelerationTest('transposed combinations', () {
      final a = Tensor<double>.fromIterable(
        [1.0, 2.0, 3.0, 4.0, 5.0, 6.0],
        shape: [3, 2],
        type: DataType.float64,
      );
      final b = Tensor<double>.fromIterable(
        [7.0, 8.0, 9.0, 10.0, 11.0, 12.0],
        shape: [3, 2],
        type: DataType.float64,
      );

      // A^T [2, 3] * B [3, 2] -> [2, 2]
      final aT = a.transpose();
      final c1 = aT.matmul(b);
      check(c1.shape).deepEquals([2, 2]);
      // [1*7 + 3*9 + 5*11, 1*8 + 3*10 + 5*12] = [89, 98]
      // [2*7 + 4*9 + 6*11, 2*8 + 4*10 + 6*12] = [116, 128]
      check(c1.getValue([0, 0])).isCloseTo(89.0, 1e-10);
      check(c1.getValue([0, 1])).isCloseTo(98.0, 1e-10);
      check(c1.getValue([1, 0])).isCloseTo(116.0, 1e-10);
      check(c1.getValue([1, 1])).isCloseTo(128.0, 1e-10);

      // A [3, 2] * B^T [2, 3] -> [3, 3]
      final bT = b.transpose();
      final c2 = a.matmul(bT);
      check(c2.shape).deepEquals([3, 3]);
      check(c2.getValue([0, 0])).isCloseTo(23.0, 1e-10);
      check(c2.getValue([2, 2])).isCloseTo(127.0, 1e-10);
    });

    accelerationTest('batched matrix multiplication with broadcasting', () {
      final a = Tensor<double>.generate(
        (idx) => (idx[0] + 1) * 1.0,
        shape: [2, 1, 2, 2],
        type: DataType.float64,
      );
      final b = Tensor<double>.filled(
        1.0,
        shape: [1, 3, 2, 2],
        type: DataType.float64,
      );

      final c = a.matmul(b);
      check(c.shape).deepEquals([2, 3, 2, 2]);
      for (var b0 = 0; b0 < 2; b0++) {
        for (var b1 = 0; b1 < 3; b1++) {
          final expected = (b0 + 1) * 2.0;
          check(c.getValue([b0, b1, 0, 0])).isCloseTo(expected, 1e-10);
          check(c.getValue([b0, b1, 1, 1])).isCloseTo(expected, 1e-10);
        }
      }
    });

    test('zero dimensions and inner dimension 0', () {
      final aZeroK = Tensor<double>.filled(
        1.0,
        shape: [2, 0],
        type: DataType.float64,
      );
      final bZeroK = Tensor<double>.filled(
        1.0,
        shape: [0, 3],
        type: DataType.float64,
      );
      final cZeroK = aZeroK.matmul(bZeroK);
      check(cZeroK.shape).deepEquals([2, 3]);
      for (var i = 0; i < 2; i++) {
        for (var j = 0; j < 3; j++) {
          check(cZeroK.getValue([i, j])).equals(0.0);
        }
      }

      final aEmpty = Tensor<double>.filled(
        1.0,
        shape: [0, 2],
        type: DataType.float64,
      );
      final bEmpty = Tensor<double>.filled(
        1.0,
        shape: [2, 3],
        type: DataType.float64,
      );
      final cEmpty = aEmpty.matmul(bEmpty);
      check(cEmpty.shape).deepEquals([0, 3]);
    });

    test('in-place target and aliasing hazard', () {
      final a = Tensor<double>.fromIterable(
        [1.0, 2.0, 3.0, 4.0],
        shape: [2, 2],
        type: DataType.float64,
      );
      final b = Tensor<double>.fromIterable(
        [2.0, 0.0, 1.0, 2.0],
        shape: [2, 2],
        type: DataType.float64,
      );

      // Explicit target
      final target = Tensor<double>.filled(
        0.0,
        shape: [2, 2],
        type: DataType.float64,
      );
      final res = a.matmul(b, target: target);
      check(identical(res, target)).isTrue();
      check(target.getValue([0, 0])).isCloseTo(4.0, 1e-10);
      check(target.getValue([1, 1])).isCloseTo(8.0, 1e-10);

      // Target aliases input: a.matmul(b, target: a)
      final aliasedRes = a.matmul(b, target: a);
      check(identical(aliasedRes, a)).isTrue();
      check(a.getValue([0, 0])).isCloseTo(4.0, 1e-10);
      check(a.getValue([0, 1])).isCloseTo(4.0, 1e-10);
      check(a.getValue([1, 0])).isCloseTo(10.0, 1e-10);
      check(a.getValue([1, 1])).isCloseTo(8.0, 1e-10);
    });

    test('validation errors', () {
      final t1D = Tensor<double>.filled(1.0, shape: [3]);
      final t2D = Tensor<double>.filled(1.0, shape: [3, 3]);
      check(() => t1D.matmul(t2D)).throws<ArgumentError>();
      check(() => t2D.matmul(t1D)).throws<ArgumentError>();

      final mismatch = Tensor<double>.filled(1.0, shape: [4, 2]);
      check(() => t2D.matmul(mismatch)).throws<ArgumentError>();

      final badTargetRank = Tensor<double>.filled(0.0, shape: [3]);
      check(() => t2D.matmul(t2D, target: badTargetRank))
          .throws<ArgumentError>();

      final badTargetShape = Tensor<double>.filled(0.0, shape: [2, 2]);
      check(() => t2D.matmul(t2D, target: badTargetShape))
          .throws<ArgumentError>();

      // Inner dimension 0 (e.g. [2, 0] * [0, 3] -> [2, 3] zeros)
      final a20 = Tensor<double>.filled(0.0, shape: [2, 0]);
      final b03 = Tensor<double>.filled(0.0, shape: [0, 3]);
      final c23 = a20.matmul(b03);
      check(c23.shape).deepEquals([2, 3]);
      check(c23.toFlatList()).deepEquals([0.0, 0.0, 0.0, 0.0, 0.0, 0.0]);

      // Transposed 1-column matrix (innerDim == 1, strides[0] == 1)
      final a31 = Tensor<double>.fromIterable(
        [1.0, 2.0, 3.0],
        shape: [1, 3],
      ).transpose([1, 0]);
      final b12 = Tensor<double>.fromIterable([4.0, 5.0], shape: [1, 2]);
      check(a31.matmul(b12).shape).deepEquals([3, 2]);

      // Non-contiguous target in batched matmul with innerDim == 0
      final batchA = Tensor<double>.filled(0.0, shape: [2, 2, 0]);
      final batchB = Tensor<double>.filled(0.0, shape: [2, 0, 2]);
      final fullTarget = Tensor<double>.filled(1.0, shape: [2, 2, 4]);
      final slicedTarget = fullTarget.getRange(axis: 2, start: 0, end: 2);
      batchA.matmul(batchB, target: slicedTarget);
      check(slicedTarget.toFlatList()).every((it) => it.equals(0.0));
    });
  });
}
