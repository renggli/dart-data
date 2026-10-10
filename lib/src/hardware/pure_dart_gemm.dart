import 'dart:typed_data';

import 'cblas.dart';

/// Block tile size for cache-blocked GEMM.
/// $32 \times 32 \times 8\text{ bytes} = 8\text{ KB}$, fitting comfortably inside L1 data cache.
const int gemmBlockSize = 32;

/// Cache-blocked matrix multiplication for [Float64List]:
///
/// $$C = \alpha \operatorname{op}(A) \operatorname{op}(B) + \beta C$$
///
/// Implements cache tiling with $32 \times 32$ blocks and $4\times$ loop unrolling
/// for optimal memory hierarchy locality and CPU register utilization.
bool cacheBlockedGemmFloat64({
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
  if (m == 0 || n == 0) return true;

  // Handle beta scaling of C
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

  if (k == 0 || alpha == 0.0) return true;

  if (transA == cblasNoTrans && transB == cblasNoTrans) {
    _gemmNNFloat64(
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
      c: c,
      cOffset: cOffset,
      ldc: ldc,
    );
  } else if (transA == cblasTrans && transB == cblasNoTrans) {
    _gemmTNFloat64(
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
      c: c,
      cOffset: cOffset,
      ldc: ldc,
    );
  } else if (transA == cblasNoTrans && transB == cblasTrans) {
    _gemmNTFloat64(
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
      c: c,
      cOffset: cOffset,
      ldc: ldc,
    );
  } else {
    _gemmTTFloat64(
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
      c: c,
      cOffset: cOffset,
      ldc: ldc,
    );
  }

  return true;
}

/// Cache-blocked matrix multiplication for [Float32List]:
///
/// $$C = \alpha \operatorname{op}(A) \operatorname{op}(B) + \beta C$$
bool cacheBlockedGemmFloat32({
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
  if (m == 0 || n == 0) return true;

  // Handle beta scaling of C
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

  if (k == 0 || alpha == 0.0) return true;

  if (transA == cblasNoTrans && transB == cblasNoTrans) {
    _gemmNNFloat32(
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
      c: c,
      cOffset: cOffset,
      ldc: ldc,
    );
  } else if (transA == cblasTrans && transB == cblasNoTrans) {
    _gemmTNFloat32(
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
      c: c,
      cOffset: cOffset,
      ldc: ldc,
    );
  } else if (transA == cblasNoTrans && transB == cblasTrans) {
    _gemmNTFloat32(
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
      c: c,
      cOffset: cOffset,
      ldc: ldc,
    );
  } else {
    _gemmTTFloat32(
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
      c: c,
      cOffset: cOffset,
      ldc: ldc,
    );
  }

  return true;
}

// ---------------------------------------------------------------------------
// Float64 Implementation Details
// ---------------------------------------------------------------------------

void _gemmNNFloat64({
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
  required Float64List c,
  required int cOffset,
  required int ldc,
}) {
  for (var ii = 0; ii < m; ii += gemmBlockSize) {
    final iLimit = (ii + gemmBlockSize < m) ? ii + gemmBlockSize : m;
    for (var kk = 0; kk < k; kk += gemmBlockSize) {
      final kLimit = (kk + gemmBlockSize < k) ? kk + gemmBlockSize : k;
      for (var jj = 0; jj < n; jj += gemmBlockSize) {
        final jLimit = (jj + gemmBlockSize < n) ? jj + gemmBlockSize : n;

        for (var i = ii; i < iLimit; i++) {
          final aRow = aOffset + i * lda;
          final cRow = cOffset + i * ldc;
          for (var p = kk; p < kLimit; p++) {
            final aVal = alpha * a[aRow + p];
            if (aVal == 0.0) continue;
            final bRow = bOffset + p * ldb;
            var j = jj;
            for (; j + 3 < jLimit; j += 4) {
              final cIdx = cRow + j;
              final bIdx = bRow + j;
              c[cIdx] += aVal * b[bIdx];
              c[cIdx + 1] += aVal * b[bIdx + 1];
              c[cIdx + 2] += aVal * b[bIdx + 2];
              c[cIdx + 3] += aVal * b[bIdx + 3];
            }
            for (; j < jLimit; j++) {
              c[cRow + j] += aVal * b[bRow + j];
            }
          }
        }
      }
    }
  }
}

void _gemmTNFloat64({
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
  required Float64List c,
  required int cOffset,
  required int ldc,
}) {
  for (var ii = 0; ii < m; ii += gemmBlockSize) {
    final iLimit = (ii + gemmBlockSize < m) ? ii + gemmBlockSize : m;
    for (var kk = 0; kk < k; kk += gemmBlockSize) {
      final kLimit = (kk + gemmBlockSize < k) ? kk + gemmBlockSize : k;
      for (var jj = 0; jj < n; jj += gemmBlockSize) {
        final jLimit = (jj + gemmBlockSize < n) ? jj + gemmBlockSize : n;

        for (var i = ii; i < iLimit; i++) {
          final cRow = cOffset + i * ldc;
          for (var p = kk; p < kLimit; p++) {
            final aVal = alpha * a[aOffset + p * lda + i];
            if (aVal == 0.0) continue;
            final bRow = bOffset + p * ldb;
            var j = jj;
            for (; j + 3 < jLimit; j += 4) {
              final cIdx = cRow + j;
              final bIdx = bRow + j;
              c[cIdx] += aVal * b[bIdx];
              c[cIdx + 1] += aVal * b[bIdx + 1];
              c[cIdx + 2] += aVal * b[bIdx + 2];
              c[cIdx + 3] += aVal * b[bIdx + 3];
            }
            for (; j < jLimit; j++) {
              c[cRow + j] += aVal * b[bRow + j];
            }
          }
        }
      }
    }
  }
}

void _gemmNTFloat64({
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
  required Float64List c,
  required int cOffset,
  required int ldc,
}) {
  for (var ii = 0; ii < m; ii += gemmBlockSize) {
    final iLimit = (ii + gemmBlockSize < m) ? ii + gemmBlockSize : m;
    for (var jj = 0; jj < n; jj += gemmBlockSize) {
      final jLimit = (jj + gemmBlockSize < n) ? jj + gemmBlockSize : n;
      for (var kk = 0; kk < k; kk += gemmBlockSize) {
        final kLimit = (kk + gemmBlockSize < k) ? kk + gemmBlockSize : k;

        for (var i = ii; i < iLimit; i++) {
          final aRow = aOffset + i * lda;
          final cRow = cOffset + i * ldc;
          for (var j = jj; j < jLimit; j++) {
            final bRow = bOffset + j * ldb;
            var sum = 0.0;
            var p = kk;
            for (; p + 3 < kLimit; p += 4) {
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
}

void _gemmTTFloat64({
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
  required Float64List c,
  required int cOffset,
  required int ldc,
}) {
  for (var ii = 0; ii < m; ii += gemmBlockSize) {
    final iLimit = (ii + gemmBlockSize < m) ? ii + gemmBlockSize : m;
    for (var jj = 0; jj < n; jj += gemmBlockSize) {
      final jLimit = (jj + gemmBlockSize < n) ? jj + gemmBlockSize : n;
      for (var kk = 0; kk < k; kk += gemmBlockSize) {
        final kLimit = (kk + gemmBlockSize < k) ? kk + gemmBlockSize : k;

        for (var i = ii; i < iLimit; i++) {
          final cRow = cOffset + i * ldc;
          for (var j = jj; j < jLimit; j++) {
            final bRow = bOffset + j * ldb;
            var sum = 0.0;
            var p = kk;
            for (; p + 3 < kLimit; p += 4) {
              sum +=
                  a[aOffset + p * lda + i] * b[bRow + p] +
                  a[aOffset + (p + 1) * lda + i] * b[bRow + p + 1] +
                  a[aOffset + (p + 2) * lda + i] * b[bRow + p + 2] +
                  a[aOffset + (p + 3) * lda + i] * b[bRow + p + 3];
            }
            for (; p < kLimit; p++) {
              sum += a[aOffset + p * lda + i] * b[bRow + p];
            }
            c[cRow + j] += alpha * sum;
          }
        }
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Float32 Implementation Details
// ---------------------------------------------------------------------------

void _gemmNNFloat32({
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
  required Float32List c,
  required int cOffset,
  required int ldc,
}) {
  for (var ii = 0; ii < m; ii += gemmBlockSize) {
    final iLimit = (ii + gemmBlockSize < m) ? ii + gemmBlockSize : m;
    for (var kk = 0; kk < k; kk += gemmBlockSize) {
      final kLimit = (kk + gemmBlockSize < k) ? kk + gemmBlockSize : k;
      for (var jj = 0; jj < n; jj += gemmBlockSize) {
        final jLimit = (jj + gemmBlockSize < n) ? jj + gemmBlockSize : n;

        for (var i = ii; i < iLimit; i++) {
          final aRow = aOffset + i * lda;
          final cRow = cOffset + i * ldc;
          for (var p = kk; p < kLimit; p++) {
            final aVal = alpha * a[aRow + p];
            if (aVal == 0.0) continue;
            final bRow = bOffset + p * ldb;
            var j = jj;
            for (; j + 3 < jLimit; j += 4) {
              final cIdx = cRow + j;
              final bIdx = bRow + j;
              c[cIdx] += aVal * b[bIdx];
              c[cIdx + 1] += aVal * b[bIdx + 1];
              c[cIdx + 2] += aVal * b[bIdx + 2];
              c[cIdx + 3] += aVal * b[bIdx + 3];
            }
            for (; j < jLimit; j++) {
              c[cRow + j] += aVal * b[bRow + j];
            }
          }
        }
      }
    }
  }
}

void _gemmTNFloat32({
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
  required Float32List c,
  required int cOffset,
  required int ldc,
}) {
  for (var ii = 0; ii < m; ii += gemmBlockSize) {
    final iLimit = (ii + gemmBlockSize < m) ? ii + gemmBlockSize : m;
    for (var kk = 0; kk < k; kk += gemmBlockSize) {
      final kLimit = (kk + gemmBlockSize < k) ? kk + gemmBlockSize : k;
      for (var jj = 0; jj < n; jj += gemmBlockSize) {
        final jLimit = (jj + gemmBlockSize < n) ? jj + gemmBlockSize : n;

        for (var i = ii; i < iLimit; i++) {
          final cRow = cOffset + i * ldc;
          for (var p = kk; p < kLimit; p++) {
            final aVal = alpha * a[aOffset + p * lda + i];
            if (aVal == 0.0) continue;
            final bRow = bOffset + p * ldb;
            var j = jj;
            for (; j + 3 < jLimit; j += 4) {
              final cIdx = cRow + j;
              final bIdx = bRow + j;
              c[cIdx] += aVal * b[bIdx];
              c[cIdx + 1] += aVal * b[bIdx + 1];
              c[cIdx + 2] += aVal * b[bIdx + 2];
              c[cIdx + 3] += aVal * b[bIdx + 3];
            }
            for (; j < jLimit; j++) {
              c[cRow + j] += aVal * b[bRow + j];
            }
          }
        }
      }
    }
  }
}

void _gemmNTFloat32({
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
  required Float32List c,
  required int cOffset,
  required int ldc,
}) {
  for (var ii = 0; ii < m; ii += gemmBlockSize) {
    final iLimit = (ii + gemmBlockSize < m) ? ii + gemmBlockSize : m;
    for (var jj = 0; jj < n; jj += gemmBlockSize) {
      final jLimit = (jj + gemmBlockSize < n) ? jj + gemmBlockSize : n;
      for (var kk = 0; kk < k; kk += gemmBlockSize) {
        final kLimit = (kk + gemmBlockSize < k) ? kk + gemmBlockSize : k;

        for (var i = ii; i < iLimit; i++) {
          final aRow = aOffset + i * lda;
          final cRow = cOffset + i * ldc;
          for (var j = jj; j < jLimit; j++) {
            final bRow = bOffset + j * ldb;
            var sum = 0.0;
            var p = kk;
            for (; p + 3 < kLimit; p += 4) {
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
}

void _gemmTTFloat32({
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
  required Float32List c,
  required int cOffset,
  required int ldc,
}) {
  for (var ii = 0; ii < m; ii += gemmBlockSize) {
    final iLimit = (ii + gemmBlockSize < m) ? ii + gemmBlockSize : m;
    for (var jj = 0; jj < n; jj += gemmBlockSize) {
      final jLimit = (jj + gemmBlockSize < n) ? jj + gemmBlockSize : n;
      for (var kk = 0; kk < k; kk += gemmBlockSize) {
        final kLimit = (kk + gemmBlockSize < k) ? kk + gemmBlockSize : k;

        for (var i = ii; i < iLimit; i++) {
          final cRow = cOffset + i * ldc;
          for (var j = jj; j < jLimit; j++) {
            final bRow = bOffset + j * ldb;
            var sum = 0.0;
            var p = kk;
            for (; p + 3 < kLimit; p += 4) {
              sum +=
                  a[aOffset + p * lda + i] * b[bRow + p] +
                  a[aOffset + (p + 1) * lda + i] * b[bRow + p + 1] +
                  a[aOffset + (p + 2) * lda + i] * b[bRow + p + 2] +
                  a[aOffset + (p + 3) * lda + i] * b[bRow + p + 3];
            }
            for (; p < kLimit; p++) {
              sum += a[aOffset + p * lda + i] * b[bRow + p];
            }
            c[cRow + j] += alpha * sum;
          }
        }
      }
    }
  }
}
