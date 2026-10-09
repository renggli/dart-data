import 'dart:math' as math;

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

    test('rank 0 scalar layout and toString', () {
      final scalarLayout = Layout(shape: []);
      expect(scalarLayout.rank, 0);
      expect(scalarLayout.length, 1);
      expect(scalarLayout.keys.toList(), [<int>[]]);
      expect(scalarLayout.indices.toList(), [0]);
      expect(scalarLayout.toString(), contains('Layout(rank: 0'));
    });

    test('layout error validations: toIndex, toKey, transpose, reshape, broadcast, getRange', () {
      final layout2D = Layout(shape: [2, 3]);

      // toIndex errors
      expect(() => layout2D.toIndex([0]), throwsArgumentError);
      expect(() => layout2D.toIndex([0, 5]), throwsRangeError);
      expect(() => layout2D.toIndex([-5, 0]), throwsRangeError);

      // toKey error
      expect(() => layout2D.toKey(-1), throwsRangeError);
      expect(() => layout2D.toKey(10), throwsRangeError);

      // transpose error
      expect(() => layout2D.transpose([0]), throwsArgumentError);

      // reshape errors and inference
      final inferred = layout2D.reshape([-1, 2]);
      expect(inferred.shape, [3, 2]);

      expect(() => layout2D.reshape([-1, -1]), throwsArgumentError);
      expect(() => layout2D.reshape([-2, 3]), throwsArgumentError);
      expect(
        () => layout2D.reshape([-1, 4]),
        throwsArgumentError,
      ); // 6 % 4 != 0
      expect(
        () => layout2D.reshape([2, 4]),
        throwsArgumentError,
      ); // length mismatch

      final transposed = layout2D.transpose();
      expect(() => transposed.reshape([6]), throwsStateError); // non-contiguous

      // flip error
      expect(() => layout2D.flip(axis: 5), throwsRangeError);

      // broadcast error
      final incompatible = Layout(shape: [3, 2]);
      expect(() => layout2D.broadcast(incompatible), throwsArgumentError);

      // getRange errors
      expect(() => layout2D.getRange(axis: 5), throwsRangeError);
      expect(() => layout2D.getRange(axis: 0, step: 0), throwsArgumentError);
      expect(() => layout2D.getRange(axis: 0, start: -1), throwsRangeError);
      expect(() => layout2D.getRange(axis: 0, end: 10), throwsRangeError);
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

    test('reductions: sum, mean, min, max, var, std, norm', () {
      final a = Tensor<double>.fromIterable(
        [1.0, 2.0, 3.0, 4.0, 5.0, 6.0],
        shape: [2, 3],
      );

      final totalSum = a.sum();
      expect(totalSum.shape, <int>[]);
      expect(totalSum.getValue([]), 21.0);

      final totalSumKeep = a.sum(keepDims: true);
      expect(totalSumKeep.shape, [1, 1]);
      expect(totalSumKeep.getValue([0, 0]), 21.0);

      final rowSum = a.sum(axis: 0);
      expect(rowSum.shape, [3]);
      expect(rowSum.toFlatList(), [5.0, 7.0, 9.0]);

      final colSum = a.sum(axis: 1);
      expect(colSum.shape, [2]);
      expect(colSum.toFlatList(), [6.0, 15.0]);

      final negAxisSum = a.sum(axis: -1, keepDims: true);
      expect(negAxisSum.shape, [2, 1]);
      expect(negAxisSum.toFlatList(), [6.0, 15.0]);

      // Target with and without memory hazard
      final targetSum = Tensor<double>.filled(0.0, shape: [2]);
      a.sum(axis: 1, target: targetSum);
      expect(targetSum.toFlatList(), [6.0, 15.0]);

      final meanVal = a.mean();
      expect(meanVal.getValue([]), 3.5);
      final meanAxis = a.mean(axis: 0, keepDims: true);
      expect(meanAxis.shape, [1, 3]);
      expect(meanAxis.toFlatList(), [2.5, 3.5, 4.5]);

      final minVal = a.min();
      expect(minVal.getValue([]), 1.0);
      final minAxis = a.min(axis: 1, keepDims: true);
      expect(minAxis.shape, [2, 1]);
      expect(minAxis.toFlatList(), [1.0, 4.0]);

      final maxVal = a.max();
      expect(maxVal.getValue([]), 6.0);
      final maxAxis = a.max(axis: 0);
      expect(maxAxis.toFlatList(), [4.0, 5.0, 6.0]);

      // Variance and Standard Deviation
      final v = a.var_();
      expect(v.getValue([]), closeTo(35.0 / 12.0, 1e-4));
      final s = a.std();
      expect(s.getValue([]), closeTo(math.sqrt(35.0 / 12.0), 1e-4));

      final vAxis = a.var_(axis: 1, ddof: 1);
      expect(vAxis.shape, [2]);
      expect(vAxis.toFlatList(), [1.0, 1.0]);

      // Norms
      expect(a.norm(1), 21.0);
      expect(a.norm(2), closeTo(math.sqrt(91.0), 1e-6));
      expect(a.norm(3), closeTo(math.pow(441.0, 1.0 / 3.0), 1e-4));
      expect(a.norm(double.infinity), 6.0);

      final empty = Tensor<double>.fromIterable([]);
      expect(empty.norm(), 0.0);
      expect(empty.mean, throwsStateError);
      expect(empty.min, throwsStateError);
      expect(empty.max, throwsStateError);
      expect(() => a.var_(ddof: 6), throwsStateError);

      // Non-contiguous reduction (transposed tensor)
      final transposed = a.transpose();
      expect(transposed.layout.isContiguous, isFalse);
      expect(transposed.sum().getValue([]), 21.0);
      expect(transposed.sum(axis: 0).toFlatList(), [6.0, 15.0]);
    });

    test('argmin and argmax', () {
      final a = Tensor<int>.fromIterable([10, 5, 20, 15], shape: [4]);
      expect(a.argmin().getValue([]), 1);
      expect(a.argmax().getValue([]), 2);

      final m = Tensor<int>.fromIterable(
        [10, 20, 30, 5, 50, 15],
        shape: [2, 3],
      );

      final min0 = m.argmin(axis: 0);
      expect(min0.shape, [3]);
      expect(min0.toFlatList(), [1, 0, 1]);

      final max1 = m.argmax(axis: 1, keepDims: true);
      expect(max1.shape, [2, 1]);
      expect(max1.toFlatList(), [2, 1]);

      final maxNeg = m.argmax(axis: -1);
      expect(maxNeg.shape, [2]);
      expect(maxNeg.toFlatList(), [2, 1]);

      expect(() => m.argmin(axis: 5), throwsRangeError);
      expect(() => Tensor<int>.fromIterable([]).argmin(), throwsStateError);
    });

    test('unary and binary operations with hazards and target shapes', () {
      final a = Tensor<double>.fromIterable(
        [1.0, 2.0, 3.0, 4.0],
        shape: [2, 2],
      );
      final wrongTarget = Tensor<double>.filled(0.0, shape: [3]);
      expect(
        () => a.unaryOperation((x) => x, target: wrongTarget),
        throwsArgumentError,
      );

      // Binary operation with target
      final target = Tensor<double>.filled(0.0, shape: [2, 2]);
      a.binaryOperation(a, (x, y) => x + y, target: target);
      expect(target.toFlatList(), [2.0, 4.0, 6.0, 8.0]);

      // Broadcasting binary operation: [2, 1] + [1, 2] -> [2, 2]
      final col = Tensor<double>.fromIterable([10.0, 20.0], shape: [2, 1]);
      final row = Tensor<double>.fromIterable([1.0, 2.0], shape: [1, 2]);
      final broadcasted = col + row;
      expect(broadcasted.shape, [2, 2]);
      expect(broadcasted.toNestedList(), [
        [11.0, 12.0],
        [21.0, 22.0],
      ]);

      // In-place unary operation with hazard (transposed view into itself)
      final transposed = a.transpose();
      transposed.unaryOperation((x) => x * 2, target: transposed);
      expect(a.toFlatList(), [2.0, 4.0, 6.0, 8.0]);
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

    test('empty tensor creation from iterable and object', () {
      final empty1 = Tensor<int>.fromIterable([]);
      expect(empty1.length, 0);
      expect(empty1.shape, [0]);
      expect(empty1.toFlatList(), isEmpty);

      final empty2 = Tensor<int>.fromObject(<int>[]);
      expect(empty2.length, 0);
      expect(empty2.shape, [0]);
      expect(empty2.toFlatList(), isEmpty);

      expect(Layout.empty.length, 0);
      expect(Layout.empty.shape, [0]);
    });

    test('shifted overlapping slice copy does not corrupt memory', () {
      final a = Tensor<int>.fromIterable([1, 2, 3, 4, 5]);
      final src = a.getRange(axis: 0, start: 0, end: 4);
      final dst = a.getRange(axis: 0, start: 1, end: 5);

      src.copy(target: dst);
      expect(a.toFlatList(), [1, 1, 2, 3, 4]);
    });

    test('matmul into aliased operand target computes safely', () {
      final a = Tensor<double>.fromObject([
        [1.0, 2.0],
        [3.0, 4.0],
      ]);
      final b = Tensor<double>.fromObject([
        [2.0, 0.0],
        [1.0, 2.0],
      ]);
      final expected = a.matmul(b);

      a.matmul(b, target: a);
      expect(a.toFlatList(), expected.toFlatList());
    });
  });

  group('Tensor operations comprehensive suite', () {
    test('unary operations: abs, sqrt, exp, log, neg, non-contiguous, target & hazard', () {
      final a = Tensor<double>.fromIterable(
        [-1.0, 2.0, -3.0, 4.0],
        shape: [2, 2],
      );
      expect(a.abs().toFlatList(), [1.0, 2.0, 3.0, 4.0]);
      expect((-a).toFlatList(), [1.0, -2.0, 3.0, -4.0]);

      final pos = Tensor<double>.fromIterable(
        [1.0, math.e, math.e * math.e, 1.0],
        shape: [4],
      );
      expect(pos.log().toFlatList()[0], closeTo(0.0, 1e-6));
      expect(pos.log().toFlatList()[1], closeTo(1.0, 1e-6));
      expect(pos.log().toFlatList()[2], closeTo(2.0, 1e-6));

      final zeros = Tensor<double>.fromIterable([0.0, 1.0, 2.0], shape: [3]);
      expect(zeros.exp().toFlatList()[0], closeTo(1.0, 1e-6));
      expect(zeros.exp().toFlatList()[1], closeTo(math.e, 1e-6));

      // Non-contiguous unary operation without target
      final transposed = a.transpose();
      expect(transposed.layout.isContiguous, isFalse);
      expect(transposed.abs().toFlatList(), [1.0, 3.0, 2.0, 4.0]);

      // Unary operation with target
      final target = Tensor<double>.filled(0.0, shape: [2, 2]);
      a.unaryOperation((x) => x.abs(), target: target);
      expect(target.toFlatList(), [1.0, 2.0, 3.0, 4.0]);

      // Target shape mismatch throws
      final wrongTarget = Tensor<double>.filled(0.0, shape: [4]);
      expect(
        () => a.unaryOperation((x) => x.abs(), target: wrongTarget),
        throwsArgumentError,
      );

      // Non-contiguous target
      final targetNonContig = Tensor<double>.filled(
        0.0,
        shape: [2, 2],
      ).transpose();
      a.unaryOperation((x) => x.abs(), target: targetNonContig);
      expect(targetNonContig.toFlatList(), [1.0, 2.0, 3.0, 4.0]);

      // Memory hazard: unaryOperation into overlapping slice
      final slice = Tensor<double>.fromIterable([1.0, 2.0, 3.0, 4.0, 5.0]);
      final sSrc = slice.getRange(axis: 0, start: 0, end: 4);
      final sDst = slice.getRange(axis: 0, start: 1, end: 5);
      sSrc.unaryOperation((x) => x * 10, target: sDst);
      expect(slice.toFlatList(), [1.0, 10.0, 20.0, 30.0, 40.0]);
    });

    test('binary operations: arithmetic, comparisons, target & hazard', () {
      final a = Tensor<double>.fromIterable(
        [10.0, 20.0, 30.0, 40.0],
        shape: [2, 2],
      );
      final b = Tensor<double>.fromIterable(
        [1.0, 2.0, 3.0, 4.0],
        shape: [2, 2],
      );

      expect((a + b).toFlatList(), [11.0, 22.0, 33.0, 44.0]);
      expect((a - b).toFlatList(), [9.0, 18.0, 27.0, 36.0]);
      expect((a * b).toFlatList(), [10.0, 40.0, 90.0, 160.0]);
      expect((a / b).toFlatList(), [10.0, 10.0, 10.0, 10.0]);

      // Comparisons
      final c1 = Tensor<int>.fromIterable([1, 5, 3]);
      final c2 = Tensor<int>.fromIterable([2, 4, 3]);
      expect((c1 < c2).toFlatList(), [true, false, false]);
      expect((c1 <= c2).toFlatList(), [true, false, true]);
      expect((c1 > c2).toFlatList(), [false, true, false]);
      expect((c1 >= c2).toFlatList(), [false, true, true]);
      expect(c1.equalTo(c2).toFlatList(), [false, false, true]);

      // Fast contiguous path with target
      final targetContig = Tensor<double>.filled(0.0, shape: [2, 2]);
      a.binaryOperation<double, double>(
        b,
        (x, y) => x + y,
        target: targetContig,
      );
      expect(targetContig.toFlatList(), [11.0, 22.0, 33.0, 44.0]);

      // Broadcasting with non-hazard target
      final row = Tensor<double>.fromIterable([100.0, 200.0], shape: [1, 2]);
      final targetBroadcast = Tensor<double>.filled(0.0, shape: [2, 2]);
      a.binaryOperation<double, double>(
        row,
        (x, y) => x + y,
        target: targetBroadcast,
      );
      expect(targetBroadcast.toFlatList(), [110.0, 220.0, 130.0, 240.0]);

      // Broadcasting with memory hazard target
      final targetHazard = a;
      a.binaryOperation<double, double>(
        row,
        (x, y) => x + y,
        target: targetHazard,
      );
      expect(targetHazard.toFlatList(), [110.0, 220.0, 130.0, 240.0]);
    });

    test('logical operations on Tensor<bool>', () {
      final t1 = Tensor<bool>.fromIterable([true, true, false, false]);
      final t2 = Tensor<bool>.fromIterable([true, false, true, false]);

      expect((~t1).toFlatList(), [false, false, true, true]);
      expect((t1 & t2).toFlatList(), [true, false, false, false]);
      expect((t1 | t2).toFlatList(), [true, true, true, false]);
    });

    test('batched matmul and error cases', () {
      // 3D batched matmul
      final b1 = Tensor<double>.fromObject([
        [
          [1.0, 2.0],
          [3.0, 4.0],
        ],
        [
          [2.0, 0.0],
          [1.0, 2.0],
        ],
      ]);
      final b2 = Tensor<double>.fromObject([
        [
          [1.0, 0.0],
          [0.0, 1.0],
        ],
        [
          [0.5, 0.0],
          [0.0, 0.5],
        ],
      ]);
      final batchedResult = b1.matmul(b2);
      expect(batchedResult.shape, [2, 2, 2]);
      expect(batchedResult.toFlatList(), [
        1.0, 2.0, 3.0, 4.0, // identity product
        1.0, 0.0, 0.5, 1.0, // scaled product
      ]);

      // Batched broadcasting matmul [1, 2, 2] x [2, 2, 2] -> [2, 2, 2]
      final singleBatch = Tensor<double>.fromObject([
        [
          [1.0, 0.0],
          [0.0, 1.0],
        ],
      ]);
      final broadcastResult = singleBatch.matmul(b1);
      expect(broadcastResult.shape, [2, 2, 2]);
      expect(broadcastResult.toFlatList(), b1.toFlatList());

      // Batched matmul with hazard target
      final batchedHazard = b1.matmul(b2, target: b1);
      expect(batchedHazard.toFlatList(), batchedResult.toFlatList());

      // Error: rank < 2
      final vec1 = Tensor<double>.fromIterable([1.0, 2.0]);
      expect(() => vec1.matmul(b1), throwsArgumentError);

      // Error: inner dimensions mismatch
      final badK = Tensor<double>.filled(0.0, shape: [3, 2]);
      expect(() => b1.matmul(badK), throwsArgumentError);

      // Error: incompatible batch shapes
      final badBatchA = Tensor<double>.filled(0.0, shape: [2, 2, 2]);
      final badBatchB = Tensor<double>.filled(0.0, shape: [3, 2, 2]);
      expect(() => badBatchA.matmul(badBatchB), throwsArgumentError);

      // Float32List matmul
      final f32A = Tensor<double>.fromObject([
        [1.0, 2.0],
        [3.0, 4.0],
      ], type: DataType.float32);
      final f32B = Tensor<double>.fromObject([
        [2.0, 0.0],
        [1.0, 2.0],
      ], type: DataType.float32);
      final f32C = f32A.matmul(f32B);
      expect(f32C.toFlatList(), [4.0, 4.0, 10.0, 8.0]);

      // Integer matmul (pure Dart fallback loop)
      final intA = Tensor<int>.fromObject([
        [1, 2],
        [3, 4],
      ]);
      final intB = Tensor<int>.fromObject([
        [2, 0],
        [1, 2],
      ]);
      final intC = intA.matmul(intB);
      expect(intC.toFlatList(), [4, 4, 10, 8]);

      // Matmul target aliased with `other`
      final targetOther = intB.copy();
      final resTarget = intA.matmul(intB, target: targetOther);
      expect(resTarget.toFlatList(), [4, 4, 10, 8]);
    });

    test('Tensor manipulation errors and default branches', () {
      final t1 = Tensor<int>.fromIterable([1, 2], shape: [2]);
      final t2 = Tensor<int>.fromIterable([3, 4], shape: [2]);
      final t2d = Tensor<int>.fromObject([
        [1, 2],
        [3, 4],
      ]);

      // Concatenate errors
      expect(
        () => ManipulationTensorExtension.concatenateAll<int>([]),
        throwsArgumentError,
      );
      expect(
        () => ManipulationTensorExtension.concatenateAll([t1, t2], axis: 2),
        throwsRangeError,
      );
      expect(
        () => ManipulationTensorExtension.concatenateAll([t1, t2d]),
        throwsArgumentError,
      );
      final mismatch = Tensor<int>.fromObject([
        [1, 2, 3],
        [4, 5, 6],
      ]);
      expect(
        () => ManipulationTensorExtension.concatenateAll([
          t2d,
          mismatch,
        ], axis: 0),
        throwsArgumentError,
      );

      // Stack errors
      expect(
        () => ManipulationTensorExtension.stackAll<int>([]),
        throwsArgumentError,
      );
      expect(
        () => ManipulationTensorExtension.stackAll([t1, t2], axis: 3),
        throwsRangeError,
      );

      // Tile errors
      expect(() => t2d.tile([2]), throwsArgumentError);

      // Pad errors and default fill value
      expect(
        () => t2d.pad([
          [1, 1],
        ]),
        throwsArgumentError,
      );
      final padded = t1.pad([
        [1, 1],
      ]);
      expect(padded.toFlatList(), [0, 1, 2, 0]);
    });

    test('Tensor scalar fromObject, reshape non-contiguous, and toString', () {
      final scalar = Tensor<int>.fromObject(42);
      expect(scalar.rank, 0);
      expect(scalar.getValue([]), 42);

      expect(() => Tensor<int>.fromObject('not-a-number'), throwsArgumentError);

      // Non-contiguous reshape
      final t2d = Tensor<int>.fromObject([
        [1, 2],
        [3, 4],
      ]);
      final transposed = t2d.transpose();
      expect(transposed.layout.isContiguous, isFalse);
      final reshaped = transposed.reshape([4]);
      expect(reshaped.toFlatList(), [1, 3, 2, 4]);

      // toString
      expect(t2d.toString(), contains('Tensor('));
    });
  });
}
