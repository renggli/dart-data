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

      // Same total length (12), matching rank (2), but mismatched dimensions [2, 6]
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

      // Same total length (12), matching rank (2), mismatched dimension sizes [2, 6]
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
  });
}
