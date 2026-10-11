import 'dart:typed_data';

import '../acceleration_manager.dart';
import '../acceleration_mode.dart';
import '../blas/cblas.dart';

/// BLAS Level 2 matrix-vector routines.
abstract final class BlasLevel2 {
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
    required BlasLibrary blas,
  }) {
    if (AccelerationManager.mode == AccelerationMode.accelerated) {
      if (!blas.isAvailable) {
        throw StateError(
          'Native acceleration is required in AccelerationMode.accelerated, but native BLAS is unavailable.',
        );
      }
      final success = blas.dgemv(
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
      if (!success) {
        throw StateError('dgemv failed in AccelerationMode.accelerated.');
      }
      return true;
    } else if (AccelerationManager.mode == AccelerationMode.auto &&
        blas.isAvailable) {
      final success = blas.dgemv(
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
    required BlasLibrary blas,
  }) {
    if (AccelerationManager.mode == AccelerationMode.accelerated) {
      if (!blas.isAvailable) {
        throw StateError(
          'Native acceleration is required in AccelerationMode.accelerated, but native BLAS is unavailable.',
        );
      }
      final success = blas.sgemv(
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
      if (!success) {
        throw StateError('sgemv failed in AccelerationMode.accelerated.');
      }
      return true;
    } else if (AccelerationManager.mode == AccelerationMode.auto &&
        blas.isAvailable) {
      final success = blas.sgemv(
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
    required BlasLibrary blas,
  }) {
    if (AccelerationManager.mode == AccelerationMode.accelerated) {
      if (!blas.isAvailable) {
        throw StateError(
          'Native acceleration is required in AccelerationMode.accelerated, but native BLAS is unavailable.',
        );
      }
      final success = blas.dsyr2(
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
      if (!success) {
        throw StateError('dsyr2 failed in AccelerationMode.accelerated.');
      }
      return true;
    } else if (AccelerationManager.mode == AccelerationMode.auto &&
        blas.isAvailable) {
      final success = blas.dsyr2(
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
    required BlasLibrary blas,
  }) {
    if (AccelerationManager.mode == AccelerationMode.accelerated) {
      if (!blas.isAvailable) {
        throw StateError(
          'Native acceleration is required in AccelerationMode.accelerated, but native BLAS is unavailable.',
        );
      }
      final success = blas.ssyr2(
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
      if (!success) {
        throw StateError('ssyr2 failed in AccelerationMode.accelerated.');
      }
      return true;
    } else if (AccelerationManager.mode == AccelerationMode.auto &&
        blas.isAvailable) {
      final success = blas.ssyr2(
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

    if (AccelerationManager.mode == AccelerationMode.accelerated) {
      if (!blas.isAvailable) {
        throw StateError(
          'Native acceleration is required in AccelerationMode.accelerated, but native BLAS is unavailable.',
        );
      }
      final success = blas.dtrmv(
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
      if (!success) {
        throw StateError('dtrmv failed in AccelerationMode.accelerated.');
      }
      return true;
    } else if (AccelerationManager.mode == AccelerationMode.auto &&
        blas.isAvailable) {
      final success = blas.dtrmv(
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

    if (AccelerationManager.mode == AccelerationMode.accelerated) {
      if (!blas.isAvailable) {
        throw StateError(
          'Native acceleration is required in AccelerationMode.accelerated, but native BLAS is unavailable.',
        );
      }
      final success = blas.strmv(
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
      if (!success) {
        throw StateError('strmv failed in AccelerationMode.accelerated.');
      }
      return true;
    } else if (AccelerationManager.mode == AccelerationMode.auto &&
        blas.isAvailable) {
      final success = blas.strmv(
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
}
