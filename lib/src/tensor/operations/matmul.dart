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

    final mRows = layout.shape[rank - 2];
    final kDim = layout.shape[rank - 1];
    final otherK = other.layout.shape[other.rank - 2];
    final nCols = other.layout.shape[other.rank - 1];

    if (kDim != otherK) {
      throw ArgumentError('Inner dimensions must match: $kDim != $otherK');
    }

    final thisBatch = layout.shape.sublist(0, rank - 2);
    final otherBatch = other.layout.shape.sublist(0, other.rank - 2);
    final batchShape = _broadcastBatchShapes(thisBatch, otherBatch);
    final outShape = [...batchShape, mRows, nCols];

    final hasHazard =
        target != null &&
        (sharesMemory(target.data, data) ||
            sharesMemory(target.data, other.data));
    final result = (target != null && !hasHazard)
        ? target
        : Tensor<T>.filled(type.defaultValue, shape: outShape, type: type);
    final field = type.field;

    // Fast 2D path
    if (rank == 2 && other.rank == 2) {
      _gemm2D(this, other, result, mRows, kDim, nCols, field);
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

      final aSlice = _slice2D(this, aKey, mRows, kDim);
      final bSlice = _slice2D(other, bKey, kDim, nCols);
      final cSlice = _slice2D(result, batchKey, mRows, nCols);

      _gemm2D(aSlice, bSlice, cSlice, mRows, kDim, nCols, field);
    }

    if (hasHazard) {
      result.copy(target: target);
      return target;
    }
    return result;
  }

  static void _gemm2D<T>(
    Tensor<T> tensorA,
    Tensor<T> tensorB,
    Tensor<T> tensorC,
    int rowsA,
    int innerDim,
    int colsB,
    Field<T> field,
  ) {
    // Transparent hardware acceleration when contiguous or transposed row-major
    int? transA;
    int? lda;
    if (tensorA.layout.strides[1] == 1 &&
        (tensorA.layout.strides[0] >= innerDim || rowsA == 1)) {
      transA = cblasNoTrans;
      lda = rowsA == 1
          ? (innerDim > 0 ? innerDim : 1)
          : tensorA.layout.strides[0];
    } else if (tensorA.layout.strides[0] == 1 &&
        (tensorA.layout.strides[1] >= rowsA || innerDim == 1)) {
      transA = cblasTrans;
      lda = innerDim == 1 ? (rowsA > 0 ? rowsA : 1) : tensorA.layout.strides[1];
    }

    int? transB;
    int? ldb;
    if (tensorB.layout.strides[1] == 1 &&
        (tensorB.layout.strides[0] >= colsB || innerDim == 1)) {
      transB = cblasNoTrans;
      ldb = innerDim == 1 ? (colsB > 0 ? colsB : 1) : tensorB.layout.strides[0];
    } else if (tensorB.layout.strides[0] == 1 &&
        (tensorB.layout.strides[1] >= innerDim || colsB == 1)) {
      transB = cblasTrans;
      ldb = colsB == 1
          ? (innerDim > 0 ? innerDim : 1)
          : tensorB.layout.strides[1];
    }

    int? ldc;
    if (tensorC.layout.strides[1] == 1 &&
        (tensorC.layout.strides[0] >= colsB || rowsA == 1)) {
      ldc = rowsA == 1 ? (colsB > 0 ? colsB : 1) : tensorC.layout.strides[0];
    }

    if (transA != null && transB != null && ldc != null) {
      if (tensorA.data is Float64List &&
          tensorB.data is Float64List &&
          tensorC.data is Float64List) {
        final success = HardwareManager.dgemm(
          transA: transA,
          transB: transB,
          m: rowsA,
          n: colsB,
          k: innerDim,
          alpha: 1.0,
          a: tensorA.data as Float64List,
          aOffset: tensorA.offset,
          lda: lda!,
          b: tensorB.data as Float64List,
          bOffset: tensorB.offset,
          ldb: ldb!,
          beta: 0.0,
          c: tensorC.data as Float64List,
          cOffset: tensorC.offset,
          ldc: ldc,
        );
        if (success) return;
      } else if (tensorA.data is Float32List &&
          tensorB.data is Float32List &&
          tensorC.data is Float32List) {
        final success = HardwareManager.sgemm(
          transA: transA,
          transB: transB,
          m: rowsA,
          n: colsB,
          k: innerDim,
          alpha: 1.0,
          a: tensorA.data as Float32List,
          aOffset: tensorA.offset,
          lda: lda!,
          b: tensorB.data as Float32List,
          bOffset: tensorB.offset,
          ldb: ldb!,
          beta: 0.0,
          c: tensorC.data as Float32List,
          cOffset: tensorC.offset,
          ldc: ldc,
        );
        if (success) return;
      }
    }

    // Cache-friendly i -> kIdx -> j loop for row-major layouts (pure Dart fallback)
    for (var i = 0; i < rowsA; i++) {
      for (var kIdx = 0; kIdx < innerDim; kIdx++) {
        final aVal = tensorA.getValue([i, kIdx]);
        for (var j = 0; j < colsB; j++) {
          final prod = field.mul(aVal, tensorB.getValue([kIdx, j]));
          final cur = kIdx == 0
              ? field.additiveIdentity
              : tensorC.getValue([i, j]);
          tensorC.setValue([i, j], field.add(cur, prod));
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

  static Tensor<T> _slice2D<T>(
    Tensor<T> tensor,
    List<int> batchKey,
    int rows,
    int cols,
  ) {
    final indices = [...batchKey, 0, 0];
    final baseOffset = tensor.layout.toIndex(indices);
    final strides = [
      tensor.layout.strides[tensor.rank - 2],
      tensor.layout.strides[tensor.rank - 1],
    ];
    return Tensor<T>.internal(
      type: tensor.type,
      layout: Layout(shape: [rows, cols], strides: strides, offset: baseOffset),
      data: tensor.data,
    );
  }
}
