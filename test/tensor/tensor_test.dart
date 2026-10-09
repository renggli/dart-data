import 'package:data/tensor.dart';
import 'package:data/type.dart';
import 'package:test/test.dart';

void main() {
  group('Layout', () {
    test('1D contiguous layout', () {
      final layout = Layout(shape: [5]);
      expect(layout.rank, 1);
      expect(layout.shape, [5]);
      expect(layout.strides, [1]);
      expect(layout.length, 5);
      expect(layout.isContiguous, isTrue);
      expect(layout.toIndex([3]), 3);
      expect(layout.toKey(3), [3]);
    });

    test('2D contiguous layout and indexing', () {
      final layout = Layout(shape: [2, 3]);
      expect(layout.rank, 2);
      expect(layout.strides, [3, 1]);
      expect(layout.length, 6);
      expect(layout.isContiguous, isTrue);
      expect(layout.toIndex([1, 2]), 5);
      expect(layout.toKey(5), [1, 2]);
    });

    test('transposed layout is non-contiguous', () {
      final layout = Layout(shape: [2, 3]);
      final transposed = layout.transpose([1, 0]);
      expect(transposed.shape, [3, 2]);
      expect(transposed.strides, [1, 3]);
      expect(transposed.isContiguous, isFalse);
      expect(transposed.toIndex([2, 1]), layout.toIndex([1, 2]));
    });

    test('reshape layout', () {
      final layout = Layout(shape: [2, 3]);
      final reshaped = layout.reshape([6]);
      expect(reshaped.shape, [6]);
      expect(reshaped.strides, [1]);
      expect(reshaped.isContiguous, isTrue);
    });

    test('broadcast layout', () {
      final layout1 = Layout(shape: [1, 3]);
      final layout2 = Layout(shape: [4, 1]);
      final (b1, b2) = layout1.broadcast(layout2);
      expect(b1.shape, [4, 3]);
      expect(b1.strides, [0, 1]);
      expect(b1.isContiguous, isFalse);
      expect(b2.shape, [4, 3]);
      expect(b2.strides, [1, 0]);
    });

    test('flip and slice layout', () {
      final layout = Layout(shape: [3, 4]);
      final flipped = layout.flip(axis: 0);
      expect(flipped.shape, [3, 4]);
      expect(flipped.toIndex([0, 0]), 8);

      final sliced = layout.getRange(axis: 0, start: 1, end: 3);
      expect(sliced.shape, [2, 4]);
      expect(sliced.toIndex([0, 0]), 4);
    });
  });

  group('Tensor creation and indexing', () {
    test('filled', () {
      final t = Tensor<double>.filled(42.0, shape: [2, 2]);
      expect(t.shape, [2, 2]);
      expect(t.length, 4);
      expect(t.getValue([0, 0]), 42.0);
      expect(t.getValue([1, 1]), 42.0);
    });

    test('generate', () {
      final t = Tensor<int>.generate(
        (key) => key[0] * 10 + key[1],
        shape: [2, 3],
        type: DataType.int32,
      );
      expect(t.getValue([0, 0]), 0);
      expect(t.getValue([0, 2]), 2);
      expect(t.getValue([1, 0]), 10);
      expect(t.getValue([1, 2]), 12);
    });

    test('fromIterable and fromObject', () {
      final t1 = Tensor<int>.fromIterable([1, 2, 3, 4], shape: [2, 2]);
      expect(t1.shape, [2, 2]);
      expect(t1.getValue([1, 0]), 3);

      final t2 = Tensor<int>.fromObject([
        [1, 2],
        [3, 4],
      ]);
      expect(t2.shape, [2, 2]);
      expect(t2.getValue([0, 1]), 2);
      expect(t2.toNestedList(), [
        [1, 2],
        [3, 4],
      ]);
    });

    test('slicing operator[]', () {
      final t = Tensor<int>.fromIterable([1, 2, 3, 4, 5, 6], shape: [2, 3]);
      final row0 = t[0];
      expect(row0.shape, [3]);
      expect(row0.getValue([0]), 1);
      expect(row0.getValue([2]), 3);

      final row1 = t[1];
      expect(row1.shape, [3]);
      expect(row1.getValue([0]), 4);
      expect(row1.getValue([2]), 6);
    });
  });

  group('Tensor operations', () {
    test('element-wise binary operations', () {
      final a = Tensor<double>.fromIterable(
        [1.0, 2.0, 3.0, 4.0],
        shape: [2, 2],
      );
      final b = Tensor<double>.fromIterable(
        [10.0, 20.0, 30.0, 40.0],
        shape: [2, 2],
      );

      final sum = a + b;
      expect(sum.toFlatList(), [11.0, 22.0, 33.0, 44.0]);

      final diff = b - a;
      expect(diff.toFlatList(), [9.0, 18.0, 27.0, 36.0]);

      final prod = a * b;
      expect(prod.toFlatList(), [10.0, 40.0, 90.0, 160.0]);

      final div = b / a;
      expect(div.toFlatList(), [10.0, 10.0, 10.0, 10.0]);
    });

    test('broadcasting operations', () {
      final a = Tensor<double>.fromIterable(
        [1.0, 2.0, 3.0, 4.0],
        shape: [2, 2],
      );
      final row = Tensor<double>.fromIterable([10.0, 20.0], shape: [1, 2]);

      final res = a + row;
      expect(res.shape, [2, 2]);
      expect(res.toFlatList(), [11.0, 22.0, 13.0, 24.0]);
    });

    test('element-wise unary operations', () {
      final a = Tensor<double>.fromIterable([1.0, 4.0, 9.0, 16.0], shape: [4]);
      expect(a.sqrt().toFlatList(), [1.0, 2.0, 3.0, 4.0]);
      expect((-a).toFlatList(), [-1.0, -4.0, -9.0, -16.0]);
    });

    test('reductions: sum, mean, min, max, norm', () {
      final a = Tensor<double>.fromIterable(
        [1.0, 2.0, 3.0, 4.0, 5.0, 6.0],
        shape: [2, 3],
      );

      final totalSum = a.sum();
      expect(totalSum.shape, <int>[]);
      expect(totalSum.getValue([]), 21.0);

      final rowSum = a.sum(axis: 0);
      expect(rowSum.shape, [3]);
      expect(rowSum.toFlatList(), [5.0, 7.0, 9.0]);

      final colSum = a.sum(axis: 1);
      expect(colSum.shape, [2]);
      expect(colSum.toFlatList(), [6.0, 15.0]);

      final meanVal = a.mean();
      expect(meanVal.getValue([]), 3.5);

      final minVal = a.min();
      expect(minVal.getValue([]), 1.0);

      final maxVal = a.max();
      expect(maxVal.getValue([]), 6.0);
    });

    test('argmin and argmax', () {
      final a = Tensor<int>.fromIterable([10, 5, 20, 15], shape: [4]);
      expect(a.argmin().getValue([]), 1);
      expect(a.argmax().getValue([]), 2);
    });
  });

  group('Matrix multiplication', () {
    test('2D GEMM', () {
      // A is 2x3, B is 3x2
      // A = [[1, 2, 3],
      //      [4, 5, 6]]
      // B = [[7, 8],
      //      [9, 1],
      //      [2, 3]]
      // C = A * B = [[1*7+2*9+3*2, 1*8+2*1+3*3],
      //              [4*7+5*9+6*2, 4*8+5*1+6*3]]
      //   = [[7+18+6, 8+2+9],
      //      [28+45+12, 32+5+18]]
      //   = [[31, 19],
      //      [85, 55]]
      final a = Tensor<double>.fromIterable([1, 2, 3, 4, 5, 6], shape: [2, 3]);
      final b = Tensor<double>.fromIterable([7, 8, 9, 1, 2, 3], shape: [3, 2]);

      final c = a.matmul(b);
      expect(c.shape, [2, 2]);
      expect(c.toNestedList(), [
        [31.0, 19.0],
        [85.0, 55.0],
      ]);
    });

    test('batched GEMM', () {
      // Batch of 2 matrices: [2, 2, 2] x [2, 2, 2]
      final a = Tensor<double>.fromIterable(
        [
          1, 0, 0, 1, // identity
          2, 0, 0, 2, // 2 * identity
        ],
        shape: [2, 2, 2],
      );

      final b = Tensor<double>.fromIterable(
        [3, 4, 5, 6, 1, 2, 3, 4],
        shape: [2, 2, 2],
      );

      final c = a.matmul(b);
      expect(c.shape, [2, 2, 2]);
      expect(c.toNestedList(), [
        [
          [3.0, 4.0],
          [5.0, 6.0],
        ],
        [
          [2.0, 4.0],
          [6.0, 8.0],
        ],
      ]);
    });
  });

  group('Tensor manipulations', () {
    test('concatenate', () {
      final a = Tensor<int>.fromIterable([1, 2], shape: [1, 2]);
      final b = Tensor<int>.fromIterable([3, 4], shape: [1, 2]);

      final concat0 = a.concatenate(b, axis: 0);
      expect(concat0.shape, [2, 2]);
      expect(concat0.toNestedList(), [
        [1, 2],
        [3, 4],
      ]);

      final concat1 = a.concatenate(b, axis: 1);
      expect(concat1.shape, [1, 4]);
      expect(concat1.toNestedList(), [
        [1, 2, 3, 4],
      ]);
    });

    test('stack', () {
      final a = Tensor<int>.fromIterable([1, 2], shape: [2]);
      final b = Tensor<int>.fromIterable([3, 4], shape: [2]);

      final stacked = a.stack(b, axis: 0);
      expect(stacked.shape, [2, 2]);
      expect(stacked.toNestedList(), [
        [1, 2],
        [3, 4],
      ]);
    });

    test('tile', () {
      final a = Tensor<int>.fromIterable([1, 2, 3, 4], shape: [2, 2]);
      final tiled = a.tile([2, 1]);
      expect(tiled.shape, [4, 2]);
      expect(tiled.toNestedList(), [
        [1, 2],
        [3, 4],
        [1, 2],
        [3, 4],
      ]);
    });

    test('pad', () {
      final a = Tensor<int>.fromIterable([1, 2, 3, 4], shape: [2, 2]);
      final padded = a.pad([
        [1, 1],
        [1, 1],
      ], fillValue: 0);
      expect(padded.shape, [4, 4]);
      expect(padded.toNestedList(), [
        [0, 0, 0, 0],
        [0, 1, 2, 0],
        [0, 3, 4, 0],
        [0, 0, 0, 0],
      ]);
    });
  });

  group('Memory safety & aliasing hazard guard', () {
    test('strided view broadcast in-place guard', () {
      final a = Tensor<double>.fromIterable(
        [1.0, 2.0, 3.0, 4.0],
        shape: [2, 2],
      );
      // Slicing shares the same underlying buffer
      final row0 = a[0];
      expect(row0.buffer.sharesMemoryWith(a.buffer), isTrue);

      // Binary operation between row0 and a does not corrupt results due to aliasing
      final result = a + row0;
      expect(result.shape, [2, 2]);
      expect(result.toFlatList(), [2.0, 4.0, 4.0, 6.0]);
    });
  });
}
