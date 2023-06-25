import 'dart:math';

import 'package:data/data.dart';
import 'package:more/collection.dart';
import 'package:more/printer.dart';
import 'package:test/test.dart';

import 'utils/matchers.dart';

final tensor2 = Tensor.fromIterable(IntegerRange(2));
final tensor2x3 = Tensor.fromIterable(IntegerRange(2 * 3), shape: [2, 3]);
final tensor2x3x4 =
    Tensor.fromIterable(IntegerRange(2 * 3 * 4), shape: [2, 3, 4]);

void main() {
  group('filled', () {
    test('value', () {
      final result = Tensor.filled(40);
      expect(
          result,
          isTensor<int>(
            type: DataType.int32,
            data: [40],
            dimensions: 0,
            shape: isEmpty,
            stride: isEmpty,
            object: 40,
          ));
      expect(result.getOffset([]), 0);
      expect(result.getValue([]), 40);
    });
    test('vector', () {
      final result = Tensor.filled(41, shape: [6]);
      expect(
          result,
          isTensor<int>(
            type: DataType.int32,
            data: [41, 41, 41, 41, 41, 41],
            dimensions: 1,
            shape: [6],
            stride: [1],
            object: [41, 41, 41, 41, 41, 41],
          ));
      for (var i = 0; i < 6; i++) {
        final indices = [i];
        expect(result.getOffset(indices), i);
        expect(result.getValue(indices), 41);
      }
    });
    test('matrix', () {
      final result = Tensor.filled(42, shape: [2, 3], type: DataType.uint32);
      expect(
          result,
          isTensor<int>(
            type: DataType.uint32,
            data: [42, 42, 42, 42, 42, 42],
            dimensions: 2,
            shape: [2, 3],
            stride: [3, 1],
            object: [
              [42, 42, 42],
              [42, 42, 42],
            ],
          ));
      for (var i = 0; i < 2; i++) {
        for (var j = 0; j < 3; j++) {
          final indices = [i, j];
          expect(result.getOffset(indices), 3 * i + j);
          expect(result.getValue(indices), 42);
        }
      }
    });
  });
  group('fromIterable', () {
    test('empty', () {
      expect(() => Tensor.fromIterable(<int>[]), throwsAssertionError);
    }, skip: !hasAssertionsEnabled());
    test('vector', () {
      final result = Tensor.fromIterable(IntegerRange(1, 7));
      expect(
          result,
          isTensor<int>(
            type: DataType.uint8,
            data: [1, 2, 3, 4, 5, 6],
            dimensions: 1,
            shape: [6],
            stride: [1],
            object: [1, 2, 3, 4, 5, 6],
          ));
      for (var i = 0; i < 6; i++) {
        final indices = [i];
        expect(result.getOffset(indices), i);
        expect(result.getValue(indices), i + 1);
      }
    });
    test('matrix', () {
      final result = Tensor.fromIterable(IntegerRange(1, 7),
          shape: [2, 3], type: DataType.uint32);
      expect(
          result,
          isTensor<int>(
            type: DataType.uint32,
            data: [1, 2, 3, 4, 5, 6],
            dimensions: 2,
            shape: [2, 3],
            stride: [3, 1],
            object: [
              [1, 2, 3],
              [4, 5, 6],
            ],
          ));
      for (var i = 0; i < 2; i++) {
        for (var j = 0; j < 3; j++) {
          final indices = [i, j];
          expect(result.getOffset(indices), 3 * i + j);
          expect(result.getValue(indices), 3 * i + j + 1);
        }
      }
    });
  });
  group('fromObject', () {
    test('vector', () {
      final result = Tensor<int>.fromObject([-1, 0, 1]);
      expect(
          result,
          isTensor<int>(
            type: DataType.int8,
            data: [-1, 0, 1],
            dimensions: 1,
            shape: [3],
            stride: [1],
            object: [-1, 0, 1],
          ));
      for (var i = 0; i < 2; i++) {
        final indices = [i];
        expect(result.getOffset(indices), i);
        expect(result.getValue(indices), i - 1);
      }
    });
    test('matrix', () {
      final result = Tensor<int>.fromObject([
        [1, 2, 3],
        [4, 5, 6],
      ]);
      expect(
          result,
          isTensor<int>(
            type: DataType.uint8,
            data: [1, 2, 3, 4, 5, 6],
            dimensions: 2,
            shape: [2, 3],
            stride: [3, 1],
            object: [
              [1, 2, 3],
              [4, 5, 6],
            ],
          ));
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
      final result = tensor2x3.reshape([1, 6]);
      expect(
          result,
          isTensor<int>(
            type: tensor2x3.type,
            data: same(tensor2x3.data),
            dimensions: 2,
            shape: [1, 6],
            stride: [6, 1],
            object: [
              [0, 1, 2, 3, 4, 5]
            ],
          ));
    });
    test('2 x 3', () {
      final result = tensor2x3.reshape([2, 3]);
      expect(
          result,
          isTensor<int>(
            type: tensor2x3.type,
            data: same(tensor2x3.data),
            dimensions: 2,
            shape: [2, 3],
            stride: [3, 1],
            object: [
              [0, 1, 2],
              [3, 4, 5],
            ],
          ));
    });
    test('3 x 2', () {
      final result = tensor2x3.reshape([3, 2]);
      expect(
          result,
          isTensor<int>(
            type: tensor2x3.type,
            data: same(tensor2x3.data),
            dimensions: 2,
            shape: [3, 2],
            stride: [2, 1],
            object: [
              [0, 1],
              [2, 3],
              [4, 5],
            ],
          ));
    });
    test('6 x 1', () {
      final result = tensor2x3.reshape([6, 1]);
      expect(
          result,
          isTensor<int>(
            type: tensor2x3.type,
            data: same(tensor2x3.data),
            dimensions: 2,
            shape: [6, 1],
            stride: [1, 1],
            object: [
              [0],
              [1],
              [2],
              [3],
              [4],
              [5],
            ],
          ));
    });
    test('6', () {
      final result = tensor2x3.reshape([6]);
      expect(
          result,
          isTensor<int>(
            type: tensor2x3.type,
            data: same(tensor2x3.data),
            dimensions: 1,
            shape: [6],
            stride: [1],
            object: [0, 1, 2, 3, 4, 5],
          ));
    });
    test('invalid size', () {
      expect(() => tensor2x3.reshape([4, 3]), throwsAssertionError);
    }, skip: !hasAssertionsEnabled());
  });
  group('transpose', () {
    test('once', () {
      final result = tensor2x3.transpose();
      expect(
          result,
          isTensor<int>(
            type: tensor2x3.type,
            data: same(tensor2x3.data),
            dimensions: 2,
            shape: [3, 2],
            stride: [1, 3],
            isContiguous: false,
            object: [
              [0, 3],
              [1, 4],
              [2, 5],
            ],
          ));
    });
    test('twice', () {
      final result = tensor2x3.transpose().transpose();
      expect(
          result,
          isTensor<int>(
            type: tensor2x3.type,
            data: same(tensor2x3.data),
            dimensions: tensor2x3.dimensions,
            shape: tensor2x3.shape,
            stride: tensor2x3.stride,
            object: [
              [0, 1, 2],
              [3, 4, 5],
            ],
          ));
    });
  });
  group('format', () {
    test('single value', () {
      const printer = TensorPrinter<double>();
      final input = Tensor.filled(pi);
      expect(printer(input), '3.141593e+000');
    });
    test('custom format', () {
      final printer = TensorPrinter<double>(
          valuePrinter: FixedNumberPrinter(precision: 2),
          paddingPrinter: const StandardPrinter<String>().padLeft(6));
      final input = Tensor.filled(pi);
      expect(printer(input), '  3.14');
    });
    test('6 element vector', () {
      const printer = TensorPrinter<int>();
      final input = Tensor.fromIterable(IntegerRange(6));
      expect(printer(input), '[0, 1, 2, 3, 4, 5]');
    });
    test('10 element vector', () {
      const printer = TensorPrinter<int>();
      final input = Tensor.fromIterable(IntegerRange(10));
      expect(printer(input), '[0, 1, 2, …, 7, 8, 9]');
    });
    test('10 element vector without limits', () {
      const printer = TensorPrinter<int>(limit: false);
      final input = Tensor.fromIterable(IntegerRange(10));
      expect(printer(input), '[0, 1, 2, 3, 4, 5, 6, 7, 8, 9]');
    });
    test('10 element vector with custom limits', () {
      const printer = TensorPrinter<int>(leadingItems: 4, trailingItems: 2);
      final input = Tensor.fromIterable(IntegerRange(10));
      expect(printer(input), '[0, 1, 2, 3, …, 8, 9]');
    });
    test('2 * 3 matrix', () {
      const printer = TensorPrinter<int>();
      final input = Tensor.fromIterable(IntegerRange(2 * 3), shape: [2, 3]);
      expect(
          printer(input),
          '[[0, 1, 2],\n'
          ' [3, 4, 5]]');
    });
    test('3 * 2 matrix', () {
      const printer = TensorPrinter<int>();
      final input = Tensor.fromIterable(IntegerRange(3 * 2), shape: [3, 2]);
      expect(
          printer(input),
          '[[0, 1],\n'
          ' [2, 3],\n'
          ' [4, 5]]');
    });
    test('1 * 6 matrix', () {
      const printer = TensorPrinter<int>();
      final input = Tensor.fromIterable(IntegerRange(1 * 6), shape: [1, 6]);
      expect(printer(input), '[[0, 1, 2, 3, 4, 5]]');
    });
    test('6 * 1 matrix', () {
      const printer = TensorPrinter<int>();
      final input = Tensor.fromIterable(IntegerRange(6 * 1), shape: [6, 1]);
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
      const printer = TensorPrinter<int>();
      final input = Tensor.fromIterable(IntegerRange(12 * 1), shape: [12, 1]);
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
      const printer = TensorPrinter<int>();
      final input =
          Tensor.fromIterable(IntegerRange(2 * 3 * 4), shape: [2, 3, 4]);
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
      const printer = TensorPrinter<int>();
      final input = Tensor.fromIterable(IntegerRange(10 * 10), shape: [10, 10]);
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
      const printer = TensorPrinter<int>(leadingItems: 1, trailingItems: 1);
      final input =
          Tensor.fromIterable(IntegerRange(3 * 3 * 3 * 3), shape: [3, 3, 3, 3]);
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
      expect(tensor2.getValue([1]), 1);
      expect(tensor2x3.getValue([0, 1]), 1);
      expect(tensor2x3x4.getValue([0, 1, 2]), 6);
    });
    test('negative indices', () {
      expect(tensor2.getValue([-1]), 1);
      expect(tensor2x3.getValue([-2, -1]), 2);
      expect(tensor2x3x4.getValue([-1, -2, -1]), 19);
    });
    test('index out of bounds', () {
      expect(() => tensor2.getValue([2]), throwsAssertionError);
      expect(() => tensor2.getValue([-3]), throwsAssertionError);
    }, skip: !hasAssertionsEnabled());
    test('wrong number of indices', () {
      expect(() => tensor2x3.getValue([0]), throwsAssertionError);
      expect(() => tensor2x3.getValue([0, 0, 0]), throwsAssertionError);
    }, skip: !hasAssertionsEnabled());
  });
  group('slice', () {
    test('empty slices', () {
      const indices = <Index>[];
      expect(
          tensor2.slice(indices),
          isTensor<int>(
              shape: tensor2.shape,
              stride: tensor2.stride,
              object: tensor2.toObject()));
      expect(
          tensor2x3.slice(indices),
          isTensor<int>(
              shape: tensor2x3.shape,
              stride: tensor2x3.stride,
              object: tensor2x3.toObject()));
      expect(
          tensor2x3x4.slice(indices),
          isTensor<int>(
              shape: tensor2x3x4.shape,
              stride: tensor2x3x4.stride,
              object: tensor2x3x4.toObject()));
    });
    test('first slice', () {
      const indices = [SingleIndex(0)];
      expect(tensor2.slice(indices), isTensor<int>(shape: <int>[], object: 0));
      expect(tensor2x3.slice(indices),
          isTensor<int>(shape: <int>[3], object: [0, 1, 2]));
      expect(
          tensor2x3x4.slice(indices),
          isTensor<int>(shape: <int>[
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
      expect(tensor2.slice(indices),
          isTensor<int>(shape: isEmpty, offset: 1, object: 1));
      expect(tensor2x3.slice(indices),
          isTensor<int>(shape: [3], offset: 3, object: [3, 4, 5]));
      expect(
          tensor2x3x4.slice(indices),
          isTensor<int>(
            offset: 12,
            shape: [3, 4],
            object: [
              [12, 13, 14, 15],
              [16, 17, 18, 19],
              [20, 21, 22, 23]
            ],
          ));
    });
    test('two slices', () {
      const indices = [SingleIndex(1), SingleIndex(2)];
      expect(() => tensor2.slice(indices), throwsAssertionError);
      expect(tensor2x3.slice(indices),
          isTensor<int>(offset: 5, shape: isEmpty, object: 5));
      expect(tensor2x3x4.slice(indices),
          isTensor<int>(offset: 20, shape: [4], object: [20, 21, 22, 23]));
    }, skip: !hasAssertionsEnabled());
  });
  group('toObject', () {
    test('default', () {
      expect(tensor2.toObject(), [0, 1]);
      expect(tensor2x3.toObject(), [
        [0, 1, 2],
        [3, 4, 5],
      ]);
      expect(tensor2x3x4.toObject(), [
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
      expect(tensor2.toObject(type: object), [0, 1]);
      expect(tensor2x3.toObject(type: object), [
        [0, 1, 2],
        [3, 4, 5],
      ]);
      expect(tensor2x3x4.toObject(type: object), [
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
