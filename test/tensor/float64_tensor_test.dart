import 'dart:typed_data';

import 'package:checks/checks.dart';
import 'package:data/acceleration.dart';
import 'package:data/tensor.dart';
import 'package:data/type.dart';
import 'package:test/test.dart';

void main() {
  group('Float64Tensor', () {
    test('filled constructor', () {
      final t = Float64Tensor.filled(3.5, shape: [2, 3]);
      check(t.shape).deepEquals([2, 3]);
      check(t.length).equals(6);
      check(t.asTypedList).isA<Float64List>();
      check(t.asTypedList).deepEquals([3.5, 3.5, 3.5, 3.5, 3.5, 3.5]);
      check(t.get2D(0, 0)).equals(3.5);
      check(t.get2D(1, 2)).equals(3.5);
    });

    test('generate constructor', () {
      final t = Float64Tensor.generate(
        (key) => (key[0] * 3 + key[1]).toDouble(),
        shape: [2, 3],
      );
      check(t.asTypedList).deepEquals([0.0, 1.0, 2.0, 3.0, 4.0, 5.0]);
      check(t.get2D(1, 1)).equals(4.0);
    });

    test('fromIterable constructor', () {
      final t = Float64Tensor.fromIterable([1.0, 2.0, 3.0, 4.0], shape: [4]);
      check(t.length).equals(4);
      check(t.get1D(2)).equals(3.0);
      t.set1D(2, 42.0);
      check(t.get1D(2)).equals(42.0);
      check(t.asTypedList[2]).equals(42.0);
    });

    test('get2D and set2D fast access', () {
      final t = Float64Tensor.filled(0.0, shape: [2, 2]);
      t.set2D(0, 1, 7.5);
      t.set2D(1, 0, -2.5);
      check(t.get2D(0, 1)).equals(7.5);
      check(t.get2D(1, 0)).equals(-2.5);
      check(t.asTypedList[1]).equals(7.5);
      check(t.asTypedList[2]).equals(-2.5);
    });

    test('reshape and transpose', () {
      final t = Float64Tensor.generate(
        (key) => (key[0] * 3 + key[1]).toDouble(),
        shape: [2, 3],
      );
      final r = t.reshape([3, 2]);
      check(r.shape).deepEquals([3, 2]);
      check(r.get2D(0, 0)).equals(0.0);
      check(r.get2D(1, 0)).equals(2.0);

      final tr = t.transpose([1, 0]);
      check(tr.shape).deepEquals([3, 2]);
      check(tr.get2D(0, 1)).equals(3.0);
    });

    test('contiguous vectorized arithmetic operators', () {
      final a = Float64Tensor.fromIterable([1.0, 2.0, 3.0, 4.0], shape: [2, 2]);
      final b = Float64Tensor.fromIterable(
        [10.0, 20.0, 30.0, 40.0],
        shape: [2, 2],
      );

      final sum = a + b;
      check(sum.asTypedList).deepEquals([11.0, 22.0, 33.0, 44.0]);

      final diff = b - a;
      check(diff.asTypedList).deepEquals([9.0, 18.0, 27.0, 36.0]);

      final prod = a * b;
      check(prod.asTypedList).deepEquals([10.0, 40.0, 90.0, 160.0]);

      final div = b / a;
      check(div.asTypedList).deepEquals([10.0, 10.0, 10.0, 10.0]);

      final neg = -a;
      check(neg.asTypedList).deepEquals([-1.0, -2.0, -3.0, -4.0]);

      final scaled = a.scale(2.5);
      check(scaled.asTypedList).deepEquals([2.5, 5.0, 7.5, 10.0]);
    });

    test('non-contiguous arithmetic fallback', () {
      final a = Float64Tensor.generate(
        (key) => (key[0] * 2 + key[1]).toDouble(),
        shape: [2, 2],
      ).transpose([1, 0]);
      final b = Float64Tensor.filled(1.0, shape: [2, 2]);

      final resSum = a + b;
      check(resSum.shape).deepEquals([2, 2]);
      check(resSum.getValue([0, 1])).equals(3.0);

      final resDiff = a - b;
      check(resDiff.getValue([0, 1])).equals(1.0);

      final resProd = a * b;
      check(resProd.getValue([0, 1])).equals(2.0);

      final resDiv = a / b;
      check(resDiv.getValue([0, 1])).equals(2.0);

      final resNeg = -a;
      check(resNeg.getValue([0, 1])).equals(-2.0);

      final resScale = a.scale(3.0);
      check(resScale.getValue([0, 1])).equals(6.0);
    });

    test('pure Dart fallback execution mode', () {
      final prev = AccelerationManager.mode;
      try {
        AccelerationManager.mode = AccelerationMode.dart;
        final a = Float64Tensor.fromIterable(
          [1.0, 2.0, 3.0, 4.0],
          shape: [2, 2],
        );
        final b = Float64Tensor.fromIterable(
          [10.0, 20.0, 30.0, 40.0],
          shape: [2, 2],
        );

        check((a + b).asTypedList).deepEquals([11.0, 22.0, 33.0, 44.0]);
        check((b - a).asTypedList).deepEquals([9.0, 18.0, 27.0, 36.0]);
        check((a * b).asTypedList).deepEquals([10.0, 40.0, 90.0, 160.0]);
        check((b / a).asTypedList).deepEquals([10.0, 10.0, 10.0, 10.0]);
        check((-a).asTypedList).deepEquals([-1.0, -2.0, -3.0, -4.0]);
        check(a.scale(2.5).asTypedList).deepEquals([2.5, 5.0, 7.5, 10.0]);
      } finally {
        AccelerationManager.mode = prev;
      }
    });

    test(
      'constructor rejects non-Float64List backing and fromDoubleTensor copies',
      () {
        final f32Tensor = Tensor<double>.filled(
          1.0,
          shape: [2, 2],
          type: DataType.float32,
        );
        check(() => Float64Tensor(f32Tensor)).throws<ArgumentError>();

        final copied = Float64Tensor.fromDoubleTensor(f32Tensor);
        check(copied.shape).deepEquals([2, 2]);
        check(copied.asTypedList).isA<Float64List>();
        check(copied.asTypedList).deepEquals([1.0, 1.0, 1.0, 1.0]);
        copied.set2D(0, 0, 42.0);
        check(copied.get2D(0, 0)).equals(42.0);
        check(f32Tensor.getValue([0, 0])).equals(1.0);

        // View/sliced non-Float64List tensor copies only the view
        final largeF32 = Tensor<double>.fromIterable(
          [1.0, 2.0, 3.0, 4.0, 5.0, 6.0],
          shape: [2, 3],
          type: DataType.float32,
        );
        final slicedF32 = largeF32[1]; // shape: [3], offset: 3, length: 3
        final copiedSlice = Float64Tensor.fromDoubleTensor(slicedF32);
        check(copiedSlice.shape).deepEquals([3]);
        check(copiedSlice.length).equals(3);
        check(copiedSlice.asTypedList.length).equals(3);
        check(copiedSlice.asTypedList).deepEquals([4.0, 5.0, 6.0]);
      },
    );

    test('arithmetic with non-Float64List contiguous operand', () {
      final a = Float64Tensor.fromIterable([10.0, 20.0, 30.0], shape: [3]);
      final b = Tensor<double>.fromIterable(
        [2.0, 4.0, 5.0],
        shape: [3],
        type: DataType.float32,
      );

      check((a + b).asTypedList).deepEquals([12.0, 24.0, 35.0]);
      check((a - b).asTypedList).deepEquals([8.0, 16.0, 25.0]);
      check((a * b).asTypedList).deepEquals([20.0, 80.0, 150.0]);
      check((a / b).asTypedList).deepEquals([5.0, 5.0, 6.0]);
    });

    test('fromObject and redeclared view methods return Float64Tensor', () {
      final t = Float64Tensor.fromObject([
        [1.0, 2.0, 3.0],
        [4.0, 5.0, 6.0],
      ]);
      check(t.shape).deepEquals([2, 3]);
      check(t.asTypedList).deepEquals([1.0, 2.0, 3.0, 4.0, 5.0, 6.0]);

      final row0 = t[0];
      check(row0.asTypedList).identicalTo(t.asTypedList);
      check(row0.toFlatList()).deepEquals([1.0, 2.0, 3.0]);

      final flipped = t.flip(axis: 0);
      check(flipped.asTypedList).identicalTo(t.asTypedList);
      check(flipped.toFlatList()).deepEquals([4.0, 5.0, 6.0, 1.0, 2.0, 3.0]);

      final range = t.getRange(axis: 1, start: 1, end: 3);
      check(range.asTypedList).identicalTo(t.asTypedList);
      check(range.toFlatList()).deepEquals([2.0, 3.0, 5.0, 6.0]);

      final sliced = t.slice(const [Slice.all, Slice(0, 2)]);
      check(sliced.asTypedList).identicalTo(t.asTypedList);
      check(sliced.toFlatList()).deepEquals([1.0, 2.0, 4.0, 5.0]);

      final copied = t[1].copy();
      check(copied.offset).equals(0);
      check(copied.asTypedList).deepEquals([4.0, 5.0, 6.0]);
    });
  });
}
