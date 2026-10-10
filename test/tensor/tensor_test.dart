import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/tensor.dart';
import 'package:data/type.dart';
import 'package:test/test.dart';

void main() {
  group('Layout', () {
    test('1D contiguous layout', () {
      final layout = Layout(shape: [5]);
      check(layout.rank).equals(1);
      check(layout.shape).deepEquals([5]);
      check(layout.strides).deepEquals([1]);
      check(layout.length).equals(5);
      check(layout.isContiguous).isTrue();
      check(layout.toIndex([3])).equals(3);
      check(layout.toKey(3)).deepEquals([3]);
    });

    test('2D contiguous layout and indexing', () {
      final layout = Layout(shape: [2, 3]);
      check(layout.rank).equals(2);
      check(layout.strides).deepEquals([3, 1]);
      check(layout.length).equals(6);
      check(layout.isContiguous).isTrue();
      check(layout.toIndex([1, 2])).equals(5);
      check(layout.toKey(5)).deepEquals([1, 2]);
    });

    test('transposed layout is non-contiguous', () {
      final layout = Layout(shape: [2, 3]);
      final transposed = layout.transpose([1, 0]);
      check(transposed.shape).deepEquals([3, 2]);
      check(transposed.strides).deepEquals([1, 3]);
      check(transposed.isContiguous).isFalse();
      check(transposed.toIndex([2, 1])).equals(layout.toIndex([1, 2]));
    });

    test('reshape layout', () {
      final layout = Layout(shape: [2, 3]);
      final reshaped = layout.reshape([6]);
      check(reshaped.shape).deepEquals([6]);
      check(reshaped.strides).deepEquals([1]);
      check(reshaped.isContiguous).isTrue();
    });

    test('broadcast layout', () {
      final layout1 = Layout(shape: [1, 3]);
      final layout2 = Layout(shape: [4, 1]);
      final (b1, b2) = layout1.broadcast(layout2);
      check(b1.shape).deepEquals([4, 3]);
      check(b1.strides).deepEquals([0, 1]);
      check(b1.isContiguous).isFalse();
      check(b2.shape).deepEquals([4, 3]);
      check(b2.strides).deepEquals([1, 0]);
    });

    test('flip and slice layout', () {
      final layout = Layout(shape: [3, 4]);
      final flipped = layout.flip(axis: 0);
      check(flipped.shape).deepEquals([3, 4]);
      check(flipped.toIndex([0, 0])).equals(8);

      final sliced = layout.getRange(axis: 0, start: 1, end: 3);
      check(sliced.shape).deepEquals([2, 4]);
      check(sliced.toIndex([0, 0])).equals(4);
    });

    test('rank 0 scalar layout and toString', () {
      final scalarLayout = Layout(shape: []);
      check(scalarLayout.rank).equals(0);
      check(scalarLayout.length).equals(1);
      check(scalarLayout.keys.toList()).deepEquals([<int>[]]);
      check(scalarLayout.indices.toList()).deepEquals([0]);
      check(scalarLayout.toString()).contains('Layout(rank: 0');
    });

    test('layout error validations: toIndex, toKey, transpose, reshape, broadcast, getRange', () {
      final layout2D = Layout(shape: [2, 3]);

      // toIndex errors
      check(() => layout2D.toIndex([0])).throws<ArgumentError>();
      check(() => layout2D.toIndex([0, 5])).throws<RangeError>();
      check(() => layout2D.toIndex([-5, 0])).throws<RangeError>();

      // toKey error
      check(() => layout2D.toKey(-1)).throws<RangeError>();
      check(() => layout2D.toKey(10)).throws<RangeError>();

      // transpose error
      check(() => layout2D.transpose([0])).throws<ArgumentError>();

      // reshape errors and inference
      final inferred = layout2D.reshape([-1, 2]);
      check(inferred.shape).deepEquals([3, 2]);

      check(() => layout2D.reshape([-1, -1])).throws<ArgumentError>();
      check(() => layout2D.reshape([-2, 3])).throws<ArgumentError>();
      check(() => layout2D.reshape([-1, 4]))
          .throws<ArgumentError>(); // 6 % 4 != 0
      check(() => layout2D.reshape([2, 4]))
          .throws<ArgumentError>(); // length mismatch

      final transposed = layout2D.transpose();
      check(() => transposed.reshape([6]))
          .throws<StateError>(); // non-contiguous

      // flip error
      check(() => layout2D.flip(axis: 5)).throws<RangeError>();

      // broadcast error
      final incompatible = Layout(shape: [3, 2]);
      check(() => layout2D.broadcast(incompatible)).throws<ArgumentError>();

      // getRange errors
      check(() => layout2D.getRange(axis: 5)).throws<RangeError>();
      check(() => layout2D.getRange(axis: 0, step: 0)).throws<ArgumentError>();
      check(() => layout2D.getRange(axis: 0, start: -1)).throws<RangeError>();
      check(() => layout2D.getRange(axis: 0, end: 10)).throws<RangeError>();
    });
  });

  group('Tensor creation and indexing', () {
    test('filled', () {
      final tensor = Tensor<double>.filled(42.0, shape: [2, 2]);
      check(tensor.shape).deepEquals([2, 2]);
      check(tensor.length).equals(4);
      check(tensor.getValue([0, 0])).equals(42.0);
      check(tensor.getValue([1, 1])).equals(42.0);
    });

    test('generate', () {
      final tensor = Tensor<int>.generate(
        (key) => key[0] * 10 + key[1],
        shape: [2, 3],
        type: DataType.int32,
      );
      check(tensor.getValue([0, 0])).equals(0);
      check(tensor.getValue([0, 2])).equals(2);
      check(tensor.getValue([1, 0])).equals(10);
      check(tensor.getValue([1, 2])).equals(12);
    });

    test('fromIterable and fromObject', () {
      final t1 = Tensor<int>.fromIterable([1, 2, 3, 4], shape: [2, 2]);
      check(t1.shape).deepEquals([2, 2]);
      check(t1.getValue([1, 0])).equals(3);

      final t2 = Tensor<int>.fromObject([
        [1, 2],
        [3, 4],
      ]);
      check(t2.shape).deepEquals([2, 2]);
      check(t2.getValue([0, 1])).equals(2);
      check(t2.toNestedList() as List).deepEquals([
        [1, 2],
        [3, 4],
      ]);
    });

    test('slicing operator[]', () {
      final tensor = Tensor<int>.fromIterable(
        [1, 2, 3, 4, 5, 6],
        shape: [2, 3],
      );
      final row0 = tensor[0];
      check(row0.shape).deepEquals([3]);
      check(row0.getValue([0])).equals(1);
      check(row0.getValue([2])).equals(3);

      final row1 = tensor[1];
      check(row1.shape).deepEquals([3]);
      check(row1.getValue([0])).equals(4);
      check(row1.getValue([2])).equals(6);
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
      check(sum.toFlatList()).deepEquals([11.0, 22.0, 33.0, 44.0]);

      final diff = b - a;
      check(diff.toFlatList()).deepEquals([9.0, 18.0, 27.0, 36.0]);

      final prod = a * b;
      check(prod.toFlatList()).deepEquals([10.0, 40.0, 90.0, 160.0]);

      final div = b / a;
      check(div.toFlatList()).deepEquals([10.0, 10.0, 10.0, 10.0]);
    });

    test('broadcasting operations', () {
      final a = Tensor<double>.fromIterable(
        [1.0, 2.0, 3.0, 4.0],
        shape: [2, 2],
      );
      final row = Tensor<double>.fromIterable([10.0, 20.0], shape: [1, 2]);

      final res = a + row;
      check(res.shape).deepEquals([2, 2]);
      check(res.toFlatList()).deepEquals([11.0, 22.0, 13.0, 24.0]);
    });

    test('element-wise unary operations', () {
      final a = Tensor<double>.fromIterable([1.0, 4.0, 9.0, 16.0], shape: [4]);
      check(a.sqrt().toFlatList()).deepEquals([1.0, 2.0, 3.0, 4.0]);
      check((-a).toFlatList()).deepEquals([-1.0, -4.0, -9.0, -16.0]);
    });

    test('reductions: sum, mean, min, max, var, std, norm', () {
      final a = Tensor<double>.fromIterable(
        [1.0, 2.0, 3.0, 4.0, 5.0, 6.0],
        shape: [2, 3],
      );

      final totalSum = a.sum();
      check(totalSum.shape).deepEquals(<int>[]);
      check(totalSum.getValue([])).equals(21.0);

      final totalSumKeep = a.sum(keepDims: true);
      check(totalSumKeep.shape).deepEquals([1, 1]);
      check(totalSumKeep.getValue([0, 0])).equals(21.0);

      final rowSum = a.sum(axis: 0);
      check(rowSum.shape).deepEquals([3]);
      check(rowSum.toFlatList()).deepEquals([5.0, 7.0, 9.0]);

      final colSum = a.sum(axis: 1);
      check(colSum.shape).deepEquals([2]);
      check(colSum.toFlatList()).deepEquals([6.0, 15.0]);

      final negAxisSum = a.sum(axis: -1, keepDims: true);
      check(negAxisSum.shape).deepEquals([2, 1]);
      check(negAxisSum.toFlatList()).deepEquals([6.0, 15.0]);

      // Target with and without memory hazard
      final targetSum = Tensor<double>.filled(0.0, shape: [2]);
      a.sum(axis: 1, target: targetSum);
      check(targetSum.toFlatList()).deepEquals([6.0, 15.0]);

      final meanVal = a.mean();
      check(meanVal.getValue([])).equals(3.5);
      final meanAxis = a.mean(axis: 0, keepDims: true);
      check(meanAxis.shape).deepEquals([1, 3]);
      check(meanAxis.toFlatList()).deepEquals([2.5, 3.5, 4.5]);

      final minVal = a.min();
      check(minVal.getValue([])).equals(1.0);
      final minAxis = a.min(axis: 1, keepDims: true);
      check(minAxis.shape).deepEquals([2, 1]);
      check(minAxis.toFlatList()).deepEquals([1.0, 4.0]);

      final maxVal = a.max();
      check(maxVal.getValue([])).equals(6.0);
      final maxAxis = a.max(axis: 0);
      check(maxAxis.toFlatList()).deepEquals([4.0, 5.0, 6.0]);

      // Variance and Standard Deviation
      final variance = a.var_();
      check(variance.getValue([])).isCloseTo(35.0 / 12.0, 1e-4);
      final stdDev = a.std();
      check(stdDev.getValue([])).isCloseTo(math.sqrt(35.0 / 12.0), 1e-4);

      final vAxis = a.var_(axis: 1, ddof: 1);
      check(vAxis.shape).deepEquals([2]);
      check(vAxis.toFlatList()).deepEquals([1.0, 1.0]);

      // Norms
      check(a.norm(1)).equals(21.0);
      check(a.norm(2)).isCloseTo(math.sqrt(91.0), 1e-6);
      check(a.norm(3)).isCloseTo(math.pow(441.0, 1.0 / 3.0), 1e-4);
      check(a.norm(double.infinity)).equals(6.0);

      final empty = Tensor<double>.fromIterable([]);
      check(empty.norm()).equals(0.0);
      check(empty.mean).throws<StateError>();
      check(empty.min).throws<StateError>();
      check(empty.max).throws<StateError>();
      check(() => a.var_(ddof: 6)).throws<StateError>();

      // Non-contiguous reduction (transposed tensor)
      final transposed = a.transpose();
      check(transposed.layout.isContiguous).isFalse();
      check(transposed.sum().getValue([])).equals(21.0);
      check(transposed.sum(axis: 0).toFlatList()).deepEquals([6.0, 15.0]);
    });

    test('argmin and argmax', () {
      final a = Tensor<int>.fromIterable([10, 5, 20, 15], shape: [4]);
      check(a.argmin().getValue([])).equals(1);
      check(a.argmax().getValue([])).equals(2);

      final m = Tensor<int>.fromIterable(
        [10, 20, 30, 5, 50, 15],
        shape: [2, 3],
      );

      final min0 = m.argmin(axis: 0);
      check(min0.shape).deepEquals([3]);
      check(min0.toFlatList()).deepEquals([1, 0, 1]);

      final max1 = m.argmax(axis: 1, keepDims: true);
      check(max1.shape).deepEquals([2, 1]);
      check(max1.toFlatList()).deepEquals([2, 1]);

      final maxNeg = m.argmax(axis: -1);
      check(maxNeg.shape).deepEquals([2]);
      check(maxNeg.toFlatList()).deepEquals([2, 1]);

      check(() => m.argmin(axis: 5)).throws<RangeError>();
      check(() => Tensor<int>.fromIterable([]).argmin()).throws<StateError>();
    });

    test('unary and binary operations with hazards and target shapes', () {
      final a = Tensor<double>.fromIterable(
        [1.0, 2.0, 3.0, 4.0],
        shape: [2, 2],
      );
      final wrongTarget = Tensor<double>.filled(0.0, shape: [3]);
      check(() => a.unaryOperation((x) => x, target: wrongTarget))
          .throws<ArgumentError>();

      // Binary operation with target
      final target = Tensor<double>.filled(0.0, shape: [2, 2]);
      a.binaryOperation(a, (x, y) => x + y, target: target);
      check(target.toFlatList()).deepEquals([2.0, 4.0, 6.0, 8.0]);

      // Broadcasting binary operation: [2, 1] + [1, 2] -> [2, 2]
      final col = Tensor<double>.fromIterable([10.0, 20.0], shape: [2, 1]);
      final row = Tensor<double>.fromIterable([1.0, 2.0], shape: [1, 2]);
      final broadcasted = col + row;
      check(broadcasted.shape).deepEquals([2, 2]);
      check(broadcasted.toNestedList() as List).deepEquals([
        [11.0, 12.0],
        [21.0, 22.0],
      ]);

      // In-place unary operation with hazard (transposed view into itself)
      final transposed = a.transpose();
      transposed.unaryOperation((x) => x * 2, target: transposed);
      check(a.toFlatList()).deepEquals([2.0, 4.0, 6.0, 8.0]);
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

      final product = a.matmul(b);
      check(product.shape).deepEquals([2, 2]);
      check(product.toNestedList() as List).deepEquals([
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

      final product = a.matmul(b);
      check(product.shape).deepEquals([2, 2, 2]);
      check(product.toNestedList() as List).deepEquals([
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
      check(concat0.shape).deepEquals([2, 2]);
      check(concat0.toNestedList() as List).deepEquals([
        [1, 2],
        [3, 4],
      ]);

      final concat1 = a.concatenate(b, axis: 1);
      check(concat1.shape).deepEquals([1, 4]);
      check(concat1.toNestedList() as List).deepEquals([
        [1, 2, 3, 4],
      ]);
    });

    test('stack', () {
      final a = Tensor<int>.fromIterable([1, 2], shape: [2]);
      final b = Tensor<int>.fromIterable([3, 4], shape: [2]);

      final stacked = a.stack(b, axis: 0);
      check(stacked.shape).deepEquals([2, 2]);
      check(stacked.toNestedList() as List).deepEquals([
        [1, 2],
        [3, 4],
      ]);
    });

    test('tile', () {
      final a = Tensor<int>.fromIterable([1, 2, 3, 4], shape: [2, 2]);
      final tiled = a.tile([2, 1]);
      check(tiled.shape).deepEquals([4, 2]);
      check(tiled.toNestedList() as List).deepEquals([
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
      check(padded.shape).deepEquals([4, 4]);
      check(padded.toNestedList() as List).deepEquals([
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
      check(row0.sharesMemoryWith(a)).isTrue();

      // Binary operation between row0 and a does not corrupt results due to aliasing
      final result = a + row0;
      check(result.shape).deepEquals([2, 2]);
      check(result.toFlatList()).deepEquals([2.0, 4.0, 4.0, 6.0]);
    });

    test('empty tensor creation from iterable and object', () {
      final empty1 = Tensor<int>.fromIterable([]);
      check(empty1.length).equals(0);
      check(empty1.shape).deepEquals([0]);
      check(empty1.toFlatList()).isEmpty();

      final empty2 = Tensor<int>.fromObject(<int>[]);
      check(empty2.length).equals(0);
      check(empty2.shape).deepEquals([0]);
      check(empty2.toFlatList()).isEmpty();

      check(Layout.empty.length).equals(0);
      check(Layout.empty.shape).deepEquals([0]);
    });

    test('shifted overlapping slice copy does not corrupt memory', () {
      final a = Tensor<int>.fromIterable([1, 2, 3, 4, 5]);
      final src = a.getRange(axis: 0, start: 0, end: 4);
      final dst = a.getRange(axis: 0, start: 1, end: 5);

      src.copy(target: dst);
      check(a.toFlatList()).deepEquals([1, 1, 2, 3, 4]);
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
      check(a.toFlatList()).deepEquals(expected.toFlatList());
    });
  });

  group('Tensor operations comprehensive suite', () {
    test('unary operations: abs, sqrt, exp, log, neg, non-contiguous, target & hazard', () {
      final a = Tensor<double>.fromIterable(
        [-1.0, 2.0, -3.0, 4.0],
        shape: [2, 2],
      );
      check(a.abs().toFlatList()).deepEquals([1.0, 2.0, 3.0, 4.0]);
      check((-a).toFlatList()).deepEquals([1.0, -2.0, 3.0, -4.0]);

      final pos = Tensor<double>.fromIterable(
        [1.0, math.e, math.e * math.e, 1.0],
        shape: [4],
      );
      check(pos.log().toFlatList()[0]).isCloseTo(0.0, 1e-6);
      check(pos.log().toFlatList()[1]).isCloseTo(1.0, 1e-6);
      check(pos.log().toFlatList()[2]).isCloseTo(2.0, 1e-6);

      final zeros = Tensor<double>.fromIterable([0.0, 1.0, 2.0], shape: [3]);
      check(zeros.exp().toFlatList()[0]).isCloseTo(1.0, 1e-6);
      check(zeros.exp().toFlatList()[1]).isCloseTo(math.e, 1e-6);

      // Non-contiguous unary operation without target
      final transposed = a.transpose();
      check(transposed.layout.isContiguous).isFalse();
      check(transposed.abs().toFlatList()).deepEquals([1.0, 3.0, 2.0, 4.0]);

      // Unary operation with target
      final target = Tensor<double>.filled(0.0, shape: [2, 2]);
      a.unaryOperation((x) => x.abs(), target: target);
      check(target.toFlatList()).deepEquals([1.0, 2.0, 3.0, 4.0]);

      // Target shape mismatch throws
      final wrongTarget = Tensor<double>.filled(0.0, shape: [4]);
      check(() => a.unaryOperation((x) => x.abs(), target: wrongTarget))
          .throws<ArgumentError>();

      // Non-contiguous target
      final targetNonContig = Tensor<double>.filled(
        0.0,
        shape: [2, 2],
      ).transpose();
      a.unaryOperation((x) => x.abs(), target: targetNonContig);
      check(targetNonContig.toFlatList()).deepEquals([1.0, 2.0, 3.0, 4.0]);

      // Memory hazard: unaryOperation into overlapping slice
      final slice = Tensor<double>.fromIterable([1.0, 2.0, 3.0, 4.0, 5.0]);
      final sSrc = slice.getRange(axis: 0, start: 0, end: 4);
      final sDst = slice.getRange(axis: 0, start: 1, end: 5);
      sSrc.unaryOperation((x) => x * 10, target: sDst);
      check(slice.toFlatList()).deepEquals([1.0, 10.0, 20.0, 30.0, 40.0]);
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

      check((a + b).toFlatList()).deepEquals([11.0, 22.0, 33.0, 44.0]);
      check((a - b).toFlatList()).deepEquals([9.0, 18.0, 27.0, 36.0]);
      check((a * b).toFlatList()).deepEquals([10.0, 40.0, 90.0, 160.0]);
      check((a / b).toFlatList()).deepEquals([10.0, 10.0, 10.0, 10.0]);

      // Comparisons
      final c1 = Tensor<int>.fromIterable([1, 5, 3]);
      final c2 = Tensor<int>.fromIterable([2, 4, 3]);
      check((c1 < c2).toFlatList()).deepEquals([true, false, false]);
      check((c1 <= c2).toFlatList()).deepEquals([true, false, true]);
      check((c1 > c2).toFlatList()).deepEquals([false, true, false]);
      check((c1 >= c2).toFlatList()).deepEquals([false, true, true]);
      check(c1.equalTo(c2).toFlatList()).deepEquals([false, false, true]);

      // Fast contiguous path with target
      final targetContig = Tensor<double>.filled(0.0, shape: [2, 2]);
      a.binaryOperation<double, double>(
        b,
        (x, y) => x + y,
        target: targetContig,
      );
      check(targetContig.toFlatList()).deepEquals([11.0, 22.0, 33.0, 44.0]);

      // Broadcasting with non-hazard target
      final row = Tensor<double>.fromIterable([100.0, 200.0], shape: [1, 2]);
      final targetBroadcast = Tensor<double>.filled(0.0, shape: [2, 2]);
      a.binaryOperation<double, double>(
        row,
        (x, y) => x + y,
        target: targetBroadcast,
      );
      check(targetBroadcast.toFlatList())
          .deepEquals([110.0, 220.0, 130.0, 240.0]);

      // Broadcasting with memory hazard target
      final targetHazard = a;
      a.binaryOperation<double, double>(
        row,
        (x, y) => x + y,
        target: targetHazard,
      );
      check(targetHazard.toFlatList()).deepEquals([110.0, 220.0, 130.0, 240.0]);
    });

    test('logical operations on Tensor<bool>', () {
      final t1 = Tensor<bool>.fromIterable([true, true, false, false]);
      final t2 = Tensor<bool>.fromIterable([true, false, true, false]);

      check((~t1).toFlatList()).deepEquals([false, false, true, true]);
      check((t1 & t2).toFlatList()).deepEquals([true, false, false, false]);
      check((t1 | t2).toFlatList()).deepEquals([true, true, true, false]);
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
      check(batchedResult.shape).deepEquals([2, 2, 2]);
      check(batchedResult.toFlatList()).deepEquals([
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
      check(broadcastResult.shape).deepEquals([2, 2, 2]);
      check(broadcastResult.toFlatList()).deepEquals(b1.toFlatList());

      // Batched matmul with hazard target
      final batchedHazard = b1.matmul(b2, target: b1);
      check(batchedHazard.toFlatList()).deepEquals(batchedResult.toFlatList());

      // Error: rank < 2
      final vec1 = Tensor<double>.fromIterable([1.0, 2.0]);
      check(() => vec1.matmul(b1)).throws<ArgumentError>();

      // Error: inner dimensions mismatch
      final badK = Tensor<double>.filled(0.0, shape: [3, 2]);
      check(() => b1.matmul(badK)).throws<ArgumentError>();

      // Error: incompatible batch shapes
      final badBatchA = Tensor<double>.filled(0.0, shape: [2, 2, 2]);
      final badBatchB = Tensor<double>.filled(0.0, shape: [3, 2, 2]);
      check(() => badBatchA.matmul(badBatchB)).throws<ArgumentError>();

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
      check(f32C.toFlatList()).deepEquals([4.0, 4.0, 10.0, 8.0]);

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
      check(intC.toFlatList()).deepEquals([4, 4, 10, 8]);

      // Matmul target aliased with `other`
      final targetOther = intB.copy();
      final resTarget = intA.matmul(intB, target: targetOther);
      check(resTarget.toFlatList()).deepEquals([4, 4, 10, 8]);
    });

    test('Tensor manipulation errors and default branches', () {
      final t1 = Tensor<int>.fromIterable([1, 2], shape: [2]);
      final t2 = Tensor<int>.fromIterable([3, 4], shape: [2]);
      final t2d = Tensor<int>.fromObject([
        [1, 2],
        [3, 4],
      ]);

      // Concatenate errors
      check(() => ManipulationTensorExtension.concatenateAll<int>([]))
          .throws<ArgumentError>();
      check(() => ManipulationTensorExtension.concatenateAll([t1, t2], axis: 2))
          .throws<RangeError>();
      check(() => ManipulationTensorExtension.concatenateAll([t1, t2d]))
          .throws<ArgumentError>();
      final mismatch = Tensor<int>.fromObject([
        [1, 2, 3],
        [4, 5, 6],
      ]);
      check(
        () => ManipulationTensorExtension.concatenateAll([
          t2d,
          mismatch,
        ], axis: 0),
      ).throws<ArgumentError>();

      // Stack errors
      check(() => ManipulationTensorExtension.stackAll<int>([]))
          .throws<ArgumentError>();
      check(() => ManipulationTensorExtension.stackAll([t1, t2], axis: 3))
          .throws<RangeError>();

      // Tile errors
      check(() => t2d.tile([2])).throws<ArgumentError>();

      // Pad errors and default fill value
      check(
        () => t2d.pad([
          [1, 1],
        ]),
      ).throws<ArgumentError>();
      final padded = t1.pad([
        [1, 1],
      ]);
      check(padded.toFlatList()).deepEquals([0, 1, 2, 0]);
    });

    test('Tensor scalar fromObject, reshape non-contiguous, and toString', () {
      final scalar = Tensor<int>.fromObject(42);
      check(scalar.rank).equals(0);
      check(scalar.getValue([])).equals(42);

      check(() => Tensor<int>.fromObject('not-a-number'))
          .throws<ArgumentError>();

      // Non-contiguous reshape
      final t2d = Tensor<int>.fromObject([
        [1, 2],
        [3, 4],
      ]);
      final transposed = t2d.transpose();
      check(transposed.layout.isContiguous).isFalse();
      final reshaped = transposed.reshape([4]);
      check(reshaped.toFlatList()).deepEquals([1, 3, 2, 4]);

      // toString
      check(t2d.toString()).contains('Tensor(');
    });
  });
}
