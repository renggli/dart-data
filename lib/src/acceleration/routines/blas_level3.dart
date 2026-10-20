import 'dart:typed_data';

import '../blas/cblas.dart';
import '../fallback/pure_dart_blas3.dart';
import 'dispatcher.dart';

/// BLAS Level 3 matrix-matrix routines.
abstract final class BlasLevel3 {
  /// Computes matrix-matrix product `C = alpha * op(A) * op(B) + beta * C` for
  /// [Float64List].
  static bool dgemm({
    int transA = cblasNoTrans,
    int transB = cblasNoTrans,
    required int m,
    required int n,
    required int k,
    required double alpha,
    required Float64List a,
    int aOffset = 0,
    required int lda,
    required Float64List b,
    int bOffset = 0,
    required int ldb,
    required double beta,
    required Float64List c,
    int cOffset = 0,
    required int ldc,
    required BlasLibrary blas,
  }) {
    if (m < 0 || n < 0 || k < 0 || lda < 1 || ldb < 1 || ldc < 1) return false;
    if (transA != cblasNoTrans &&
        transA != cblasTrans &&
        transA != cblasConjTrans) {
      return false;
    }
    if (transB != cblasNoTrans &&
        transB != cblasTrans &&
        transB != cblasConjTrans) {
      return false;
    }
    final aRows = transA == cblasNoTrans ? m : k;
    final aCols = transA == cblasNoTrans ? k : m;
    final bRows = transB == cblasNoTrans ? k : n;
    final bCols = transB == cblasNoTrans ? n : k;
    if (lda < aCols || ldb < bCols || ldc < n) return false;
    if (m == 0 || n == 0) return true;
    final aReq = aOffset + (aRows - 1) * lda + aCols;
    final bReq = bOffset + (bRows - 1) * ldb + bCols;
    final cReq = cOffset + (m - 1) * ldc + n;
    if (a.length < aReq || b.length < bReq || c.length < cReq) return false;

    return executeAcceleratedOperation(
      feature: 'BLAS',
      operation: 'dgemm',
      isAvailable: blas.isAvailable,
      canAccelerate: m >= 64 || n >= 64 || k >= 64,
      accelerate: () => blas.dgemm(
        transA: transA,
        transB: transB,
        m: m,
        n: n,
        k: k,
        alpha: alpha,
        a: a,
        aOffset: aOffset,
        lda: lda,
        b: b,
        bOffset: bOffset,
        ldb: ldb,
        beta: beta,
        c: c,
        cOffset: cOffset,
        ldc: ldc,
      ),
      fallback: () => PureDartBlas3.gemmFloat64(
        transA: transA,
        transB: transB,
        m: m,
        n: n,
        k: k,
        alpha: alpha,
        a: a,
        aOffset: aOffset,
        lda: lda,
        b: b,
        bOffset: bOffset,
        ldb: ldb,
        beta: beta,
        c: c,
        cOffset: cOffset,
        ldc: ldc,
      ),
    );
  }

  /// Computes matrix-matrix product `C = alpha * op(A) * op(B) + beta * C` for
  /// [Float32List].
  static bool sgemm({
    int transA = cblasNoTrans,
    int transB = cblasNoTrans,
    required int m,
    required int n,
    required int k,
    required double alpha,
    required Float32List a,
    int aOffset = 0,
    required int lda,
    required Float32List b,
    int bOffset = 0,
    required int ldb,
    required double beta,
    required Float32List c,
    int cOffset = 0,
    required int ldc,
    required BlasLibrary blas,
  }) {
    if (m < 0 || n < 0 || k < 0 || lda < 1 || ldb < 1 || ldc < 1) return false;
    if (transA != cblasNoTrans &&
        transA != cblasTrans &&
        transA != cblasConjTrans) {
      return false;
    }
    if (transB != cblasNoTrans &&
        transB != cblasTrans &&
        transB != cblasConjTrans) {
      return false;
    }
    final aRows = transA == cblasNoTrans ? m : k;
    final aCols = transA == cblasNoTrans ? k : m;
    final bRows = transB == cblasNoTrans ? k : n;
    final bCols = transB == cblasNoTrans ? n : k;
    if (lda < aCols || ldb < bCols || ldc < n) return false;
    if (m == 0 || n == 0) return true;
    final aReq = aOffset + (aRows - 1) * lda + aCols;
    final bReq = bOffset + (bRows - 1) * ldb + bCols;
    final cReq = cOffset + (m - 1) * ldc + n;
    if (a.length < aReq || b.length < bReq || c.length < cReq) return false;

    return executeAcceleratedOperation(
      feature: 'BLAS',
      operation: 'sgemm',
      isAvailable: blas.isAvailable,
      canAccelerate: m >= 64 || n >= 64 || k >= 64,
      accelerate: () => blas.sgemm(
        transA: transA,
        transB: transB,
        m: m,
        n: n,
        k: k,
        alpha: alpha,
        a: a,
        aOffset: aOffset,
        lda: lda,
        b: b,
        bOffset: bOffset,
        ldb: ldb,
        beta: beta,
        c: c,
        cOffset: cOffset,
        ldc: ldc,
      ),
      fallback: () => PureDartBlas3.gemmFloat32(
        transA: transA,
        transB: transB,
        m: m,
        n: n,
        k: k,
        alpha: alpha,
        a: a,
        aOffset: aOffset,
        lda: lda,
        b: b,
        bOffset: bOffset,
        ldb: ldb,
        beta: beta,
        c: c,
        cOffset: cOffset,
        ldc: ldc,
      ),
    );
  }

  /// Performs symmetric rank-k update `C = alpha * A * A^T + beta * C` (or `A^T
  /// * A`) for [Float64List].
  static bool dsyrk({
    int uplo = cblasUpper,
    int trans = cblasNoTrans,
    required int n,
    required int k,
    required double alpha,
    required Float64List a,
    int aOffset = 0,
    required int lda,
    required double beta,
    required Float64List c,
    int cOffset = 0,
    required int ldc,
    required BlasLibrary blas,
  }) {
    if (n < 0 || k < 0) return false;
    if (uplo != cblasUpper && uplo != cblasLower) return false;
    if (trans != cblasNoTrans &&
        trans != cblasTrans &&
        trans != cblasConjTrans) {
      return false;
    }
    final aRows = trans == cblasNoTrans ? n : k;
    final aCols = trans == cblasNoTrans ? k : n;
    if (lda < aCols || ldc < n) return false;
    if (n == 0) return true;
    final aReq = aOffset + (aRows - 1) * lda + aCols;
    final cReq = cOffset + (n - 1) * ldc + n;
    if (a.length < aReq || c.length < cReq) return false;

    return executeAcceleratedOperation(
      feature: 'BLAS',
      operation: 'dsyrk',
      isAvailable: blas.isAvailable,
      accelerate: () => blas.dsyrk(
        uplo: uplo,
        trans: trans,
        n: n,
        k: k,
        alpha: alpha,
        a: a,
        aOffset: aOffset,
        lda: lda,
        beta: beta,
        c: c,
        cOffset: cOffset,
        ldc: ldc,
      ),
      fallback: () => PureDartBlas3.dsyrk(
        uplo: uplo,
        trans: trans,
        n: n,
        k: k,
        alpha: alpha,
        a: a,
        aOffset: aOffset,
        lda: lda,
        beta: beta,
        c: c,
        cOffset: cOffset,
        ldc: ldc,
      ),
    );
  }

  /// Performs symmetric rank-k update for [Float32List].
  static bool ssyrk({
    int uplo = cblasUpper,
    int trans = cblasNoTrans,
    required int n,
    required int k,
    required double alpha,
    required Float32List a,
    int aOffset = 0,
    required int lda,
    required double beta,
    required Float32List c,
    int cOffset = 0,
    required int ldc,
    required BlasLibrary blas,
  }) {
    if (n < 0 || k < 0) return false;
    if (uplo != cblasUpper && uplo != cblasLower) return false;
    if (trans != cblasNoTrans &&
        trans != cblasTrans &&
        trans != cblasConjTrans) {
      return false;
    }
    final aRows = trans == cblasNoTrans ? n : k;
    final aCols = trans == cblasNoTrans ? k : n;
    if (lda < aCols || ldc < n) return false;
    if (n == 0) return true;
    final aReq = aOffset + (aRows - 1) * lda + aCols;
    final cReq = cOffset + (n - 1) * ldc + n;
    if (a.length < aReq || c.length < cReq) return false;

    return executeAcceleratedOperation(
      feature: 'BLAS',
      operation: 'ssyrk',
      isAvailable: blas.isAvailable,
      accelerate: () => blas.ssyrk(
        uplo: uplo,
        trans: trans,
        n: n,
        k: k,
        alpha: alpha,
        a: a,
        aOffset: aOffset,
        lda: lda,
        beta: beta,
        c: c,
        cOffset: cOffset,
        ldc: ldc,
      ),
      fallback: () => PureDartBlas3.ssyrk(
        uplo: uplo,
        trans: trans,
        n: n,
        k: k,
        alpha: alpha,
        a: a,
        aOffset: aOffset,
        lda: lda,
        beta: beta,
        c: c,
        cOffset: cOffset,
        ldc: ldc,
      ),
    );
  }

  /// Symmetric matrix-matrix multiplication `C = alpha * A * B + beta * C` (or
  /// `B * A`) for [Float64List].
  static bool dsymm({
    int side = cblasLeft,
    int uplo = cblasUpper,
    required int m,
    required int n,
    required double alpha,
    required Float64List a,
    int aOffset = 0,
    required int lda,
    required Float64List b,
    int bOffset = 0,
    required int ldb,
    required double beta,
    required Float64List c,
    int cOffset = 0,
    required int ldc,
    required BlasLibrary blas,
  }) {
    if (m < 0 || n < 0) return false;
    if (side != cblasLeft && side != cblasRight) return false;
    if (uplo != cblasUpper && uplo != cblasLower) return false;
    final aDim = side == cblasLeft ? m : n;
    if (lda < aDim || ldb < n || ldc < n) return false;
    if (m == 0 || n == 0) return true;
    final aReq = aOffset + (aDim - 1) * lda + aDim;
    final bReq = bOffset + (m - 1) * ldb + n;
    final cReq = cOffset + (m - 1) * ldc + n;
    if (a.length < aReq || b.length < bReq || c.length < cReq) return false;

    return executeAcceleratedOperation(
      feature: 'BLAS',
      operation: 'dsymm',
      isAvailable: blas.isAvailable,
      accelerate: () => blas.dsymm(
        side: side,
        uplo: uplo,
        m: m,
        n: n,
        alpha: alpha,
        a: a,
        aOffset: aOffset,
        lda: lda,
        b: b,
        bOffset: bOffset,
        ldb: ldb,
        beta: beta,
        c: c,
        cOffset: cOffset,
        ldc: ldc,
      ),
      fallback: () => PureDartBlas3.dsymm(
        side: side,
        uplo: uplo,
        m: m,
        n: n,
        alpha: alpha,
        a: a,
        aOffset: aOffset,
        lda: lda,
        b: b,
        bOffset: bOffset,
        ldb: ldb,
        beta: beta,
        c: c,
        cOffset: cOffset,
        ldc: ldc,
      ),
    );
  }

  /// Symmetric matrix-matrix multiplication for [Float32List].
  static bool ssymm({
    int side = cblasLeft,
    int uplo = cblasUpper,
    required int m,
    required int n,
    required double alpha,
    required Float32List a,
    int aOffset = 0,
    required int lda,
    required Float32List b,
    int bOffset = 0,
    required int ldb,
    required double beta,
    required Float32List c,
    int cOffset = 0,
    required int ldc,
    required BlasLibrary blas,
  }) {
    if (m < 0 || n < 0) return false;
    if (side != cblasLeft && side != cblasRight) return false;
    if (uplo != cblasUpper && uplo != cblasLower) return false;
    final aDim = side == cblasLeft ? m : n;
    if (lda < aDim || ldb < n || ldc < n) return false;
    if (m == 0 || n == 0) return true;
    final aReq = aOffset + (aDim - 1) * lda + aDim;
    final bReq = bOffset + (m - 1) * ldb + n;
    final cReq = cOffset + (m - 1) * ldc + n;
    if (a.length < aReq || b.length < bReq || c.length < cReq) return false;

    return executeAcceleratedOperation(
      feature: 'BLAS',
      operation: 'ssymm',
      isAvailable: blas.isAvailable,
      accelerate: () => blas.ssymm(
        side: side,
        uplo: uplo,
        m: m,
        n: n,
        alpha: alpha,
        a: a,
        aOffset: aOffset,
        lda: lda,
        b: b,
        bOffset: bOffset,
        ldb: ldb,
        beta: beta,
        c: c,
        cOffset: cOffset,
        ldc: ldc,
      ),
      fallback: () => PureDartBlas3.ssymm(
        side: side,
        uplo: uplo,
        m: m,
        n: n,
        alpha: alpha,
        a: a,
        aOffset: aOffset,
        lda: lda,
        b: b,
        bOffset: bOffset,
        ldb: ldb,
        beta: beta,
        c: c,
        cOffset: cOffset,
        ldc: ldc,
      ),
    );
  }

  /// Triangular matrix-matrix multiplication `B = alpha * op(A) * B` (or `B *
  /// op(A)`) for [Float64List].
  static bool dtrmm({
    int side = cblasLeft,
    int uplo = cblasUpper,
    int transA = cblasNoTrans,
    int diag = cblasNonUnit,
    required int m,
    required int n,
    required double alpha,
    required Float64List a,
    int aOffset = 0,
    required int lda,
    required Float64List b,
    int bOffset = 0,
    required int ldb,
    required BlasLibrary blas,
  }) {
    if (m < 0 || n < 0) return false;
    if (side != cblasLeft && side != cblasRight) return false;
    if (uplo != cblasUpper && uplo != cblasLower) return false;
    if (transA != cblasNoTrans &&
        transA != cblasTrans &&
        transA != cblasConjTrans) {
      return false;
    }
    if (diag != cblasNonUnit && diag != cblasUnit) return false;
    final aDim = side == cblasLeft ? m : n;
    if (lda < aDim || ldb < n) return false;
    if (m == 0 || n == 0) return true;
    final aReq = aOffset + (aDim - 1) * lda + aDim;
    final bReq = bOffset + (m - 1) * ldb + n;
    if (a.length < aReq || b.length < bReq) return false;

    return executeAcceleratedOperation(
      feature: 'BLAS',
      operation: 'dtrmm',
      isAvailable: blas.isAvailable,
      accelerate: () => blas.dtrmm(
        side: side,
        uplo: uplo,
        transA: transA,
        diag: diag,
        m: m,
        n: n,
        alpha: alpha,
        a: a,
        aOffset: aOffset,
        lda: lda,
        b: b,
        bOffset: bOffset,
        ldb: ldb,
      ),
      fallback: () => PureDartBlas3.dtrmm(
        side: side,
        uplo: uplo,
        transA: transA,
        diag: diag,
        m: m,
        n: n,
        alpha: alpha,
        a: a,
        aOffset: aOffset,
        lda: lda,
        b: b,
        bOffset: bOffset,
        ldb: ldb,
      ),
    );
  }

  /// Triangular matrix-matrix multiplication for [Float32List].
  static bool strmm({
    int side = cblasLeft,
    int uplo = cblasUpper,
    int transA = cblasNoTrans,
    int diag = cblasNonUnit,
    required int m,
    required int n,
    required double alpha,
    required Float32List a,
    int aOffset = 0,
    required int lda,
    required Float32List b,
    int bOffset = 0,
    required int ldb,
    required BlasLibrary blas,
  }) {
    if (m < 0 || n < 0) return false;
    if (side != cblasLeft && side != cblasRight) return false;
    if (uplo != cblasUpper && uplo != cblasLower) return false;
    if (transA != cblasNoTrans &&
        transA != cblasTrans &&
        transA != cblasConjTrans) {
      return false;
    }
    if (diag != cblasNonUnit && diag != cblasUnit) return false;
    final aDim = side == cblasLeft ? m : n;
    if (lda < aDim || ldb < n) return false;
    if (m == 0 || n == 0) return true;
    final aReq = aOffset + (aDim - 1) * lda + aDim;
    final bReq = bOffset + (m - 1) * ldb + n;
    if (a.length < aReq || b.length < bReq) return false;

    return executeAcceleratedOperation(
      feature: 'BLAS',
      operation: 'strmm',
      isAvailable: blas.isAvailable,
      accelerate: () => blas.strmm(
        side: side,
        uplo: uplo,
        transA: transA,
        diag: diag,
        m: m,
        n: n,
        alpha: alpha,
        a: a,
        aOffset: aOffset,
        lda: lda,
        b: b,
        bOffset: bOffset,
        ldb: ldb,
      ),
      fallback: () => PureDartBlas3.strmm(
        side: side,
        uplo: uplo,
        transA: transA,
        diag: diag,
        m: m,
        n: n,
        alpha: alpha,
        a: a,
        aOffset: aOffset,
        lda: lda,
        b: b,
        bOffset: bOffset,
        ldb: ldb,
      ),
    );
  }
}
