import 'dart:math' as math;
import 'dart:typed_data';

import '../blas/cblas_constants.dart';

/// Pure Dart reference implementation of LAPACK decomposition and solver routines.
abstract final class LapackDart {
  /// Computes the Cholesky factorization of a symmetric positive-definite matrix A.
  static bool dpotrf({
    required int uplo,
    required int n,
    required Float64List a,
    required int aOffset,
    required int lda,
  }) {
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

  /// Solves $A X = B$ for general square matrix A using LU decomposition.
  static bool dgesv({
    required int n,
    required int nrhs,
    required Float64List a,
    required int aOffset,
    required int lda,
    required Float64List b,
    required int bOffset,
    required int ldb,
  }) {
    if (n < 0 || nrhs < 0 || lda < n || (nrhs > 0 && ldb < nrhs)) return false;
    if (n == 0 || nrhs == 0) return true;
    final aRequired = aOffset + (n - 1) * lda + n;
    final bRequired = bOffset + (n - 1) * ldb + nrhs;
    if (a.length < aRequired || b.length < bRequired) return false;

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

  /// Solves overdetermined or underdetermined linear least squares in pure Dart.
  static bool dgels({
    required int m,
    required int n,
    required int nrhs,
    required Float64List a,
    required int aOffset,
    required int lda,
    required Float64List b,
    required int bOffset,
    required int ldb,
  }) {
    if (m >= n) {
      final atA = Float64List(n * n);
      for (var j = 0; j < n; j++) {
        for (var k = 0; k < n; k++) {
          var sum = 0.0;
          for (var i = 0; i < m; i++) {
            sum += a[aOffset + i * lda + j] * a[aOffset + i * lda + k];
          }
          atA[j * n + k] = sum;
        }
      }
      final atB = Float64List(n * nrhs);
      for (var j = 0; j < n; j++) {
        for (var col = 0; col < nrhs; col++) {
          var sum = 0.0;
          for (var i = 0; i < m; i++) {
            sum += a[aOffset + i * lda + j] * b[bOffset + i * ldb + col];
          }
          atB[j * nrhs + col] = sum;
        }
      }
      final ok = dgesv(
        n: n,
        nrhs: nrhs,
        a: atA,
        aOffset: 0,
        lda: n,
        b: atB,
        bOffset: 0,
        ldb: nrhs,
      );
      if (!ok) return false;
      for (var i = 0; i < n; i++) {
        for (var col = 0; col < nrhs; col++) {
          b[bOffset + i * ldb + col] = atB[i * nrhs + col];
        }
      }
      return true;
    } else {
      final aAt = Float64List(m * m);
      for (var i = 0; i < m; i++) {
        for (var j = 0; j < m; j++) {
          var sum = 0.0;
          for (var k = 0; k < n; k++) {
            sum += a[aOffset + i * lda + k] * a[aOffset + j * lda + k];
          }
          aAt[i * m + j] = sum;
        }
      }
      final y = Float64List(m * nrhs);
      for (var i = 0; i < m; i++) {
        for (var col = 0; col < nrhs; col++) {
          y[i * nrhs + col] = b[bOffset + i * ldb + col];
        }
      }
      final ok = dgesv(
        n: m,
        nrhs: nrhs,
        a: aAt,
        aOffset: 0,
        lda: m,
        b: y,
        bOffset: 0,
        ldb: nrhs,
      );
      if (!ok) return false;
      for (var k = 0; k < n; k++) {
        for (var col = 0; col < nrhs; col++) {
          var sum = 0.0;
          for (var i = 0; i < m; i++) {
            sum += a[aOffset + i * lda + k] * y[i * nrhs + col];
          }
          b[bOffset + k * ldb + col] = sum;
        }
      }
      return true;
    }
  }

  /// Computes eigenvalues and optionally eigenvectors of a symmetric matrix.
  static bool dsyev({
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

    final d = Float64List(n);
    final e = Float64List(n);
    final v = Float64List(n * n);

    for (var i = 0; i < n; i++) {
      for (var j = 0; j < n; j++) {
        final r = (uplo == cblasUpper && i > j) ? j : i;
        final c = (uplo == cblasUpper && i > j) ? i : j;
        v[i * n + j] = a[aOffset + r * lda + c];
      }
    }

    // Tridiagonalization (Householder reduction)
    for (var i = n - 1; i > 0; i--) {
      final l = i - 1;
      var h = 0.0;
      var scale = 0.0;
      if (l > 0) {
        for (var k = 0; k <= l; k++) {
          scale += v[i * n + k].abs();
        }
        if (scale == 0.0) {
          e[i] = v[i * n + l];
        } else {
          for (var k = 0; k <= l; k++) {
            v[i * n + k] /= scale;
            h += v[i * n + k] * v[i * n + k];
          }
          var f = v[i * n + l];
          var g = math.sqrt(h);
          if (f > 0) g = -g;
          e[i] = scale * g;
          h -= f * g;
          v[i * n + l] = f - g;
          f = 0.0;
          for (var j = 0; j <= l; j++) {
            v[j * n + i] = v[i * n + j] / h;
            g = 0.0;
            for (var k = 0; k <= j; k++) {
              g += v[j * n + k] * v[i * n + k];
            }
            for (var k = j + 1; k <= l; k++) {
              g += v[k * n + j] * v[i * n + k];
            }
            e[j] = g / h;
            f += e[j] * v[i * n + j];
          }
          final hh = f / (h + h);
          for (var j = 0; j <= l; j++) {
            f = v[i * n + j];
            e[j] = g = e[j] - hh * f;
            for (var k = 0; k <= j; k++) {
              v[j * n + k] -= f * e[k] + g * v[i * n + k];
            }
          }
        }
      } else {
        e[i] = v[i * n + l];
      }
      d[i] = h;
    }

    d[0] = 0.0;
    e[0] = 0.0;
    for (var i = 0; i < n; i++) {
      final l = i - 1;
      if (d[i] != 0.0) {
        for (var j = 0; j <= l; j++) {
          var g = 0.0;
          for (var k = 0; k <= l; k++) {
            g += v[i * n + k] * v[k * n + j];
          }
          for (var k = 0; k <= l; k++) {
            v[k * n + j] -= g * v[k * n + i];
          }
        }
      }
      d[i] = v[i * n + i];
      v[i * n + i] = 1.0;
      for (var j = 0; j <= l; j++) {
        v[j * n + i] = 0.0;
        v[i * n + j] = 0.0;
      }
    }

    // QL algorithm with implicit shifts
    for (var i = 1; i < n; i++) {
      e[i - 1] = e[i];
    }
    e[n - 1] = 0.0;

    var fVal = 0.0;
    var tst1 = 0.0;
    final eps = math.pow(2.0, -52).toDouble();

    for (var lIdx = 0; lIdx < n; lIdx++) {
      tst1 = math.max(tst1, d[lIdx].abs() + e[lIdx].abs());
      var mIdx = lIdx;
      while (mIdx < n) {
        if (e[mIdx].abs() <= eps * tst1) break;
        mIdx++;
      }

      if (mIdx > lIdx) {
        do {
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

  /// Single-precision symmetric eigenvalue solver in pure Dart.
  static bool ssyev({
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
    final ok = dsyev(
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
}
