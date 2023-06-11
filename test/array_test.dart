import 'package:data/data.dart';
import 'package:more/collection.dart';
import 'package:test/test.dart';

import 'utils/matchers.dart';

void main() {
  group('filled', () {
    test('basic', () {
      final result = Array<int>.filled(42, shape: Shape.forVector(6));
      expect(result.type, DataType.int32);
      expect(result.data, [42, 42, 42, 42, 42, 42]);
      expect(result.offset, 0);
      expect(result.dimensions, 1);
      expect(result.shape.values, [6]);
      expect(result.strides.values, [1]);
      for (var i = 0; i < 6; i++) {
        final indices = [i];
        expect(result.getIndex(indices), i);
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
      expect(result.shape.values, [6]);
      expect(result.strides.values, [1]);
      for (var i = 0; i < 6; i++) {
        final indices = [i];
        expect(result.getIndex(indices), i);
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
      expect(result.shape.values, [2, 3]);
      expect(result.strides.values, [3, 1]);
      for (var i = 0; i < 2; i++) {
        for (var j = 0; j < 3; j++) {
          final indices = [i, j];
          expect(result.getIndex(indices), i * 3 + j);
          expect(result.getValue(indices), i * 3 + j + 1);
        }
      }
    });
  });
  group('reshape', () {
    final input = Array<int>.fromObject([
      [1, 2, 3],
      [4, 5, 6],
    ]);
    test('1 x 6', () {
      final result = input.reshape(Shape.fromIterable(const [1, 6]));
      expect(result.type, input.type);
      expect(result.data, same(input.data));
      expect(result.dimensions, 2);
      expect(result.shape.values, [1, 6]);
      expect(result.strides.values, [6, 1]);
    });
    test('2 x 3', () {
      final result = input.reshape(Shape.fromIterable(const [2, 3]));
      expect(result.type, input.type);
      expect(result.data, same(input.data));
      expect(result.dimensions, 2);
      expect(result.shape.values, [2, 3]);
      expect(result.strides.values, [3, 1]);
    });
    test('3 x 2', () {
      final result = input.reshape(Shape.fromIterable(const [3, 2]));
      expect(result.type, input.type);
      expect(result.data, same(input.data));
      expect(result.dimensions, 2);
      expect(result.shape.values, [3, 2]);
      expect(result.strides.values, [2, 1]);
    });
    test('6 x 1', () {
      final result = input.reshape(Shape.fromIterable(const [6, 1]));
      expect(result.type, input.type);
      expect(result.data, same(input.data));
      expect(result.dimensions, 2);
      expect(result.shape.values, [6, 1]);
      expect(result.strides.values, [1, 1]);
    });
    test('6', () {
      final result = input.reshape(Shape.fromIterable(const [6]));
      expect(result.type, input.type);
      expect(result.data, same(input.data));
      expect(result.dimensions, 1);
      expect(result.shape.values, [6]);
      expect(result.strides.values, [1]);
    });
    test('invalid size', () {
      expect(() => input.reshape(Shape.fromIterable(const [4, 3])),
          throwsArgumentError);
    });
  });
  group('transpose', () {
    final input = Array<int>.fromObject([
      [1, 2, 3],
      [4, 5, 6],
    ]);
    test('once', () {
      final result = input.transpose();
      expect(result.type, input.type);
      expect(result.data, same(input.data));
      expect(result.dimensions, input.dimensions);
      expect(result.shape.values, [3, 2]);
      expect(result.strides.values, [1, 3]);
    });
    test('twice', () {
      final result = input.transpose().transpose();
      expect(result.type, input.type);
      expect(result.data, same(input.data));
      expect(result.dimensions, input.dimensions);
      expect(result.shape, input.shape);
      expect(result.strides, input.strides);
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
      final input = Array.fromIterable(IntegerRange(2 * 3),
          shape: Shape.fromIterable(const [2, 3]));
      expect(
          printer(input),
          '[[0, 1, 2],\n'
          ' [3, 4, 5]]');
    });
    test('3 * 2 matrix', () {
      const printer = ArrayPrinter<int>();
      final input = Array.fromIterable(IntegerRange(3 * 2),
          shape: Shape.fromIterable(const [3, 2]));
      expect(
          printer(input),
          '[[0, 1],\n'
          ' [2, 3],\n'
          ' [4, 5]]');
    });
    test('1 * 6 matrix', () {
      const printer = ArrayPrinter<int>();
      final input = Array.fromIterable(IntegerRange(1 * 6),
          shape: Shape.fromIterable(const [1, 6]));
      expect(printer(input), '[[0, 1, 2, 3, 4, 5]]');
    });
    test('6 * 1 matrix', () {
      const printer = ArrayPrinter<int>();
      final input = Array.fromIterable(IntegerRange(6 * 1),
          shape: Shape.fromIterable(const [6, 1]));
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
      final input = Array.fromIterable(IntegerRange(12 * 1),
          shape: Shape.fromIterable(const [12, 1]));
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
      final input = Array.fromIterable(IntegerRange(2 * 3 * 4),
          shape: Shape.fromIterable(const [2, 3, 4]));
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
      final input = Array.fromIterable(IntegerRange(10 * 10),
          shape: Shape.fromIterable(const [10, 10]));
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
      final input = Array.fromIterable(IntegerRange(3 * 3 * 3 * 3),
          shape: Shape.fromIterable(const [3, 3, 3, 3]));
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
  group('slice', () {
    final array2 = Array.fromIterable(IntegerRange(2));
    final array2x3 = Array.fromIterable(IntegerRange(2 * 3),
        shape: Shape.fromIterable(const [2, 3]));
    final array2x3x4 = Array.fromIterable(IntegerRange(2 * 3 * 4),
        shape: Shape.fromIterable(const [2, 3, 4]));
    test('empty slices', () {
      const indices = <Index>[];
      expect(array2.slice(indices),
          isArray<int>(shape: <int>[2], format: '[0, 1]'));
      expect(
          array2x3.slice(indices),
          isArray<int>(
              shape: <int>[2, 3],
              format: '[[0, 1, 2],\n'
                  ' [3, 4, 5]]'));
      expect(
          array2x3x4.slice(indices),
          isArray<int>(
              shape: <int>[2, 3, 4],
              format: '[[[0, 1, 2, 3],\n'
                  '  [4, 5, 6, 7],\n'
                  '  [8, 9, 10, 11]],\n'
                  ' [[12, 13, 14, 15],\n'
                  '  [16, 17, 18, 19],\n'
                  '  [20, 21, 22, 23]]]'));
    });
    test('first slice', () {
      const indices = [SingleIndex(0)];
      expect(array2.slice(indices), isArray<int>(shape: <int>[], format: '0'));
      expect(array2x3.slice(indices),
          isArray<int>(shape: <int>[3], format: '[0, 1, 2]'));
      expect(
          array2x3x4.slice(indices),
          isArray<int>(
              shape: <int>[3, 4],
              format: '[[0, 1, 2, 3],\n'
                  ' [4, 5, 6, 7],\n'
                  ' [8, 9, 10, 11]]'));
    });
    test('last slice', () {
      const indices = [SingleIndex(-1)];
      expect(array2.slice(indices), isArray<int>(shape: <int>[], format: '1'));
      expect(array2x3.slice(indices),
          isArray<int>(shape: <int>[3], format: '[3, 4, 5]'));
      expect(
          array2x3x4.slice(indices),
          isArray<int>(
              shape: <int>[3, 4],
              format: '[[12, 13, 14, 15],\n'
                  ' [16, 17, 18, 19],\n'
                  ' [20, 21, 22, 23]]'));
    });
    test('two slices', () {
      const indices = [SingleIndex(1), SingleIndex(2)];
      expect(() => array2.slice(indices), throwsAssertionError);
      expect(
          array2x3.slice(indices), isArray<int>(shape: <int>[], format: '5'));
      expect(array2x3x4.slice(indices),
          isArray<int>(shape: <int>[4], format: '[20, 21, 22, 23]'));
    });
  });
}
