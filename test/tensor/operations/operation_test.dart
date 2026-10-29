import 'dart:typed_data';

import 'package:checks/checks.dart';
import 'package:data/tensor.dart';
import 'package:data/type.dart';
import 'package:test/test.dart';

void main() {
  group('Tensor.unaryOperation target validation', () {
    test('target with matching shape succeeds (contiguous and strided)', () {
      final tensor = Tensor<int>.fromIterable(
        [1, 2, 3, 4, 5, 6],
        shape: [2, 3],
        type: DataType.int32,
      );

      final targetContig = Tensor<int>.filled(
        0,
        shape: [2, 3],
        type: DataType.int32,
      );
      final result1 = tensor.unaryOperation(
        (x) => x * 10,
        target: targetContig,
      );
      check(result1).identicalTo(targetContig);
      check(targetContig.toFlatList()).deepEquals([10, 20, 30, 40, 50, 60]);

      final targetStrided = Tensor<int>.filled(
        0,
        shape: [3, 2],
        type: DataType.int32,
      ).transpose();
      check(targetStrided.shape).deepEquals([2, 3]);
      check(targetStrided.isContiguous).isFalse();
      final result2 = tensor.unaryOperation(
        (x) => x + 1,
        target: targetStrided,
      );
      check(result2).identicalTo(targetStrided);
      check(targetStrided.toFlatList()).deepEquals([2, 3, 4, 5, 6, 7]);
    });

    test('target with mismatched rank throws ArgumentError', () {
      final tensor = Tensor<int>.fromIterable(
        [1, 2, 3, 4, 5, 6],
        shape: [2, 3],
        type: DataType.int32,
      );

      final target1D = Tensor<int>.filled(0, shape: [6], type: DataType.int32);
      check(() => tensor.unaryOperation((x) => x * 2, target: target1D))
          .throws<ArgumentError>();

      final target3D = Tensor<int>.filled(
        0,
        shape: [1, 2, 3],
        type: DataType.int32,
      );
      check(() => tensor.unaryOperation((x) => x * 2, target: target3D))
          .throws<ArgumentError>();
    });

    test('target with matching rank but mismatched dimension sizes throws ArgumentError', () {
      final tensor = Tensor<int>.fromIterable(
        [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12],
        shape: [3, 4],
        type: DataType.int32,
      );

      // Same total length (12), matching rank (2), but mismatched dimensions
      // [2, 6]
      final targetSameLen = Tensor<int>.filled(
        0,
        shape: [2, 6],
        type: DataType.int32,
      );
      check(() => tensor.unaryOperation((x) => x * 2, target: targetSameLen))
          .throws<ArgumentError>();

      // Same total length (12), matching rank (2), transposed dimensions [4, 3]
      final targetTransposedShape = Tensor<int>.filled(
        0,
        shape: [4, 3],
        type: DataType.int32,
      );
      check(
        () =>
            tensor.unaryOperation((x) => x * 2, target: targetTransposedShape),
      ).throws<ArgumentError>();

      // Different length, same rank [3, 3]
      final targetDifferentLen = Tensor<int>.filled(
        0,
        shape: [3, 3],
        type: DataType.int32,
      );
      check(
        () => tensor.unaryOperation((x) => x * 2, target: targetDifferentLen),
      ).throws<ArgumentError>();
    });

    test('target validation with 0-rank and 3D tensors', () {
      final scalar = Tensor<int>.filled(
        42,
        shape: const [],
        type: DataType.int32,
      );
      final scalarTarget = Tensor<int>.filled(
        0,
        shape: const [],
        type: DataType.int32,
      );
      scalar.unaryOperation((x) => x + 1, target: scalarTarget);
      check(scalarTarget.toFlatList()).deepEquals([43]);

      final invalidScalarTarget = Tensor<int>.filled(
        0,
        shape: const [1],
        type: DataType.int32,
      );
      check(
        () => scalar.unaryOperation((x) => x + 1, target: invalidScalarTarget),
      ).throws<ArgumentError>();

      final tensor3D = Tensor<int>.filled(
        1,
        shape: [2, 3, 4],
        type: DataType.int32,
      );
      final invalid3D = Tensor<int>.filled(
        0,
        shape: [2, 4, 3],
        type: DataType.int32,
      );
      check(() => tensor3D.unaryOperation((x) => x + 1, target: invalid3D))
          .throws<ArgumentError>();
    });
  });

  group('Tensor.binaryOperation contiguous fast-path target validation', () {
    test('contiguous operands with matching shape target succeed', () {
      final a = Tensor<int>.fromIterable(
        [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12],
        shape: [3, 4],
        type: DataType.int32,
      );
      final b = Tensor<int>.fromIterable(
        [10, 20, 30, 40, 50, 60, 70, 80, 90, 100, 110, 120],
        shape: [3, 4],
        type: DataType.int32,
      );

      final target = Tensor<int>.filled(0, shape: [3, 4], type: DataType.int32);
      final result = a.binaryOperation(b, (x, y) => x + y, target: target);
      check(result).identicalTo(target);
      check(target.toFlatList())
          .deepEquals([11, 22, 33, 44, 55, 66, 77, 88, 99, 110, 121, 132]);
    });

    test(
      'contiguous operands with mismatched rank target throw ArgumentError',
      () {
        final a = Tensor<int>.filled(1, shape: [3, 4], type: DataType.int32);
        final b = Tensor<int>.filled(2, shape: [3, 4], type: DataType.int32);

        final target1D = Tensor<int>.filled(
          0,
          shape: [12],
          type: DataType.int32,
        );
        check(() => a.binaryOperation(b, (x, y) => x + y, target: target1D))
            .throws<ArgumentError>();

        final target3D = Tensor<int>.filled(
          0,
          shape: [1, 3, 4],
          type: DataType.int32,
        );
        check(() => a.binaryOperation(b, (x, y) => x + y, target: target3D))
            .throws<ArgumentError>();
      },
    );

    test('contiguous operands with matching rank but mismatched dimension sizes throw ArgumentError', () {
      final a = Tensor<int>.filled(1, shape: [3, 4], type: DataType.int32);
      final b = Tensor<int>.filled(2, shape: [3, 4], type: DataType.int32);

      // Same total length (12), matching rank (2), mismatched dimension sizes
      // [2, 6]
      final target2x6 = Tensor<int>.filled(
        0,
        shape: [2, 6],
        type: DataType.int32,
      );
      check(() => a.binaryOperation(b, (x, y) => x + y, target: target2x6))
          .throws<ArgumentError>();

      // Same total length (12), swapped dimensions [4, 3]
      final target4x3 = Tensor<int>.filled(
        0,
        shape: [4, 3],
        type: DataType.int32,
      );
      check(() => a.binaryOperation(b, (x, y) => x + y, target: target4x3))
          .throws<ArgumentError>();

      // Different length, same rank [3, 5]
      final target3x5 = Tensor<int>.filled(
        0,
        shape: [3, 5],
        type: DataType.int32,
      );
      check(() => a.binaryOperation(b, (x, y) => x + y, target: target3x5))
          .throws<ArgumentError>();
    });
  });

  group('Tensor.binaryOperation broadcasting target validation', () {
    test('broadcasted operation with matching target shape succeeds', () {
      final col = Tensor<int>.fromIterable(
        [10, 20],
        shape: [2, 1],
        type: DataType.int32,
      );
      final row = Tensor<int>.fromIterable(
        [1, 2, 3],
        shape: [1, 3],
        type: DataType.int32,
      );

      final target = Tensor<int>.filled(0, shape: [2, 3], type: DataType.int32);
      final result = col.binaryOperation(row, (x, y) => x + y, target: target);
      check(result).identicalTo(target);
      check(target.toFlatList()).deepEquals([11, 12, 13, 21, 22, 23]);
    });

    test('broadcasted operation targeting an operand shape throws ArgumentError', () {
      final col = Tensor<int>.fromIterable(
        [10, 20],
        shape: [2, 1],
        type: DataType.int32,
      );
      final row = Tensor<int>.fromIterable(
        [1, 2, 3],
        shape: [1, 3],
        type: DataType.int32,
      );

      // Target matching left operand [2, 1] instead of broadcast shape [2, 3]
      final targetCol = Tensor<int>.filled(
        0,
        shape: [2, 1],
        type: DataType.int32,
      );
      check(() => col.binaryOperation(row, (x, y) => x + y, target: targetCol))
          .throws<ArgumentError>();

      // Target matching right operand [1, 3] instead of broadcast shape [2, 3]
      final targetRow = Tensor<int>.filled(
        0,
        shape: [1, 3],
        type: DataType.int32,
      );
      check(() => col.binaryOperation(row, (x, y) => x + y, target: targetRow))
          .throws<ArgumentError>();
    });

    test('broadcasted operation with same length but mismatched dimensions throws ArgumentError', () {
      final col = Tensor<int>.fromIterable(
        [10, 20],
        shape: [2, 1],
        type: DataType.int32,
      );
      final row = Tensor<int>.fromIterable(
        [1, 2, 3],
        shape: [1, 3],
        type: DataType.int32,
      );

      // Total length 6, rank 2, but shape [3, 2] instead of [2, 3]
      final target3x2 = Tensor<int>.filled(
        0,
        shape: [3, 2],
        type: DataType.int32,
      );
      check(() => col.binaryOperation(row, (x, y) => x + y, target: target3x2))
          .throws<ArgumentError>();

      // Flattened [6] instead of [2, 3]
      final targetFlat = Tensor<int>.filled(
        0,
        shape: [6],
        type: DataType.int32,
      );
      check(() => col.binaryOperation(row, (x, y) => x + y, target: targetFlat))
          .throws<ArgumentError>();
    });

    test('broadcasting with rank expansion and target shape validation', () {
      final matrix = Tensor<int>.fromIterable(
        [1, 2, 3, 4, 5, 6],
        shape: [2, 3],
        type: DataType.int32,
      );
      final vector = Tensor<int>.fromIterable(
        [10, 20, 30],
        shape: [3],
        type: DataType.int32,
      );

      // Output shape is [2, 3]
      final validTarget = Tensor<int>.filled(
        0,
        shape: [2, 3],
        type: DataType.int32,
      );
      matrix.binaryOperation(vector, (x, y) => x + y, target: validTarget);
      check(validTarget.toFlatList()).deepEquals([11, 22, 33, 14, 25, 36]);

      // Target with rank-1 shape [3] matching vector must throw ArgumentError
      final invalidTargetRank1 = Tensor<int>.filled(
        0,
        shape: [3],
        type: DataType.int32,
      );
      check(
        () => matrix.binaryOperation(
          vector,
          (x, y) => x + y,
          target: invalidTargetRank1,
        ),
      ).throws<ArgumentError>();

      // Target with rank-2 shape [3, 2] must throw ArgumentError
      final invalidTargetSwapped = Tensor<int>.filled(
        0,
        shape: [3, 2],
        type: DataType.int32,
      );
      check(
        () => matrix.binaryOperation(
          vector,
          (x, y) => x + y,
          target: invalidTargetSwapped,
        ),
      ).throws<ArgumentError>();
    });

    test('non-contiguous target with matching shape executes correctly', () {
      final col = Tensor<int>.fromIterable(
        [10, 20],
        shape: [2, 1],
        type: DataType.int32,
      );
      final row = Tensor<int>.fromIterable(
        [1, 2, 3],
        shape: [1, 3],
        type: DataType.int32,
      );

      // Transposed [3, 2] -> shape is [2, 3], non-contiguous
      final nonContigTarget = Tensor<int>.filled(
        0,
        shape: [3, 2],
        type: DataType.int32,
      ).transpose();
      check(nonContigTarget.shape).deepEquals([2, 3]);
      check(nonContigTarget.isContiguous).isFalse();

      col.binaryOperation(row, (x, y) => x + y, target: nonContigTarget);
      check(nonContigTarget.toFlatList()).deepEquals([11, 12, 13, 21, 22, 23]);
    });

    test('slice target with non-zero offset', () {
      final buffer = Tensor<int>.filled(0, shape: [4, 3], type: DataType.int32);
      // Slice rows 1..3 -> shape [2, 3], offset != 0
      final sliceTarget = buffer.getRange(axis: 0, start: 1, end: 3);
      check(sliceTarget.shape).deepEquals([2, 3]);
      check(sliceTarget.layout.offset).equals(3);

      final col = Tensor<int>.fromIterable(
        [10, 20],
        shape: [2, 1],
        type: DataType.int32,
      );
      final row = Tensor<int>.fromIterable(
        [1, 2, 3],
        shape: [1, 3],
        type: DataType.int32,
      );

      col.binaryOperation(row, (x, y) => x + y, target: sliceTarget);
      check(sliceTarget.toFlatList()).deepEquals([11, 12, 13, 21, 22, 23]);
      check(buffer.toFlatList())
          .deepEquals([0, 0, 0, 11, 12, 13, 21, 22, 23, 0, 0, 0]);
    });

    test('contiguous operands with non-zero offset slice target (fast-path eligible)', () {
      final a = Tensor<int>.fromIterable(
        [1, 2, 3, 4, 5, 6],
        shape: [2, 3],
        type: DataType.int32,
      );
      final b = Tensor<int>.fromIterable(
        [10, 20, 30, 40, 50, 60],
        shape: [2, 3],
        type: DataType.int32,
      );

      final buffer = Tensor<int>.filled(0, shape: [4, 3], type: DataType.int32);
      final sliceTarget = buffer.getRange(axis: 0, start: 1, end: 3);
      check(sliceTarget.isContiguous).isTrue();
      check(sliceTarget.layout.offset).equals(3);

      final result = a.binaryOperation(b, (x, y) => x + y, target: sliceTarget);
      check(result).identicalTo(sliceTarget);
      check(sliceTarget.toFlatList()).deepEquals([11, 22, 33, 44, 55, 66]);
      check(buffer.toFlatList())
          .deepEquals([0, 0, 0, 11, 22, 33, 44, 55, 66, 0, 0, 0]);
    });

    test('in-place binary operation on contiguous non-zero offset slice', () {
      final buffer = Tensor<int>.fromIterable(
        [0, 0, 0, 1, 2, 3, 4, 5, 6, 0, 0, 0],
        shape: [4, 3],
        type: DataType.int32,
      );
      final slice = buffer.getRange(axis: 0, start: 1, end: 3);
      check(slice.layout.offset).equals(3);
      check(slice.isContiguous).isTrue();

      final other = Tensor<int>.fromIterable(
        [10, 20, 30, 40, 50, 60],
        shape: [2, 3],
        type: DataType.int32,
      );

      final result = slice.binaryOperation(
        other,
        (x, y) => x + y,
        target: slice,
      );
      check(result).identicalTo(slice);
      check(slice.toFlatList()).deepEquals([11, 22, 33, 44, 55, 66]);
      check(buffer.toFlatList())
          .deepEquals([0, 0, 0, 11, 22, 33, 44, 55, 66, 0, 0, 0]);
    });

    test('non-contiguous operands with matching shape but mismatched target throw ArgumentError', () {
      final a = Tensor<int>.fromIterable(
        [1, 2, 3, 4, 5, 6],
        shape: [2, 3],
        type: DataType.int32,
      ).transpose();
      final b = Tensor<int>.fromIterable(
        [10, 20, 30, 40, 50, 60],
        shape: [2, 3],
        type: DataType.int32,
      ).transpose();
      check(a.shape).deepEquals([3, 2]);
      check(b.shape).deepEquals([3, 2]);
      check(a.isContiguous).isFalse();

      // Mismatched target shape [2, 3] instead of [3, 2]
      final wrongTarget = Tensor<int>.filled(
        0,
        shape: [2, 3],
        type: DataType.int32,
      );
      check(() => a.binaryOperation(b, (x, y) => x + y, target: wrongTarget))
          .throws<ArgumentError>();
    });

    test('non-contiguous unary operation with mismatched target throws ArgumentError', () {
      final a = Tensor<int>.fromIterable(
        [1, 2, 3, 4, 5, 6],
        shape: [2, 3],
        type: DataType.int32,
      ).transpose();
      check(a.shape).deepEquals([3, 2]);
      check(a.isContiguous).isFalse();

      final wrongTarget = Tensor<int>.filled(
        0,
        shape: [2, 3],
        type: DataType.int32,
      );
      check(() => a.unaryOperation((x) => x * 2, target: wrongTarget))
          .throws<ArgumentError>();
    });

    test('empty / 0-dimension tensor shape validation', () {
      final a = Tensor<int>.filled(0, shape: [0, 2], type: DataType.int32);
      final b = Tensor<int>.filled(0, shape: [0, 2], type: DataType.int32);

      // Same total length (0), same rank (2), mismatched dimension size [0, 3]
      final wrongTarget = Tensor<int>.filled(
        0,
        shape: [0, 3],
        type: DataType.int32,
      );

      check(() => a.unaryOperation((x) => x + 1, target: wrongTarget))
          .throws<ArgumentError>();
      check(() => a.binaryOperation(b, (x, y) => x + y, target: wrongTarget))
          .throws<ArgumentError>();

      // Matching empty target shape [0, 2] succeeds
      final validTarget = Tensor<int>.filled(
        0,
        shape: [0, 2],
        type: DataType.int32,
      );
      final unaryResult = a.unaryOperation((x) => x + 1, target: validTarget);
      check(unaryResult.shape).deepEquals([0, 2]);
      check(unaryResult.layout.length).equals(0);

      final binaryResult = a.binaryOperation(
        b,
        (x, y) => x + y,
        target: validTarget,
      );
      check(binaryResult.shape).deepEquals([0, 2]);
      check(binaryResult.layout.length).equals(0);
    });

    test('Tensor.copy target shape validation', () {
      final tensor = Tensor<int>.fromIterable(
        [1, 2, 3, 4, 5, 6],
        shape: [2, 3],
        type: DataType.int32,
      );

      final wrongTarget = Tensor<int>.filled(
        0,
        shape: [3, 2],
        type: DataType.int32,
      );
      check(() => tensor.copy(target: wrongTarget)).throws<ArgumentError>();

      final validTarget = Tensor<int>.filled(
        0,
        shape: [2, 3],
        type: DataType.int32,
      );
      final copied = tensor.copy(target: validTarget);
      check(copied).identicalTo(validTarget);
      check(validTarget.toFlatList()).deepEquals([1, 2, 3, 4, 5, 6]);
    });

    test('unaryOperation memory hazard with overlapping sub-tensors', () {
      final base = Tensor<int>.fromIterable(
        [1, 2, 3, 4, 5, 6],
        shape: [6],
        type: DataType.int32,
      );
      final src = base.getRange(axis: 0, start: 0, end: 3);
      final dst = base.getRange(axis: 0, start: 1, end: 4);
      final res = src.unaryOperation((x) => x * 10, target: dst);
      check(res).identicalTo(dst);
      check(dst.toFlatList() as List).deepEquals([10, 20, 30]);
    });

    test(
      'in-place unaryOperation with identical target avoids temporary copy',
      () {
        final a = Tensor<double>.fromIterable(
          [1.0, 2.0, 3.0, 4.0],
          shape: [2, 2],
          type: DataType.float64,
        );
        final res = a.unaryOperation((x) => x * 2.0, target: a);
        check(res).identicalTo(a);
        check(a.toFlatList()).deepEquals([2.0, 4.0, 6.0, 8.0]);
      },
    );

    test('binaryOperation broadcast type inference R == T and R == O', () {
      final a = Tensor<int>.fromIterable(
        [1, 2, 3],
        shape: [1, 3],
        type: DataType.int32,
      );
      final b = Tensor<double>.fromIterable(
        [0.5, 1.5, 2.5, 3.5, 4.5, 5.5],
        shape: [2, 3],
        type: DataType.float64,
      );
      final resT = a.binaryOperation<double, int>(b, (x, y) => (x + y).toInt());
      check(resT.type).equals(DataType.int32);
      check(resT.shape).deepEquals([2, 3]);

      final resO = a.binaryOperation<double, double>(b, (x, y) => x + y);
      check(resO.type).equals(DataType.float64);
      check(resO.shape).deepEquals([2, 3]);
    });

    test(
      'binaryOperation memory hazard with broadcast and overlapping target',
      () {
        final base = Tensor<int>.fromIterable(
          [1, 2, 3, 4, 5, 6, 7, 8],
          shape: [8],
          type: DataType.int32,
        );
        final a = base.getRange(axis: 0, start: 0, end: 2);
        final b = base.getRange(axis: 0, start: 1, end: 3);
        final dst = base.getRange(axis: 0, start: 2, end: 4);
        final res = a.binaryOperation(b, (x, y) => x + y, target: dst);
        check(res).identicalTo(dst);
      },
    );

    test('aliasing hazard with overlapping Float64List.sublistView and NullableList', () {
      final buf = Float64List.fromList([1.0, 2.0, 3.0, 4.0, 5.0]);
      final v0 = Float64List.sublistView(buf, 0, 4);
      final v1 = Float64List.sublistView(buf, 1, 5);
      final t0 = Tensor<double>.internal(
        type: DataType.float64,
        layout: Layout(shape: [4]),
        data: v0,
      );
      final t1 = Tensor<double>.internal(
        type: DataType.float64,
        layout: Layout(shape: [4]),
        data: v1,
      );
      check(t0.sharesMemoryWith(t1)).isTrue();
      t0.unaryOperation((x) => x * 10.0, target: t1);
      check(buf).deepEquals([1.0, 10.0, 20.0, 30.0, 40.0]);

      final buf2 = Float64List.fromList([1.0, 2.0, 3.0, 4.0, 5.0]);
      final b0 = Float64List.sublistView(buf2, 0, 4);
      final b1 = Float64List.sublistView(buf2, 1, 5);
      final tb0 = Tensor<double>.internal(
        type: DataType.float64,
        layout: Layout(shape: [4]),
        data: b0,
      );
      final tb1 = Tensor<double>.internal(
        type: DataType.float64,
        layout: Layout(shape: [4]),
        data: b1,
      );
      tb0.binaryOperation<double, double>(tb0, (a, b) => a + b, target: tb1);
      check(buf2).deepEquals([1.0, 2.0, 4.0, 6.0, 8.0]);

      // In-place binaryOperation where target == other (sameStartAddress with otherData)
      final inPlaceTarget = Tensor<int>.fromIterable(
        [10, 20, 30],
        shape: [3],
        type: DataType.int32,
      );
      final leftDouble = Tensor<double>.fromIterable(
        [1.0, 2.0, 3.0],
        shape: [3],
      );
      // R == O (int == int, while T is double) without explicit type, and target == other
      final inferredRight = leftDouble.binaryOperation<int, int>(
        inPlaceTarget,
        (a, b) => a.toInt() + b,
      );
      check(inferredRight.toFlatList()).deepEquals([11, 22, 33]);
      // R != T and R != O (String) without explicit type
      final inferredThird = leftDouble.binaryOperation<int, String>(
        inPlaceTarget,
        (a, b) => '${a.toInt()}:$b',
      );
      check(inferredThird.toFlatList()).deepEquals(['1:10', '2:20', '3:30']);
      leftDouble.binaryOperation<int, int>(
        inPlaceTarget,
        (a, b) => a.toInt() + b,
        target: inPlaceTarget,
      );
      check(inPlaceTarget.toFlatList()).deepEquals([11, 22, 33]);

      final nullableType = DataType.int32.nullable;
      final nList = nullableType.newList(5, fillValue: 1);
      for (var i = 0; i < 5; i++) {
        nList[i] = i + 1;
      }
      final tn = Tensor<int?>.internal(
        type: nullableType,
        layout: Layout(shape: [5]),
        data: nList,
      );
      final tnSrc = tn.getRange(axis: 0, start: 0, end: 4);
      final tnDst = tn.getRange(axis: 0, start: 1, end: 5);
      check(tnSrc.sharesMemoryWith(tnDst)).isTrue();
      tnSrc.unaryOperation((x) => (x ?? 0) * 10, target: tnDst);
      check(tn.toFlatList()).deepEquals([1, 10, 20, 30, 40]);

      final cList = Float64ComplexList.fromList([
        const Complex(1, 0),
        const Complex(2, 0),
        const Complex(3, 0),
      ]);
      final cUnmod = cList.asUnmodifiableView();
      final tc1 = Tensor<Complex>.internal(
        type: DataType.complex,
        layout: Layout(shape: [3]),
        data: cList,
      );
      final tc2 = Tensor<Complex>.internal(
        type: DataType.complex,
        layout: Layout(shape: [3]),
        data: cUnmod,
      );
      check(tc1.sharesMemoryWith(tc2)).isTrue();
    });

    test('relational operators adhere to IEEE 754 with NaN and -0.0', () {
      final nanTensor = Tensor.fromIterable([
        double.nan,
      ], type: DataType.float64);
      final oneTensor = Tensor.fromIterable([1.0], type: DataType.float64);
      final negZeroTensor = Tensor.fromIterable([-0.0], type: DataType.float64);
      final posZeroTensor = Tensor.fromIterable([0.0], type: DataType.float64);

      // NaN comparisons must always be false
      check((nanTensor > oneTensor).toFlatList()).deepEquals([false]);
      check((nanTensor < oneTensor).toFlatList()).deepEquals([false]);
      check((nanTensor >= oneTensor).toFlatList()).deepEquals([false]);
      check((nanTensor <= oneTensor).toFlatList()).deepEquals([false]);
      check((oneTensor > nanTensor).toFlatList()).deepEquals([false]);
      check((oneTensor < nanTensor).toFlatList()).deepEquals([false]);

      // -0.0 and 0.0 must be equal
      check((negZeroTensor < posZeroTensor).toFlatList()).deepEquals([false]);
      check((negZeroTensor > posZeroTensor).toFlatList()).deepEquals([false]);
      check((negZeroTensor <= posZeroTensor).toFlatList()).deepEquals([true]);
      check((negZeroTensor >= posZeroTensor).toFlatList()).deepEquals([true]);
      check((posZeroTensor <= negZeroTensor).toFlatList()).deepEquals([true]);
      check((posZeroTensor >= negZeroTensor).toFlatList()).deepEquals([true]);
    });

    test('binaryOperation with disjoint slices of the same buffer in contiguous fast-path', () {
      final big = Tensor<int>.fromIterable(
        [1, 2, 3, 10, 20, 30, 0, 0, 0],
        shape: [9],
        type: DataType.int32,
      );
      final s1 = big.getRange(axis: 0, start: 0, end: 3);
      final s2 = big.getRange(axis: 0, start: 3, end: 6);
      final target = big.getRange(axis: 0, start: 6, end: 9);

      check(s1.sharesMemoryWith(target)).isTrue();
      check(s2.sharesMemoryWith(target)).isTrue();

      s1.binaryOperation<int, int>(s2, (a, b) => a + b, target: target);
      check(target.toFlatList()).deepEquals([11, 22, 33]);
      check(big.toFlatList()).deepEquals([1, 2, 3, 10, 20, 30, 11, 22, 33]);
    });

    test('binaryOperation with matching start address but differing strides is guarded', () {
      final data = [1, 2, 3];
      // Layout with shape [1, 3] and non-standard stride [10, 1] vs [3, 1]
      final t1 = Tensor<int>.internal(
        type: DataType.int32,
        layout: Layout(shape: [1, 3], strides: [10, 1]),
        data: data,
      );
      final target = Tensor<int>.internal(
        type: DataType.int32,
        layout: Layout(shape: [1, 3], strides: [3, 1]),
        data: [0, 0, 0],
      );
      check(t1.layout.isContiguous).isTrue();
      check(target.layout.isContiguous).isTrue();
      t1.binaryOperation<int, int>(t1, (a, b) => a + b, target: target);
      check(target.toFlatList()).deepEquals([2, 4, 6]);
    });
  });
}
