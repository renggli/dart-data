import 'package:checks/checks.dart';
import 'package:data/tensor.dart';
import 'package:test/test.dart';

void main() {
  group('Slice', () {
    test('defaults and Slice.all', () {
      const slice = Slice();
      check(slice.start).isNull();
      check(slice.end).isNull();
      check(slice.step).equals(1);

      check(Slice.all.start).isNull();
      check(Slice.all.end).isNull();
      check(Slice.all.step).equals(1);
      check(Slice.all).equals(const Slice());
    });

    test('custom start, end, and step', () {
      const slice = Slice(2, 8, 2);
      check(slice.start).equals(2);
      check(slice.end).equals(8);
      check(slice.step).equals(2);
      check(slice.toString()).equals('Slice(2, 8, 2)');
    });

    test('equality and hashCode', () {
      const s1 = Slice(1, 5, 2);
      const s2 = Slice(1, 5, 2);
      const s3 = Slice(1, 5, 1);
      check(s1).equals(s2);
      check(s1.hashCode).equals(s2.hashCode);
      check(s1 == s3).isFalse();
    });

    test('zero step assertion/exception', () {
      check(() => Slice(0, 5, 0)).throws<AssertionError>();
      final layout = Layout(shape: [5]);
      // Also verify Layout.slice throws ArgumentError when step is 0
      check(() => layout.slice([const Slice(0, 2, 1), const Slice(0, 2, 1)]))
          .throws<ArgumentError>();
    });
  });

  group('Layout.slice', () {
    test('1D strided slicing and isContiguous', () {
      final layout = Layout(shape: [10]);
      final sub = layout.slice(const [Slice(2, 8, 2)]);
      check(sub.shape).deepEquals([3]);
      check(sub.strides).deepEquals([2]);
      check(sub.offset).equals(2);
      check(sub.length).equals(3);
      check(sub.isContiguous).isFalse();
      check(sub.indices.toList()).deepEquals([2, 4, 6]);
    });

    test('1D contiguous sub-slice', () {
      final layout = Layout(shape: [10]);
      final sub = layout.slice(const [Slice(2, 7, 1)]);
      check(sub.shape).deepEquals([5]);
      check(sub.strides).deepEquals([1]);
      check(sub.offset).equals(2);
      check(sub.isContiguous).isTrue();
      check(sub.indices.toList()).deepEquals([2, 3, 4, 5, 6]);
    });

    test('1D full reversal with negative step', () {
      final layout = Layout(shape: [5]);
      final rev = layout.slice(const [Slice(null, null, -1)]);
      check(rev.shape).deepEquals([5]);
      check(rev.strides).deepEquals([-1]);
      check(rev.offset).equals(4);
      check(rev.length).equals(5);
      check(rev.isContiguous).isFalse();
      check(rev.indices.toList()).deepEquals([4, 3, 2, 1, 0]);
    });

    test('1D partial negative step slicing', () {
      final layout = Layout(shape: [5]);
      // [4, 2] -> indices 4, 2
      final sub = layout.slice(const [Slice(4, 1, -2)]);
      check(sub.shape).deepEquals([2]);
      check(sub.strides).deepEquals([-2]);
      check(sub.offset).equals(4);
      check(sub.indices.toList()).deepEquals([4, 2]);
    });

    test('negative indices relative to dimension length', () {
      final layout = Layout(shape: [10]);
      // -7 -> 3, -2 -> 8, step 2 -> indices 3, 5, 7
      final sub = layout.slice(const [Slice(-7, -2, 2)]);
      check(sub.shape).deepEquals([3]);
      check(sub.offset).equals(3);
      check(sub.indices.toList()).deepEquals([3, 5, 7]);
    });

    test('negative indices with negative step', () {
      final layout = Layout(shape: [5]);
      // -2 -> 3, -5 -> 0, step -1 -> indices 3, 2, 1
      final sub = layout.slice(const [Slice(-2, -5, -1)]);
      check(sub.shape).deepEquals([3]);
      check(sub.offset).equals(3);
      check(sub.indices.toList()).deepEquals([3, 2, 1]);
    });

    test('clamping of out-of-bounds indices', () {
      final layout = Layout(shape: [5]);
      // Clamped to [0, 5) -> all 5 elements
      final subPos = layout.slice(const [Slice(-100, 100, 1)]);
      check(subPos.shape).deepEquals([5]);
      check(subPos.offset).equals(0);
      check(subPos.indices.toList()).deepEquals([0, 1, 2, 3, 4]);

      // Negative step clamped from high to low -> all 5 elements reversed
      final subNeg = layout.slice(const [Slice(100, -100, -1)]);
      check(subNeg.shape).deepEquals([5]);
      check(subNeg.offset).equals(4);
      check(subNeg.indices.toList()).deepEquals([4, 3, 2, 1, 0]);
    });

    test('empty slices produce zero length', () {
      final layout = Layout(shape: [5]);
      final emptyPos = layout.slice(const [Slice(4, 2, 1)]);
      check(emptyPos.shape).deepEquals([0]);
      check(emptyPos.length).equals(0);
      check(emptyPos.indices.toList()).isEmpty();

      final emptyNeg = layout.slice(const [Slice(2, 4, -1)]);
      check(emptyNeg.shape).deepEquals([0]);
      check(emptyNeg.length).equals(0);
      check(emptyNeg.indices.toList()).isEmpty();
    });

    test('omitted trailing slices default to Slice.all', () {
      final layout = Layout(shape: [3, 4]);
      final sub = layout.slice(const [Slice(1, 3)]);
      check(sub.shape).deepEquals([2, 4]);
      check(sub.strides).deepEquals([4, 1]);
      check(sub.offset).equals(4);
      check(sub.isContiguous).isTrue();
    });

    test('0-rank scalar slicing', () {
      final scalar = Layout(shape: const []);
      final sliced = scalar.slice(const []);
      check(sliced.rank).equals(0);
      check(sliced.length).equals(1);

      check(() => scalar.slice(const [Slice.all])).throws<ArgumentError>();
    });

    test('too many slices throws ArgumentError', () {
      final layout = Layout(shape: [2, 3]);
      check(() => layout.slice(const [Slice.all, Slice.all, Slice.all]))
          .throws<ArgumentError>();
    });
  });

  group('Tensor.slice', () {
    test('multi-axis strided slice', () {
      final tensor = Tensor<int>.fromObject([
        [0, 1, 2, 3, 4],
        [5, 6, 7, 8, 9],
        [10, 11, 12, 13, 14],
        [15, 16, 17, 18, 19],
      ]);
      // Rows: 0..4 step 2 -> rows 0, 2
      // Cols: 1..5 step 2 -> cols 1, 3
      final sliced = tensor.slice(const [Slice(0, 4, 2), Slice(1, 5, 2)]);
      check(sliced.shape).deepEquals([2, 2]);
      check(sliced.toNestedList() as List).deepEquals([
        [1, 3],
        [11, 13],
      ]);
    });

    test('multi-axis negative step and Slice.all', () {
      final tensor = Tensor<int>.fromObject([
        [1, 2, 3],
        [4, 5, 6],
      ]);
      // Reverse rows, keep columns
      final revRows = tensor.slice(const [Slice(null, null, -1), Slice.all]);
      check(revRows.toNestedList() as List).deepEquals([
        [4, 5, 6],
        [1, 2, 3],
      ]);

      // Keep rows, reverse columns
      final revCols = tensor.slice(const [Slice.all, Slice(null, null, -1)]);
      check(revCols.toNestedList() as List).deepEquals([
        [3, 2, 1],
        [6, 5, 4],
      ]);

      // Reverse both
      final revBoth = tensor.slice(const [
        Slice(null, null, -1),
        Slice(null, null, -1),
      ]);
      check(revBoth.toNestedList() as List).deepEquals([
        [6, 5, 4],
        [3, 2, 1],
      ]);
    });

    test('zero-copy view mutation propagates to original tensor', () {
      final tensor = Tensor<int>.fromObject([
        [1, 2, 3],
        [4, 5, 6],
        [7, 8, 9],
      ]);
      final sub = tensor.slice(const [Slice(1, 3), Slice(1, 3)]);
      check(sub.sharesMemoryWith(tensor)).isTrue();
      check(sub.toNestedList() as List).deepEquals([
        [5, 6],
        [8, 9],
      ]);

      // Modify sub-view
      sub.setValue([0, 0], 99);
      // Original at [1, 1] should reflect the change
      check(tensor.getValue([1, 1])).equals(99);
      check(tensor.toNestedList() as List).deepEquals([
        [1, 2, 3],
        [4, 99, 6],
        [7, 8, 9],
      ]);
    });

    test('zero-copy negative step view mutation', () {
      final tensor = Tensor.fromIterable([10, 20, 30, 40, 50]);
      final rev = tensor.slice(const [Slice(null, null, -1)]);
      check(rev.sharesMemoryWith(tensor)).isTrue();
      check(rev.toFlatList()).deepEquals([50, 40, 30, 20, 10]);

      // Modify element at index 0 of reversed view (which corresponds to index
      // 4 of original)
      rev.setValue([0], 999);
      check(tensor.getValue([4])).equals(999);
      check(rev.toFlatList()).deepEquals([999, 40, 30, 20, 10]);
    });
  });

  group('Tensor.split', () {
    test('equal parts split along axis 0', () {
      final tensor = Tensor<int>.fromObject([
        [1, 2],
        [3, 4],
        [5, 6],
        [7, 8],
      ]);
      final parts = tensor.split(2, axis: 0);
      check(parts.length).equals(2);
      check(parts[0].shape).deepEquals([2, 2]);
      check(parts[0].toNestedList() as List).deepEquals([
        [1, 2],
        [3, 4],
      ]);
      check(parts[1].shape).deepEquals([2, 2]);
      check(parts[1].toNestedList() as List).deepEquals([
        [5, 6],
        [7, 8],
      ]);

      // Zero-copy verification
      check(parts[0].sharesMemoryWith(tensor)).isTrue();
      parts[0].setValue([0, 0], 100);
      check(tensor.getValue([0, 0])).equals(100);
    });

    test('equal parts split along axis 1 and negative axis', () {
      final tensor = Tensor<int>.fromObject([
        [1, 2, 3, 4],
        [5, 6, 7, 8],
      ]);
      final parts = tensor.split(2, axis: 1);
      check(parts.length).equals(2);
      check(parts[0].shape).deepEquals([2, 2]);
      check(parts[0].toNestedList() as List).deepEquals([
        [1, 2],
        [5, 6],
      ]);
      check(parts[1].shape).deepEquals([2, 2]);
      check(parts[1].toNestedList() as List).deepEquals([
        [3, 4],
        [7, 8],
      ]);

      final partsNeg = tensor.split(2, axis: -1);
      check(partsNeg.length).equals(2);
      check(partsNeg[0].toNestedList() as List).deepEquals([
        [1, 2],
        [5, 6],
      ]);
    });

    test('single part split returns view of entire tensor', () {
      final tensor = Tensor.fromIterable([1, 2, 3]);
      final parts = tensor.split(1);
      check(parts.length).equals(1);
      check(parts[0].toFlatList()).deepEquals([1, 2, 3]);
      check(parts[0].sharesMemoryWith(tensor)).isTrue();
    });

    test('split error validation: non-positive parts, uneven dimension, axis out of bounds', () {
      final tensor = Tensor<int>.fromObject([
        [1, 2, 3],
        [4, 5, 6],
      ]);
      // Non-positive parts
      check(() => tensor.split(0)).throws<ArgumentError>();
      check(() => tensor.split(-1)).throws<ArgumentError>();

      // Uneven split
      check(() => tensor.split(3, axis: 0)).throws<ArgumentError>();
      check(() => tensor.split(2, axis: 1)).throws<ArgumentError>();

      // Axis out of bounds
      check(() => tensor.split(2, axis: 2)).throws<RangeError>();
      check(() => tensor.split(2, axis: -3)).throws<RangeError>();
    });
  });

  group('Tensor.splitWithSizes', () {
    test('exact partitions along axis 0', () {
      final tensor = Tensor.fromIterable([10, 20, 30, 40, 50, 60]);
      final parts = tensor.splitWithSizes([1, 3, 2]);
      check(parts.length).equals(3);
      check(parts[0].toFlatList()).deepEquals([10]);
      check(parts[1].toFlatList()).deepEquals([20, 30, 40]);
      check(parts[2].toFlatList()).deepEquals([50, 60]);

      // Zero-copy verification
      check(parts[1].sharesMemoryWith(tensor)).isTrue();
      parts[1].setValue([0], 999);
      check(tensor.getValue([1])).equals(999);
    });

    test('exact partitions along axis 1 with zero-size partition', () {
      final tensor = Tensor<int>.fromObject([
        [1, 2, 3, 4],
        [5, 6, 7, 8],
      ]);
      final parts = tensor.splitWithSizes([2, 0, 2], axis: 1);
      check(parts.length).equals(3);
      check(parts[0].shape).deepEquals([2, 2]);
      check(parts[0].toNestedList() as List).deepEquals([
        [1, 2],
        [5, 6],
      ]);
      check(parts[1].shape).deepEquals([2, 0]);
      check(parts[2].shape).deepEquals([2, 2]);
      check(parts[2].toNestedList() as List).deepEquals([
        [3, 4],
        [7, 8],
      ]);
    });

    test('negative axis normalization', () {
      final tensor = Tensor<int>.fromObject([
        [1, 2, 3],
        [4, 5, 6],
      ]);
      final parts = tensor.splitWithSizes([2, 1], axis: -1);
      check(parts.length).equals(2);
      check(parts[0].toNestedList() as List).deepEquals([
        [1, 2],
        [4, 5],
      ]);
      check(parts[1].toNestedList() as List).deepEquals([
        [3],
        [6],
      ]);
    });

    test('splitWithSizes error validation: negative sizes, sum mismatch, axis out of bounds', () {
      final tensor = Tensor.fromIterable([1, 2, 3, 4, 5]);

      // Negative size
      check(() => tensor.splitWithSizes([3, -1, 3])).throws<ArgumentError>();

      // Sum mismatch: too small or too large
      check(() => tensor.splitWithSizes([2, 2])).throws<ArgumentError>();
      check(() => tensor.splitWithSizes([2, 4])).throws<ArgumentError>();

      // Axis out of bounds
      check(() => tensor.splitWithSizes([5], axis: 1)).throws<RangeError>();
      check(() => tensor.splitWithSizes([5], axis: -2)).throws<RangeError>();
    });

    test(
      'split and splitWithSizes on 4D tensor along internal and negative axes',
      () {
        final tensor = Tensor<int>.fromIterable(
          List.generate(2 * 3 * 4 * 5, (i) => i),
          shape: [2, 3, 4, 5],
        );

        // Split along axis 2 (dim size 4) into 2 parts of shape [2, 3, 2, 5]
        final splitParts = tensor.split(2, axis: 2);
        check(splitParts.length).equals(2);
        check(splitParts[0].shape).deepEquals([2, 3, 2, 5]);
        check(splitParts[1].shape).deepEquals([2, 3, 2, 5]);
        check(splitParts[0].getValue([0, 0, 0, 0])).equals(0);
        check(splitParts[1].getValue([0, 0, 0, 0])).equals(10); // 2 * 5

        // Split along axis -1 (dim size 5) with splitSizes [2, 1, 2]
        final sizeParts = tensor.splitWithSizes([2, 1, 2], axis: -1);
        check(sizeParts.length).equals(3);
        check(sizeParts[0].shape).deepEquals([2, 3, 4, 2]);
        check(sizeParts[1].shape).deepEquals([2, 3, 4, 1]);
        check(sizeParts[2].shape).deepEquals([2, 3, 4, 2]);
        check(sizeParts[1].getValue([0, 0, 0, 0])).equals(2);
        check(sizeParts[2].getValue([0, 0, 0, 0])).equals(3);
      },
    );
  });

  group('Advanced multi-axis strided slicing', () {
    test(
      '4D multi-axis strided slicing with mixed positive and negative strides',
      () {
        // Shape: [2, 3, 4, 5] = 120 elements
        final tensor = Tensor<int>.fromIterable(
          List.generate(120, (i) => i),
          shape: [2, 3, 4, 5],
        );

        // Slices:
        // Axis 0: reverse [Slice(null, null, -1)] -> indices [1, 0] (len 2)
        // Axis 1: step 2 [Slice(0, 3, 2)] -> indices [0, 2] (len 2)
        // Axis 2: sub-range step 2 [Slice(1, 4, 2)] -> indices [1, 3] (len 2)
        // Axis 3: reverse step -2 [Slice(null, null, -2)] -> indices [4, 2, 0]
        // (len 3)
        final sliced = tensor.slice(const [
          Slice(null, null, -1),
          Slice(0, 3, 2),
          Slice(1, 4, 2),
          Slice(null, null, -2),
        ]);

        check(sliced.shape).deepEquals([2, 2, 2, 3]);
        check(sliced.rank).equals(4);
        check(sliced.length).equals(24);
        check(sliced.isContiguous).isFalse();

        // Check specific element coordinates:
        // sliced[0, 0, 0, 0] -> tensor[1, 0, 1, 4]:
        // 1*60 + 0*20 + 1*5 + 4 = 69
        check(sliced.getValue([0, 0, 0, 0])).equals(69);

        // sliced[1, 1, 1, 2] -> tensor[0, 2, 3, 0]:
        // 0*60 + 2*20 + 3*5 + 0 = 55
        check(sliced.getValue([1, 1, 1, 2])).equals(55);

        // Zero-copy mutation check
        sliced.setValue([0, 0, 0, 0], 9999);
        check(tensor.getValue([1, 0, 1, 4])).equals(9999);
      },
    );

    test('chained slicing correctly composes offsets and strides', () {
      final tensor = Tensor<int>.fromIterable(
        List.generate(20, (i) => i),
        shape: [4, 5],
      );

      // First slice: rows 1..4 (len 3), cols 1..5 step 2 (len 2: cols 1, 3)
      final s1 = tensor.slice(const [Slice(1, 4), Slice(1, 5, 2)]);
      check(s1.shape).deepEquals([3, 2]);
      // s1 rows: [ [6, 8], [11, 13], [16, 18] ]

      // Second slice: reverse rows, take col 1
      final s2 = s1.slice(const [Slice(null, null, -1), Slice(1, 2)]);
      check(s2.shape).deepEquals([3, 1]);
      check(s2.toFlatList()).deepEquals([18, 13, 8]);

      // Third slice: reverse again (should restore ascending order 8, 13, 18)
      final s3 = s2.slice(const [Slice(null, null, -1)]);
      check(s3.shape).deepEquals([3, 1]);
      check(s3.toFlatList()).deepEquals([8, 13, 18]);

      // Zero-copy verification through 3 levels of slicing
      s3.setValue([1, 0], -77);
      check(tensor.getValue([2, 3])).equals(-77);
    });

    test(
      'slicing transposed layout preserves zero-copy coordinate mapping',
      () {
        final tensor = Tensor<int>.fromIterable(
          List.generate(6, (i) => i),
          shape: [2, 3],
        );
        // [[0, 1, 2], [3, 4, 5]]
        // Transpose -> [[0, 3], [1, 4], [2, 5]] shape [3, 2]
        final transposed = tensor.transpose();
        check(transposed.shape).deepEquals([3, 2]);

        // Slice rows 1..3, reverse cols -> rows [ [1, 4], [2, 5] ] reversed
        // cols -> [ [4, 1], [5, 2] ]
        final sliced = transposed.slice(const [
          Slice(1, 3),
          Slice(null, null, -1),
        ]);
        check(sliced.shape).deepEquals([2, 2]);
        check(sliced.toNestedList() as List).deepEquals([
          [4, 1],
          [5, 2],
        ]);

        // Mutation propagates to original tensor
        sliced.setValue([0, 0], 44);
        check(tensor.getValue([1, 1])).equals(44);
      },
    );

    test(
      'multi-dimensional empty slice produces 0 length and empty indices',
      () {
        final tensor = Tensor<int>.fromIterable(
          List.generate(24, (i) => i),
          shape: [2, 3, 4],
        );
        // Empty slice on axis 1
        final empty = tensor.slice(const [Slice.all, Slice(2, 2), Slice.all]);
        check(empty.shape).deepEquals([2, 0, 4]);
        check(empty.length).equals(0);
        check(empty.layout.indices.toList()).isEmpty();
        check(empty.toNestedList() as List).deepEquals([[], []]);
      },
    );

    test('stackAll, pad, and tile validation errors', () {
      final t1 = Tensor<int>.fromIterable([1, 2, 3], shape: [3]);
      final t2 = Tensor<int>.fromIterable([1, 2, 3, 4], shape: [4]);
      check(() => ManipulationTensorExtension.stackAll([t1, t2]))
          .throws<ArgumentError>();

      check(() => t1.tile([-1])).throws<ArgumentError>();
      check(t1.tile([0]).shape).deepEquals([0]);

      check(
        () => t1.pad([
          [1],
        ]),
      ).throws<ArgumentError>();
      check(
        () => t1.pad([
          [1, 2, 3],
        ]),
      ).throws<ArgumentError>();
      check(
        () => t1.pad([
          [-1, 1],
        ]),
      ).throws<ArgumentError>();
      check(
        () => t1.pad([
          [1, -1],
        ]),
      ).throws<ArgumentError>();
    });
  });
}
