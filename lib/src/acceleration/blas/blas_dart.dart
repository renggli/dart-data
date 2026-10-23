import 'dart:math' as math;
import 'dart:typed_data';

import 'blas_validation.dart';
import 'cblas_constants.dart';

/// Block tile size for cache-blocked GEMM.
const int _gemmBlockSize = 32;

/// Pure Dart reference implementation of BLAS routines.
abstract final class BlasDart {
  // --- BLAS Level 1: Vector-Vector Operations ---

  /// Computes dot product of two [Float64List] vectors.
  static double ddot({
    required int n,
    required Float64List x,
    required int xOffset,
    required int incX,
    required Float64List y,
    required int yOffset,
    required int incY,
  }) {
    if (n <= 0) return 0.0;
    final startX = xOffset + (incX < 0 ? (1 - n) * incX : 0);
    final startY = yOffset + (incY < 0 ? (1 - n) * incY : 0);
    var sum = 0.0;
    for (
      var i = 0, xi = startX, yi = startY;
      i < n;
      i++, xi += incX, yi += incY
    ) {
      sum += x[xi] * y[yi];
    }
    return sum;
  }

  /// Computes dot product of two [Float32List] vectors.
  static double sdot({
    required int n,
    required Float32List x,
    required int xOffset,
    required int incX,
    required Float32List y,
    required int yOffset,
    required int incY,
  }) {
    if (n <= 0) return 0.0;
    final startX = xOffset + (incX < 0 ? (1 - n) * incX : 0);
    final startY = yOffset + (incY < 0 ? (1 - n) * incY : 0);
    var sum = 0.0;
    for (
      var i = 0, xi = startX, yi = startY;
      i < n;
      i++, xi += incX, yi += incY
    ) {
      sum += x[xi] * y[yi];
    }
    return sum;
  }

  /// Computes Euclidean norm of a [Float64List] vector.
  static double dnrm2({
    required int n,
    required Float64List x,
    required int xOffset,
    required int incX,
  }) {
    if (n <= 0) return 0.0;
    if (n == 1) return x[xOffset].abs();
    var scale = 0.0;
    var sumsq = 1.0;
    final startX = xOffset + (incX < 0 ? (1 - n) * incX : 0);
    for (var i = 0, xi = startX; i < n; i++, xi += incX) {
      final val = x[xi];
      if (val != 0.0) {
        final absVal = val.abs();
        if (scale < absVal) {
          sumsq = 1.0 + sumsq * (scale / absVal) * (scale / absVal);
          scale = absVal;
        } else {
          sumsq += (absVal / scale) * (absVal / scale);
        }
      }
    }
    return scale * math.sqrt(sumsq);
  }

  /// Computes Euclidean norm of a [Float32List] vector.
  static double snrm2({
    required int n,
    required Float32List x,
    required int xOffset,
    required int incX,
  }) {
    if (n <= 0) return 0.0;
    if (n == 1) return x[xOffset].abs();
    var scale = 0.0;
    var sumsq = 1.0;
    final startX = xOffset + (incX < 0 ? (1 - n) * incX : 0);
    for (var i = 0, xi = startX; i < n; i++, xi += incX) {
      final val = x[xi];
      if (val != 0.0) {
        final absVal = val.abs();
        if (scale < absVal) {
          sumsq = 1.0 + sumsq * (scale / absVal) * (scale / absVal);
          scale = absVal;
        } else {
          sumsq += (absVal / scale) * (absVal / scale);
        }
      }
    }
    return scale * math.sqrt(sumsq);
  }

  /// Computes in-place scaled addition `y = alpha * x + y` for [Float64List].
  static bool daxpy({
    required int n,
    required double alpha,
    required Float64List x,
    required int xOffset,
    required int incX,
    required Float64List y,
    required int yOffset,
    required int incY,
  }) {
    if (n <= 0 || alpha == 0.0) return true;
    final startX = xOffset + (incX < 0 ? (1 - n) * incX : 0);
    final startY = yOffset + (incY < 0 ? (1 - n) * incY : 0);
    for (
      var i = 0, xi = startX, yi = startY;
      i < n;
      i++, xi += incX, yi += incY
    ) {
      y[yi] += alpha * x[xi];
    }
    return true;
  }

  /// Computes in-place scaled addition `y = alpha * x + y` for [Float32List].
  static bool saxpy({
    required int n,
    required double alpha,
    required Float32List x,
    required int xOffset,
    required int incX,
    required Float32List y,
    required int yOffset,
    required int incY,
  }) {
    if (n <= 0 || alpha == 0.0) return true;
    final startX = xOffset + (incX < 0 ? (1 - n) * incX : 0);
    final startY = yOffset + (incY < 0 ? (1 - n) * incY : 0);
    for (
      var i = 0, xi = startX, yi = startY;
      i < n;
      i++, xi += incX, yi += incY
    ) {
      y[yi] += alpha * x[xi];
    }
    return true;
  }

  /// In-place scaling `x = alpha * x` for [Float64List].
  static bool dscal({
    required int n,
    required double alpha,
    required Float64List x,
    required int xOffset,
    required int incX,
  }) {
    if (n <= 0) return true;
    final startX = xOffset + (incX < 0 ? (1 - n) * incX : 0);
    for (var i = 0, xi = startX; i < n; i++, xi += incX) {
      x[xi] *= alpha;
    }
    return true;
  }

  /// In-place scaling `x = alpha * x` for [Float32List].
  static bool sscal({
    required int n,
    required double alpha,
    required Float32List x,
    required int xOffset,
    required int incX,
  }) {
    if (n <= 0) return true;
    final startX = xOffset + (incX < 0 ? (1 - n) * incX : 0);
    for (var i = 0, xi = startX; i < n; i++, xi += incX) {
      x[xi] *= alpha;
    }
    return true;
  }

  // --- BLAS Level 2: Matrix-Vector Operations ---

  /// Computes matrix-vector product `y = alpha * op(A) * x + beta * y` for
  /// [Float64List].
  static bool dgemv({
    required int transA,
    required int m,
    required int n,
    required double alpha,
    required Float64List a,
    required int aOffset,
    required int lda,
    required Float64List x,
    required int xOffset,
    required int incX,
    required double beta,
    required Float64List y,
    required int yOffset,
    required int incY,
  }) {
    final isTransA = transA == cblasTrans || transA == cblasConjTrans;
    final lenY = isTransA ? n : m;
    final lenX = isTransA ? m : n;
    final startX = xOffset + (incX < 0 ? (1 - lenX) * incX : 0);
    final startY = yOffset + (incY < 0 ? (1 - lenY) * incY : 0);
    for (var i = 0; i < lenY; i++) {
      var sum = 0.0;
      for (var j = 0; j < lenX; j++) {
        final aVal = isTransA
            ? a[aOffset + j * lda + i]
            : a[aOffset + i * lda + j];
        sum += aVal * x[startX + j * incX];
      }
      final yIdx = startY + i * incY;
      y[yIdx] = alpha * sum + (beta == 0.0 ? 0.0 : beta * y[yIdx]);
    }
    return true;
  }

  /// Computes matrix-vector product `y = alpha * op(A) * x + beta * y` for
  /// [Float32List].
  static bool sgemv({
    required int transA,
    required int m,
    required int n,
    required double alpha,
    required Float32List a,
    required int aOffset,
    required int lda,
    required Float32List x,
    required int xOffset,
    required int incX,
    required double beta,
    required Float32List y,
    required int yOffset,
    required int incY,
  }) {
    final isTransA = transA == cblasTrans || transA == cblasConjTrans;
    final lenY = isTransA ? n : m;
    final lenX = isTransA ? m : n;
    final startX = xOffset + (incX < 0 ? (1 - lenX) * incX : 0);
    final startY = yOffset + (incY < 0 ? (1 - lenY) * incY : 0);
    for (var i = 0; i < lenY; i++) {
      var sum = 0.0;
      for (var j = 0; j < lenX; j++) {
        final aVal = isTransA
            ? a[aOffset + j * lda + i]
            : a[aOffset + i * lda + j];
        sum += aVal * x[startX + j * incX];
      }
      final yIdx = startY + i * incY;
      y[yIdx] = alpha * sum + (beta == 0.0 ? 0.0 : beta * y[yIdx]);
    }
    return true;
  }

  /// Performs symmetric rank-2 update `A = alpha * x * y^T + alpha * y * x^T + A`
  /// for [Float64List].
  static bool dsyr2({
    required int uplo,
    required int n,
    required double alpha,
    required Float64List x,
    required int xOffset,
    required int incX,
    required Float64List y,
    required int yOffset,
    required int incY,
    required Float64List a,
    required int aOffset,
    required int lda,
  }) {
    final startX = xOffset + (incX < 0 ? (1 - n) * incX : 0);
    final startY = yOffset + (incY < 0 ? (1 - n) * incY : 0);
    if (uplo == cblasUpper) {
      for (var i = 0; i < n; i++) {
        final xi = x[startX + i * incX];
        final yi = y[startY + i * incY];
        for (var j = i; j < n; j++) {
          final xj = x[startX + j * incX];
          final yj = y[startY + j * incY];
          a[aOffset + i * lda + j] += alpha * (xi * yj + yi * xj);
        }
      }
    } else {
      for (var i = 0; i < n; i++) {
        final xi = x[startX + i * incX];
        final yi = y[startY + i * incY];
        for (var j = 0; j <= i; j++) {
          final xj = x[startX + j * incX];
          final yj = y[startY + j * incY];
          a[aOffset + i * lda + j] += alpha * (xi * yj + yi * xj);
        }
      }
    }
    mirrorSymmetricDouble(a, aOffset, n, lda, uplo);
    return true;
  }

  /// Performs symmetric rank-2 update `A = alpha * x * y^T + alpha * y * x^T + A`
  /// for [Float32List].
  static bool ssyr2({
    required int uplo,
    required int n,
    required double alpha,
    required Float32List x,
    required int xOffset,
    required int incX,
    required Float32List y,
    required int yOffset,
    required int incY,
    required Float32List a,
    required int aOffset,
    required int lda,
  }) {
    final startX = xOffset + (incX < 0 ? (1 - n) * incX : 0);
    final startY = yOffset + (incY < 0 ? (1 - n) * incY : 0);
    if (uplo == cblasUpper) {
      for (var i = 0; i < n; i++) {
        final xi = x[startX + i * incX];
        final yi = y[startY + i * incY];
        for (var j = i; j < n; j++) {
          final xj = x[startX + j * incX];
          final yj = y[startY + j * incY];
          a[aOffset + i * lda + j] += alpha * (xi * yj + yi * xj);
        }
      }
    } else {
      for (var i = 0; i < n; i++) {
        final xi = x[startX + i * incX];
        final yi = y[startY + i * incY];
        for (var j = 0; j <= i; j++) {
          final xj = x[startX + j * incX];
          final yj = y[startY + j * incY];
          a[aOffset + i * lda + j] += alpha * (xi * yj + yi * xj);
        }
      }
    }
    mirrorSymmetricFloat(a, aOffset, n, lda, uplo);
    return true;
  }

  /// Computes matrix-vector product for a triangular matrix for [Float64List].
  static bool dtrmv({
    required int uplo,
    required int trans,
    required int diag,
    required int n,
    required Float64List a,
    required int aOffset,
    required int lda,
    required Float64List x,
    required int xOffset,
    required int incX,
  }) {
    if (n <= 0) return true;
    final temp = Float64List(n);
    final isUpper = uplo == cblasUpper;
    final isUnit = diag == cblasUnit;
    final isNoTrans = trans == cblasNoTrans;
    final startX = xOffset + (incX < 0 ? (1 - n) * incX : 0);

    for (var i = 0; i < n; i++) {
      var sum = 0.0;
      if (isNoTrans) {
        final start = isUpper ? i : 0;
        final end = isUpper ? n : i + 1;
        for (var j = start; j < end; j++) {
          final aVal = (i == j && isUnit) ? 1.0 : a[aOffset + i * lda + j];
          sum += aVal * x[startX + j * incX];
        }
      } else {
        final start = isUpper ? 0 : i;
        final end = isUpper ? i + 1 : n;
        for (var j = start; j < end; j++) {
          final aVal = (i == j && isUnit) ? 1.0 : a[aOffset + j * lda + i];
          sum += aVal * x[startX + j * incX];
        }
      }
      temp[i] = sum;
    }
    for (var i = 0; i < n; i++) {
      x[startX + i * incX] = temp[i];
    }
    return true;
  }

  /// Computes matrix-vector product for a triangular matrix for [Float32List].
  static bool strmv({
    required int uplo,
    required int trans,
    required int diag,
    required int n,
    required Float32List a,
    required int aOffset,
    required int lda,
    required Float32List x,
    required int xOffset,
    required int incX,
  }) {
    if (n <= 0) return true;
    final temp = Float32List(n);
    final isUpper = uplo == cblasUpper;
    final isUnit = diag == cblasUnit;
    final isNoTrans = trans == cblasNoTrans;
    final startX = xOffset + (incX < 0 ? (1 - n) * incX : 0);

    for (var i = 0; i < n; i++) {
      var sum = 0.0;
      if (isNoTrans) {
        final start = isUpper ? i : 0;
        final end = isUpper ? n : i + 1;
        for (var j = start; j < end; j++) {
          final aVal = (i == j && isUnit) ? 1.0 : a[aOffset + i * lda + j];
          sum += aVal * x[startX + j * incX];
        }
      } else {
        final start = isUpper ? 0 : i;
        final end = isUpper ? i + 1 : n;
        for (var j = start; j < end; j++) {
          final aVal = (i == j && isUnit) ? 1.0 : a[aOffset + j * lda + i];
          sum += aVal * x[startX + j * incX];
        }
      }
      temp[i] = sum;
    }
    for (var i = 0; i < n; i++) {
      x[startX + i * incX] = temp[i];
    }
    return true;
  }

  // --- BLAS Level 3: Matrix-Matrix Operations ---

  /// General matrix multiplication $C = \alpha \operatorname{op}(A) \operatorname{op}(B) + \beta C$
  /// for [Float64List].
  static bool dgemm({
    required int transA,
    required int transB,
    required int m,
    required int n,
    required int k,
    required double alpha,
    required Float64List a,
    required int aOffset,
    required int lda,
    required Float64List b,
    required int bOffset,
    required int ldb,
    required double beta,
    required Float64List c,
    required int cOffset,
    required int ldc,
  }) {
    if (m <= 0 || n <= 0) return true;

    if (beta == 0.0) {
      for (var i = 0; i < m; i++) {
        final cRow = cOffset + i * ldc;
        c.fillRange(cRow, cRow + n, 0.0);
      }
    } else if (beta != 1.0) {
      for (var i = 0; i < m; i++) {
        final cRow = cOffset + i * ldc;
        for (var j = 0; j < n; j++) {
          c[cRow + j] *= beta;
        }
      }
    }

    if (alpha == 0.0 || k <= 0) return true;

    final isTransA = transA == cblasTrans || transA == cblasConjTrans;
    final isTransB = transB == cblasTrans || transB == cblasConjTrans;

    if (!isTransA && !isTransB) {
      for (var ii = 0; ii < m; ii += _gemmBlockSize) {
        final iLimit = math.min(ii + _gemmBlockSize, m);
        for (var kk = 0; kk < k; kk += _gemmBlockSize) {
          final kLimit = math.min(kk + _gemmBlockSize, k);
          for (var jj = 0; jj < n; jj += _gemmBlockSize) {
            final jLimit = math.min(jj + _gemmBlockSize, n);
            for (var i = ii; i < iLimit; i++) {
              final aRow = aOffset + i * lda;
              final cRow = cOffset + i * ldc;
              for (var p = kk; p < kLimit; p++) {
                final aVal = alpha * a[aRow + p];
                final bRow = bOffset + p * ldb;
                var j = jj;
                final unrolledEnd = jj + ((jLimit - jj) & ~3);
                for (; j < unrolledEnd; j += 4) {
                  c[cRow + j] += aVal * b[bRow + j];
                  c[cRow + j + 1] += aVal * b[bRow + j + 1];
                  c[cRow + j + 2] += aVal * b[bRow + j + 2];
                  c[cRow + j + 3] += aVal * b[bRow + j + 3];
                }
                for (; j < jLimit; j++) {
                  c[cRow + j] += aVal * b[bRow + j];
                }
              }
            }
          }
        }
      }
    } else if (isTransA && !isTransB) {
      for (var ii = 0; ii < m; ii += _gemmBlockSize) {
        final iLimit = math.min(ii + _gemmBlockSize, m);
        for (var kk = 0; kk < k; kk += _gemmBlockSize) {
          final kLimit = math.min(kk + _gemmBlockSize, k);
          for (var jj = 0; jj < n; jj += _gemmBlockSize) {
            final jLimit = math.min(jj + _gemmBlockSize, n);
            for (var i = ii; i < iLimit; i++) {
              final cRow = cOffset + i * ldc;
              for (var p = kk; p < kLimit; p++) {
                final aVal = alpha * a[aOffset + p * lda + i];
                final bRow = bOffset + p * ldb;
                var j = jj;
                final unrolledEnd = jj + ((jLimit - jj) & ~3);
                for (; j < unrolledEnd; j += 4) {
                  c[cRow + j] += aVal * b[bRow + j];
                  c[cRow + j + 1] += aVal * b[bRow + j + 1];
                  c[cRow + j + 2] += aVal * b[bRow + j + 2];
                  c[cRow + j + 3] += aVal * b[bRow + j + 3];
                }
                for (; j < jLimit; j++) {
                  c[cRow + j] += aVal * b[bRow + j];
                }
              }
            }
          }
        }
      }
    } else if (!isTransA && isTransB) {
      for (var ii = 0; ii < m; ii += _gemmBlockSize) {
        final iLimit = math.min(ii + _gemmBlockSize, m);
        for (var jj = 0; jj < n; jj += _gemmBlockSize) {
          final jLimit = math.min(jj + _gemmBlockSize, n);
          for (var kk = 0; kk < k; kk += _gemmBlockSize) {
            final kLimit = math.min(kk + _gemmBlockSize, k);
            for (var i = ii; i < iLimit; i++) {
              final aRow = aOffset + i * lda;
              final cRow = cOffset + i * ldc;
              for (var j = jj; j < jLimit; j++) {
                final bRow = bOffset + j * ldb;
                var sum = 0.0;
                var p = kk;
                final unrolledEnd = kk + ((kLimit - kk) & ~3);
                for (; p < unrolledEnd; p += 4) {
                  sum +=
                      a[aRow + p] * b[bRow + p] +
                      a[aRow + p + 1] * b[bRow + p + 1] +
                      a[aRow + p + 2] * b[bRow + p + 2] +
                      a[aRow + p + 3] * b[bRow + p + 3];
                }
                for (; p < kLimit; p++) {
                  sum += a[aRow + p] * b[bRow + p];
                }
                c[cRow + j] += alpha * sum;
              }
            }
          }
        }
      }
    } else {
      // Both transposed
      for (var i = 0; i < m; i++) {
        final cRow = cOffset + i * ldc;
        for (var j = 0; j < n; j++) {
          final bRow = bOffset + j * ldb;
          var sum = 0.0;
          for (var p = 0; p < k; p++) {
            sum += a[aOffset + p * lda + i] * b[bRow + p];
          }
          c[cRow + j] += alpha * sum;
        }
      }
    }
    return true;
  }

  /// General matrix multiplication $C = \alpha \operatorname{op}(A) \operatorname{op}(B) + \beta C$
  /// for [Float32List].
  static bool sgemm({
    required int transA,
    required int transB,
    required int m,
    required int n,
    required int k,
    required double alpha,
    required Float32List a,
    required int aOffset,
    required int lda,
    required Float32List b,
    required int bOffset,
    required int ldb,
    required double beta,
    required Float32List c,
    required int cOffset,
    required int ldc,
  }) {
    if (m <= 0 || n <= 0) return true;

    if (beta == 0.0) {
      for (var i = 0; i < m; i++) {
        final cRow = cOffset + i * ldc;
        c.fillRange(cRow, cRow + n, 0.0);
      }
    } else if (beta != 1.0) {
      for (var i = 0; i < m; i++) {
        final cRow = cOffset + i * ldc;
        for (var j = 0; j < n; j++) {
          c[cRow + j] *= beta;
        }
      }
    }

    if (alpha == 0.0 || k <= 0) return true;

    final isTransA = transA == cblasTrans || transA == cblasConjTrans;
    final isTransB = transB == cblasTrans || transB == cblasConjTrans;

    if (!isTransA && !isTransB) {
      for (var ii = 0; ii < m; ii += _gemmBlockSize) {
        final iLimit = math.min(ii + _gemmBlockSize, m);
        for (var kk = 0; kk < k; kk += _gemmBlockSize) {
          final kLimit = math.min(kk + _gemmBlockSize, k);
          for (var jj = 0; jj < n; jj += _gemmBlockSize) {
            final jLimit = math.min(jj + _gemmBlockSize, n);
            for (var i = ii; i < iLimit; i++) {
              final aRow = aOffset + i * lda;
              final cRow = cOffset + i * ldc;
              for (var p = kk; p < kLimit; p++) {
                final aVal = alpha * a[aRow + p];
                final bRow = bOffset + p * ldb;
                var j = jj;
                final unrolledEnd = jj + ((jLimit - jj) & ~3);
                for (; j < unrolledEnd; j += 4) {
                  c[cRow + j] += aVal * b[bRow + j];
                  c[cRow + j + 1] += aVal * b[bRow + j + 1];
                  c[cRow + j + 2] += aVal * b[bRow + j + 2];
                  c[cRow + j + 3] += aVal * b[bRow + j + 3];
                }
                for (; j < jLimit; j++) {
                  c[cRow + j] += aVal * b[bRow + j];
                }
              }
            }
          }
        }
      }
    } else if (isTransA && !isTransB) {
      for (var ii = 0; ii < m; ii += _gemmBlockSize) {
        final iLimit = math.min(ii + _gemmBlockSize, m);
        for (var kk = 0; kk < k; kk += _gemmBlockSize) {
          final kLimit = math.min(kk + _gemmBlockSize, k);
          for (var jj = 0; jj < n; jj += _gemmBlockSize) {
            final jLimit = math.min(jj + _gemmBlockSize, n);
            for (var i = ii; i < iLimit; i++) {
              final cRow = cOffset + i * ldc;
              for (var p = kk; p < kLimit; p++) {
                final aVal = alpha * a[aOffset + p * lda + i];
                final bRow = bOffset + p * ldb;
                var j = jj;
                final unrolledEnd = jj + ((jLimit - jj) & ~3);
                for (; j < unrolledEnd; j += 4) {
                  c[cRow + j] += aVal * b[bRow + j];
                  c[cRow + j + 1] += aVal * b[bRow + j + 1];
                  c[cRow + j + 2] += aVal * b[bRow + j + 2];
                  c[cRow + j + 3] += aVal * b[bRow + j + 3];
                }
                for (; j < jLimit; j++) {
                  c[cRow + j] += aVal * b[bRow + j];
                }
              }
            }
          }
        }
      }
    } else if (!isTransA && isTransB) {
      for (var ii = 0; ii < m; ii += _gemmBlockSize) {
        final iLimit = math.min(ii + _gemmBlockSize, m);
        for (var jj = 0; jj < n; jj += _gemmBlockSize) {
          final jLimit = math.min(jj + _gemmBlockSize, n);
          for (var kk = 0; kk < k; kk += _gemmBlockSize) {
            final kLimit = math.min(kk + _gemmBlockSize, k);
            for (var i = ii; i < iLimit; i++) {
              final aRow = aOffset + i * lda;
              final cRow = cOffset + i * ldc;
              for (var j = jj; j < jLimit; j++) {
                final bRow = bOffset + j * ldb;
                var sum = 0.0;
                var p = kk;
                final unrolledEnd = kk + ((kLimit - kk) & ~3);
                for (; p < unrolledEnd; p += 4) {
                  sum +=
                      a[aRow + p] * b[bRow + p] +
                      a[aRow + p + 1] * b[bRow + p + 1] +
                      a[aRow + p + 2] * b[bRow + p + 2] +
                      a[aRow + p + 3] * b[bRow + p + 3];
                }
                for (; p < kLimit; p++) {
                  sum += a[aRow + p] * b[bRow + p];
                }
                c[cRow + j] += alpha * sum;
              }
            }
          }
        }
      }
    } else {
      for (var i = 0; i < m; i++) {
        final cRow = cOffset + i * ldc;
        for (var j = 0; j < n; j++) {
          final bRow = bOffset + j * ldb;
          var sum = 0.0;
          for (var p = 0; p < k; p++) {
            sum += a[aOffset + p * lda + i] * b[bRow + p];
          }
          c[cRow + j] += alpha * sum;
        }
      }
    }
    return true;
  }

  /// Performs symmetric rank-$k$ update: $C = \alpha A A^T + \beta C$ or
  /// $C = \alpha A^T A + \beta C$ for [Float64List].
  static bool dsyrk({
    required int uplo,
    required int trans,
    required int n,
    required int k,
    required double alpha,
    required Float64List a,
    required int aOffset,
    required int lda,
    required double beta,
    required Float64List c,
    required int cOffset,
    required int ldc,
  }) {
    if (n <= 0) return true;
    final isUpper = uplo == cblasUpper;
    final isTrans = trans == cblasTrans || trans == cblasConjTrans;
    for (var i = 0; i < n; i++) {
      final jStart = isUpper ? i : 0;
      final jEnd = isUpper ? n : i + 1;
      for (var j = jStart; j < jEnd; j++) {
        var sum = 0.0;
        for (var p = 0; p < k; p++) {
          final aVal1 = isTrans
              ? a[aOffset + p * lda + i]
              : a[aOffset + i * lda + p];
          final aVal2 = isTrans
              ? a[aOffset + p * lda + j]
              : a[aOffset + j * lda + p];
          sum += aVal1 * aVal2;
        }
        final cIdx = cOffset + i * ldc + j;
        c[cIdx] = alpha * sum + (beta == 0.0 ? 0.0 : beta * c[cIdx]);
      }
    }
    mirrorSymmetricDouble(c, cOffset, n, ldc, uplo);
    return true;
  }

  /// Performs symmetric rank-$k$ update for [Float32List].
  static bool ssyrk({
    required int uplo,
    required int trans,
    required int n,
    required int k,
    required double alpha,
    required Float32List a,
    required int aOffset,
    required int lda,
    required double beta,
    required Float32List c,
    required int cOffset,
    required int ldc,
  }) {
    if (n <= 0) return true;
    final isUpper = uplo == cblasUpper;
    final isTrans = trans == cblasTrans || trans == cblasConjTrans;
    for (var i = 0; i < n; i++) {
      final jStart = isUpper ? i : 0;
      final jEnd = isUpper ? n : i + 1;
      for (var j = jStart; j < jEnd; j++) {
        var sum = 0.0;
        for (var p = 0; p < k; p++) {
          final aVal1 = isTrans
              ? a[aOffset + p * lda + i]
              : a[aOffset + i * lda + p];
          final aVal2 = isTrans
              ? a[aOffset + p * lda + j]
              : a[aOffset + j * lda + p];
          sum += aVal1 * aVal2;
        }
        final cIdx = cOffset + i * ldc + j;
        c[cIdx] = alpha * sum + (beta == 0.0 ? 0.0 : beta * c[cIdx]);
      }
    }
    mirrorSymmetricFloat(c, cOffset, n, ldc, uplo);
    return true;
  }

  /// Performs symmetric matrix-matrix multiplication $C = \alpha A B + \beta C$
  /// or $C = \alpha B A + \beta C$ for [Float64List].
  static bool dsymm({
    required int side,
    required int uplo,
    required int m,
    required int n,
    required double alpha,
    required Float64List a,
    required int aOffset,
    required int lda,
    required Float64List b,
    required int bOffset,
    required int ldb,
    required double beta,
    required Float64List c,
    required int cOffset,
    required int ldc,
  }) {
    if (m <= 0 || n <= 0) return true;
    final isLeft = side == cblasLeft;
    final isUpper = uplo == cblasUpper;
    for (var i = 0; i < m; i++) {
      for (var j = 0; j < n; j++) {
        var sum = 0.0;
        if (isLeft) {
          for (var k = 0; k < m; k++) {
            final aVal = (isUpper ? (k >= i) : (k <= i))
                ? a[aOffset + (isUpper ? i * lda + k : k * lda + i)]
                : a[aOffset + (isUpper ? k * lda + i : i * lda + k)];
            sum += aVal * b[bOffset + k * ldb + j];
          }
        } else {
          for (var k = 0; k < n; k++) {
            final aVal = (isUpper ? (k >= j) : (k <= j))
                ? a[aOffset + (isUpper ? j * lda + k : k * lda + j)]
                : a[aOffset + (isUpper ? k * lda + j : j * lda + k)];
            sum += b[bOffset + i * ldb + k] * aVal;
          }
        }
        final cIdx = cOffset + i * ldc + j;
        c[cIdx] = alpha * sum + (beta == 0.0 ? 0.0 : beta * c[cIdx]);
      }
    }
    return true;
  }

  /// Performs symmetric matrix-matrix multiplication for [Float32List].
  static bool ssymm({
    required int side,
    required int uplo,
    required int m,
    required int n,
    required double alpha,
    required Float32List a,
    required int aOffset,
    required int lda,
    required Float32List b,
    required int bOffset,
    required int ldb,
    required double beta,
    required Float32List c,
    required int cOffset,
    required int ldc,
  }) {
    if (m <= 0 || n <= 0) return true;
    final isLeft = side == cblasLeft;
    final isUpper = uplo == cblasUpper;
    for (var i = 0; i < m; i++) {
      for (var j = 0; j < n; j++) {
        var sum = 0.0;
        if (isLeft) {
          for (var k = 0; k < m; k++) {
            final aVal = (isUpper ? (k >= i) : (k <= i))
                ? a[aOffset + (isUpper ? i * lda + k : k * lda + i)]
                : a[aOffset + (isUpper ? k * lda + i : i * lda + k)];
            sum += aVal * b[bOffset + k * ldb + j];
          }
        } else {
          for (var k = 0; k < n; k++) {
            final aVal = (isUpper ? (k >= j) : (k <= j))
                ? a[aOffset + (isUpper ? j * lda + k : k * lda + j)]
                : a[aOffset + (isUpper ? k * lda + j : j * lda + k)];
            sum += b[bOffset + i * ldb + k] * aVal;
          }
        }
        final cIdx = cOffset + i * ldc + j;
        c[cIdx] = alpha * sum + (beta == 0.0 ? 0.0 : beta * c[cIdx]);
      }
    }
    return true;
  }

  /// Performs triangular matrix-matrix multiplication $B = \alpha \operatorname{op}(A) B$
  /// or $B = \alpha B \operatorname{op}(A)$ for [Float64List].
  static bool dtrmm({
    required int side,
    required int uplo,
    required int transA,
    required int diag,
    required int m,
    required int n,
    required double alpha,
    required Float64List a,
    required int aOffset,
    required int lda,
    required Float64List b,
    required int bOffset,
    required int ldb,
  }) {
    if (m <= 0 || n <= 0) return true;
    final temp = Float64List(m * n);
    final isLeft = side == cblasLeft;
    final isUpper = uplo == cblasUpper;
    final isUnit = diag == cblasUnit;
    final isTransA = transA == cblasTrans || transA == cblasConjTrans;

    for (var i = 0; i < m; i++) {
      for (var j = 0; j < n; j++) {
        var sum = 0.0;
        if (isLeft) {
          if (!isTransA) {
            final start = isUpper ? i : 0;
            final end = isUpper ? m : i + 1;
            for (var k = start; k < end; k++) {
              final aVal = (i == k && isUnit) ? 1.0 : a[aOffset + i * lda + k];
              sum += aVal * b[bOffset + k * ldb + j];
            }
          } else {
            final start = isUpper ? 0 : i;
            final end = isUpper ? i + 1 : m;
            for (var k = start; k < end; k++) {
              final aVal = (i == k && isUnit) ? 1.0 : a[aOffset + k * lda + i];
              sum += aVal * b[bOffset + k * ldb + j];
            }
          }
        } else {
          if (!isTransA) {
            final start = isUpper ? 0 : j;
            final end = isUpper ? j + 1 : n;
            for (var k = start; k < end; k++) {
              final aVal = (k == j && isUnit) ? 1.0 : a[aOffset + k * lda + j];
              sum += b[bOffset + i * ldb + k] * aVal;
            }
          } else {
            final start = isUpper ? j : 0;
            final end = isUpper ? n : j + 1;
            for (var k = start; k < end; k++) {
              final aVal = (j == k && isUnit) ? 1.0 : a[aOffset + j * lda + k];
              sum += b[bOffset + i * ldb + k] * aVal;
            }
          }
        }
        temp[i * n + j] = alpha * sum;
      }
    }

    for (var i = 0; i < m; i++) {
      final bRow = bOffset + i * ldb;
      final tempRow = i * n;
      for (var j = 0; j < n; j++) {
        b[bRow + j] = temp[tempRow + j];
      }
    }
    return true;
  }

  /// Performs triangular matrix-matrix multiplication for [Float32List].
  static bool strmm({
    required int side,
    required int uplo,
    required int transA,
    required int diag,
    required int m,
    required int n,
    required double alpha,
    required Float32List a,
    required int aOffset,
    required int lda,
    required Float32List b,
    required int bOffset,
    required int ldb,
  }) {
    if (m <= 0 || n <= 0) return true;
    final temp = Float32List(m * n);
    final isLeft = side == cblasLeft;
    final isUpper = uplo == cblasUpper;
    final isUnit = diag == cblasUnit;
    final isTransA = transA == cblasTrans || transA == cblasConjTrans;

    for (var i = 0; i < m; i++) {
      for (var j = 0; j < n; j++) {
        var sum = 0.0;
        if (isLeft) {
          if (!isTransA) {
            final start = isUpper ? i : 0;
            final end = isUpper ? m : i + 1;
            for (var k = start; k < end; k++) {
              final aVal = (i == k && isUnit) ? 1.0 : a[aOffset + i * lda + k];
              sum += aVal * b[bOffset + k * ldb + j];
            }
          } else {
            final start = isUpper ? 0 : i;
            final end = isUpper ? i + 1 : m;
            for (var k = start; k < end; k++) {
              final aVal = (i == k && isUnit) ? 1.0 : a[aOffset + k * lda + i];
              sum += aVal * b[bOffset + k * ldb + j];
            }
          }
        } else {
          if (!isTransA) {
            final start = isUpper ? 0 : j;
            final end = isUpper ? j + 1 : n;
            for (var k = start; k < end; k++) {
              final aVal = (k == j && isUnit) ? 1.0 : a[aOffset + k * lda + j];
              sum += b[bOffset + i * ldb + k] * aVal;
            }
          } else {
            final start = isUpper ? j : 0;
            final end = isUpper ? n : j + 1;
            for (var k = start; k < end; k++) {
              final aVal = (j == k && isUnit) ? 1.0 : a[aOffset + j * lda + k];
              sum += b[bOffset + i * ldb + k] * aVal;
            }
          }
        }
        temp[i * n + j] = alpha * sum;
      }
    }

    for (var i = 0; i < m; i++) {
      final bRow = bOffset + i * ldb;
      final tempRow = i * n;
      for (var j = 0; j < n; j++) {
        b[bRow + j] = temp[tempRow + j];
      }
    }
    return true;
  }
}
