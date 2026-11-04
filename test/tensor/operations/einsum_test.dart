import 'package:checks/checks.dart';
import 'package:data/tensor.dart';
import 'package:data/type.dart';
import 'package:test/test.dart';

void main() {
  group('einsum basic contractions', () {
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

      // Transposed contraction output via tensordot path
      final resTrans = einsum('ij,jk->ki', [a, b]);
      check(resTrans.shape).deepEquals([2, 2]);
      check(resTrans.getValue([0, 0])).equals(19.0);
      check(resTrans.getValue([1, 0])).equals(22.0);
      check(resTrans.getValue([0, 1])).equals(43.0);
      check(resTrans.getValue([1, 1])).equals(50.0);
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
  });

  group('einsum permutations and batch operations', () {
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

      // Transposed output: bik -> bki
      final cTrans = einsum('bij,bjk->bki', [a, b]);
      check(cTrans.shape).deepEquals([2, 2, 2]);
      check(cTrans.getValue([0, 0, 0])).equals(3.0);
      check(cTrans.getValue([0, 1, 0])).equals(4.0);
      check(cTrans.getValue([1, 0, 0])).equals(2.0);
      check(cTrans.getValue([1, 1, 1])).equals(8.0);
    });

    test('batched matrix-vector multiplication', () {
      final a = Tensor<double>.fromIterable(
        [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0],
        shape: [2, 2, 2],
        type: DataType.float64,
      );
      final v = Tensor<double>.fromIterable(
        [1.0, 2.0, 3.0, 4.0],
        shape: [2, 2],
        type: DataType.float64,
      );

      // Batch 0: [[1, 2], [3, 4]] * [1, 2] = [5, 11]
      // Batch 1: [[5, 6], [7, 8]] * [3, 4] = [39, 53]
      final c = einsum('bij,bj->bi', [a, v]);
      check(c.shape).deepEquals([2, 2]);
      check(c.getValue([0, 0])).equals(5.0);
      check(c.getValue([0, 1])).equals(11.0);
      check(c.getValue([1, 0])).equals(39.0);
      check(c.getValue([1, 1])).equals(53.0);
    });

    test('batched vector-matrix multiplication', () {
      final v = Tensor<double>.fromIterable(
        [1.0, 2.0, 3.0, 4.0],
        shape: [2, 2],
        type: DataType.float64,
      );
      final a = Tensor<double>.fromIterable(
        [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0],
        shape: [2, 2, 2],
        type: DataType.float64,
      );

      // Batch 0: [1, 2] * [[1, 2], [3, 4]] = [7, 10]
      // Batch 1: [3, 4] * [[5, 6], [7, 8]] = [43, 50]
      final c = einsum('bj,bjk->bk', [v, a]);
      check(c.shape).deepEquals([2, 2]);
      check(c.getValue([0, 0])).equals(7.0);
      check(c.getValue([0, 1])).equals(10.0);
      check(c.getValue([1, 0])).equals(43.0);
      check(c.getValue([1, 1])).equals(50.0);
    });

    test('batched vector dot product and matrix inner product', () {
      final u = Tensor<double>.fromIterable(
        [1.0, 2.0, 3.0, 4.0],
        shape: [2, 2],
        type: DataType.float64,
      );
      final v = Tensor<double>.fromIterable(
        [5.0, 6.0, 7.0, 8.0],
        shape: [2, 2],
        type: DataType.float64,
      );

      // Batch 0: 1*5 + 2*6 = 17
      // Batch 1: 3*7 + 4*8 = 53
      final dot = einsum('bi,bi->b', [u, v]);
      check(dot.shape).deepEquals([2]);
      check(dot.getValue([0])).equals(17.0);
      check(dot.getValue([1])).equals(53.0);

      final a = Tensor<double>.fromIterable(
        [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0],
        shape: [2, 2, 2],
        type: DataType.float64,
      );
      // Batch 0: 1*1 + 2*2 + 3*3 + 4*4 = 30
      // Batch 1: 5*5 + 6*6 + 7*7 + 8*8 = 174
      final frob = einsum('bij,bij->b', [a, a]);
      check(frob.shape).deepEquals([2]);
      check(frob.getValue([0])).equals(30.0);
      check(frob.getValue([1])).equals(174.0);
    });

    test('multi-dimensional batching', () {
      final a = Tensor<double>.fromIterable(
        List.generate(16, (i) => (i + 1).toDouble()),
        shape: [2, 2, 2, 2],
        type: DataType.float64,
      );
      final b = Tensor<double>.fromIterable(
        List.generate(16, (i) => (i + 1).toDouble()),
        shape: [2, 2, 2, 2],
        type: DataType.float64,
      );

      final c = einsum('abij,abjk->abik', [a, b]);
      check(c.shape).deepEquals([2, 2, 2, 2]);
      // Slices (0, 0)
      // a[0, 0] = [[1, 2], [3, 4]], b[0, 0] = [[1, 2], [3, 4]]
      // c[0, 0] = [[7, 10], [15, 22]]
      check(c.getValue([0, 0, 0, 0])).equals(7.0);
      check(c.getValue([0, 0, 0, 1])).equals(10.0);
      check(c.getValue([0, 0, 1, 0])).equals(15.0);
      check(c.getValue([0, 0, 1, 1])).equals(22.0);
    });

    test('batched outer product', () {
      final u = Tensor<double>.fromIterable(
        [1.0, 2.0, 3.0, 4.0],
        shape: [2, 2],
        type: DataType.float64,
      );
      final v = Tensor<double>.fromIterable(
        [5.0, 6.0, 7.0, 8.0],
        shape: [2, 2],
        type: DataType.float64,
      );

      final outer = einsum('bi,bj->bij', [u, v]);
      check(outer.shape).deepEquals([2, 2, 2]);
      // Batch 0: [1, 2] outer [5, 6] = [[5, 6], [10, 12]]
      check(outer.getValue([0, 0, 0])).equals(5.0);
      check(outer.getValue([0, 0, 1])).equals(6.0);
      check(outer.getValue([0, 1, 0])).equals(10.0);
      check(outer.getValue([0, 1, 1])).equals(12.0);
      // Batch 1: [3, 4] outer [7, 8] = [[21, 24], [28, 32]]
      check(outer.getValue([1, 0, 0])).equals(21.0);
      check(outer.getValue([1, 0, 1])).equals(24.0);
      check(outer.getValue([1, 1, 0])).equals(28.0);
      check(outer.getValue([1, 1, 1])).equals(32.0);
    });

    test('contraction with strided and transposed inputs', () {
      final a = Tensor<double>.fromIterable(
        [1.0, 2.0, 3.0, 4.0, 5.0, 6.0],
        shape: [2, 3],
        type: DataType.float64,
      );
      final b = Tensor<double>.fromIterable(
        [7.0, 8.0, 9.0, 10.0, 11.0, 12.0],
        shape: [2, 3],
        type: DataType.float64,
      );

      // Transposed b has shape [3, 2]
      final bT = b.transpose([1, 0]);
      final c = einsum('ij,jk->ik', [a, bT]);
      check(c.shape).deepEquals([2, 2]);
      // [1, 2, 3] * [7, 8, 9] = 7 + 16 + 27 = 50
      check(c.getValue([0, 0])).equals(50.0);
      // [1, 2, 3] * [10, 11, 12] = 10 + 22 + 36 = 68
      check(c.getValue([0, 1])).equals(68.0);
      // [4, 5, 6] * [7, 8, 9] = 28 + 40 + 54 = 122
      check(c.getValue([1, 0])).equals(122.0);
      // [4, 5, 6] * [10, 11, 12] = 40 + 55 + 72 = 167
      check(c.getValue([1, 1])).equals(167.0);
    });

    test('fallback odometer with internal duplicate indices', () {
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

      // ii on a selects diagonal [1, 4], contracted with b columns: [1, 4] * [[5, 6], [7, 8]] = [33, 38]
      final res = einsum('ii,ik->k', [a, b]);
      check(res.shape).deepEquals([2]);
      check(res.getValue([0])).equals(33.0);
      check(res.getValue([1])).equals(38.0);
    });

    test('3-operand chain contraction via odometer loop', () {
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
      final c = Tensor<double>.fromIterable(
        [1.0, 0.0, 0.0, 1.0],
        shape: [2, 2],
        type: DataType.float64,
      );

      // ij,jk,kl->il is a * b * c. Since c = I, result is a * b: [[19, 22], [43, 50]]
      final res = einsum('ij,jk,kl->il', [a, b, c]);
      check(res.shape).deepEquals([2, 2]);
      check(res.getValue([0, 0])).equals(19.0);
      check(res.getValue([0, 1])).equals(22.0);
      check(res.getValue([1, 0])).equals(43.0);
      check(res.getValue([1, 1])).equals(50.0);
    });

    test('empty dimension and zero-length steps', () {
      final a = Tensor<double>.filled(
        1.0,
        shape: [0, 2],
        type: DataType.float64,
      );
      final b = Tensor<double>.filled(
        1.0,
        shape: [2, 3],
        type: DataType.float64,
      );

      final res = einsum('ij,jk->ik', [a, b]);
      check(res.shape).deepEquals([0, 3]);

      // Zero-step odometer fallback with 3 operands
      final c = Tensor<double>.filled(
        1.0,
        shape: [3, 0],
        type: DataType.float64,
      );
      final res3 = einsum('ij,jk,kl->il', [a, b, c]);
      check(res3.shape).deepEquals([0, 0]);
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
  });

  group('einsum error handling', () {
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
      check(() => einsum('i', [])).throws<ArgumentError>();
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
      check(() => einsum('ij->jk->ik', [a])).throws<ArgumentError>();
    });
  });
}
