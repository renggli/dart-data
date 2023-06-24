import 'package:data/data.dart';
import 'package:more/collection.dart';
import 'package:test/test.dart';

import 'utils/matchers.dart';

final array2 = Array.fromIterable(IntegerRange(2));
final array2x3 = Array.fromIterable(IntegerRange(2 * 3), shape: [2, 3]);
final array2x3x4 =
    Array.fromIterable(IntegerRange(2 * 3 * 4), shape: [2, 3, 4]);

void main() {
  group('filled', () {
    test('single', () {
      final result = Array<int>.filled(42);
      expect(result.type, DataType.int32);
      expect(result.data, [42]);
      expect(result.offset, 0);
      expect(result.dimensions, 0);
      expect(result.shape, <int>[]);
      expect(result.stride, <int>[]);
      expect(result.getOffset([]), 0);
      expect(result.getValue([]), 42);
    });
    test('basic', () {
      final result = Array<int>.filled(42, shape: [6]);
      expect(result.type, DataType.int32);
      expect(result.data, [42, 42, 42, 42, 42, 42]);
      expect(result.offset, 0);
      expect(result.dimensions, 1);
      expect(result.shape, [6]);
      expect(result.stride, [1]);
      for (var i = 0; i < 6; i++) {
        final indices = [i];
        expect(result.getOffset(indices), i);
        expect(result.getValue(indices), 42);
      }
    });
  });
  group('fromIterable', () {
    test('basic', () {
      final result = Array<int>.fromIterable(IntegerRange(1, 7));
      expect(result.type, DataType.uint8);
      expect(result.data, [1, 2, 3, 4, 5, 6]);
      expect(result.offset, 0);
      expect(result.dimensions, 1);
      expect(result.shape, [6]);
      expect(result.stride, [1]);
      for (var i = 0; i < 6; i++) {
        final indices = [i];
        expect(result.getOffset(indices), i);
        expect(result.getValue(indices), i + 1);
      }
    });
  });
  group('fromObject', () {
    test('basic', () {
      final result = Array<int>.fromObject([
        [1, 2, 3],
        [4, 5, 6],
      ]);
      expect(result.type, DataType.uint8);
      expect(result.data, [1, 2, 3, 4, 5, 6]);
      expect(result.offset, 0);
      expect(result.dimensions, 2);
      expect(result.shape, [2, 3]);
      expect(result.stride, [3, 1]);
      for (var i = 0; i < 2; i++) {
        for (var j = 0; j < 3; j++) {
          final indices = [i, j];
          expect(result.getOffset(indices), i * 3 + j);
          expect(result.getValue(indices), i * 3 + j + 1);
        }
      }
    });
  });
  group('reshape', () {
    test('1 x 6', () {
      final result = array2x3.reshape([1, 6]);
      expect(result.type, array2x3.type);
      expect(result.data, same(array2x3.data));
      expect(result.dimensions, 2);
      expect(result.shape, [1, 6]);
      expect(result.stride, [6, 1]);
      expect(result.toObject(), [
        [0, 1, 2, 3, 4, 5]
      ]);
    });
    test('2 x 3', () {
      final result = array2x3.reshape([2, 3]);
      expect(result.type, array2x3.type);
      expect(result.data, same(array2x3.data));
      expect(result.dimensions, 2);
      expect(result.shape, [2, 3]);
      expect(result.stride, [3, 1]);
      expect(result.toObject(), [
        [0, 1, 2],
        [3, 4, 5]
      ]);
    });
    test('3 x 2', () {
      final result = array2x3.reshape([3, 2]);
      expect(result.type, array2x3.type);
      expect(result.data, same(array2x3.data));
      expect(result.dimensions, 2);
      expect(result.shape, [3, 2]);
      expect(result.stride, [2, 1]);
      expect(result.toObject(), [
        [0, 1],
        [2, 3],
        [4, 5]
      ]);
    });
    test('6 x 1', () {
      final result = array2x3.reshape([6, 1]);
      expect(result.type, array2x3.type);
      expect(result.data, same(array2x3.data));
      expect(result.dimensions, 2);
      expect(result.shape, [6, 1]);
      expect(result.stride, [1, 1]);
      expect(result.toObject(), [
        [0],
        [1],
        [2],
        [3],
        [4],
        [5]
      ]);
    });
    test('6', () {
      final result = array2x3.reshape([6]);
      expect(result.type, array2x3.type);
      expect(result.data, same(array2x3.data));
      expect(result.dimensions, 1);
      expect(result.shape, [6]);
      expect(result.stride, [1]);
      expect(result.toObject(), [0, 1, 2, 3, 4, 5]);
    });
    test('invalid size', () {
      expect(() => array2x3.reshape([4, 3]), throwsAssertionError);
    }, skip: !hasAssertionsEnabled());
  });
  group('transpose', () {
    test('once', () {
      final result = array2x3.transpose();
      expect(result.type, array2x3.type);
      expect(result.data, same(array2x3.data));
      expect(result.dimensions, array2x3.dimensions);
      expect(result.shape, [3, 2]);
      expect(result.stride, [1, 3]);
      expect(result.toObject(), [
        [0, 3],
        [1, 4],
        [2, 5]
      ]);
    });
    test('twice', () {
      final result = array2x3.transpose().transpose();
      expect(result.type, array2x3.type);
      expect(result.data, same(array2x3.data));
      expect(result.dimensions, array2x3.dimensions);
      expect(result.shape, array2x3.shape);
      expect(result.stride, array2x3.stride);
      expect(result.toObject(), [
        [0, 1, 2],
        [3, 4, 5]
      ]);
    });
  });
  group('format', () {
    test('6 element array', () {
      const printer = ArrayPrinter<int>();
      final input = Array.fromIterable(IntegerRange(6));
      expect(printer(input), '[0, 1, 2, 3, 4, 5]');
    });
    test('10 element array', () {
      const printer = ArrayPrinter<int>();
      final input = Array.fromIterable(IntegerRange(10));
      expect(printer(input), '[0, 1, 2, …, 7, 8, 9]');
    });
    test('10 element array without limits', () {
      const printer = ArrayPrinter<int>(limit: false);
      final input = Array.fromIterable(IntegerRange(10));
      expect(printer(input), '[0, 1, 2, 3, 4, 5, 6, 7, 8, 9]');
    });
    test('10 element array with custom limits', () {
      const printer = ArrayPrinter<int>(leadingItems: 4, trailingItems: 2);
      final input = Array.fromIterable(IntegerRange(10));
      expect(printer(input), '[0, 1, 2, 3, …, 8, 9]');
    });
    test('2 * 3 matrix', () {
      const printer = ArrayPrinter<int>();
      final input = Array.fromIterable(IntegerRange(2 * 3), shape: [2, 3]);
      expect(
          printer(input),
          '[[0, 1, 2],\n'
          ' [3, 4, 5]]');
    });
    test('3 * 2 matrix', () {
      const printer = ArrayPrinter<int>();
      final input = Array.fromIterable(IntegerRange(3 * 2), shape: [3, 2]);
      expect(
          printer(input),
          '[[0, 1],\n'
          ' [2, 3],\n'
          ' [4, 5]]');
    });
    test('1 * 6 matrix', () {
      const printer = ArrayPrinter<int>();
      final input = Array.fromIterable(IntegerRange(1 * 6), shape: [1, 6]);
      expect(printer(input), '[[0, 1, 2, 3, 4, 5]]');
    });
    test('6 * 1 matrix', () {
      const printer = ArrayPrinter<int>();
      final input = Array.fromIterable(IntegerRange(6 * 1), shape: [6, 1]);
      expect(
          printer(input),
          '[[0],\n'
          ' [1],\n'
          ' [2],\n'
          ' [3],\n'
          ' [4],\n'
          ' [5]]');
    });
    test('12 * 1 matrix', () {
      const printer = ArrayPrinter<int>();
      final input = Array.fromIterable(IntegerRange(12 * 1), shape: [12, 1]);
      expect(
          printer(input),
          '[[0],\n'
          ' [1],\n'
          ' [2],\n'
          ' ⋮,\n'
          ' [9],\n'
          ' [10],\n'
          ' [11]]');
    });
    test('2 * 3 * 4', () {
      const printer = ArrayPrinter<int>();
      final input =
          Array.fromIterable(IntegerRange(2 * 3 * 4), shape: [2, 3, 4]);
      expect(
          printer(input),
          '[[[0, 1, 2, 3],\n'
          '  [4, 5, 6, 7],\n'
          '  [8, 9, 10, 11]],\n'
          ' [[12, 13, 14, 15],\n'
          '  [16, 17, 18, 19],\n'
          '  [20, 21, 22, 23]]]');
    });
    test('10 * 10', () {
      const printer = ArrayPrinter<int>();
      final input = Array.fromIterable(IntegerRange(10 * 10), shape: [10, 10]);
      expect(
          printer(input),
          '[[0, 1, 2, …, 7, 8, 9],\n'
          ' [10, 11, 12, …, 17, 18, 19],\n'
          ' [20, 21, 22, …, 27, 28, 29],\n'
          ' ⋮,\n'
          ' [70, 71, 72, …, 77, 78, 79],\n'
          ' [80, 81, 82, …, 87, 88, 89],\n'
          ' [90, 91, 92, …, 97, 98, 99]]');
    });
    test('3 * 3 * 3 * 3', () {
      const printer = ArrayPrinter<int>(leadingItems: 1, trailingItems: 1);
      final input =
          Array.fromIterable(IntegerRange(3 * 3 * 3 * 3), shape: [3, 3, 3, 3]);
      expect(
          printer(input),
          '[[[[0, …, 2],\n'
          '   ⋮,\n'
          '   [6, …, 8]],\n'
          '  ⋮,\n'
          '  [[18, …, 20],\n'
          '   ⋮,\n'
          '   [24, …, 26]]],\n'
          ' ⋮,\n'
          ' [[[54, …, 56],\n'
          '   ⋮,\n'
          '   [60, …, 62]],\n'
          '  ⋮,\n'
          '  [[72, …, 74],\n'
          '   ⋮,\n'
          '   [78, …, 80]]]]');
    });
  });
  group('value', () {
    test('positive indices', () {
      expect(array2.getValue([1]), 1);
      expect(array2x3.getValue([0, 1]), 1);
      expect(array2x3x4.getValue([0, 1, 2]), 6);
    });
    test('negative indices', () {
      expect(array2.getValue([-1]), 1);
      expect(array2x3.getValue([-2, -1]), 2);
      expect(array2x3x4.getValue([-1, -2, -1]), 19);
    });
    test('index out of bounds', () {
      expect(() => array2.getValue([2]), throwsAssertionError);
      expect(() => array2.getValue([-3]), throwsAssertionError);
    }, skip: !hasAssertionsEnabled());
    test('wrong number of indices', () {
      expect(() => array2x3.getValue([0]), throwsAssertionError);
      expect(() => array2x3.getValue([0, 0, 0]), throwsAssertionError);
    }, skip: !hasAssertionsEnabled());
  });
  group('slice', () {
    test('empty slices', () {
      const indices = <Index>[];
      expect(
          array2.slice(indices),
          isArray<int>(
              shape: array2.shape,
              strides: array2.stride,
              object: array2.toObject()));
      expect(
          array2x3.slice(indices),
          isArray<int>(
              shape: array2x3.shape,
              strides: array2x3.stride,
              object: array2x3.toObject()));
      expect(
          array2x3x4.slice(indices),
          isArray<int>(
              shape: array2x3x4.shape,
              strides: array2x3x4.stride,
              object: array2x3x4.toObject()));
    });
    test('first slice', () {
      const indices = [SingleIndex(0)];
      expect(array2.slice(indices), isArray<int>(shape: <int>[], object: 0));
      expect(array2x3.slice(indices),
          isArray<int>(shape: <int>[3], object: [0, 1, 2]));
      expect(
          array2x3x4.slice(indices),
          isArray<int>(shape: <int>[
            3,
            4
          ], object: [
            [0, 1, 2, 3],
            [4, 5, 6, 7],
            [8, 9, 10, 11]
          ]));
    });
    test('last slice', () {
      const indices = [SingleIndex(-1)];
      expect(array2.slice(indices), isArray<int>(shape: <int>[], object: 1));
      expect(array2x3.slice(indices),
          isArray<int>(shape: <int>[3], object: [3, 4, 5]));
      expect(
          array2x3x4.slice(indices),
          isArray<int>(shape: <int>[
            3,
            4
          ], object: [
            [12, 13, 14, 15],
            [16, 17, 18, 19],
            [20, 21, 22, 23]
          ]));
    });
    test('two slices', () {
      const indices = [SingleIndex(1), SingleIndex(2)];
      expect(() => array2.slice(indices), throwsAssertionError);
      expect(array2x3.slice(indices), isArray<int>(shape: <int>[], object: 5));
      expect(array2x3x4.slice(indices),
          isArray<int>(shape: <int>[4], object: [20, 21, 22, 23]));
    }, skip: !hasAssertionsEnabled());
  });
  group('toObject', () {
    test('default', () {
      expect(array2.toObject(), [0, 1]);
      expect(array2x3.toObject(), [
        [0, 1, 2],
        [3, 4, 5],
      ]);
      expect(array2x3x4.toObject(), [
        [
          [0, 1, 2, 3],
          [4, 5, 6, 7],
          [8, 9, 10, 11],
        ],
        [
          [12, 13, 14, 15],
          [16, 17, 18, 19],
          [20, 21, 22, 23],
        ]
      ]);
    });
    test('type', () {
      final object = DataType.object(0);
      expect(array2.toObject(type: object), [0, 1]);
      expect(array2x3.toObject(type: object), [
        [0, 1, 2],
        [3, 4, 5],
      ]);
      expect(array2x3x4.toObject(type: object), [
        [
          [0, 1, 2, 3],
          [4, 5, 6, 7],
          [8, 9, 10, 11],
        ],
        [
          [12, 13, 14, 15],
          [16, 17, 18, 19],
          [20, 21, 22, 23],
        ]
      ]);
    });
  });
}
