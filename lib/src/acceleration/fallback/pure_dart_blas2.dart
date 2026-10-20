import 'dart:typed_data';

import '../blas/cblas.dart';

/// Pure Dart reference implementations of BLAS Level 2 matrix-vector routines.
abstract final class PureDartBlas2 {
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
  }) {
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
  }) {
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
  }) {
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
  }) {
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
  }) {
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
  }) {
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
