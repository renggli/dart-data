import 'dart:math' as math;
import 'dart:typed_data';

import '../blas/cblas.dart';

/// Pure Dart LAPACK fallback algorithms (eigenvalue solvers and linear system
/// solvers).
abstract final class PureDartLapack {
  /// Computes eigenvalues and optionally eigenvectors of a symmetric matrix in
  /// pure Dart.
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

  /// Solves AX = B using LU decomposition with partial pivoting in pure Dart.
  static bool luSolve(
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

  /// Solves overdetermined or underdetermined linear least squares in pure
  /// Dart.
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
      final ok = luSolve(n, nrhs, atA, 0, n, atB, 0, nrhs);
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
      final ok = luSolve(m, nrhs, aAt, 0, m, y, 0, nrhs);
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
