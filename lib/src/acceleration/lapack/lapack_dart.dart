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
    if (n == 0) return true;
    final lower = Float64List(n * n);
    for (var i = 0; i < n; i++) {
      for (var j = 0; j <= i; j++) {
        var sum = 0.0;
        for (var k = 0; k < j; k++) {
          sum += lower[i * n + k] * lower[j * n + k];
        }
        if (i == j) {
          final val = a[aOffset + i * lda + i] - sum;
          if (!(val > 0.0)) return false;
          lower[i * n + j] = math.sqrt(val);
        } else {
          final denom = lower[j * n + j];
          if (!(denom > 0.0)) return false;
          final aij = uplo == cblasUpper
              ? a[aOffset + j * lda + i]
              : a[aOffset + i * lda + j];
          lower[i * n + j] = (aij - sum) / denom;
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

    final aCopy = Float64List(n * n);
    for (var i = 0; i < n; i++) {
      for (var j = 0; j < n; j++) {
        aCopy[i * n + j] = a[aOffset + i * lda + j];
      }
    }
    final bCopy = Float64List(n * nrhs);
    for (var i = 0; i < n; i++) {
      for (var j = 0; j < nrhs; j++) {
        bCopy[i * nrhs + j] = b[bOffset + i * ldb + j];
      }
    }

    for (var i = 0; i < n; i++) {
      var maxVal = aCopy[i * n + i].abs();
      var maxRow = i;
      for (var row = i + 1; row < n; row++) {
        final val = aCopy[row * n + i].abs();
        if (val > maxVal) {
          maxVal = val;
          maxRow = row;
        }
      }
      if (!(maxVal > 0.0)) return false;

      if (maxRow != i) {
        for (var k = 0; k < n; k++) {
          final temp = aCopy[i * n + k];
          aCopy[i * n + k] = aCopy[maxRow * n + k];
          aCopy[maxRow * n + k] = temp;
        }
        for (var k = 0; k < nrhs; k++) {
          final temp = bCopy[i * nrhs + k];
          bCopy[i * nrhs + k] = bCopy[maxRow * nrhs + k];
          bCopy[maxRow * nrhs + k] = temp;
        }
      }

      final diag = aCopy[i * n + i];
      for (var row = i + 1; row < n; row++) {
        final factor = aCopy[row * n + i] / diag;
        aCopy[row * n + i] = factor;
        for (var col = i + 1; col < n; col++) {
          aCopy[row * n + col] -= factor * aCopy[i * n + col];
        }
        for (var col = 0; col < nrhs; col++) {
          bCopy[row * nrhs + col] -= factor * bCopy[i * nrhs + col];
        }
      }
    }

    for (var col = 0; col < nrhs; col++) {
      for (var i = n - 1; i >= 0; i--) {
        var sum = bCopy[i * nrhs + col];
        for (var k = i + 1; k < n; k++) {
          sum -= aCopy[i * n + k] * bCopy[k * nrhs + col];
        }
        bCopy[i * nrhs + col] = sum / aCopy[i * n + i];
      }
    }
    for (var i = 0; i < n; i++) {
      for (var j = 0; j < nrhs; j++) {
        b[bOffset + i * ldb + j] = bCopy[i * nrhs + j];
      }
    }
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
    if (m == 0 || n == 0 || nrhs == 0) return true;

    if (m >= n) {
      // Overdetermined system: QR factorization via Householder reflections.
      final qr = Float64List(m * n);
      for (var i = 0; i < m; i++) {
        for (var j = 0; j < n; j++) {
          qr[i * n + j] = a[aOffset + i * lda + j];
        }
      }

      final bx = Float64List(m * nrhs);
      for (var i = 0; i < m; i++) {
        for (var col = 0; col < nrhs; col++) {
          bx[i * nrhs + col] = b[bOffset + i * ldb + col];
        }
      }

      final v = Float64List(m);
      for (var k = 0; k < n; k++) {
        var scale = 0.0;
        for (var i = k; i < m; i++) {
          final absVal = qr[i * n + k].abs();
          if (absVal > scale) scale = absVal;
        }

        if (!(scale > 0.0)) {
          return false;
        }

        var sumsq = 0.0;
        for (var i = k; i < m; i++) {
          final val = qr[i * n + k] / scale;
          sumsq += val * val;
        }
        var nrm = scale * math.sqrt(sumsq);
        final alpha = qr[k * n + k];
        if (alpha > 0) {
          nrm = -nrm;
        }
        final beta = alpha - nrm;
        v[k] = 1.0;
        for (var i = k + 1; i < m; i++) {
          v[i] = qr[i * n + k] / beta;
        }
        final tau = -beta / nrm;

        // Apply H_k = I - tau * v * v^T to qr[:, k+1:n]
        for (var j = k + 1; j < n; j++) {
          var w = qr[k * n + j];
          for (var i = k + 1; i < m; i++) {
            w += v[i] * qr[i * n + j];
          }
          final tauW = tau * w;
          qr[k * n + j] -= tauW;
          for (var i = k + 1; i < m; i++) {
            qr[i * n + j] -= tauW * v[i];
          }
        }
        qr[k * n + k] = nrm;

        // Apply H_k to bx
        for (var col = 0; col < nrhs; col++) {
          var w = bx[k * nrhs + col];
          for (var i = k + 1; i < m; i++) {
            w += v[i] * bx[i * nrhs + col];
          }
          final tauW = tau * w;
          bx[k * nrhs + col] -= tauW;
          for (var i = k + 1; i < m; i++) {
            bx[i * nrhs + col] -= tauW * v[i];
          }
        }
      }

      var maxDiag = 0.0;
      for (var k = 0; k < n; k++) {
        final d = qr[k * n + k].abs();
        if (d > maxDiag) maxDiag = d;
      }
      final tol = math.max(1e-12, m * 2.220446049250313e-16 * maxDiag);
      for (var k = 0; k < n; k++) {
        if (!(qr[k * n + k].abs() >= tol)) return false;
      }

      // Back-substitution: R[0:n, 0:n] * X = bx[0:n, :]
      for (var col = 0; col < nrhs; col++) {
        for (var i = n - 1; i >= 0; i--) {
          var sum = bx[i * nrhs + col];
          for (var j = i + 1; j < n; j++) {
            sum -= qr[i * n + j] * bx[j * nrhs + col];
          }
          bx[i * nrhs + col] = sum / qr[i * n + i];
        }
      }

      for (var i = 0; i < m; i++) {
        for (var col = 0; col < nrhs; col++) {
          b[bOffset + i * ldb + col] = bx[i * nrhs + col];
        }
      }
      return true;
    } else {
      // Underdetermined system: LQ factorization via Householder reflections.
      final lq = Float64List(m * n);
      for (var i = 0; i < m; i++) {
        for (var j = 0; j < n; j++) {
          lq[i * n + j] = a[aOffset + i * lda + j];
        }
      }

      final taus = Float64List(m);
      for (var k = 0; k < m; k++) {
        var scale = 0.0;
        for (var j = k; j < n; j++) {
          final absVal = lq[k * n + j].abs();
          if (absVal > scale) scale = absVal;
        }

        if (!(scale > 0.0)) {
          return false;
        }

        var sumsq = 0.0;
        for (var j = k; j < n; j++) {
          final val = lq[k * n + j] / scale;
          sumsq += val * val;
        }
        var nrm = scale * math.sqrt(sumsq);
        final alpha = lq[k * n + k];
        if (alpha > 0) {
          nrm = -nrm;
        }
        final beta = alpha - nrm;
        taus[k] = -beta / nrm;
        for (var j = k + 1; j < n; j++) {
          lq[k * n + j] /= beta;
        }

        // Apply H_k = I - tau * v * v^T on the right to lq[k+1:m, :]
        for (var i = k + 1; i < m; i++) {
          var w = lq[i * n + k];
          for (var j = k + 1; j < n; j++) {
            w += lq[i * n + j] * lq[k * n + j];
          }
          final tauW = taus[k] * w;
          lq[i * n + k] -= tauW;
          for (var j = k + 1; j < n; j++) {
            lq[i * n + j] -= tauW * lq[k * n + j];
          }
        }
        lq[k * n + k] = nrm;
      }

      var maxDiag = 0.0;
      for (var k = 0; k < m; k++) {
        final d = lq[k * n + k].abs();
        if (d > maxDiag) maxDiag = d;
      }
      final tol = math.max(1e-12, n * 2.220446049250313e-16 * maxDiag);
      for (var k = 0; k < m; k++) {
        if (!(lq[k * n + k].abs() >= tol)) return false;
      }

      // Forward-substitution: L[0:m, 0:m] * Y = B[0:m, :]
      final x = Float64List(n * nrhs);
      for (var col = 0; col < nrhs; col++) {
        for (var i = 0; i < m; i++) {
          var sum = b[bOffset + i * ldb + col];
          for (var j = 0; j < i; j++) {
            sum -= lq[i * n + j] * x[j * nrhs + col];
          }
          x[i * nrhs + col] = sum / lq[i * n + i];
        }
      }

      // Compute X = Q^T * [Y; 0] = H_0 * H_1 * ... * H_{m-1} * [Y; 0]
      for (var k = m - 1; k >= 0; k--) {
        final tau = taus[k];
        if (tau == 0.0) continue;
        for (var col = 0; col < nrhs; col++) {
          var w = x[k * nrhs + col];
          for (var j = k + 1; j < n; j++) {
            w += lq[k * n + j] * x[j * nrhs + col];
          }
          final tauW = tau * w;
          x[k * nrhs + col] -= tauW;
          for (var j = k + 1; j < n; j++) {
            x[j * nrhs + col] -= tauW * lq[k * n + j];
          }
        }
      }

      for (var i = 0; i < n; i++) {
        for (var col = 0; col < nrhs; col++) {
          b[bOffset + i * ldb + col] = x[i * nrhs + col];
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
    if (n == 0) return true;
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
        final int r, c;
        if (uplo == cblasUpper) {
          r = i <= j ? i : j;
          c = i <= j ? j : i;
        } else {
          r = i >= j ? i : j;
          c = i >= j ? j : i;
        }
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
        var iter = 0;
        do {
          if (++iter > 30) return false;
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
    if (n == 0) return true;
    final a64 = Float64List(n * n);
    for (var i = 0; i < n; i++) {
      for (var j = 0; j < n; j++) {
        final int r, c;
        if (uplo == cblasUpper) {
          r = i <= j ? i : j;
          c = i <= j ? j : i;
        } else {
          r = i >= j ? i : j;
          c = i >= j ? j : i;
        }
        a64[i * n + j] = a[aOffset + r * lda + c];
      }
    }
    final w64 = Float64List(n);
    final ok = dsyev(
      jobz: jobz,
      uplo: uplo,
      n: n,
      a: a64,
      aOffset: 0,
      lda: n,
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
          a[aOffset + i * lda + j] = a64[i * n + j];
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
