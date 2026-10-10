import 'package:checks/checks.dart';
import 'package:data/tensor.dart';
import 'package:data/type.dart';
import 'package:test/test.dart';

void main() {
  group('einsum', () {
    test('vector dot product', () {
      final a = Tensor<double>.fromIterable(
        [1.0, 2.0, 3.0],
        shape: [3],
        type: DataType.float64,
      );
      final b = Tensor<double>.fromIterable(
        [4.0, 5.0, 6.0],
        shape: [3],
        type: DataType.float64,
      );

      final resExplicit = einsum('i,i->', [a, b]);
      check(resExplicit.rank).equals(0);
      check(resExplicit.getValue([])).equals(32.0);

      // Implicit output notation (no single indices remain -> scalar)
      final resImplicit = einsum('i,i', [a, b]);
      check(resImplicit.rank).equals(0);
      check(resImplicit.getValue([])).equals(32.0);
    });

    test('matrix multiplication', () {
      final a = Tensor<double>.fromIterable(
        [1.0, 2.0, 3.0, 4.0],
        shape: [2, 2],
        type: DataType.float64,
      );
      final b = Tensor<double>.fromIterable(
        [5.0, 6.0, 7.0, 8.0],
        shape: [2, 2],
        type: DataType.float64,
      );

      final res = einsum('ij,jk->ik', [a, b]);
      check(res.shape).deepEquals([2, 2]);
      check(res.getValue([0, 0])).equals(19.0);
      check(res.getValue([0, 1])).equals(22.0);
      check(res.getValue([1, 0])).equals(43.0);
      check(res.getValue([1, 1])).equals(50.0);

      // Implicit output notation: single indices are i and k
      final resImplicit = einsum('ij,jk', [a, b]);
      check(resImplicit.shape).deepEquals([2, 2]);
      check(resImplicit.getValue([0, 0])).equals(19.0);
    });

    test('matrix transpose', () {
      final a = Tensor<double>.fromIterable(
        [1.0, 2.0, 3.0, 4.0, 5.0, 6.0],
        shape: [2, 3],
        type: DataType.float64,
      );

      final trans = einsum('ij->ji', [a]);
      check(trans.shape).deepEquals([3, 2]);
      check(trans.getValue([0, 0])).equals(1.0);
      check(trans.getValue([1, 0])).equals(2.0);
      check(trans.getValue([2, 0])).equals(3.0);
      check(trans.getValue([0, 1])).equals(4.0);
    });

    test('matrix trace and diagonal extraction', () {
      final a = Tensor<double>.fromIterable(
        [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0],
        shape: [3, 3],
        type: DataType.float64,
      );

      // Trace: sum along diagonal
      final trace = einsum('ii->', [a]);
      check(trace.rank).equals(0);
      check(trace.getValue([])).equals(15.0); // 1 + 5 + 9

      // Diagonal extraction
      final diag = einsum('ii->i', [a]);
      check(diag.shape).deepEquals([3]);
      check(diag.getValue([0])).equals(1.0);
      check(diag.getValue([1])).equals(5.0);
      check(diag.getValue([2])).equals(9.0);
    });

    test('batched matrix multiplication', () {
      // Shape: [batch=2, 2, 2]
      final a = Tensor<double>.fromIterable(
        [
          // Batch 0
          1.0, 0.0,
          0.0, 1.0,
          // Batch 1
          2.0, 0.0,
          0.0, 2.0,
        ],
        shape: [2, 2, 2],
        type: DataType.float64,
      );

      final b = Tensor<double>.fromIterable(
        [
          // Batch 0
          3.0, 4.0,
          5.0, 6.0,
          // Batch 1
          1.0, 2.0,
          3.0, 4.0,
        ],
        shape: [2, 2, 2],
        type: DataType.float64,
      );

      final c = einsum('bij,bjk->bik', [a, b]);
      check(c.shape).deepEquals([2, 2, 2]);
      // Batch 0 is I * b[0] = b[0]
      check(c.getValue([0, 0, 0])).equals(3.0);
      check(c.getValue([0, 0, 1])).equals(4.0);
      // Batch 1 is 2I * b[1] = 2 * b[1]
      check(c.getValue([1, 0, 0])).equals(2.0);
      check(c.getValue([1, 1, 1])).equals(8.0);
    });

    test('matrix sum and vector sum', () {
      final a = Tensor<double>.fromIterable(
        [1.0, 2.0, 3.0, 4.0],
        shape: [2, 2],
        type: DataType.float64,
      );

      final totalSum = einsum('ij->', [a]);
      check(totalSum.getValue([])).equals(10.0);

      final rowSum = einsum('ij->i', [a]);
      check(rowSum.shape).deepEquals([2]);
      check(rowSum.getValue([0])).equals(3.0); // 1 + 2
      check(rowSum.getValue([1])).equals(7.0); // 3 + 4
    });

    test('multi-tensor contraction (3 operands)', () {
      final a = Tensor<double>.fromIterable(
        [1.0, 2.0],
        shape: [2],
        type: DataType.float64,
      );
      final b = Tensor<double>.fromIterable(
        [3.0, 4.0],
        shape: [2],
        type: DataType.float64,
      );
      final c = Tensor<double>.fromIterable(
        [5.0, 6.0],
        shape: [2],
        type: DataType.float64,
      );

      // Outer product of 3 vectors
      final outer3 = einsum('i,j,k->ijk', [a, b, c]);
      check(outer3.shape).deepEquals([2, 2, 2]);
      check(outer3.getValue([0, 0, 0])).equals(15.0); // 1 * 3 * 5
      check(outer3.getValue([1, 1, 1])).equals(48.0); // 2 * 4 * 6
    });

    test('error handling', () {
      final a = Tensor<double>.filled(
        1.0,
        shape: [2, 3],
        type: DataType.float64,
      );
      final b = Tensor<double>.filled(
        1.0,
        shape: [3, 4],
        type: DataType.float64,
      );

      // Mismatched operand count
      check(() => einsum('ij,jk->ik', [a])).throws<ArgumentError>();

      // Mismatched rank and label length
      check(() => einsum('ijk,jk->ik', [a, b])).throws<ArgumentError>();

      // Inconsistent dimension for same index
      final badB = Tensor<double>.filled(
        1.0,
        shape: [5, 4],
        type: DataType.float64,
      );
      check(() => einsum('ij,jk->ik', [a, badB])).throws<ArgumentError>();

      // Output index not in inputs
      check(() => einsum('ij,jk->iz', [a, b])).throws<ArgumentError>();

      // Duplicate output index
      check(() => einsum('ij,jk->ii', [a, b])).throws<ArgumentError>();
    });
  });
}
