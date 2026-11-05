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
        final val = a[aOffset + i * lda + j];
        if (!val.isFinite) return false;
        aCopy[i * n + j] = val;
      }
    }
    final bCopy = Float64List(n * nrhs);
    for (var i = 0; i < n; i++) {
      for (var j = 0; j < nrhs; j++) {
        final val = b[bOffset + i * ldb + j];
        if (!val.isFinite) return false;
        bCopy[i * nrhs + j] = val;
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

    for (var i = 0; i < m; i++) {
      for (var j = 0; j < n; j++) {
        if (!a[aOffset + i * lda + j].isFinite) return false;
      }
    }
    for (var i = 0; i < m; i++) {
      for (var col = 0; col < nrhs; col++) {
        if (!b[bOffset + i * ldb + col].isFinite) return false;
      }
    }

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
    for (var i = 0; i < n; i++) {
      if (uplo == cblasUpper) {
        for (var j = i; j < n; j++) {
          if (!a[aOffset + i * lda + j].isFinite) return false;
        }
      } else {
        for (var j = 0; j <= i; j++) {
          if (!a[aOffset + i * lda + j].isFinite) return false;
        }
      }
    }
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
      if (!tst1.isFinite) return false;
      var mIdx = lIdx;
      while (mIdx < n - 1) {
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

  /// Computes the Singular Value Decomposition (SVD) of an $m \times n$ matrix
  /// for [Float64List].
  static bool dgesvd({
    required String jobu,
    required String jobvt,
    required int m,
    required int n,
    required Float64List a,
    required int aOffset,
    required int lda,
    required Float64List s,
    required int sOffset,
    Float64List? u,
    int uOffset = 0,
    int? ldu,
    Float64List? vt,
    int vtOffset = 0,
    int? ldvt,
  }) {
    if (m < 0 || n < 0 || lda < n) return false;
    final normJobu = jobu.toUpperCase();
    final normJobvt = jobvt.toUpperCase();
    if (normJobu != 'A' && normJobu != 'N') return false;
    if (normJobvt != 'A' && normJobvt != 'N') return false;
    final effLdu = ldu ?? m;
    final effLdvt = ldvt ?? n;
    if (normJobu == 'A' && (u == null || effLdu < m)) return false;
    if (normJobvt == 'A' && (vt == null || effLdvt < n)) return false;
    if (m == 0 || n == 0) return true;

    final minMN = math.min(m, n);
    final aRequired = aOffset + (m - 1) * lda + n;
    final sRequired = sOffset + minMN;
    if (a.length < aRequired || s.length < sRequired) return false;
    if (normJobu == 'A' && u!.length < uOffset + (m - 1) * effLdu + m) {
      return false;
    }
    if (normJobvt == 'A' && vt!.length < vtOffset + (n - 1) * effLdvt + n) {
      return false;
    }

    for (var i = 0; i < m; i++) {
      for (var j = 0; j < n; j++) {
        final val = a[aOffset + i * lda + j];
        if (!val.isFinite) return false;
      }
    }

    final computeU = normJobu == 'A';
    final computeVt = normJobvt == 'A';

    final aCol = Float64List(m * n);
    for (var i = 0; i < m; i++) {
      for (var j = 0; j < n; j++) {
        aCol[j * m + i] = a[aOffset + i * lda + j];
      }
    }

    final uCol = computeU ? Float64List(m * m) : Float64List(0);
    final vList = computeVt ? Float64List(n * n) : Float64List(0);
    final sVals = Float64List(minMN);

    final converged = _computeSvd(
      computeU: computeU,
      computeVt: computeVt,
      a: aCol,
      rowsA: m,
      colsA: n,
      sVals: sVals,
      uVals: uCol,
      vList: vList,
    );
    if (!converged) return false;

    for (var i = 0; i < minMN; i++) {
      s[sOffset + i] = sVals[i];
    }
    if (computeU) {
      for (var i = 0; i < m; i++) {
        for (var j = 0; j < m; j++) {
          u![uOffset + i * effLdu + j] = uCol[j * m + i];
        }
      }
    }
    if (computeVt) {
      for (var i = 0; i < n; i++) {
        for (var j = 0; j < n; j++) {
          vt![vtOffset + i * effLdvt + j] = vList[i * n + j];
        }
      }
    }
    return true;
  }

  static ({double da, double db, double cosVal, double sinVal}) _rotg(
    double da,
    double db,
  ) {
    final absda = da.abs();
    final absdb = db.abs();
    final roe = (absda > absdb) ? da : db;
    final scale = absda + absdb;

    double rVal, zVal, cosVal, sinVal;
    if (scale == 0.0) {
      cosVal = 1.0;
      sinVal = 0.0;
      rVal = 0.0;
      zVal = 0.0;
    } else {
      final sda = da / scale;
      final sdb = db / scale;
      rVal = scale * math.sqrt(sda * sda + sdb * sdb);
      if (roe < 0.0) rVal = -rVal;
      cosVal = da / rVal;
      sinVal = db / rVal;
      zVal = 1.0;
      if (absda > absdb) zVal = sinVal;
      if (absdb >= absda && cosVal != 0.0) zVal = 1.0 / cosVal;
    }
    return (da: rVal, db: zVal, cosVal: cosVal, sinVal: sinVal);
  }

  static bool _computeSvd({
    required bool computeU,
    required bool computeVt,
    required Float64List a,
    required int rowsA,
    required int colsA,
    required Float64List sVals,
    required Float64List uVals,
    required Float64List vList,
  }) {
    final work = Float64List(rowsA);
    final eList = Float64List(colsA);
    final stemp = Float64List(math.min(rowsA + 1, colsA));

    final ncu = rowsA;
    final nct = math.min(rowsA - 1, colsA);
    final nrt = math.max(0, math.min(colsA - 2, rowsA));
    final lu = math.max(nct, nrt);

    for (var lIdx = 0; lIdx < lu; lIdx++) {
      final lp1 = lIdx + 1;
      if (lIdx < nct) {
        var sum = 0.0;
        for (var i = lIdx; i < rowsA; i++) {
          final val = a[lIdx * rowsA + i];
          sum += val * val;
        }
        stemp[lIdx] = math.sqrt(sum);
        if (stemp[lIdx] != 0.0) {
          if (a[lIdx * rowsA + lIdx] != 0.0) {
            stemp[lIdx] =
                stemp[lIdx].abs() *
                (a[lIdx * rowsA + lIdx] / a[lIdx * rowsA + lIdx].abs());
          }
          for (var i = lIdx; i < rowsA; i++) {
            a[lIdx * rowsA + i] /= stemp[lIdx];
          }
          a[lIdx * rowsA + lIdx] += 1.0;
        }
        stemp[lIdx] = -stemp[lIdx];
      }

      for (var j = lp1; j < colsA; j++) {
        if (lIdx < nct && stemp[lIdx] != 0.0) {
          var tVal = 0.0;
          for (var i = lIdx; i < rowsA; i++) {
            tVal += a[j * rowsA + i] * a[lIdx * rowsA + i];
          }
          tVal = -tVal / a[lIdx * rowsA + lIdx];
          for (var ii = lIdx; ii < rowsA; ii++) {
            a[j * rowsA + ii] += tVal * a[lIdx * rowsA + ii];
          }
        }
        eList[j] = a[j * rowsA + lIdx];
      }

      if (computeU && lIdx < nct) {
        for (var i = lIdx; i < rowsA; i++) {
          uVals[lIdx * rowsA + i] = a[lIdx * rowsA + i];
        }
      }

      if (lIdx < nrt) {
        var enorm = 0.0;
        for (var i = lp1; i < eList.length; i++) {
          enorm += eList[i] * eList[i];
        }
        eList[lIdx] = math.sqrt(enorm);
        if (eList[lIdx] != 0.0) {
          if (eList[lp1] != 0.0) {
            eList[lIdx] = eList[lIdx].abs() * (eList[lp1] / eList[lp1].abs());
          }
          for (var i = lp1; i < eList.length; i++) {
            eList[i] /= eList[lIdx];
          }
          eList[lp1] += 1.0;
        }
        eList[lIdx] = -eList[lIdx];

        if (lp1 < rowsA && eList[lIdx] != 0.0) {
          for (var i = lp1; i < rowsA; i++) {
            work[i] = 0.0;
          }
          for (var j = lp1; j < colsA; j++) {
            for (var ii = lp1; ii < rowsA; ii++) {
              work[ii] += eList[j] * a[j * rowsA + ii];
            }
          }
          for (var j = lp1; j < colsA; j++) {
            final ww = -eList[j] / eList[lp1];
            for (var ii = lp1; ii < rowsA; ii++) {
              a[j * rowsA + ii] += ww * work[ii];
            }
          }
        }

        if (computeVt) {
          for (var i = lp1; i < colsA; i++) {
            vList[lIdx * colsA + i] = eList[i];
          }
        }
      }
    }

    var mDim = math.min(colsA, rowsA + 1);
    final nctp1 = nct + 1;
    final nrtp1 = nrt + 1;
    if (nct < colsA) {
      stemp[nctp1 - 1] = a[(nctp1 - 1) * rowsA + (nctp1 - 1)];
    }
    if (rowsA < mDim) {
      stemp[mDim - 1] = 0.0;
    }
    if (nrtp1 < mDim) {
      eList[nrtp1 - 1] = a[(mDim - 1) * rowsA + (nrtp1 - 1)];
    }
    eList[mDim - 1] = 0.0;

    if (computeU) {
      for (var j = nctp1 - 1; j < ncu; j++) {
        for (var i = 0; i < rowsA; i++) {
          uVals[j * rowsA + i] = 0.0;
        }
        uVals[j * rowsA + j] = 1.0;
      }
      for (var lIdx = nct - 1; lIdx >= 0; lIdx--) {
        if (stemp[lIdx] != 0.0) {
          for (var j = lIdx + 1; j < ncu; j++) {
            var tVal = 0.0;
            for (var i = lIdx; i < rowsA; i++) {
              tVal += uVals[j * rowsA + i] * uVals[lIdx * rowsA + i];
            }
            tVal = -tVal / uVals[lIdx * rowsA + lIdx];
            for (var ii = lIdx; ii < rowsA; ii++) {
              uVals[j * rowsA + ii] += tVal * uVals[lIdx * rowsA + ii];
            }
          }
          for (var i = lIdx; i < rowsA; i++) {
            uVals[lIdx * rowsA + i] = -uVals[lIdx * rowsA + i];
          }
          uVals[lIdx * rowsA + lIdx] = 1.0 + uVals[lIdx * rowsA + lIdx];
          for (var i = 0; i < lIdx; i++) {
            uVals[lIdx * rowsA + i] = 0.0;
          }
        } else {
          for (var i = 0; i < rowsA; i++) {
            uVals[lIdx * rowsA + i] = 0.0;
          }
          uVals[lIdx * rowsA + lIdx] = 1.0;
        }
      }
    }

    if (computeVt) {
      for (var lIdx = colsA - 1; lIdx >= 0; lIdx--) {
        final lp1 = lIdx + 1;
        if (lIdx < nrt && eList[lIdx] != 0.0) {
          for (var j = lp1; j < colsA; j++) {
            var tVal = 0.0;
            for (var i = lp1; i < colsA; i++) {
              tVal += vList[j * colsA + i] * vList[lIdx * colsA + i];
            }
            tVal = -tVal / vList[lIdx * colsA + lp1];
            for (var ii = lIdx; ii < colsA; ii++) {
              vList[j * colsA + ii] += tVal * vList[lIdx * colsA + ii];
            }
          }
        }
        for (var i = 0; i < colsA; i++) {
          vList[lIdx * colsA + i] = 0.0;
        }
        vList[lIdx * colsA + lIdx] = 1.0;
      }
    }

    final mn = mDim;
    var iter = 0;
    while (mDim > 0) {
      if (iter >= 1000) return false;

      int lIdx;
      for (lIdx = mDim - 2; lIdx >= 0; lIdx--) {
        final test = stemp[lIdx].abs() + stemp[lIdx + 1].abs();
        final ztest = test + eList[lIdx].abs();
        if (eList[lIdx] == 0.0 || (ztest - test).abs() <= 1e-15 * test) {
          eList[lIdx] = 0.0;
          break;
        }
      }

      int kase;
      if (lIdx == mDim - 2) {
        kase = 4;
      } else {
        int lsIdx;
        for (lsIdx = mDim - 1; lsIdx > lIdx; lsIdx--) {
          var test = 0.0;
          if (lsIdx != mDim - 1) test += eList[lsIdx].abs();
          if (lsIdx != lIdx + 1) test += eList[lsIdx - 1].abs();
          final ztest = test + stemp[lsIdx].abs();
          if (stemp[lsIdx] == 0.0 || (ztest - test).abs() <= 1e-15 * test) {
            stemp[lsIdx] = 0.0;
            break;
          }
        }
        if (lsIdx == lIdx) {
          kase = 3;
        } else if (lsIdx == mDim - 1) {
          kase = 1;
        } else {
          kase = 2;
          lIdx = lsIdx;
        }
      }
      lIdx = lIdx + 1;

      switch (kase) {
        case 1:
          var fVal = eList[mDim - 2];
          eList[mDim - 2] = 0.0;
          for (var kk = lIdx; kk < mDim - 1; kk++) {
            final k = mDim - 2 - kk + lIdx;
            var t1 = stemp[k];
            final rotg = _rotg(t1, fVal);
            t1 = rotg.da;
            fVal = rotg.db;
            final cs = rotg.cosVal;
            final sn = rotg.sinVal;
            stemp[k] = t1;
            if (k != lIdx) {
              fVal = -sn * eList[k - 1];
              eList[k - 1] = cs * eList[k - 1];
            }
            if (computeVt) {
              for (var i = 0; i < colsA; i++) {
                final z =
                    cs * vList[k * colsA + i] +
                    sn * vList[(mDim - 1) * colsA + i];
                vList[(mDim - 1) * colsA + i] =
                    cs * vList[(mDim - 1) * colsA + i] -
                    sn * vList[k * colsA + i];
                vList[k * colsA + i] = z;
              }
            }
          }
          iter++;
        case 2:
          var fVal = eList[lIdx - 1];
          eList[lIdx - 1] = 0.0;
          for (var k = lIdx; k < mDim; k++) {
            var t1 = stemp[k];
            final rotg = _rotg(t1, fVal);
            t1 = rotg.da;
            fVal = rotg.db;
            final cs = rotg.cosVal;
            final sn = rotg.sinVal;
            stemp[k] = t1;
            fVal = -sn * eList[k];
            eList[k] = cs * eList[k];
            if (computeU) {
              for (var i = 0; i < rowsA; i++) {
                final z =
                    cs * uVals[k * rowsA + i] +
                    sn * uVals[(lIdx - 1) * rowsA + i];
                uVals[(lIdx - 1) * rowsA + i] =
                    cs * uVals[(lIdx - 1) * rowsA + i] -
                    sn * uVals[k * rowsA + i];
                uVals[k * rowsA + i] = z;
              }
            }
          }
          iter++;
        case 3:
          var scale = 0.0;
          scale = math.max(scale, stemp[mDim - 1].abs());
          scale = math.max(scale, stemp[mDim - 2].abs());
          scale = math.max(scale, eList[mDim - 2].abs());
          scale = math.max(scale, stemp[lIdx].abs());
          scale = math.max(scale, eList[lIdx].abs());
          double fVal, gVal;
          if (scale == 0.0) {
            fVal = 0.0;
            gVal = 0.0;
          } else {
            final sm = stemp[mDim - 1] / scale;
            final smm1 = stemp[mDim - 2] / scale;
            final emm1 = eList[mDim - 2] / scale;
            final sl = stemp[lIdx] / scale;
            final el = eList[lIdx] / scale;
            final b = ((smm1 + sm) * (smm1 - sm) + emm1 * emm1) / 2.0;
            final cVal = (sm * emm1) * (sm * emm1);
            var shift = 0.0;
            if (b != 0.0 || cVal != 0.0) {
              shift = math.sqrt(b * b + cVal);
              if (b < 0.0) shift = -shift;
              shift = cVal / (b + shift);
            }
            fVal = (sl + sm) * (sl - sm) + shift;
            gVal = sl * el;
          }
          for (var k = lIdx; k < mDim - 1; k++) {
            var rotg = _rotg(fVal, gVal);
            fVal = rotg.da;
            gVal = rotg.db;
            var cs = rotg.cosVal;
            var sn = rotg.sinVal;
            if (k != lIdx) eList[k - 1] = fVal;
            fVal = cs * stemp[k] + sn * eList[k];
            eList[k] = cs * eList[k] - sn * stemp[k];
            gVal = sn * stemp[k + 1];
            stemp[k + 1] = cs * stemp[k + 1];
            if (computeVt) {
              for (var i = 0; i < colsA; i++) {
                final z =
                    cs * vList[k * colsA + i] + sn * vList[(k + 1) * colsA + i];
                vList[(k + 1) * colsA + i] =
                    cs * vList[(k + 1) * colsA + i] - sn * vList[k * colsA + i];
                vList[k * colsA + i] = z;
              }
            }
            rotg = _rotg(fVal, gVal);
            fVal = rotg.da;
            gVal = rotg.db;
            cs = rotg.cosVal;
            sn = rotg.sinVal;
            stemp[k] = fVal;
            fVal = cs * eList[k] + sn * stemp[k + 1];
            stemp[k + 1] = -sn * eList[k] + cs * stemp[k + 1];
            gVal = sn * eList[k + 1];
            eList[k + 1] = cs * eList[k + 1];
            if (computeU && k < rowsA - 1) {
              for (var i = 0; i < rowsA; i++) {
                final z =
                    cs * uVals[k * rowsA + i] + sn * uVals[(k + 1) * rowsA + i];
                uVals[(k + 1) * rowsA + i] =
                    cs * uVals[(k + 1) * rowsA + i] - sn * uVals[k * rowsA + i];
                uVals[k * rowsA + i] = z;
              }
            }
          }
          eList[mDim - 2] = fVal;
          iter++;
        case 4:
          if (stemp[lIdx] < 0.0) {
            stemp[lIdx] = -stemp[lIdx];
            if (computeVt) {
              for (var i = 0; i < colsA; i++) {
                vList[lIdx * colsA + i] = -vList[lIdx * colsA + i];
              }
            }
          }
          while (lIdx != mn - 1) {
            if (stemp[lIdx] >= stemp[lIdx + 1]) break;
            final temp = stemp[lIdx];
            stemp[lIdx] = stemp[lIdx + 1];
            stemp[lIdx + 1] = temp;
            if (computeVt && lIdx < colsA - 1) {
              for (var i = 0; i < colsA; i++) {
                final aVal = vList[(lIdx + 1) * colsA + i];
                final bVal = vList[lIdx * colsA + i];
                vList[lIdx * colsA + i] = aVal;
                vList[(lIdx + 1) * colsA + i] = bVal;
              }
            }
            if (computeU && lIdx < rowsA - 1) {
              for (var i = 0; i < rowsA; i++) {
                final aVal = uVals[(lIdx + 1) * rowsA + i];
                final bVal = uVals[lIdx * rowsA + i];
                uVals[lIdx * rowsA + i] = aVal;
                uVals[(lIdx + 1) * rowsA + i] = bVal;
              }
            }
            lIdx++;
          }
          iter = 0;
          mDim--;
      }
    }

    for (var i = 0; i < math.min(rowsA, colsA); i++) {
      sVals[i] = stemp[i] == 0.0 ? 0.0 : stemp[i];
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
