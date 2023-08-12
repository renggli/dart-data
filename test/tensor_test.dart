import 'dart:math';

import 'package:data/tensor.dart';
import 'package:data/type.dart';
import 'package:more/collection.dart';
import 'package:more/printer.dart';
import 'package:test/test.dart';

import 'utils/matchers.dart';

final value = Tensor.filled(42);
final tensor2 = Tensor.fromIterable(IntegerRange(2));
final tensor2x3 = Tensor.fromIterable(IntegerRange(2 * 3), shape: [2, 3]);
final tensor2x3x4 =
    Tensor.fromIterable(IntegerRange(2 * 3 * 4), shape: [2, 3, 4]);
final tensor2x3x4x5 =
    Tensor.fromIterable(IntegerRange(2 * 3 * 4 * 5), shape: [2, 3, 4, 5]);
final tensor2x2x2 =
    Tensor<int>.fromIterable(IntegerRange(2 * 2 * 2), shape: [2, 2, 2]);

void main() {
  group('layout', () {
    test('empty', () {
      final layout = Layout.empty;
      expect(
          layout,
          isLayout(
              rank: 0,
              length: 0,
              offset: 0,
              shape: isEmpty,
              strides: isEmpty,
              isContiguous: true,
              indices: isEmpty,
              keys: isEmpty));
    });
    test('value', () {
      final layout = Layout();
      expect(
          layout,
          isLayout(
              rank: 0,
              length: 1,
              offset: 0,
              shape: isEmpty,
              strides: isEmpty,
              isContiguous: true,
              indices: [0],
              keys: [<int>[]]));
    });
    test('1', () {
      final layout = Layout(shape: const [1]);
      expect(
          layout,
          isLayout(
              rank: 1,
              length: 1,
              offset: 0,
              shape: [1],
              strides: [1],
              isContiguous: true,
              indices: [0],
              keys: [
                [0]
              ]));
    });
    test('3', () {
      final layout = Layout(shape: const [3]);
      expect(
          layout,
          isLayout(
              rank: 1,
              length: 3,
              offset: 0,
              shape: [3],
              strides: [1],
              isContiguous: true,
              indices: [0, 1, 2],
              keys: [
                [0],
                [1],
                [2],
              ]));
    });
    test('2x2', () {
      final layout = Layout(shape: const [2, 2]);
      expect(
          layout,
          isLayout(
              rank: 2,
              length: 4,
              offset: 0,
              shape: [2, 2],
              strides: [2, 1],
              isContiguous: true,
              indices: [0, 1, 2, 3],
              keys: [
                [0, 0],
                [0, 1],
                [1, 0],
                [1, 1],
              ]));
    });
    test('2x3', () {
      final layout = Layout(shape: const [2, 3]);
      expect(
          layout,
          isLayout(
              rank: 2,
              length: 6,
              offset: 0,
              shape: [2, 3],
              strides: [3, 1],
              isContiguous: true,
              indices: [0, 1, 2, 3, 4, 5],
              keys: [
                [0, 0],
                [0, 1],
                [0, 2],
                [1, 0],
                [1, 1],
                [1, 2],
              ]));
    });
    test('3x2', () {
      final layout = Layout(shape: const [3, 2]);
      expect(
          layout,
          isLayout(
              rank: 2,
              length: 6,
              offset: 0,
              shape: [3, 2],
              strides: [2, 1],
              isContiguous: true,
              indices: [0, 1, 2, 3, 4, 5],
              keys: [
                [0, 0],
                [0, 1],
                [1, 0],
                [1, 1],
                [2, 0],
                [2, 1],
              ]));
    });
    test('3x2 with offset', () {
      final layout = Layout(shape: const [3, 2], offset: 7);
      expect(
          layout,
          isLayout(
              rank: 2,
              length: 6,
              offset: 7,
              shape: [3, 2],
              strides: [2, 1],
              isContiguous: true,
              indices: [7, 8, 9, 10, 11, 12],
              keys: [
                [0, 0],
                [0, 1],
                [1, 0],
                [1, 1],
                [2, 0],
                [2, 1],
              ]));
    });
  });
  group('filled', () {
    test('value', () {
      final result = Tensor.filled(40);
      expect(
          result,
          isTensor<int>(
            type: DataType.int32,
            data: [40],
            layout: isLayout(
              rank: 0,
              length: 1,
              shape: isEmpty,
              strides: isEmpty,
            ),
            object: 40,
          ));
      expect(result.getValue([]), 40);
    });
    test('vector', () {
      final result = Tensor.filled(41, shape: [3]);
      expect(
          result,
          isTensor<int>(
            type: DataType.int32,
            data: [41, 41, 41],
            layout: isLayout(
              rank: 1,
              length: 3,
              shape: [3],
              strides: [1],
            ),
            object: [41, 41, 41],
          ));
    });
    test('matrix', () {
      final result = Tensor.filled(42, shape: [2, 3], type: DataType.uint32);
      expect(
          result,
          isTensor<int>(
            type: DataType.uint32,
            data: [42, 42, 42, 42, 42, 42],
            layout: isLayout(
              rank: 2,
              shape: [2, 3],
              strides: [3, 1],
            ),
            object: [
              [42, 42, 42],
              [42, 42, 42],
            ],
          ));
    });
  });
  group('generate', () {
    test('vector', () {
      final result = Tensor.generate((key) => 10 + 2 * key[0], shape: [4]);
      expect(
          result,
          isTensor<int>(
            type: DataType.int32,
            data: [10, 12, 14, 16],
            layout: isLayout(
              rank: 1,
              length: 4,
              shape: [4],
              strides: [1],
            ),
            object: [10, 12, 14, 16],
          ));
    });
    test('matrix', () {
      final result = Tensor.generate((key) => key[0] * key[1],
          shape: [3, 4], type: DataType.uint32);
      expect(
          result,
          isTensor<int>(
            type: DataType.uint32,
            data: [0, 0, 0, 0, 0, 1, 2, 3, 0, 2, 4, 6],
            layout: isLayout(
              rank: 2,
              shape: [3, 4],
              strides: [4, 1],
            ),
            object: [
              [0, 0, 0, 0],
              [0, 1, 2, 3],
              [0, 2, 4, 6],
            ],
          ));
    });
  });
  group('iterable', () {
    test('empty', () {
      final result = Tensor.fromIterable(<int>[]);
      expect(
          result,
          isTensor<int>(
            type: DataType.integer,
            layout: isLayout(
              rank: 0,
              length: 0,
              offset: 0,
              shape: isEmpty,
              strides: isEmpty,
              isContiguous: true,
            ),
            data: isEmpty,
            object: isNull,
            format: '∅',
          ));
    });
    test('vector', () {
      final result = IntegerRange(1, 7).toTensor();
      expect(
          result,
          isTensor<int>(
            type: DataType.uint8,
            data: [1, 2, 3, 4, 5, 6],
            layout: isLayout(
              rank: 1,
              shape: [6],
              strides: [1],
            ),
            object: [1, 2, 3, 4, 5, 6],
          ));
    });
    test('matrix', () {
      final result =
          IntegerRange(1, 7).toTensor(shape: [2, 3], type: DataType.uint32);
      expect(
          result,
          isTensor<int>(
            type: DataType.uint32,
            data: [1, 2, 3, 4, 5, 6],
            layout: isLayout(
              rank: 2,
              shape: [2, 3],
              strides: [3, 1],
            ),
            object: [
              [1, 2, 3],
              [4, 5, 6],
            ],
          ));
    });
    test('steps', () {
      final result =
          IntegerRange(1, 13).toTensor(shape: [2, 3], strides: [6, 2]);
      expect(
          result,
          isTensor<int>(
            data: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12],
            layout: isLayout(
              rank: 2,
              shape: [2, 3],
              strides: [6, 2],
            ),
            object: [
              [1, 3, 5],
              [7, 9, 11],
            ],
          ));
    });
  });
  group('object', () {
    test('empty', () {
      final result = Tensor<int>.fromObject(null);
      expect(
          result,
          isTensor<int>(
            type: DataType.integer,
            layout: isLayout(
              rank: 0,
              offset: 0,
              length: 0,
              shape: isEmpty,
              strides: isEmpty,
            ),
            data: isEmpty,
            object: null,
          ));
    });
    test('value', () {
      final result = Tensor<int>.fromObject(42);
      expect(
          result,
          isTensor<int>(
            type: DataType.uint8,
            layout: isLayout(
              rank: 0,
              offset: 0,
              length: 1,
              shape: isEmpty,
              strides: isEmpty,
            ),
            data: [42],
            object: 42,
          ));
    });
    test('vector', () {
      final result = Tensor<int>.fromObject([-1, 0, 1]);
      expect(
          result,
          isTensor<int>(
            type: DataType.int8,
            layout: isLayout(
              rank: 1,
              length: 3,
              offset: 0,
              shape: [3],
              strides: [1],
            ),
            data: [-1, 0, 1],
            object: [-1, 0, 1],
          ));
    });
    test('matrix', () {
      final result = Tensor<int>.fromObject([
        [1, 2, 3],
        [4, 5, 6],
      ], type: DataType.int32);
      expect(
          result,
          isTensor<int>(
            type: DataType.int32,
            layout: isLayout(
              rank: 2,
              length: 6,
              offset: 0,
              shape: [2, 3],
              strides: [3, 1],
            ),
            data: [1, 2, 3, 4, 5, 6],
            object: [
              [1, 2, 3],
              [4, 5, 6],
            ],
          ));
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
            layout: isLayout(
              rank: 2,
              shape: [1, 6],
              strides: [6, 1],
            ),
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
            layout: isLayout(
              rank: 2,
              shape: [2, 3],
              strides: [3, 1],
            ),
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
            layout: isLayout(
              rank: 2,
              shape: [3, 2],
              strides: [2, 1],
            ),
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
            layout: isLayout(
              rank: 2,
              shape: [6, 1],
              strides: [1, 1],
            ),
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
            layout: isLayout(
              rank: 1,
              shape: [6],
              strides: [1],
            ),
            object: [0, 1, 2, 3, 4, 5],
          ));
    });
    test('inferred', () {
      final result = tensor2x3x4.reshape([8, -1]);
      expect(
          result,
          isTensor<int>(
            type: tensor2x3x4.type,
            data: same(tensor2x3x4.data),
            layout: isLayout(
              rank: 2,
              shape: [8, 3],
              strides: [3, 1],
            ),
            object: [
              [0, 1, 2],
              [3, 4, 5],
              [6, 7, 8],
              [9, 10, 11],
              [12, 13, 14],
              [15, 16, 17],
              [18, 19, 20],
              [21, 22, 23],
            ],
          ));
    });
    test('error', () {
      expect(
        () => tensor2x3.reshape([4, 3]),
        throwsLayoutErrorWith(name: 'shape'),
      );
      expect(
        () => tensor2x3.reshape([-1, 5]),
        throwsLayoutErrorWith(name: 'shape'),
      );
    });
  });
  group('expand', () {
    test('default', () {
      final result = tensor2x3.expand();
      expect(
          result,
          isTensor<int>(
            type: tensor2x3.type,
            data: same(tensor2x3.data),
            layout: isLayout(
              rank: 3,
              length: 6,
              shape: [1, 2, 3],
              strides: [3, 3, 1],
            ),
            object: [
              [
                [0, 1, 2],
                [3, 4, 5],
              ],
            ],
          ));
    });
    test('middle', () {
      final result = tensor2x3.expand(axis: 1);
      expect(
          result,
          isTensor<int>(
            type: tensor2x3.type,
            data: same(tensor2x3.data),
            layout: isLayout(
              rank: 3,
              length: 6,
              shape: [2, 1, 3],
              strides: [3, 1, 1],
            ),
            object: [
              [
                [0, 1, 2],
              ],
              [
                [3, 4, 5],
              ],
            ],
          ));
    });
    test('end', () {
      final result = tensor2x3.expand(axis: 2);
      expect(
          result,
          isTensor<int>(
            type: tensor2x3.type,
            data: same(tensor2x3.data),
            layout: isLayout(
              rank: 3,
              length: 6,
              shape: [2, 3, 1],
              strides: [3, 1, 1],
            ),
            object: [
              [
                [0],
                [1],
                [2],
              ],
              [
                [3],
                [4],
                [5],
              ],
            ],
          ));
    });
    test('error range', () {
      expect(
        () => tensor2x3.expand(axis: 3),
        throwsRangeErrorWith(name: 'axis'),
      );
      expect(
        () => tensor2x3.expand(axis: -4),
        throwsRangeErrorWith(name: 'axis'),
      );
    });
  });
  group('collapse', () {
    test('default', () {
      final result = tensor2x3.expand().collapse();
      expect(
          result,
          isTensor<int>(
            type: tensor2x3.type,
            data: same(tensor2x3.data),
            layout: tensor2x3.layout,
            object: tensor2x3.toObject(),
          ));
    });
    test('middle', () {
      final result = tensor2x3.expand(axis: 1).collapse(axis: 1);
      expect(
          result,
          isTensor<int>(
            type: tensor2x3.type,
            data: same(tensor2x3.data),
            layout: tensor2x3.layout,
            object: tensor2x3.toObject(),
          ));
    });
    test('end', () {
      final result = tensor2x3.expand(axis: 2).collapse(axis: 2);
      expect(
          result,
          isTensor<int>(
            type: tensor2x3.type,
            data: same(tensor2x3.data),
            layout: tensor2x3.layout,
            object: tensor2x3.toObject(),
          ));
    });
    test('error range', () {
      expect(
        () => tensor2x3.collapse(axis: 2),
        throwsRangeErrorWith(name: 'axis'),
      );
      expect(
        () => tensor2x3.collapse(axis: -3),
        throwsRangeErrorWith(name: 'axis'),
      );
    });
    test('error axis', () {
      expect(
        () => tensor2x3.collapse(axis: 0),
        throwsLayoutErrorWith(name: 'axis'),
      );
      expect(
        () => tensor2x3.collapse(axis: 1),
        throwsLayoutErrorWith(name: 'axis'),
      );
    });
  });
  group('flatten', () {
    test('value', () {
      final result = value.flatten();
      expect(
          result,
          isTensor<int>(
            type: value.type,
            data: same(value.data),
            layout: isLayout(
              rank: 1,
              shape: [1],
              strides: [1],
            ),
            object: value.values,
          ));
    });
    test('rank = 1', () {
      final result = tensor2.flatten();
      expect(
          result,
          isTensor<int>(
            type: tensor2.type,
            data: same(tensor2.data),
            layout: tensor2.layout,
            object: tensor2.values,
          ));
    });
    test('rank = 2', () {
      final result = tensor2x3.flatten();
      expect(
          result,
          isTensor<int>(
            type: tensor2x3.type,
            data: same(tensor2x3.data),
            layout: isLayout(
              rank: 1,
              shape: [6],
              strides: [1],
            ),
            object: tensor2x3.values,
          ));
    });
    test('not contiguous', () {
      final source = tensor2x3.transpose();
      final result = source.flatten();
      expect(
          result,
          isTensor<int>(
            type: tensor2x3.type,
            data: isNot(same(tensor2x3.data)),
            layout: isLayout(
              rank: 1,
              shape: [6],
              strides: [1],
            ),
            object: source.values,
          ));
    });
  });
  group('transpose', () {
    test('once', () {
      expect(
          tensor2x3.transpose(),
          isTensor<int>(
            type: tensor2x3.type,
            data: same(tensor2x3.data),
            layout: isLayout(
              rank: 2,
              shape: [3, 2],
              strides: [1, 3],
              isContiguous: false,
            ),
            object: [
              [0, 3],
              [1, 4],
              [2, 5],
            ],
          ));
    });
    test('twice', () {
      expect(
          tensor2x3.transpose().transpose(),
          isTensor<int>(
            type: tensor2x3.type,
            data: same(tensor2x3.data),
            layout: isLayout(
              rank: tensor2x3.rank,
              shape: tensor2x3.layout.shape,
              strides: tensor2x3.layout.strides,
              isContiguous: true,
            ),
            object: [
              [0, 1, 2],
              [3, 4, 5],
            ],
          ));
    });
  });
  group('swapAxes', () {
    test('0, 1', () {
      expect(
          tensor2x3.swapAxes(0, 1),
          isTensor<int>(
            data: same(tensor2x3.data),
            layout: isLayout(
              rank: 2,
              length: 6,
              offset: 0,
              shape: [3, 2],
              strides: [1, 3],
            ),
            object: [
              [0, 3],
              [1, 4],
              [2, 5],
            ],
          ));
    });
    test('0, -1', () {
      expect(
          tensor2x2x2.swapAxes(0, -1),
          isTensor<int>(
            data: same(tensor2x2x2.data),
            layout: isLayout(
              rank: 3,
              length: 8,
              offset: 0,
              shape: [2, 2, 2],
              strides: [1, 2, 4],
            ),
            object: [
              [
                [0, 4],
                [2, 6],
              ],
              [
                [1, 5],
                [3, 7],
              ],
            ],
          ));
    });
  });
  group('moveAxis', () {
    test('0, -1', () {
      expect(
          tensor2x3x4.moveAxes(0, -1),
          isTensor<int>(
            data: same(tensor2x3x4.data),
            layout: isLayout(
              rank: 3,
              length: 24,
              offset: 0,
              shape: [3, 4, 2],
              strides: [4, 1, 12],
            ),
            object: [
              [
                [0, 12],
                [1, 13],
                [2, 14],
                [3, 15],
              ],
              [
                [4, 16],
                [5, 17],
                [6, 18],
                [7, 19],
              ],
              [
                [8, 20],
                [9, 21],
                [10, 22],
                [11, 23],
              ],
            ],
          ));
    });
    test('-1, 0', () {
      expect(
          tensor2x3x4.moveAxes(-1, 0),
          isTensor<int>(
            data: same(tensor2x3x4.data),
            layout: isLayout(
              rank: 3,
              length: 24,
              offset: 0,
              shape: [4, 2, 3],
              strides: [1, 12, 4],
            ),
            object: [
              [
                [0, 4, 8],
                [12, 16, 20],
              ],
              [
                [1, 5, 9],
                [13, 17, 21],
              ],
              [
                [2, 6, 10],
                [14, 18, 22],
              ],
              [
                [3, 7, 11],
                [15, 19, 23],
              ],
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
      expect(
        () => tensor2.getValue([2]),
        throwsRangeErrorWith(name: 'key'),
      );
      expect(
        () => tensor2.getValue([-3]),
        throwsRangeErrorWith(name: 'key'),
      );
    }, skip: !hasAssertionsEnabled());
    test('wrong number of indices', () {
      expect(
        () => tensor2x3.getValue([0]),
        throwsRangeErrorWith(name: 'key.length'),
      );
      expect(
        () => tensor2x3.getValue([0, 0, 0]),
        throwsRangeErrorWith(name: 'key.length'),
      );
    });
  });
  group('operator[]', () {
    test('first', () {
      expect(
          tensor2[0],
          isTensor<int>(
            layout: isLayout(
              rank: 0,
              length: 1,
              offset: 0,
              shape: isEmpty,
              strides: isEmpty,
            ),
            object: 0,
          ));
      expect(
          tensor2x3[0],
          isTensor<int>(
            layout: isLayout(
              rank: 1,
              length: 3,
              offset: 0,
              shape: [3],
              strides: [1],
            ),
            object: [0, 1, 2],
          ));
      expect(
          tensor2x3x4[0],
          isTensor<int>(
            layout: isLayout(
              rank: 2,
              length: 12,
              offset: 0,
              shape: [3, 4],
              strides: [4, 1],
            ),
            object: [
              [0, 1, 2, 3],
              [4, 5, 6, 7],
              [8, 9, 10, 11]
            ],
          ));
    });
    test('last', () {
      expect(
          tensor2[-1],
          isTensor<int>(
            layout: isLayout(
              rank: 0,
              length: 1,
              offset: 1,
              shape: isEmpty,
              strides: isEmpty,
            ),
            object: 1,
          ));
      expect(
          tensor2x3[-1],
          isTensor<int>(
            layout: isLayout(
              rank: 1,
              length: 3,
              offset: 3,
              shape: [3],
              strides: [1],
            ),
            object: [3, 4, 5],
          ));
      expect(
          tensor2x3x4[-1],
          isTensor<int>(
            layout: isLayout(
              rank: 2,
              length: 12,
              offset: 12,
              shape: [3, 4],
              strides: [4, 1],
            ),
            object: [
              [12, 13, 14, 15],
              [16, 17, 18, 19],
              [20, 21, 22, 23],
            ],
          ));
    });
    test('repeated', () {
      expect(
          tensor2x3[0][1],
          isTensor<int>(
            layout: isLayout(
              rank: 0,
              length: 1,
              offset: 1,
              shape: isEmpty,
              strides: isEmpty,
            ),
            object: 1,
          ));
      expect(
          tensor2x3x4[0][1],
          isTensor<int>(
            layout: isLayout(
              rank: 1,
              length: 4,
              offset: 4,
              shape: [4],
              strides: [1],
            ),
            object: [4, 5, 6, 7],
          ));
      expect(
          tensor2x3x4[0][1][2],
          isTensor<int>(
            layout: isLayout(
              rank: 0,
              length: 1,
              offset: 6,
              shape: isEmpty,
              strides: isEmpty,
            ),
            object: 6,
          ));
    });
    test('axis error', () {
      expect(
        () => value[0],
        throwsRangeErrorWith(name: 'axis'),
      );
    });
    test('index error', () {
      expect(
        () => tensor2[2],
        throwsRangeErrorWith(name: 'index'),
      );
      expect(
        () => tensor2[-3],
        throwsRangeErrorWith(name: 'index'),
      );
    });
  });
  group('elementAt', () {
    test('first', () {
      expect(
          tensor2x3x4.elementAt(0, axis: 0),
          isTensor<int>(
            layout: isLayout(
              rank: 2,
              length: 12,
              offset: 0,
              shape: [3, 4],
              strides: [4, 1],
            ),
            object: [
              [0, 1, 2, 3],
              [4, 5, 6, 7],
              [8, 9, 10, 11],
            ],
          ));
      expect(
          tensor2x3x4.elementAt(0, axis: 1),
          isTensor<int>(
            layout: isLayout(
              rank: 2,
              length: 8,
              offset: 0,
              shape: [2, 4],
              strides: [12, 1],
            ),
            object: [
              [0, 1, 2, 3],
              [12, 13, 14, 15],
            ],
          ));
      expect(
          tensor2x3x4.elementAt(0, axis: 2),
          isTensor<int>(
            layout: isLayout(
              rank: 2,
              length: 6,
              offset: 0,
              shape: [2, 3],
              strides: [12, 4],
            ),
            object: [
              [0, 4, 8],
              [12, 16, 20],
            ],
          ));
    });
    test('middle', () {
      expect(
          tensor2x3x4.elementAt(1, axis: 0),
          isTensor<int>(
            layout: isLayout(
              rank: 2,
              length: 12,
              offset: 12,
              shape: [3, 4],
              strides: [4, 1],
            ),
            object: [
              [12, 13, 14, 15],
              [16, 17, 18, 19],
              [20, 21, 22, 23],
            ],
          ));
      expect(
          tensor2x3x4.elementAt(1, axis: 1),
          isTensor<int>(
            layout: isLayout(
              rank: 2,
              length: 8,
              offset: 4,
              shape: [2, 4],
              strides: [12, 1],
            ),
            object: [
              [4, 5, 6, 7],
              [16, 17, 18, 19],
            ],
          ));
      expect(
          tensor2x3x4.elementAt(2, axis: 2),
          isTensor<int>(
            layout: isLayout(
              rank: 2,
              length: 6,
              offset: 2,
              shape: [2, 3],
              strides: [12, 4],
            ),
            object: [
              [2, 6, 10],
              [14, 18, 22],
            ],
          ));
    });
    test('last', () {
      expect(
          tensor2x3x4.elementAt(-1, axis: 0),
          isTensor<int>(
            layout: isLayout(
              rank: 2,
              length: 12,
              offset: 12,
              shape: [3, 4],
              strides: [4, 1],
            ),
            object: [
              [12, 13, 14, 15],
              [16, 17, 18, 19],
              [20, 21, 22, 23],
            ],
          ));
      expect(
          tensor2x3x4.elementAt(-1, axis: 1),
          isTensor<int>(
            layout: isLayout(
              rank: 2,
              length: 8,
              offset: 8,
              shape: [2, 4],
              strides: [12, 1],
            ),
            object: [
              [8, 9, 10, 11],
              [20, 21, 22, 23],
            ],
          ));
      expect(
          tensor2x3x4.elementAt(-1, axis: 2),
          isTensor<int>(
            layout: isLayout(
              rank: 2,
              length: 6,
              offset: 3,
              shape: [2, 3],
              strides: [12, 4],
            ),
            object: [
              [3, 7, 11],
              [15, 19, 23],
            ],
          ));
    });
    test('repeated', () {
      for (final axis in IntegerRange(tensor2x3x4x5.rank).permutations()) {
        var tensor = tensor2x3x4x5;
        for (var i = 0; i < axis.length; i++) {
          tensor = tensor.elementAt(axis[i],
              axis: axis[i] - axis.take(i).count((a) => a < axis[i]));
        }
        expect(
            tensor,
            isTensor<int>(
              layout: isLayout(
                rank: 0,
                length: 1,
                offset: 33,
                shape: isEmpty,
                strides: isEmpty,
              ),
              object: 33,
            ));
      }
    });
    test('axis error', () {
      expect(
        () => tensor2x3x4.elementAt(0, axis: 3),
        throwsRangeErrorWith(name: 'axis'),
      );
      expect(
        () => tensor2x3x4.elementAt(0, axis: -4),
        throwsRangeErrorWith(name: 'axis'),
      );
    });
    test('index error', () {
      expect(
        () => tensor2.elementAt(2),
        throwsRangeErrorWith(name: 'index'),
      );
      expect(
        () => tensor2.elementAt(-3),
        throwsRangeErrorWith(name: 'index'),
      );
    });
  });
  group('getRange', () {
    test('same', () {
      expect(
          tensor2x3x4.getRange(0, 2),
          isTensor<int>(
            layout: tensor2x3x4.layout,
            object: tensor2x3x4.toObject(),
          ));
      expect(
          tensor2x3x4.getRange(0, 3, axis: 1),
          isTensor<int>(
            layout: tensor2x3x4.layout,
            object: tensor2x3x4.toObject(),
          ));
      expect(
          tensor2x3x4.getRange(0, 4, axis: 2),
          isTensor<int>(
            layout: tensor2x3x4.layout,
            object: tensor2x3x4.toObject(),
          ));
    });
    test('first', () {
      expect(
          tensor2x3x4.getRange(0, 1),
          isTensor<int>(
            layout: isLayout(
              rank: 3,
              length: 12,
              offset: 0,
              shape: [1, 3, 4],
              strides: [12, 4, 1],
            ),
            object: [
              [
                [0, 1, 2, 3],
                [4, 5, 6, 7],
                [8, 9, 10, 11],
              ]
            ],
          ));
      expect(
          tensor2x3x4.getRange(0, 1, axis: 1),
          isTensor<int>(
            layout: isLayout(
              rank: 3,
              length: 8,
              offset: 0,
              shape: [2, 1, 4],
              strides: [12, 4, 1],
            ),
            object: [
              [
                [0, 1, 2, 3],
              ],
              [
                [12, 13, 14, 15],
              ],
            ],
          ));
      expect(
          tensor2x3x4.getRange(0, 1, axis: 2),
          isTensor<int>(
            layout: isLayout(
              rank: 3,
              length: 6,
              offset: 0,
              shape: [2, 3, 1],
              strides: [12, 4, 1],
            ),
            object: [
              [
                [0],
                [4],
                [8],
              ],
              [
                [12],
                [16],
                [20],
              ],
            ],
          ));
    });
    test('middle', () {
      expect(
          tensor2x3x4.getRange(1, -1, axis: 1),
          isTensor<int>(
            layout: isLayout(
              rank: 3,
              length: 8,
              offset: 4,
              shape: [2, 1, 4],
              strides: [12, 4, 1],
            ),
            object: [
              [
                [4, 5, 6, 7],
              ],
              [
                [16, 17, 18, 19],
              ],
            ],
          ));
      expect(
          tensor2x3x4.getRange(1, -1, axis: 2),
          isTensor<int>(
            layout: isLayout(
              rank: 3,
              length: 12,
              offset: 1,
              shape: [2, 3, 2],
              strides: [12, 4, 1],
            ),
            object: [
              [
                [1, 2],
                [5, 6],
                [9, 10],
              ],
              [
                [13, 14],
                [17, 18],
                [21, 22],
              ],
            ],
          ));
    });
    test('last', () {
      expect(
          tensor2x3x4.getRange(-1, null),
          isTensor<int>(
            layout: isLayout(
              rank: 3,
              length: 12,
              offset: 12,
              shape: [1, 3, 4],
              strides: [12, 4, 1],
            ),
            object: [
              [
                [12, 13, 14, 15],
                [16, 17, 18, 19],
                [20, 21, 22, 23],
              ],
            ],
          ));
      expect(
          tensor2x3x4.getRange(-1, null, axis: 1),
          isTensor<int>(
            layout: isLayout(
              rank: 3,
              length: 8,
              offset: 8,
              shape: [2, 1, 4],
              strides: [12, 4, 1],
            ),
            object: [
              [
                [8, 9, 10, 11],
              ],
              [
                [20, 21, 22, 23],
              ],
            ],
          ));
      expect(
          tensor2x3x4.getRange(-1, null, axis: 2),
          isTensor<int>(
            layout: isLayout(
              rank: 3,
              length: 6,
              offset: 3,
              shape: [2, 3, 1],
              strides: [12, 4, 1],
            ),
            object: [
              [
                [3],
                [7],
                [11],
              ],
              [
                [15],
                [19],
                [23],
              ],
            ],
          ));
    });
    test('step', () {
      expect(
          tensor2x3x4.getRange(0, 4, axis: 2, step: 2),
          isTensor<int>(
            layout: isLayout(
              rank: 3,
              length: 12,
              offset: 0,
              shape: [2, 3, 2],
              strides: [12, 4, 2],
            ),
            object: [
              [
                [0, 2],
                [4, 6],
                [8, 10],
              ],
              [
                [12, 14],
                [16, 18],
                [20, 22],
              ],
            ],
          ));
      expect(
          tensor2x3x4.getRange(0, 4, axis: 2, step: 3),
          isTensor<int>(
            layout: isLayout(
              rank: 3,
              length: 6,
              offset: 0,
              shape: [2, 3, 1],
              strides: [12, 4, 3],
            ),
            object: [
              [
                [0],
                [4],
                [8],
              ],
              [
                [12],
                [16],
                [20],
              ],
            ],
          ));
    });
    test('axis error', () {
      expect(
        () => tensor2x3x4.getRange(0, 0, axis: 3),
        throwsRangeErrorWith(name: 'axis'),
      );
    });
    test('start error', () {
      expect(
        () => tensor2.getRange(3, 0),
        throwsRangeErrorWith(name: 'start'),
      );
      expect(
        () => tensor2.getRange(-3, 0),
        throwsRangeErrorWith(name: 'start'),
      );
    });
    test('end error', () {
      expect(
        () => tensor2.getRange(0, 3),
        throwsRangeErrorWith(name: 'end'),
      );
      expect(
        () => tensor2.getRange(1, 0),
        throwsRangeErrorWith(name: 'end'),
      );
    });
    test('step error', () {
      expect(
        () => tensor2.getRange(0, 2, step: -1),
        throwsRangeErrorWith(name: 'step'),
      );
      expect(
        () => tensor2.getRange(0, 2, step: 0),
        throwsRangeErrorWith(name: 'step'),
      );
    });
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
      final object = DataType.nullableObject<int>();
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
  group('copy', () {
    test('default', () {
      final source = tensor2x3x4x5.elementAt(2, axis: 2);
      final target = source.copy();
      expect(
          target,
          isTensor<int>(
            type: source.type,
            data: allOf(isNot(same(source.data)), source.data),
            layout: source.layout,
          ));
    });
    test('contiguous', () {
      final source = tensor2x3x4x5.elementAt(2, axis: 2);
      final target = source.copy(contiguous: true);
      expect(
          target,
          isTensor<int>(
            type: source.type,
            data: isNot(source.data),
            layout: isLayout(
              rank: source.rank,
              length: source.length,
              offset: 0,
              shape: [2, 3, 5],
              strides: [15, 5, 1],
              isContiguous: true,
            ),
          ));
    });
  });
  group('contiguous', () {
    test('already contiguous', () {
      final source = tensor2x3x4;
      final target = source.contiguous();
      expect(target, same(source));
    });
    test('not contiguous', () {
      final source = tensor2x3x4x5.elementAt(2, axis: 2);
      final target = source.copy(contiguous: true);
      expect(
          target,
          isTensor<int>(
            type: source.type,
            data: isNot(source.data),
            layout: isLayout(
              rank: source.rank,
              length: source.length,
              offset: 0,
              shape: [2, 3, 5],
              strides: [15, 5, 1],
              isContiguous: true,
            ),
            object: source.toObject(),
          ));
    });
  });
  group('broadcast', () {
    void validateBroadcast(
        Layout aSource, Layout bSource, dynamic aTarget, dynamic bTarget) {
      final (a1, b1) = aSource.broadcast(bSource);
      final (b2, a2) = bSource.broadcast(aSource);
      expect(a1, aTarget);
      expect(b1, bTarget);
      expect(a2, aTarget);
      expect(b2, bTarget);
      expect(a1, a2);
      expect(b1, b2);
    }

    test('same shape', () {
      final as = Layout(shape: const [5, 7, 3]);
      final bs = Layout(shape: const [5, 7, 3]);
      validateBroadcast(as, bs, same(as), same(bs));
    });
    test('missing dimensions', () {
      final as = Layout(shape: const [], offset: 3);
      final bs = Layout(shape: const [2, 2], offset: 7);
      validateBroadcast(
          as,
          bs,
          isLayout(
            offset: 3,
            length: 4,
            shape: [2, 2],
            strides: [0, 0],
          ),
          isLayout(
            offset: 7,
            length: 4,
            shape: [2, 2],
            strides: [2, 1],
          ));
    });
    test('trailing dimensions', () {
      final as = Layout(shape: const [5, 3, 4, 1]);
      final bs = Layout(shape: const [3, 1, 1]);
      validateBroadcast(
          as,
          bs,
          isLayout(
            offset: 0,
            length: 60,
            shape: [5, 3, 4, 1],
            strides: [12, 4, 1, 1],
          ),
          isLayout(
            offset: 0,
            length: 60,
            shape: [5, 3, 4, 1],
            strides: [0, 1, 0, 1],
          ));
    });
    test('singular dimension', () {
      final as = Layout(shape: const [256, 256, 3]);
      final bs = Layout(shape: const [3]);
      validateBroadcast(
          as,
          bs,
          isLayout(
            offset: as.offset,
            length: 196608,
            shape: [256, 256, 3],
            strides: as.strides,
          ),
          isLayout(
            offset: as.offset,
            length: 196608,
            shape: [256, 256, 3],
            strides: [0, 0, 1],
          ));
    });
    test('mixed dimensions', () {
      final as = Layout(shape: const [8, 1, 6, 1]);
      final bs = Layout(shape: const [7, 1, 5]);
      validateBroadcast(
          as,
          bs,
          isLayout(
            offset: as.offset,
            length: 1680,
            shape: [8, 7, 6, 5],
            strides: [6, 0, 1, 0],
          ),
          isLayout(
            offset: as.offset,
            length: 1680,
            shape: [8, 7, 6, 5],
            strides: [0, 5, 0, 1],
          ));
    });
    test('error empty', () {
      final layout = Layout(shape: const [1, 2, 3]);
      expect(
        () => Layout.empty.broadcast(layout),
        throwsLayoutErrorWith(message: matches('is empty')),
      );
      expect(
        () => layout.broadcast(Layout.empty),
        throwsLayoutErrorWith(message: matches('is empty')),
      );
    });
    test('error incompatible', () {
      final first = Layout(shape: const [5, 2, 4, 1]);
      final second = Layout(shape: const [3, 1, 1]);
      expect(
        () => first.broadcast(second),
        throwsLayoutErrorWith(
            message: matches('incompatible shape at 1 and 0')),
      );
      expect(
        () => second.broadcast(first),
        throwsLayoutErrorWith(
            message: matches('incompatible shape at 0 and 1')),
      );
    });
  });
  group('operations', () {
    group('broadcasting', () {
      test('same shape', () {
        final a = Tensor<int>.fromObject([1, 2, 3]);
        final b = Tensor<int>.fromObject([10, 20, 30]);
        expect(a + b, isTensor<int>(object: [11, 22, 33]));
      });
      test('stretch scalar', () {
        final a = Tensor<int>.fromObject([1, 2, 3]);
        final b = Tensor<int>.fromObject([10]);
        expect(a + b, isTensor<int>(object: [11, 12, 13]));
      });
      test('stretch vector', () {
        final a = Tensor<int>.fromObject([
          [1, 2, 3],
          [4, 5, 6],
        ]);
        final b = Tensor<int>.fromObject([10, 20, 30]);
        expect(
            a + b,
            isTensor<int>(object: [
              [11, 22, 33],
              [14, 25, 36],
            ]));
      });
      test('outer vectors', () {
        final a = Tensor<int>.fromIterable([1, 2, 3]).expand(axis: 1);
        final b = Tensor<int>.fromIterable([10, 20, 30]);
        expect(
            a + b,
            isTensor<int>(object: [
              [11, 21, 31],
              [12, 22, 32],
              [13, 23, 33],
            ]));
      });
    });
    group('operation', () {
      group('unary', () {
        final neg = DataType.integer.field.neg;
        test('default', () {
          final a = Tensor<int>.fromIterable([1, 2, 3]);
          final r = a.unaryOperation(neg);
          expect(r, isNot(same(a)));
          expect(r, isTensor<int>(object: [-1, -2, -3]));
        });
        test('in-place', () {
          final a = Tensor<int>.fromIterable([1, 2, 3], type: DataType.int8);
          final r = a.unaryOperation(neg, target: a);
          expect(r, same(a));
          expect(r, isTensor<int>(object: [-1, -2, -3]));
        });
        test('unrelated', () {
          final a = Tensor<int>.fromIterable([1, 2, 3]);
          final b = Tensor<int>.filled(0, shape: [3], type: DataType.int8);
          final r = a.unaryOperation(neg, target: b);
          expect(r, same(b));
          expect(r, isTensor<int>(object: [-1, -2, -3]));
        });
        test('error', () {
          final a = Tensor<int>.fromIterable([1, 2, 3]);
          final r1 = Tensor<int>.filled(0, shape: [3, 2]);
          final r2 = Tensor<int>.filled(0, shape: [2]);
          expect(
            () => a.unaryOperation(neg, target: r1),
            throwsLayoutErrorWith(message: matches('incompatible rank')),
          );
          expect(
            () => a.unaryOperation(neg, target: r2),
            throwsLayoutErrorWith(message: matches('incompatible shape')),
          );
        });
      });
      group('binary', () {
        final add = DataType.integer.field.add;
        test('default', () {
          final a = Tensor<int>.fromIterable([1, 2, 3]);
          final b = Tensor<int>.fromIterable([10, 20, 30]);
          final r = a.binaryOperation(b, add);
          expect(r, allOf(isNot(same(a)), isNot(same(b))));
          expect(r, isTensor<int>(object: [11, 22, 33]));
        });
        test('in-place (receiver)', () {
          final a = Tensor<int>.fromIterable([1, 2, 3]);
          final b = Tensor<int>.fromIterable([10, 20, 30]);
          final r = a.binaryOperation(b, add, target: a);
          expect(r, allOf(same(a), isNot(same(b))));
          expect(r, isTensor<int>(object: [11, 22, 33]));
        });
        test('in-place (argument)', () {
          final a = Tensor<int>.fromIterable([1, 2, 3]);
          final b = Tensor<int>.fromIterable([10, 20, 30]);
          final r = a.binaryOperation(b, add, target: b);
          expect(r, allOf(isNot(same(a)), same(b)));
          expect(r, isTensor<int>(object: [11, 22, 33]));
        });
        test('unrelated', () {
          final a = Tensor<int>.fromIterable([1, 2, 3]);
          final b = Tensor<int>.fromIterable([10, 20, 30]);
          final c = Tensor<int>.filled(0, shape: [3], type: DataType.int8);
          final r = a.binaryOperation(b, add, target: c);
          expect(r, allOf(isNot(same(a)), isNot(same(b)), same(c)));
          expect(r, isTensor<int>(object: [11, 22, 33]));
        });
        test('error', () {
          final a = Tensor<int>.fromIterable([1, 2, 3]);
          final b = Tensor<int>.fromIterable([10, 20]);
          expect(
            () => a.binaryOperation(b, add),
            throwsLayoutErrorWith(message: matches('incompatible shape')),
          );
          expect(
            () => a.binaryOperation(a, add, target: b),
            throwsLayoutErrorWith(message: matches('incompatible shape')),
          );
        });
      });
      group('math', () {
        test('neg', () {
          final a = Tensor<int>.fromIterable([1, 2, 3]);
          expect(-a, isTensor<int>(object: [-1, -2, -3]));
        });
        test('add', () {
          final a = Tensor<int>.fromIterable([1, 2, 3]);
          final b = Tensor<int>.fromIterable([4, 5, 6]);
          expect(a + b, isTensor<int>(object: [5, 7, 9]));
        });
        test('sub', () {
          final a = Tensor<int>.fromIterable([1, 2, 3]);
          final b = Tensor<int>.fromIterable([4, 5, 6]);
          expect(a - b, isTensor<int>(object: [-3, -3, -3]));
        });
        test('mul', () {
          final a = Tensor<int>.fromIterable([1, 2, 3]);
          final b = Tensor<int>.fromIterable([4, 5, 6]);
          expect(a * b, isTensor<int>(object: [4, 10, 18]));
        });
        test('div', () {
          final a = Tensor<int>.fromIterable([12, 24, 48]);
          final b = Tensor<int>.fromIterable([2, 8, 6]);
          expect(a / b, isTensor<int>(object: [6, 3, 8]));
        });
        test('div', () {
          final a = Tensor<int>.fromIterable([12, 24, 48]);
          final b = Tensor<int>.fromIterable([2, 8, 6]);
          expect(a ~/ b, isTensor<int>(object: [6, 3, 8]));
        });
        test('mod', () {
          final a = Tensor<int>.fromIterable([6, 5, 4]);
          final b = Tensor<int>.fromIterable([3, 2, 1]);
          expect(a % b, isTensor<int>(object: [0, 1, 0]));
        });
      });
      group('comparison', () {
        test('less than', () {
          final a = Tensor<int>.fromIterable([4, 2, 4]);
          final b = Tensor<int>.fromIterable([4, 4, 2]);
          expect(a < b, isTensor<bool>(object: [false, true, false]));
        });
        test('less than or equal to', () {
          final a = Tensor<int>.fromIterable([4, 2, 4]);
          final b = Tensor<int>.fromIterable([4, 4, 2]);
          expect(a <= b, isTensor<bool>(object: [true, true, false]));
        });
        test('greater than', () {
          final a = Tensor<int>.fromIterable([4, 2, 4]);
          final b = Tensor<int>.fromIterable([4, 4, 2]);
          expect(a > b, isTensor<bool>(object: [false, false, true]));
        });
        test('greater than or equal to', () {
          final a = Tensor<int>.fromIterable([4, 2, 4]);
          final b = Tensor<int>.fromIterable([4, 4, 2]);
          expect(a >= b, isTensor<bool>(object: [true, false, true]));
        });
        test('equal to', () {
          final a = Tensor<int>.fromIterable([4, 2, 4]);
          final b = Tensor<int>.fromIterable([4, 4, 2]);
          expect(a.equalTo(b), isTensor<bool>(object: [true, false, false]));
        });
        test('not equal to', () {
          final a = Tensor<int>.fromIterable([4, 2, 4]);
          final b = Tensor<int>.fromIterable([4, 4, 2]);
          expect(a.notEqualTo(b), isTensor<bool>(object: [false, true, true]));
        });
      });
      group('logical', () {
        test('not', () {
          final a = Tensor<bool>.fromIterable([true, false]);
          expect(~a, isTensor<bool>(object: [false, true]));
        });
        test('and', () {
          final a = Tensor<bool>.fromIterable([true, true, false, false]);
          final b = Tensor<bool>.fromIterable([true, false, true, false]);
          expect(a & b, isTensor<bool>(object: [true, false, false, false]));
        });
        test('or', () {
          final a = Tensor<bool>.fromIterable([true, true, false, false]);
          final b = Tensor<bool>.fromIterable([true, false, true, false]);
          expect(a | b, isTensor<bool>(object: [true, true, true, false]));
        });
      });
    });
  });
  group('flip', () {
    test('default', () {
      expect(
          tensor2x2x2.flip(),
          isTensor<int>(
            layout: isLayout(
              rank: 3,
              length: 8,
              offset: 4,
              shape: [2, 2, 2],
              strides: [-4, 2, 1],
            ),
            data: same(tensor2x2x2.data),
            object: [
              [
                [4, 5],
                [6, 7],
              ],
              [
                [0, 1],
                [2, 3],
              ],
            ],
          ));
    });
    test('axis = 0', () {
      expect(
          tensor2x2x2.flip(axis: 0),
          isTensor<int>(
            layout: isLayout(
              rank: 3,
              length: 8,
              offset: 4,
              shape: [2, 2, 2],
              strides: [-4, 2, 1],
            ),
            data: same(tensor2x2x2.data),
            object: [
              [
                [4, 5],
                [6, 7],
              ],
              [
                [0, 1],
                [2, 3],
              ],
            ],
          ));
    });
    test('axis = 1', () {
      expect(
          tensor2x2x2.flip(axis: 1),
          isTensor<int>(
              layout: isLayout(
                rank: 3,
                length: 8,
                offset: 2,
                shape: [2, 2, 2],
                strides: [4, -2, 1],
              ),
              data: same(tensor2x2x2.data),
              object: [
                [
                  [2, 3],
                  [0, 1],
                ],
                [
                  [6, 7],
                  [4, 5],
                ],
              ]));
    });
    test('axis = -1', () {
      expect(
          tensor2x2x2.flip(axis: -1),
          isTensor<int>(
              layout: isLayout(
                rank: 3,
                length: 8,
                offset: 1,
                shape: [2, 2, 2],
                strides: [4, 2, -1],
              ),
              data: same(tensor2x2x2.data),
              object: [
                [
                  [1, 0],
                  [3, 2],
                ],
                [
                  [5, 4],
                  [7, 6],
                ],
              ]));
    });
    test('composed', () {
      expect(
          tensor2x2x2.flip(axis: 0).flip(axis: 2),
          isTensor<int>(
              layout: isLayout(
                rank: 3,
                length: 8,
                offset: 5,
                shape: [2, 2, 2],
                strides: [-4, 2, -1],
              ),
              data: same(tensor2x2x2.data),
              object: [
                [
                  [5, 4],
                  [7, 6],
                ],
                [
                  [1, 0],
                  [3, 2],
                ],
              ]));
    });
    test('reversible', () {
      for (var i = 0; i < tensor2x3x4x5.rank; i++) {
        expect(
            tensor2x3x4x5.flip(axis: i).flip(axis: i),
            isTensor<int>(
              layout: tensor2x3x4x5.layout,
              data: same(tensor2x3x4x5.data),
            ));
      }
    });
    test('error', () {
      expect(
        () => tensor2x2x2.flip(axis: 3),
        throwsRangeErrorWith(name: 'axis'),
      );
      expect(
        () => tensor2x2x2.flip(axis: -4),
        throwsRangeErrorWith(name: 'axis'),
      );
    });
  });
}
