import 'dart:math' as math;
import 'dart:typed_data';

import 'cblas.dart';
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
    if (isAccelerated) {
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

    // Pure Dart fallback
    for (var i = 0; i < m; i++) {
      for (var j = 0; j < n; j++) {
        var sum = 0.0;
        for (var p = 0; p < k; p++) {
          final aVal = transA == cblasTrans
              ? a[aOffset + p * lda + i]
              : a[aOffset + i * lda + p];
          final bVal = transB == cblasTrans
              ? b[bOffset + j * ldb + p]
              : b[bOffset + p * ldb + j];
          sum += aVal * bVal;
        }
        final cIdx = cOffset + i * ldc + j;
        c[cIdx] = alpha * sum + (beta == 0.0 ? 0.0 : beta * c[cIdx]);
      }
    }
    return true;
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
    if (isAccelerated) {
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

    // Pure Dart fallback
    for (var i = 0; i < m; i++) {
      for (var j = 0; j < n; j++) {
        var sum = 0.0;
        for (var p = 0; p < k; p++) {
          final aVal = transA == cblasTrans
              ? a[aOffset + p * lda + i]
              : a[aOffset + i * lda + p];
          final bVal = transB == cblasTrans
              ? b[bOffset + j * ldb + p]
              : b[bOffset + p * ldb + j];
          sum += aVal * bVal;
        }
        final cIdx = cOffset + i * ldc + j;
        c[cIdx] = alpha * sum + (beta == 0.0 ? 0.0 : beta * c[cIdx]);
      }
    }
    return true;
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
          for (var p = 0; p < k; p++) {
            sum += a[aOffset + p * lda + i] * a[aOffset + p * lda + j];
          }
        } else {
          for (var p = 0; p < k; p++) {
            sum += a[aOffset + i * lda + p] * a[aOffset + j * lda + p];
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
          for (var p = 0; p < k; p++) {
            sum += a[aOffset + p * lda + i] * a[aOffset + p * lda + j];
          }
        } else {
          for (var p = 0; p < k; p++) {
            sum += a[aOffset + i * lda + p] * a[aOffset + j * lda + p];
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
    final l = Float64List(n * n);
    for (var i = 0; i < n; i++) {
      for (var j = 0; j <= i; j++) {
        var sum = 0.0;
        for (var k = 0; k < j; k++) {
          sum += l[i * n + k] * l[j * n + k];
        }
        if (i == j) {
          final val = a[aOffset + i * lda + i] - sum;
          if (val <= 0.0) return false;
          l[i * n + j] = math.sqrt(val);
        } else {
          final denom = l[j * n + j];
          if (denom == 0.0) return false;
          l[i * n + j] = (a[aOffset + i * lda + j] - sum) / denom;
        }
      }
    }

    if (uplo == cblasUpper) {
      for (var i = 0; i < n; i++) {
        for (var j = i; j < n; j++) {
          a[aOffset + i * lda + j] = l[j * n + i];
        }
      }
    } else {
      for (var i = 0; i < n; i++) {
        for (var j = 0; j <= i; j++) {
          a[aOffset + i * lda + j] = l[i * n + j];
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
      for (var r = i + 1; r < n; r++) {
        final val = aCopy[r * lda + i].abs();
        if (val > maxVal) {
          maxVal = val;
          maxRow = r;
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
      for (var r = i + 1; r < n; r++) {
        final factor = aCopy[r * lda + i] / diag;
        aCopy[r * lda + i] = factor;
        for (var c = i + 1; c < n; c++) {
          aCopy[r * lda + c] -= factor * aCopy[i * lda + c];
        }
        for (var c = 0; c < nrhs; c++) {
          bCopy[r * ldb + c] -= factor * bCopy[i * ldb + c];
        }
      }
    }

    for (var c = 0; c < nrhs; c++) {
      for (var i = n - 1; i >= 0; i--) {
        var sum = bCopy[i * ldb + c];
        for (var k = i + 1; k < n; k++) {
          sum -= aCopy[i * lda + k] * bCopy[k * ldb + c];
        }
        bCopy[i * ldb + c] = sum / aCopy[i * lda + i];
      }
    }
    b.setRange(bOffset, bOffset + n * ldb, bCopy);
    return true;
  }
}
