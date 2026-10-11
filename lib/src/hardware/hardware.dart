import 'dart:math' as math;
import 'dart:typed_data';

import 'cblas.dart';
import 'pure_dart_gemm.dart';
import 'simd.dart';

/// Central hardware acceleration manager providing transparent routing between
/// native BLAS/LAPACK (via FFI), Dart SIMD, and pure Dart scalar algorithms.
class HardwareManager {
  new _(); // coverage:ignore-line

  /// Whether hardware acceleration is globally enabled. Can be disabled for benchmarking or testing fallbacks.
  static bool isEnabled = true;

  static final BlasLibrary _blas = loadBlas();

  /// Whether native BLAS is loaded and available on the current platform.
  static bool get isNativeAvailable => _blas.isAvailable;

  /// Whether hardware acceleration is currently active.
  static bool get isAccelerated => isEnabled && _blas.isAvailable;

  /// Computes matrix multiplication C = alpha * op(A) * op(B) + beta * C for Float64List.
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
  }) {
    if (isAccelerated && (m >= 64 || n >= 64 || k >= 64)) {
      final success = _blas.dgemm(
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
      );
      if (success) return true;
    }

    return cacheBlockedGemmFloat64(
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
    );
  }

  /// Computes matrix multiplication C = alpha * op(A) * op(B) + beta * C for Float32List.
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
  }) {
    if (isAccelerated && (m >= 64 || n >= 64 || k >= 64)) {
      final success = _blas.sgemm(
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
      );
      if (success) return true;
    }

    return cacheBlockedGemmFloat32(
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
    );
  }

  /// Computes matrix-vector product y = alpha * op(A) * x + beta * y for Float64List.
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
  }) {
    if (isAccelerated) {
      final success = _blas.dgemv(
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
      );
      if (success) return true;
    }

    // Pure Dart fallback
    final lenY = transA == cblasTrans ? n : m;
    final lenX = transA == cblasTrans ? m : n;
    for (var i = 0; i < lenY; i++) {
      var sum = 0.0;
      for (var j = 0; j < lenX; j++) {
        final aVal = transA == cblasTrans
            ? a[aOffset + j * lda + i]
            : a[aOffset + i * lda + j];
        sum += aVal * x[xOffset + j * incX];
      }
      final yIdx = yOffset + i * incY;
      y[yIdx] = alpha * sum + (beta == 0.0 ? 0.0 : beta * y[yIdx]);
    }
    return true;
  }

  /// Computes matrix-vector product y = alpha * op(A) * x + beta * y for Float32List.
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
  }) {
    if (isAccelerated) {
      final success = _blas.sgemv(
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
      );
      if (success) return true;
    }

    // Pure Dart fallback
    final lenY = transA == cblasTrans ? n : m;
    final lenX = transA == cblasTrans ? m : n;
    for (var i = 0; i < lenY; i++) {
      var sum = 0.0;
      for (var j = 0; j < lenX; j++) {
        final aVal = transA == cblasTrans
            ? a[aOffset + j * lda + i]
            : a[aOffset + i * lda + j];
        sum += aVal * x[xOffset + j * incX];
      }
      final yIdx = yOffset + i * incY;
      y[yIdx] = alpha * sum + (beta == 0.0 ? 0.0 : beta * y[yIdx]);
    }
    return true;
  }

  /// Computes dot product of two Float64List vectors.
  static double? ddot({
    required int n,
    required Float64List x,
    int xOffset = 0,
    int incX = 1,
    required Float64List y,
    int yOffset = 0,
    int incY = 1,
  }) {
    if (isAccelerated) {
      final res = _blas.ddot(
        n: n,
        x: x,
        xOffset: xOffset,
        incX: incX,
        y: y,
        yOffset: yOffset,
        incY: incY,
      );
      if (res != null) return res;
    }

    var sum = 0.0;
    for (
      var i = 0, xi = xOffset, yi = yOffset;
      i < n;
      i++, xi += incX, yi += incY
    ) {
      sum += x[xi] * y[yi];
    }
    return sum;
  }

  /// Computes dot product of two Float32List vectors.
  static double? sdot({
    required int n,
    required Float32List x,
    int xOffset = 0,
    int incX = 1,
    required Float32List y,
    int yOffset = 0,
    int incY = 1,
  }) {
    if (isAccelerated) {
      final res = _blas.sdot(
        n: n,
        x: x,
        xOffset: xOffset,
        incX: incX,
        y: y,
        yOffset: yOffset,
        incY: incY,
      );
      if (res != null) return res;
    }

    if (xOffset == 0 &&
        yOffset == 0 &&
        incX == 1 &&
        incY == 1 &&
        x.length == n &&
        y.length == n) {
      return SimdEngine.dotFloat32(x, y);
    }

    var sum = 0.0;
    for (
      var i = 0, xi = xOffset, yi = yOffset;
      i < n;
      i++, xi += incX, yi += incY
    ) {
      sum += x[xi] * y[yi];
    }
    return sum;
  }

  /// Computes Euclidean norm of a Float64List vector.
  static double? dnrm2({
    required int n,
    required Float64List x,
    int xOffset = 0,
    int incX = 1,
  }) {
    if (isAccelerated) {
      final res = _blas.dnrm2(n: n, x: x, xOffset: xOffset, incX: incX);
      if (res != null) return res;
    }

    var sumSq = 0.0;
    for (var i = 0, xi = xOffset; i < n; i++, xi += incX) {
      final val = x[xi];
      sumSq += val * val;
    }
    return math.sqrt(sumSq);
  }

  /// Computes Euclidean norm of a Float32List vector.
  static double? snrm2({
    required int n,
    required Float32List x,
    int xOffset = 0,
    int incX = 1,
  }) {
    if (isAccelerated) {
      final res = _blas.snrm2(n: n, x: x, xOffset: xOffset, incX: incX);
      if (res != null) return res;
    }

    if (xOffset == 0 && incX == 1 && x.length == n) {
      return math.sqrt(SimdEngine.dotFloat32(x, x));
    }

    var sumSq = 0.0;
    for (var i = 0, xi = xOffset; i < n; i++, xi += incX) {
      final val = x[xi];
      sumSq += val * val;
    }
    return math.sqrt(sumSq);
  }

  /// Computes in-place scaled addition y = alpha * x + y for Float64List.
  static bool daxpy({
    required int n,
    required double alpha,
    required Float64List x,
    int xOffset = 0,
    int incX = 1,
    required Float64List y,
    int yOffset = 0,
    int incY = 1,
  }) {
    if (isAccelerated) {
      final success = _blas.daxpy(
        n: n,
        alpha: alpha,
        x: x,
        xOffset: xOffset,
        incX: incX,
        y: y,
        yOffset: yOffset,
        incY: incY,
      );
      if (success) return true;
    }

    for (
      var i = 0, xi = xOffset, yi = yOffset;
      i < n;
      i++, xi += incX, yi += incY
    ) {
      y[yi] += alpha * x[xi];
    }
    return true;
  }

  /// Computes in-place scaled addition y = alpha * x + y for Float32List.
  static bool saxpy({
    required int n,
    required double alpha,
    required Float32List x,
    int xOffset = 0,
    int incX = 1,
    required Float32List y,
    int yOffset = 0,
    int incY = 1,
  }) {
    if (isAccelerated) {
      final success = _blas.saxpy(
        n: n,
        alpha: alpha,
        x: x,
        xOffset: xOffset,
        incX: incX,
        y: y,
        yOffset: yOffset,
        incY: incY,
      );
      if (success) return true;
    }

    for (
      var i = 0, xi = xOffset, yi = yOffset;
      i < n;
      i++, xi += incX, yi += incY
    ) {
      y[yi] += alpha * x[xi];
    }
    return true;
  }

  /// In-place scaling x = alpha * x for Float64List.
  static bool dscal({
    required int n,
    required double alpha,
    required Float64List x,
    int xOffset = 0,
    int incX = 1,
  }) {
    if (isAccelerated) {
      final success = _blas.dscal(
        n: n,
        alpha: alpha,
        x: x,
        xOffset: xOffset,
        incX: incX,
      );
      if (success) return true;
    }

    for (var i = 0, xi = xOffset; i < n; i++, xi += incX) {
      x[xi] *= alpha;
    }
    return true;
  }

  /// In-place scaling x = alpha * x for Float32List.
  static bool sscal({
    required int n,
    required double alpha,
    required Float32List x,
    int xOffset = 0,
    int incX = 1,
  }) {
    if (isAccelerated) {
      final success = _blas.sscal(
        n: n,
        alpha: alpha,
        x: x,
        xOffset: xOffset,
        incX: incX,
      );
      if (success) return true;
    }

    for (var i = 0, xi = xOffset; i < n; i++, xi += incX) {
      x[xi] *= alpha;
    }
    return true;
  }

  /// Performs symmetric rank-k update C = alpha * A * A^T + beta * C (or A^T * A).
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
  }) {
    if (isAccelerated) {
      final success = _blas.dsyrk(
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
      );
      if (success) return true;
    }

    // Pure Dart fallback computing symmetric triangle and mirroring
    for (var i = 0; i < n; i++) {
      for (var j = i; j < n; j++) {
        var sum = 0.0;
        if (trans == cblasTrans) {
          for (var pIdx = 0; pIdx < k; pIdx++) {
            sum += a[aOffset + pIdx * lda + i] * a[aOffset + pIdx * lda + j];
          }
        } else {
          for (var pIdx = 0; pIdx < k; pIdx++) {
            sum += a[aOffset + i * lda + pIdx] * a[aOffset + j * lda + pIdx];
          }
        }
        final val =
            alpha * sum + (beta == 0.0 ? 0.0 : beta * c[cOffset + i * ldc + j]);
        c[cOffset + i * ldc + j] = val;
        c[cOffset + j * ldc + i] = val;
      }
    }
    return true;
  }

  /// Performs symmetric rank-k update for Float32List.
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
  }) {
    if (isAccelerated) {
      final success = _blas.ssyrk(
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
      );
      if (success) return true;
    }

    // Pure Dart fallback
    for (var i = 0; i < n; i++) {
      for (var j = i; j < n; j++) {
        var sum = 0.0;
        if (trans == cblasTrans) {
          for (var pIdx = 0; pIdx < k; pIdx++) {
            sum += a[aOffset + pIdx * lda + i] * a[aOffset + pIdx * lda + j];
          }
        } else {
          for (var pIdx = 0; pIdx < k; pIdx++) {
            sum += a[aOffset + i * lda + pIdx] * a[aOffset + j * lda + pIdx];
          }
        }
        final val =
            alpha * sum + (beta == 0.0 ? 0.0 : beta * c[cOffset + i * ldc + j]);
        c[cOffset + i * ldc + j] = val;
        c[cOffset + j * ldc + i] = val;
      }
    }
    return true;
  }

  /// Performs symmetric rank-2 update A = alpha * x * y^T + alpha * y * x^T + A for Float64List.
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
  }) {
    if (isAccelerated) {
      final success = _blas.dsyr2(
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
      );
      if (success) return true;
    }

    for (var i = 0; i < n; i++) {
      final xi = x[xOffset + i * incX];
      final yi = y[yOffset + i * incY];
      for (var j = i; j < n; j++) {
        final xj = x[xOffset + j * incX];
        final yj = y[yOffset + j * incY];
        final val = alpha * (xi * yj + yi * xj);
        a[aOffset + i * lda + j] += val;
        if (i != j) {
          a[aOffset + j * lda + i] += val;
        }
      }
    }
    return true;
  }

  /// Performs symmetric rank-2 update for Float32List.
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
  }) {
    if (isAccelerated) {
      final success = _blas.ssyr2(
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
      );
      if (success) return true;
    }

    for (var i = 0; i < n; i++) {
      final xi = x[xOffset + i * incX];
      final yi = y[yOffset + i * incY];
      for (var j = i; j < n; j++) {
        final xj = x[xOffset + j * incX];
        final yj = y[yOffset + j * incY];
        final val = alpha * (xi * yj + yi * xj);
        a[aOffset + i * lda + j] += val;
        if (i != j) {
          a[aOffset + j * lda + i] += val;
        }
      }
    }
    return true;
  }

  /// Computes the Cholesky factorization of a symmetric positive-definite matrix A.
  /// Overwrites the upper or lower triangle of A with the factor U or L.
  static bool dpotrf({
    int uplo = cblasUpper,
    required int n,
    required Float64List a,
    int aOffset = 0,
    required int lda,
  }) {
    if (isAccelerated) {
      final success = _blas.dpotrf(
        uplo: uplo,
        n: n,
        a: a,
        aOffset: aOffset,
        lda: lda,
      );
      if (success) return true;
    }

    // Pure Dart fallback Cholesky factorization
    final lower = Float64List(n * n);
    for (var i = 0; i < n; i++) {
      for (var j = 0; j <= i; j++) {
        var sum = 0.0;
        for (var k = 0; k < j; k++) {
          sum += lower[i * n + k] * lower[j * n + k];
        }
        if (i == j) {
          final val = a[aOffset + i * lda + i] - sum;
          if (val <= 0.0) return false;
          lower[i * n + j] = math.sqrt(val);
        } else {
          final denom = lower[j * n + j];
          if (denom == 0.0) return false;
          lower[i * n + j] = (a[aOffset + i * lda + j] - sum) / denom;
        }
      }
    }

    if (uplo == cblasUpper) {
      for (var i = 0; i < n; i++) {
        for (var j = i; j < n; j++) {
          a[aOffset + i * lda + j] = lower[j * n + i];
        }
      }
    } else {
      for (var i = 0; i < n; i++) {
        for (var j = 0; j <= i; j++) {
          a[aOffset + i * lda + j] = lower[i * n + j];
        }
      }
    }
    return true;
  }

  /// Solves A * X = B for general square matrix A using LU decomposition.
  /// Attempts native LAPACK if accelerated, falling back to pure Dart LU decomposition.
  static bool dgesv({
    required int n,
    required int nrhs,
    required Float64List a,
    int aOffset = 0,
    required int lda,
    required Float64List b,
    int bOffset = 0,
    required int ldb,
  }) {
    if (n < 0 || nrhs < 0 || lda < n || (nrhs > 0 && ldb < nrhs)) return false;
    if (n == 0 || nrhs == 0) return true;
    final aRequired = aOffset + (n - 1) * lda + n;
    final bRequired = bOffset + (n - 1) * ldb + nrhs;
    if (a.length < aRequired || b.length < bRequired) return false;

    if (isAccelerated) {
      final success = _blas.dgesv(
        n: n,
        nrhs: nrhs,
        a: a,
        aOffset: aOffset,
        lda: lda,
        b: b,
        bOffset: bOffset,
        ldb: ldb,
      );
      if (success) return true;
    }
    return _luSolve(n, nrhs, a, aOffset, lda, b, bOffset, ldb);
  }

  /// Solves overdetermined linear least squares min ||A * X - B||_2 using LAPACK dgels.
  static bool dgels({
    required int m,
    required int n,
    required int nrhs,
    required Float64List a,
    int aOffset = 0,
    required int lda,
    required Float64List b,
    int bOffset = 0,
    required int ldb,
  }) {
    if (isAccelerated) {
      return _blas.dgels(
        m: m,
        n: n,
        nrhs: nrhs,
        a: a,
        aOffset: aOffset,
        lda: lda,
        b: b,
        bOffset: bOffset,
        ldb: ldb,
      );
    }
    return false;
  }

  /// Triangular matrix-vector multiplication x = op(A) * x for Float64List.
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

    if (isAccelerated) {
      final success = _blas.dtrmv(
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
      );
      if (success) return true;
    }

    // Pure Dart fallback
    final temp = Float64List(n);
    for (var i = 0; i < n; i++) {
      temp[i] = x[xOffset + i * incX];
    }
    for (var i = 0; i < n; i++) {
      var sum = 0.0;
      if (trans == cblasNoTrans) {
        if (uplo == cblasUpper) {
          for (var j = i; j < n; j++) {
            final aVal = (i == j && diag == cblasUnit)
                ? 1.0
                : a[aOffset + i * lda + j];
            sum += aVal * temp[j];
          }
        } else {
          for (var j = 0; j <= i; j++) {
            final aVal = (i == j && diag == cblasUnit)
                ? 1.0
                : a[aOffset + i * lda + j];
            sum += aVal * temp[j];
          }
        }
      } else {
        if (uplo == cblasUpper) {
          for (var j = 0; j <= i; j++) {
            final aVal = (i == j && diag == cblasUnit)
                ? 1.0
                : a[aOffset + j * lda + i];
            sum += aVal * temp[j];
          }
        } else {
          for (var j = i; j < n; j++) {
            final aVal = (i == j && diag == cblasUnit)
                ? 1.0
                : a[aOffset + j * lda + i];
            sum += aVal * temp[j];
          }
        }
      }
      x[xOffset + i * incX] = sum;
    }
    return true;
  }

  /// Triangular matrix-vector multiplication x = op(A) * x for Float32List.
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

    if (isAccelerated) {
      final success = _blas.strmv(
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
      );
      if (success) return true;
    }

    // Pure Dart fallback
    final temp = Float32List(n);
    for (var i = 0; i < n; i++) {
      temp[i] = x[xOffset + i * incX];
    }
    for (var i = 0; i < n; i++) {
      var sum = 0.0;
      if (trans == cblasNoTrans) {
        if (uplo == cblasUpper) {
          for (var j = i; j < n; j++) {
            final aVal = (i == j && diag == cblasUnit)
                ? 1.0
                : a[aOffset + i * lda + j];
            sum += aVal * temp[j];
          }
        } else {
          for (var j = 0; j <= i; j++) {
            final aVal = (i == j && diag == cblasUnit)
                ? 1.0
                : a[aOffset + i * lda + j];
            sum += aVal * temp[j];
          }
        }
      } else {
        if (uplo == cblasUpper) {
          for (var j = 0; j <= i; j++) {
            final aVal = (i == j && diag == cblasUnit)
                ? 1.0
                : a[aOffset + j * lda + i];
            sum += aVal * temp[j];
          }
        } else {
          for (var j = i; j < n; j++) {
            final aVal = (i == j && diag == cblasUnit)
                ? 1.0
                : a[aOffset + j * lda + i];
            sum += aVal * temp[j];
          }
        }
      }
      x[xOffset + i * incX] = sum;
    }
    return true;
  }

  /// Symmetric matrix-matrix multiplication C = alpha * A * B + beta * C (or B * A) for Float64List.
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

    if (isAccelerated) {
      final success = _blas.dsymm(
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
      );
      if (success) return true;
    }

    // Pure Dart fallback
    for (var i = 0; i < m; i++) {
      for (var j = 0; j < n; j++) {
        var sum = 0.0;
        if (side == cblasLeft) {
          for (var k = 0; k < m; k++) {
            final aVal = uplo == cblasUpper
                ? (i <= k ? a[aOffset + i * lda + k] : a[aOffset + k * lda + i])
                : (i >= k
                      ? a[aOffset + i * lda + k]
                      : a[aOffset + k * lda + i]);
            sum += aVal * b[bOffset + k * ldb + j];
          }
        } else {
          for (var k = 0; k < n; k++) {
            final aVal = uplo == cblasUpper
                ? (k <= j ? a[aOffset + k * lda + j] : a[aOffset + j * lda + k])
                : (k >= j
                      ? a[aOffset + k * lda + j]
                      : a[aOffset + j * lda + k]);
            sum += b[bOffset + i * ldb + k] * aVal;
          }
        }
        final val =
            alpha * sum + (beta == 0.0 ? 0.0 : beta * c[cOffset + i * ldc + j]);
        c[cOffset + i * ldc + j] = val;
      }
    }
    return true;
  }

  /// Symmetric matrix-matrix multiplication for Float32List.
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

    if (isAccelerated) {
      final success = _blas.ssymm(
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
      );
      if (success) return true;
    }

    // Pure Dart fallback
    for (var i = 0; i < m; i++) {
      for (var j = 0; j < n; j++) {
        var sum = 0.0;
        if (side == cblasLeft) {
          for (var k = 0; k < m; k++) {
            final aVal = uplo == cblasUpper
                ? (i <= k ? a[aOffset + i * lda + k] : a[aOffset + k * lda + i])
                : (i >= k
                      ? a[aOffset + i * lda + k]
                      : a[aOffset + k * lda + i]);
            sum += aVal * b[bOffset + k * ldb + j];
          }
        } else {
          for (var k = 0; k < n; k++) {
            final aVal = uplo == cblasUpper
                ? (k <= j ? a[aOffset + k * lda + j] : a[aOffset + j * lda + k])
                : (k >= j
                      ? a[aOffset + k * lda + j]
                      : a[aOffset + j * lda + k]);
            sum += b[bOffset + i * ldb + k] * aVal;
          }
        }
        final val =
            alpha * sum + (beta == 0.0 ? 0.0 : beta * c[cOffset + i * ldc + j]);
        c[cOffset + i * ldc + j] = val;
      }
    }
    return true;
  }

  /// Triangular matrix-matrix multiplication B = alpha * op(A) * B (or B * op(A)) for Float64List.
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

    if (isAccelerated) {
      final success = _blas.dtrmm(
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
      );
      if (success) return true;
    }

    // Pure Dart fallback (copy b to scratch buffer to prevent in-place overwrite corruption)
    final bCopy = Float64List(m * n);
    for (var i = 0; i < m; i++) {
      for (var j = 0; j < n; j++) {
        bCopy[i * n + j] = b[bOffset + i * ldb + j];
      }
    }

    for (var i = 0; i < m; i++) {
      for (var j = 0; j < n; j++) {
        var sum = 0.0;
        if (side == cblasLeft) {
          if (transA == cblasNoTrans) {
            final startK = uplo == cblasUpper ? i : 0;
            final endK = uplo == cblasUpper ? m : i + 1;
            for (var k = startK; k < endK; k++) {
              final aVal = (i == k && diag == cblasUnit)
                  ? 1.0
                  : a[aOffset + i * lda + k];
              sum += aVal * bCopy[k * n + j];
            }
          } else {
            final startK = uplo == cblasUpper ? 0 : i;
            final endK = uplo == cblasUpper ? i + 1 : m;
            for (var k = startK; k < endK; k++) {
              final aVal = (i == k && diag == cblasUnit)
                  ? 1.0
                  : a[aOffset + k * lda + i];
              sum += aVal * bCopy[k * n + j];
            }
          }
        } else {
          if (transA == cblasNoTrans) {
            final startK = uplo == cblasUpper ? 0 : j;
            final endK = uplo == cblasUpper ? j + 1 : n;
            for (var k = startK; k < endK; k++) {
              final aVal = (k == j && diag == cblasUnit)
                  ? 1.0
                  : a[aOffset + k * lda + j];
              sum += bCopy[i * n + k] * aVal;
            }
          } else {
            final startK = uplo == cblasUpper ? j : 0;
            final endK = uplo == cblasUpper ? n : j + 1;
            for (var k = startK; k < endK; k++) {
              final aVal = (k == j && diag == cblasUnit)
                  ? 1.0
                  : a[aOffset + j * lda + k];
              sum += bCopy[i * n + k] * aVal;
            }
          }
        }
        b[bOffset + i * ldb + j] = alpha * sum;
      }
    }
    return true;
  }

  /// Triangular matrix-matrix multiplication for Float32List.
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

    if (isAccelerated) {
      final success = _blas.strmm(
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
      );
      if (success) return true;
    }

    // Pure Dart fallback
    final bCopy = Float32List(m * n);
    for (var i = 0; i < m; i++) {
      for (var j = 0; j < n; j++) {
        bCopy[i * n + j] = b[bOffset + i * ldb + j];
      }
    }

    for (var i = 0; i < m; i++) {
      for (var j = 0; j < n; j++) {
        var sum = 0.0;
        if (side == cblasLeft) {
          if (transA == cblasNoTrans) {
            final startK = uplo == cblasUpper ? i : 0;
            final endK = uplo == cblasUpper ? m : i + 1;
            for (var k = startK; k < endK; k++) {
              final aVal = (i == k && diag == cblasUnit)
                  ? 1.0
                  : a[aOffset + i * lda + k];
              sum += aVal * bCopy[k * n + j];
            }
          } else {
            final startK = uplo == cblasUpper ? 0 : i;
            final endK = uplo == cblasUpper ? i + 1 : m;
            for (var k = startK; k < endK; k++) {
              final aVal = (i == k && diag == cblasUnit)
                  ? 1.0
                  : a[aOffset + k * lda + i];
              sum += aVal * bCopy[k * n + j];
            }
          }
        } else {
          if (transA == cblasNoTrans) {
            final startK = uplo == cblasUpper ? 0 : j;
            final endK = uplo == cblasUpper ? j + 1 : n;
            for (var k = startK; k < endK; k++) {
              final aVal = (k == j && diag == cblasUnit)
                  ? 1.0
                  : a[aOffset + k * lda + j];
              sum += bCopy[i * n + k] * aVal;
            }
          } else {
            final startK = uplo == cblasUpper ? j : 0;
            final endK = uplo == cblasUpper ? n : j + 1;
            for (var k = startK; k < endK; k++) {
              final aVal = (k == j && diag == cblasUnit)
                  ? 1.0
                  : a[aOffset + j * lda + k];
              sum += bCopy[i * n + k] * aVal;
            }
          }
        }
        b[bOffset + i * ldb + j] = alpha * sum;
      }
    }
    return true;
  }

  /// Computes all eigenvalues and, optionally, eigenvectors of a real symmetric matrix A.
  ///
  /// On exit, [w] contains eigenvalues in ascending order. If [jobz] == 'V',
  /// [a] contains orthonormal eigenvectors in its columns.
  static bool dsyev({
    String jobz = 'V',
    int uplo = cblasUpper,
    required int n,
    required Float64List a,
    int aOffset = 0,
    required int lda,
    required Float64List w,
    int wOffset = 0,
  }) {
    if (n < 0 || lda < n) return false;
    final normJobz = jobz.toUpperCase();
    if (normJobz != 'V' && normJobz != 'N') return false;
    if (uplo != cblasUpper && uplo != cblasLower) return false;
    if (n == 0) return true;
    final aReq = aOffset + (n - 1) * lda + n;
    final wReq = wOffset + n;
    if (a.length < aReq || w.length < wReq) return false;

    if (isAccelerated) {
      final success = _blas.dsyev(
        jobz: normJobz,
        uplo: uplo,
        n: n,
        a: a,
        aOffset: aOffset,
        lda: lda,
        w: w,
        wOffset: wOffset,
      );
      if (success) return true;
    }

    return _dsyevFallback(
      jobz: normJobz,
      uplo: uplo,
      n: n,
      a: a,
      aOffset: aOffset,
      lda: lda,
      w: w,
      wOffset: wOffset,
    );
  }

  /// Computes all eigenvalues and eigenvectors of a single-precision symmetric matrix.
  static bool ssyev({
    String jobz = 'V',
    int uplo = cblasUpper,
    required int n,
    required Float32List a,
    int aOffset = 0,
    required int lda,
    required Float32List w,
    int wOffset = 0,
  }) {
    if (n < 0 || lda < n) return false;
    final normJobz = jobz.toUpperCase();
    if (normJobz != 'V' && normJobz != 'N') return false;
    if (uplo != cblasUpper && uplo != cblasLower) return false;
    if (n == 0) return true;
    final aReq = aOffset + (n - 1) * lda + n;
    final wReq = wOffset + n;
    if (a.length < aReq || w.length < wReq) return false;

    if (isAccelerated) {
      final success = _blas.ssyev(
        jobz: normJobz,
        uplo: uplo,
        n: n,
        a: a,
        aOffset: aOffset,
        lda: lda,
        w: w,
        wOffset: wOffset,
      );
      if (success) return true;
    }

    return _ssyevFallback(
      jobz: normJobz,
      uplo: uplo,
      n: n,
      a: a,
      aOffset: aOffset,
      lda: lda,
      w: w,
      wOffset: wOffset,
    );
  }

  static bool _dsyevFallback({
    required String jobz,
    required int uplo,
    required int n,
    required Float64List a,
    required int aOffset,
    required int lda,
    required Float64List w,
    required int wOffset,
  }) {
    if (n == 1) {
      w[wOffset] = a[aOffset];
      if (jobz.toUpperCase() == 'V') a[aOffset] = 1.0;
      return true;
    }

    final v = Float64List(n * n);
    for (var i = 0; i < n; i++) {
      for (var j = 0; j < n; j++) {
        final val = uplo == cblasUpper
            ? (i <= j ? a[aOffset + i * lda + j] : a[aOffset + j * lda + i])
            : (i >= j ? a[aOffset + i * lda + j] : a[aOffset + j * lda + i]);
        v[i * n + j] = val;
      }
    }

    final d = Float64List(n);
    final e = Float64List(n);

    // Householder reduction to tridiagonal form (tred2)
    for (var j = 0; j < n; j++) {
      d[j] = v[(n - 1) * n + j];
    }
    for (var i = n - 1; i > 0; i--) {
      var scale = 0.0;
      var hVal = 0.0;
      for (var k = 0; k < i; k++) {
        scale += d[k].abs();
      }
      if (scale == 0.0) {
        e[i] = d[i - 1];
        for (var j = 0; j < i; j++) {
          d[j] = v[(i - 1) * n + j];
          v[i * n + j] = 0.0;
          v[j * n + i] = 0.0;
        }
      } else {
        for (var k = 0; k < i; k++) {
          d[k] /= scale;
          hVal += d[k] * d[k];
        }
        var fVal = d[i - 1];
        var gVal = math.sqrt(hVal);
        if (fVal > 0) gVal = -gVal;
        e[i] = scale * gVal;
        hVal -= fVal * gVal;
        d[i - 1] = fVal - gVal;
        for (var j = 0; j < i; j++) {
          e[j] = 0.0;
        }
        for (var j = 0; j < i; j++) {
          fVal = d[j];
          v[j * n + i] = fVal;
          gVal = e[j] + v[j * n + j] * fVal;
          for (var k = j + 1; k <= i - 1; k++) {
            gVal += v[k * n + j] * d[k];
            e[k] += v[k * n + j] * fVal;
          }
          e[j] = gVal;
        }
        fVal = 0.0;
        for (var j = 0; j < i; j++) {
          e[j] /= hVal;
          fVal += e[j] * d[j];
        }
        final hh = fVal / (hVal + hVal);
        for (var j = 0; j < i; j++) {
          e[j] -= hh * d[j];
        }
        for (var j = 0; j < i; j++) {
          fVal = d[j];
          gVal = e[j];
          for (var k = j; k <= i - 1; k++) {
            v[k * n + j] -= fVal * e[k] + gVal * d[k];
          }
          d[j] = v[(i - 1) * n + j];
          v[i * n + j] = 0.0;
        }
      }
      d[i] = hVal;
    }

    for (var i = 0; i < n - 1; i++) {
      v[(n - 1) * n + i] = v[i * n + i];
      v[i * n + i] = 1.0;
      final hVal = d[i + 1];
      if (hVal != 0.0) {
        for (var k = 0; k <= i; k++) {
          d[k] = v[k * n + (i + 1)] / hVal;
        }
        for (var j = 0; j <= i; j++) {
          var gVal = 0.0;
          for (var k = 0; k <= i; k++) {
            gVal += v[k * n + (i + 1)] * v[k * n + j];
          }
          for (var k = 0; k <= i; k++) {
            v[k * n + j] -= gVal * d[k];
          }
        }
      }
      for (var k = 0; k <= i; k++) {
        v[k * n + (i + 1)] = 0.0;
      }
    }
    for (var j = 0; j < n; j++) {
      d[j] = v[(n - 1) * n + j];
      v[(n - 1) * n + j] = 0.0;
    }
    v[(n - 1) * n + (n - 1)] = 1.0;
    e[0] = 0.0;

    // QL algorithm with implicit shifts (tql2)
    for (var i = 1; i < n; i++) {
      e[i - 1] = e[i];
    }
    e[n - 1] = 0.0;

    var fVal = 0.0;
    var tst1 = 0.0;
    const eps = 2.220446049250313e-16;
    for (var lIdx = 0; lIdx < n; lIdx++) {
      tst1 = math.max(tst1, d[lIdx].abs() + e[lIdx].abs());
      var mIdx = lIdx;
      while (mIdx < n) {
        if (e[mIdx].abs() <= eps * tst1) break;
        mIdx++;
      }
      if (mIdx > lIdx) {
        var iter = 0;
        do {
          iter++;
          if (iter > 100) return false;
          var gVal = d[lIdx];
          var pVal = (d[lIdx + 1] - gVal) / (2.0 * e[lIdx]);
          var rVal = _hypot(pVal, 1.0);
          if (pVal < 0) rVal = -rVal;
          d[lIdx] = e[lIdx] / (pVal + rVal);
          d[lIdx + 1] = e[lIdx] * (pVal + rVal);
          final dl1 = d[lIdx + 1];
          var hVal = gVal - d[lIdx];
          for (var i = lIdx + 2; i < n; i++) {
            d[i] -= hVal;
          }
          fVal += hVal;

          pVal = d[mIdx];
          var cosVal = 1.0;
          var cos2Val = cosVal;
          var cos3Val = cosVal;
          final el1 = e[lIdx + 1];
          var sinVal = 0.0;
          var sin2Val = 0.0;
          for (var i = mIdx - 1; i >= lIdx; i--) {
            cos3Val = cos2Val;
            cos2Val = cosVal;
            sin2Val = sinVal;
            gVal = cosVal * e[i];
            hVal = cosVal * pVal;
            rVal = _hypot(pVal, e[i]);
            e[i + 1] = sinVal * rVal;
            sinVal = e[i] / rVal;
            cosVal = pVal / rVal;
            pVal = cosVal * d[i] - sinVal * gVal;
            d[i + 1] = hVal + sinVal * (cosVal * gVal + sinVal * d[i]);

            for (var k = 0; k < n; k++) {
              hVal = v[k * n + (i + 1)];
              v[k * n + (i + 1)] = sinVal * v[k * n + i] + cosVal * hVal;
              v[k * n + i] = cosVal * v[k * n + i] - sinVal * hVal;
            }
          }
          pVal = -sinVal * sin2Val * cos3Val * el1 * e[lIdx] / dl1;
          e[lIdx] = sinVal * pVal;
          d[lIdx] = cosVal * pVal;
        } while (e[lIdx].abs() > eps * tst1);
      }
      d[lIdx] += fVal;
      e[lIdx] = 0.0;
    }

    // Sort eigenvalues and permute eigenvectors
    for (var i = 0; i < n - 1; i++) {
      var k = i;
      var pVal = d[i];
      for (var j = i + 1; j < n; j++) {
        if (d[j] < pVal) {
          k = j;
          pVal = d[j];
        }
      }
      if (k != i) {
        d[k] = d[i];
        d[i] = pVal;
        for (var j = 0; j < n; j++) {
          pVal = v[j * n + i];
          v[j * n + i] = v[j * n + k];
          v[j * n + k] = pVal;
        }
      }
    }

    for (var i = 0; i < n; i++) {
      w[wOffset + i] = d[i];
    }
    if (jobz.toUpperCase() == 'V') {
      for (var i = 0; i < n; i++) {
        for (var j = 0; j < n; j++) {
          a[aOffset + i * lda + j] = v[i * n + j];
        }
      }
    }
    return true;
  }

  static bool _ssyevFallback({
    required String jobz,
    required int uplo,
    required int n,
    required Float32List a,
    required int aOffset,
    required int lda,
    required Float32List w,
    required int wOffset,
  }) {
    final a64 = Float64List(n * lda);
    for (var i = 0; i < n; i++) {
      for (var j = 0; j < n; j++) {
        a64[i * lda + j] = a[aOffset + i * lda + j];
      }
    }
    final w64 = Float64List(n);
    final ok = _dsyevFallback(
      jobz: jobz,
      uplo: uplo,
      n: n,
      a: a64,
      aOffset: 0,
      lda: lda,
      w: w64,
      wOffset: 0,
    );
    if (!ok) return false;
    for (var i = 0; i < n; i++) {
      w[wOffset + i] = w64[i];
    }
    if (jobz.toUpperCase() == 'V') {
      for (var i = 0; i < n; i++) {
        for (var j = 0; j < n; j++) {
          a[aOffset + i * lda + j] = a64[i * lda + j];
        }
      }
    }
    return true;
  }

  static double _hypot(double a, double b) {
    if (a.abs() > b.abs()) {
      final ratio = b / a;
      return a.abs() * math.sqrt(1 + ratio * ratio);
    } else if (b != 0) {
      final ratio = a / b;
      return b.abs() * math.sqrt(1 + ratio * ratio);
    } else {
      return 0.0;
    }
  }

  static bool _luSolve(
    int n,
    int nrhs,
    Float64List a,
    int aOffset,
    int lda,
    Float64List b,
    int bOffset,
    int ldb,
  ) {
    final aCopy = Float64List(n * lda);
    aCopy.setRange(0, n * lda, a, aOffset);
    final bCopy = Float64List(n * ldb);
    bCopy.setRange(0, n * ldb, b, bOffset);

    for (var i = 0; i < n; i++) {
      var maxVal = aCopy[i * lda + i].abs();
      var maxRow = i;
      for (var row = i + 1; row < n; row++) {
        final val = aCopy[row * lda + i].abs();
        if (val > maxVal) {
          maxVal = val;
          maxRow = row;
        }
      }
      if (maxVal == 0.0) return false;

      if (maxRow != i) {
        for (var k = 0; k < n; k++) {
          final temp = aCopy[i * lda + k];
          aCopy[i * lda + k] = aCopy[maxRow * lda + k];
          aCopy[maxRow * lda + k] = temp;
        }
        for (var k = 0; k < nrhs; k++) {
          final temp = bCopy[i * ldb + k];
          bCopy[i * ldb + k] = bCopy[maxRow * ldb + k];
          bCopy[maxRow * ldb + k] = temp;
        }
      }

      final diag = aCopy[i * lda + i];
      for (var row = i + 1; row < n; row++) {
        final factor = aCopy[row * lda + i] / diag;
        aCopy[row * lda + i] = factor;
        for (var col = i + 1; col < n; col++) {
          aCopy[row * lda + col] -= factor * aCopy[i * lda + col];
        }
        for (var col = 0; col < nrhs; col++) {
          bCopy[row * ldb + col] -= factor * bCopy[i * ldb + col];
        }
      }
    }

    for (var col = 0; col < nrhs; col++) {
      for (var i = n - 1; i >= 0; i--) {
        var sum = bCopy[i * ldb + col];
        for (var k = i + 1; k < n; k++) {
          sum -= aCopy[i * lda + k] * bCopy[k * ldb + col];
        }
        bCopy[i * ldb + col] = sum / aCopy[i * lda + i];
      }
    }
    b.setRange(bOffset, bOffset + n * ldb, bCopy);
    return true;
  }
}
