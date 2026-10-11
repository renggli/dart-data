import 'dart:typed_data';

import '../acceleration_manager.dart';
import '../acceleration_mode.dart';
import '../blas/cblas.dart';
import '../fallback/pure_dart_gemm.dart';

/// BLAS Level 3 matrix-matrix routines.
abstract final class BlasLevel3 {
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
    required BlasLibrary blas,
  }) {
    if (AccelerationManager.mode == AccelerationMode.accelerated) {
      if (!blas.isAvailable) {
        throw StateError(
          'Native acceleration is required in AccelerationMode.accelerated, but native BLAS is unavailable.',
        );
      }
      final success = blas.dgemm(
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
      if (!success) {
        throw StateError('dgemm failed in AccelerationMode.accelerated.');
      }
      return true;
    } else if (AccelerationManager.mode == AccelerationMode.auto &&
        blas.isAvailable &&
        (m >= 64 || n >= 64 || k >= 64)) {
      final success = blas.dgemm(
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
    required BlasLibrary blas,
  }) {
    if (AccelerationManager.mode == AccelerationMode.accelerated) {
      if (!blas.isAvailable) {
        throw StateError(
          'Native acceleration is required in AccelerationMode.accelerated, but native BLAS is unavailable.',
        );
      }
      final success = blas.sgemm(
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
      if (!success) {
        throw StateError('sgemm failed in AccelerationMode.accelerated.');
      }
      return true;
    } else if (AccelerationManager.mode == AccelerationMode.auto &&
        blas.isAvailable &&
        (m >= 64 || n >= 64 || k >= 64)) {
      final success = blas.sgemm(
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
    required BlasLibrary blas,
  }) {
    if (AccelerationManager.mode == AccelerationMode.accelerated) {
      if (!blas.isAvailable) {
        throw StateError(
          'Native acceleration is required in AccelerationMode.accelerated, but native BLAS is unavailable.',
        );
      }
      final success = blas.dsyrk(
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
      if (!success) {
        throw StateError('dsyrk failed in AccelerationMode.accelerated.');
      }
      return true;
    } else if (AccelerationManager.mode == AccelerationMode.auto &&
        blas.isAvailable) {
      final success = blas.dsyrk(
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
    required BlasLibrary blas,
  }) {
    if (AccelerationManager.mode == AccelerationMode.accelerated) {
      if (!blas.isAvailable) {
        throw StateError(
          'Native acceleration is required in AccelerationMode.accelerated, but native BLAS is unavailable.',
        );
      }
      final success = blas.ssyrk(
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
      if (!success) {
        throw StateError('ssyrk failed in AccelerationMode.accelerated.');
      }
      return true;
    } else if (AccelerationManager.mode == AccelerationMode.auto &&
        blas.isAvailable) {
      final success = blas.ssyrk(
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

    if (AccelerationManager.mode == AccelerationMode.accelerated) {
      if (!blas.isAvailable) {
        throw StateError(
          'Native acceleration is required in AccelerationMode.accelerated, but native BLAS is unavailable.',
        );
      }
      final success = blas.dsymm(
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
      if (!success) {
        throw StateError('dsymm failed in AccelerationMode.accelerated.');
      }
      return true;
    } else if (AccelerationManager.mode == AccelerationMode.auto &&
        blas.isAvailable) {
      final success = blas.dsymm(
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

    if (AccelerationManager.mode == AccelerationMode.accelerated) {
      if (!blas.isAvailable) {
        throw StateError(
          'Native acceleration is required in AccelerationMode.accelerated, but native BLAS is unavailable.',
        );
      }
      final success = blas.ssymm(
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
      if (!success) {
        throw StateError('ssymm failed in AccelerationMode.accelerated.');
      }
      return true;
    } else if (AccelerationManager.mode == AccelerationMode.auto &&
        blas.isAvailable) {
      final success = blas.ssymm(
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

    if (AccelerationManager.mode == AccelerationMode.accelerated) {
      if (!blas.isAvailable) {
        throw StateError(
          'Native acceleration is required in AccelerationMode.accelerated, but native BLAS is unavailable.',
        );
      }
      final success = blas.dtrmm(
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
      if (!success) {
        throw StateError('dtrmm failed in AccelerationMode.accelerated.');
      }
      return true;
    } else if (AccelerationManager.mode == AccelerationMode.auto &&
        blas.isAvailable) {
      final success = blas.dtrmm(
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

    if (AccelerationManager.mode == AccelerationMode.accelerated) {
      if (!blas.isAvailable) {
        throw StateError(
          'Native acceleration is required in AccelerationMode.accelerated, but native BLAS is unavailable.',
        );
      }
      final success = blas.strmm(
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
      if (!success) {
        throw StateError('strmm failed in AccelerationMode.accelerated.');
      }
      return true;
    } else if (AccelerationManager.mode == AccelerationMode.auto &&
        blas.isAvailable) {
      final success = blas.strmm(
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
}
