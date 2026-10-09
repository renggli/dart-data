import 'dart:typed_data';

import '../../../type.dart';
import '../../hardware/cblas.dart';
import '../../hardware/hardware.dart';
import '../layout.dart';
import '../tensor.dart';

extension MatmulTensorExtension<T> on Tensor<T> {
  /// Multiplies this tensor with [other] using matrix multiplication semantics.
  /// Supports 2D and batched N-D matrix multiplication.
  Tensor<T> matmul(Tensor<T> other, {Tensor<T>? target}) {
    if (rank < 2 || other.rank < 2) {
      throw ArgumentError(
        'matmul requires tensors of rank >= 2, got $rank and ${other.rank}',
      );
    }

    final m = layout.shape[rank - 2];
    final k = layout.shape[rank - 1];
    final otherK = other.layout.shape[other.rank - 2];
    final n = other.layout.shape[other.rank - 1];

    if (k != otherK) {
      throw ArgumentError('Inner dimensions must match: $k != $otherK');
    }

    final thisBatch = layout.shape.sublist(0, rank - 2);
    final otherBatch = other.layout.shape.sublist(0, other.rank - 2);
    final batchShape = _broadcastBatchShapes(thisBatch, otherBatch);
    final outShape = [...batchShape, m, n];

    final hasHazard =
        target != null &&
        (sharesMemory(target.data, data) ||
            sharesMemory(target.data, other.data));
    final result = (target != null && !hasHazard)
        ? target
        : Tensor<T>.filled(type.defaultValue, shape: outShape, type: type);
    final f = type.field;

    // Fast 2D path
    if (rank == 2 && other.rank == 2) {
      _gemm2D(this, other, result, m, k, n, f);
      if (hasHazard) {
        result.copy(target: target);
        return target;
      }
      return result;
    }

    // Batched path
    final batchLayout = Layout(shape: batchShape);
    for (final batchKey in batchLayout.keys) {
      final aKey = _mapBatchKey(batchKey, thisBatch);
      final bKey = _mapBatchKey(batchKey, otherBatch);

      final aSlice = _slice2D(this, aKey, m, k);
      final bSlice = _slice2D(other, bKey, k, n);
      final cSlice = _slice2D(result, batchKey, m, n);

      _gemm2D(aSlice, bSlice, cSlice, m, k, n, f);
    }

    if (hasHazard) {
      result.copy(target: target);
      return target;
    }
    return result;
  }

  static void _gemm2D<T>(
    Tensor<T> a,
    Tensor<T> b,
    Tensor<T> c,
    int m,
    int k,
    int n,
    Field<T> f,
  ) {
    // Transparent hardware acceleration when contiguous or transposed row-major
    int? transA;
    int? lda;
    if (a.layout.strides[1] == 1 && (a.layout.strides[0] >= k || m == 1)) {
      transA = cblasNoTrans;
      lda = m == 1 ? (k > 0 ? k : 1) : a.layout.strides[0];
    } else if (a.layout.strides[0] == 1 &&
        (a.layout.strides[1] >= m || k == 1)) {
      transA = cblasTrans;
      lda = k == 1 ? (m > 0 ? m : 1) : a.layout.strides[1];
    }

    int? transB;
    int? ldb;
    if (b.layout.strides[1] == 1 && (b.layout.strides[0] >= n || k == 1)) {
      transB = cblasNoTrans;
      ldb = k == 1 ? (n > 0 ? n : 1) : b.layout.strides[0];
    } else if (b.layout.strides[0] == 1 &&
        (b.layout.strides[1] >= k || n == 1)) {
      transB = cblasTrans;
      ldb = n == 1 ? (k > 0 ? k : 1) : b.layout.strides[1];
    }

    int? ldc;
    if (c.layout.strides[1] == 1 && (c.layout.strides[0] >= n || m == 1)) {
      ldc = m == 1 ? (n > 0 ? n : 1) : c.layout.strides[0];
    }

    if (transA != null && transB != null && ldc != null) {
      if (a.data is Float64List &&
          b.data is Float64List &&
          c.data is Float64List) {
        final success = HardwareManager.dgemm(
          transA: transA,
          transB: transB,
          m: m,
          n: n,
          k: k,
          alpha: 1.0,
          a: a.data as Float64List,
          aOffset: a.offset,
          lda: lda!,
          b: b.data as Float64List,
          bOffset: b.offset,
          ldb: ldb!,
          beta: 0.0,
          c: c.data as Float64List,
          cOffset: c.offset,
          ldc: ldc,
        );
        if (success) return;
      } else if (a.data is Float32List &&
          b.data is Float32List &&
          c.data is Float32List) {
        final success = HardwareManager.sgemm(
          transA: transA,
          transB: transB,
          m: m,
          n: n,
          k: k,
          alpha: 1.0,
          a: a.data as Float32List,
          aOffset: a.offset,
          lda: lda!,
          b: b.data as Float32List,
          bOffset: b.offset,
          ldb: ldb!,
          beta: 0.0,
          c: c.data as Float32List,
          cOffset: c.offset,
          ldc: ldc,
        );
        if (success) return;
      }
    }

    // Cache-friendly i -> p -> j loop for row-major layouts (pure Dart fallback)
    for (var i = 0; i < m; i++) {
      for (var p = 0; p < k; p++) {
        final aVal = a.getValue([i, p]);
        for (var j = 0; j < n; j++) {
          final prod = f.mul(aVal, b.getValue([p, j]));
          final cur = p == 0 ? f.additiveIdentity : c.getValue([i, j]);
          c.setValue([i, j], f.add(cur, prod));
        }
      }
    }
  }

  static List<int> _broadcastBatchShapes(List<int> a, List<int> b) {
    final maxLen = a.length > b.length ? a.length : b.length;
    final result = List<int>.filled(maxLen, 0);
    for (var i = 0; i < maxLen; i++) {
      final aIdx = a.length - 1 - i;
      final bIdx = b.length - 1 - i;
      final aDim = aIdx >= 0 ? a[aIdx] : 1;
      final bDim = bIdx >= 0 ? b[bIdx] : 1;
      if (aDim != bDim && aDim != 1 && bDim != 1) {
        throw ArgumentError('Cannot broadcast batch shapes $a and $b');
      }
      result[maxLen - 1 - i] = aDim > bDim ? aDim : bDim;
    }
    return result;
  }

  static List<int> _mapBatchKey(List<int> fullBatchKey, List<int> targetBatch) {
    final offset = fullBatchKey.length - targetBatch.length;
    return List<int>.generate(targetBatch.length, (i) {
      final dim = targetBatch[i];
      return dim == 1 ? 0 : fullBatchKey[offset + i];
    });
  }

  static Tensor<T> _slice2D<T>(Tensor<T> t, List<int> batchKey, int r, int c) {
    final indices = [...batchKey, 0, 0];
    final baseOffset = t.layout.toIndex(indices);
    final strides = [
      t.layout.strides[t.rank - 2],
      t.layout.strides[t.rank - 1],
    ];
    return Tensor<T>.internal(
      type: t.type,
      layout: Layout(shape: [r, c], strides: strides, offset: baseOffset),
      data: t.data,
    );
  }
}
