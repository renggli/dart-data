import 'dart:typed_data';

import '../blas/cblas.dart';
import '../fallback/pure_dart_blas2.dart';
import 'dispatcher.dart';

/// BLAS Level 2 matrix-vector routines.
abstract final class BlasLevel2 {
  /// Computes matrix-vector product `y = alpha * op(A) * x + beta * y` for
  /// [Float64List].
  static bool dgemv({
    int transA = cblasNoTrans,
    required int m,
    required int n,
    required double alpha,
    required Float64List a,
    int aOffset = 0,
    required int lda,
    required Float64List x,
    int xOffset = 0,
    required int incX,
    required double beta,
    required Float64List y,
    int yOffset = 0,
    required int incY,
    required BlasLibrary blas,
  }) => executeAcceleratedOperation(
    feature: 'BLAS',
    operation: 'dgemv',
    isAvailable: blas.isAvailable,
    accelerate: () => blas.dgemv(
      transA: transA,
      m: m,
      n: n,
      alpha: alpha,
      a: a,
      aOffset: aOffset,
      lda: lda,
      x: x,
      xOffset: xOffset,
      incX: incX,
      beta: beta,
      y: y,
      yOffset: yOffset,
      incY: incY,
    ),
    fallback: () => PureDartBlas2.dgemv(
      transA: transA,
      m: m,
      n: n,
      alpha: alpha,
      a: a,
      aOffset: aOffset,
      lda: lda,
      x: x,
      xOffset: xOffset,
      incX: incX,
      beta: beta,
      y: y,
      yOffset: yOffset,
      incY: incY,
    ),
  );

  /// Computes matrix-vector product `y = alpha * op(A) * x + beta * y` for
  /// [Float32List].
  static bool sgemv({
    int transA = cblasNoTrans,
    required int m,
    required int n,
    required double alpha,
    required Float32List a,
    int aOffset = 0,
    required int lda,
    required Float32List x,
    int xOffset = 0,
    required int incX,
    required double beta,
    required Float32List y,
    int yOffset = 0,
    required int incY,
    required BlasLibrary blas,
  }) => executeAcceleratedOperation(
    feature: 'BLAS',
    operation: 'sgemv',
    isAvailable: blas.isAvailable,
    accelerate: () => blas.sgemv(
      transA: transA,
      m: m,
      n: n,
      alpha: alpha,
      a: a,
      aOffset: aOffset,
      lda: lda,
      x: x,
      xOffset: xOffset,
      incX: incX,
      beta: beta,
      y: y,
      yOffset: yOffset,
      incY: incY,
    ),
    fallback: () => PureDartBlas2.sgemv(
      transA: transA,
      m: m,
      n: n,
      alpha: alpha,
      a: a,
      aOffset: aOffset,
      lda: lda,
      x: x,
      xOffset: xOffset,
      incX: incX,
      beta: beta,
      y: y,
      yOffset: yOffset,
      incY: incY,
    ),
  );

  /// Performs symmetric rank-2 update `A = alpha * x * y^T + alpha * y * x^T + A`
  /// for [Float64List].
  static bool dsyr2({
    int uplo = cblasUpper,
    required int n,
    required double alpha,
    required Float64List x,
    int xOffset = 0,
    int incX = 1,
    required Float64List y,
    int yOffset = 0,
    int incY = 1,
    required Float64List a,
    int aOffset = 0,
    required int lda,
    required BlasLibrary blas,
  }) => executeAcceleratedOperation(
    feature: 'BLAS',
    operation: 'dsyr2',
    isAvailable: blas.isAvailable,
    accelerate: () => blas.dsyr2(
      uplo: uplo,
      n: n,
      alpha: alpha,
      x: x,
      xOffset: xOffset,
      incX: incX,
      y: y,
      yOffset: yOffset,
      incY: incY,
      a: a,
      aOffset: aOffset,
      lda: lda,
    ),
    fallback: () => PureDartBlas2.dsyr2(
      uplo: uplo,
      n: n,
      alpha: alpha,
      x: x,
      xOffset: xOffset,
      incX: incX,
      y: y,
      yOffset: yOffset,
      incY: incY,
      a: a,
      aOffset: aOffset,
      lda: lda,
    ),
  );

  /// Performs symmetric rank-2 update for [Float32List].
  static bool ssyr2({
    int uplo = cblasUpper,
    required int n,
    required double alpha,
    required Float32List x,
    int xOffset = 0,
    int incX = 1,
    required Float32List y,
    int yOffset = 0,
    int incY = 1,
    required Float32List a,
    int aOffset = 0,
    required int lda,
    required BlasLibrary blas,
  }) => executeAcceleratedOperation(
    feature: 'BLAS',
    operation: 'ssyr2',
    isAvailable: blas.isAvailable,
    accelerate: () => blas.ssyr2(
      uplo: uplo,
      n: n,
      alpha: alpha,
      x: x,
      xOffset: xOffset,
      incX: incX,
      y: y,
      yOffset: yOffset,
      incY: incY,
      a: a,
      aOffset: aOffset,
      lda: lda,
    ),
    fallback: () => PureDartBlas2.ssyr2(
      uplo: uplo,
      n: n,
      alpha: alpha,
      x: x,
      xOffset: xOffset,
      incX: incX,
      y: y,
      yOffset: yOffset,
      incY: incY,
      a: a,
      aOffset: aOffset,
      lda: lda,
    ),
  );

  /// Triangular matrix-vector multiplication `x = op(A) * x` for [Float64List].
  static bool dtrmv({
    int uplo = cblasUpper,
    int trans = cblasNoTrans,
    int diag = cblasNonUnit,
    required int n,
    required Float64List a,
    int aOffset = 0,
    required int lda,
    required Float64List x,
    int xOffset = 0,
    int incX = 1,
    required BlasLibrary blas,
  }) {
    if (n < 0 || lda < n || incX == 0) return false;
    if (uplo != cblasUpper && uplo != cblasLower) return false;
    if (trans != cblasNoTrans &&
        trans != cblasTrans &&
        trans != cblasConjTrans) {
      return false;
    }
    if (diag != cblasNonUnit && diag != cblasUnit) return false;
    if (n == 0) return true;
    final aReq = aOffset + (n - 1) * lda + n;
    final xReq = xOffset + (n - 1) * incX.abs() + 1;
    if (a.length < aReq || x.length < xReq) return false;

    return executeAcceleratedOperation(
      feature: 'BLAS',
      operation: 'dtrmv',
      isAvailable: blas.isAvailable,
      accelerate: () => blas.dtrmv(
        uplo: uplo,
        trans: trans,
        diag: diag,
        n: n,
        a: a,
        aOffset: aOffset,
        lda: lda,
        x: x,
        xOffset: xOffset,
        incX: incX,
      ),
      fallback: () => PureDartBlas2.dtrmv(
        uplo: uplo,
        trans: trans,
        diag: diag,
        n: n,
        a: a,
        aOffset: aOffset,
        lda: lda,
        x: x,
        xOffset: xOffset,
        incX: incX,
      ),
    );
  }

  /// Triangular matrix-vector multiplication `x = op(A) * x` for [Float32List].
  static bool strmv({
    int uplo = cblasUpper,
    int trans = cblasNoTrans,
    int diag = cblasNonUnit,
    required int n,
    required Float32List a,
    int aOffset = 0,
    required int lda,
    required Float32List x,
    int xOffset = 0,
    int incX = 1,
    required BlasLibrary blas,
  }) {
    if (n < 0 || lda < n || incX == 0) return false;
    if (uplo != cblasUpper && uplo != cblasLower) return false;
    if (trans != cblasNoTrans &&
        trans != cblasTrans &&
        trans != cblasConjTrans) {
      return false;
    }
    if (diag != cblasNonUnit && diag != cblasUnit) return false;
    if (n == 0) return true;
    final aReq = aOffset + (n - 1) * lda + n;
    final xReq = xOffset + (n - 1) * incX.abs() + 1;
    if (a.length < aReq || x.length < xReq) return false;

    return executeAcceleratedOperation(
      feature: 'BLAS',
      operation: 'strmv',
      isAvailable: blas.isAvailable,
      accelerate: () => blas.strmv(
        uplo: uplo,
        trans: trans,
        diag: diag,
        n: n,
        a: a,
        aOffset: aOffset,
        lda: lda,
        x: x,
        xOffset: xOffset,
        incX: incX,
      ),
      fallback: () => PureDartBlas2.strmv(
        uplo: uplo,
        trans: trans,
        diag: diag,
        n: n,
        a: a,
        aOffset: aOffset,
        lda: lda,
        x: x,
        xOffset: xOffset,
        incX: incX,
      ),
    );
  }
}
