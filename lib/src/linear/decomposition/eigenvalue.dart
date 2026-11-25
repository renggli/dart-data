import 'dart:math' as math;
import 'dart:typed_data';

import 'package:more/number.dart' show Complex;

import '../../acceleration/blas/cblas_constants.dart';
import '../../acceleration/lapack/lapack.dart';
import '../../type/data_type.dart';
import '../matrix.dart';

/// Extension methods providing Eigenvalue decomposition on numeric matrices.
extension EigenvalueMatrixExtension<T extends num> on Matrix<T> {
  /// Computes the Eigenvalue decomposition of this square matrix.
  EigenvalueDecomposition get eigenvalue =>
      EigenvalueDecomposition(toDoubleMatrix());
}

/// Eigenvalues and eigenvectors of a real square matrix.
///
/// Conceptually, when a matrix transforms space, an eigenvector is a special
/// direction that does not rotate—it only gets stretched or shrunk by a
/// scaling factor called the eigenvalue (`A * v = lambda * v`).
/// More formally, this computes the spectral decomposition `A * V = V * Lambda`.
/// For real symmetric matrices, uses LAPACK `dsyev` (or pure-Dart Householder
/// tridiagonalization + QL) to yield orthogonal eigenvectors (`A = V * D * V^T`).
/// For general matrices, reduces to Hessenberg form and applies Francis
/// double-shift QR iteration.
///
/// ```dart
/// final a = Matrix<double>.fromRows([
///   [2.0, 0.0],
///   [0.0, 3.0],
/// ]);
/// final eig = a.eigenvalue;
/// print(eig.realEigenvalues); // [2.0, 3.0]
/// ```
class EigenvalueDecomposition {
  /// Computes the eigenvalue decomposition of a square [matrix].
  new(Matrix<num> matrix)
    : _n = matrix.colCount,
      _isSymmetric = _checkSymmetry(matrix),
      _d = List<double>.filled(matrix.colCount, 0.0),
      _e = List<double>.filled(matrix.colCount, 0.0),
      _v = Matrix<double>.filled(
        matrix.colCount,
        matrix.colCount,
        0.0,
        type: DataType.float64,
      ) {
    if (matrix.rowCount != matrix.colCount) {
      throw ArgumentError(
        'Matrix must be square, got ${matrix.rowCount} x ${matrix.colCount}.',
      );
    }
    if (_n == 0) return;
    if (_isSymmetric) {
      final aList = Float64List(_n * _n);
      var allFinite = true;
      for (var i = 0; i < _n; i++) {
        for (var j = 0; j < _n; j++) {
          final val = matrix.getUnchecked(i, j).toDouble();
          if (!val.isFinite) allFinite = false;
          aList[i * _n + j] = val;
        }
      }
      if (allFinite) {
        final wList = Float64List(_n);
        final ok = Lapack.dsyev(
          jobz: 'V',
          uplo: cblasUpper,
          n: _n,
          a: aList,
          lda: _n,
          w: wList,
        );
        if (ok) {
          for (var i = 0; i < _n; i++) {
            _d[i] = wList[i];
            _e[i] = 0.0;
            for (var j = 0; j < _n; j++) {
              _v.setUnchecked(j, i, aList[j * _n + i]);
            }
          }
          return;
        }
      }
      _fillNaN();
      return;
    } else {
      final h = Matrix<double>.filled(_n, _n, 0.0, type: DataType.float64);
      var allFinite = true;
      for (var j = 0; j < _n; j++) {
        for (var i = 0; i < _n; i++) {
          final val = matrix.getUnchecked(i, j).toDouble();
          if (!val.isFinite) allFinite = false;
          h.setUnchecked(i, j, val);
        }
      }
      if (!allFinite) {
        _fillNaN();
        return;
      }
      final ort = List<double>.filled(_n, 0.0);
      _orthes(h, ort);
      _hqr2(h);
    }
  }

  final int _n;
  final bool _isSymmetric;
  final List<double> _d;
  final List<double> _e;
  final Matrix<double> _v;
  double _cdivr = 0.0;
  double _cdivi = 0.0;

  /// Whether the input matrix was detected as symmetric.
  bool get isSymmetric => _isSymmetric;

  /// The eigenvector matrix `V`.
  Matrix<double> get v => _v.copy();

  /// The block diagonal eigenvalue matrix `D`.
  Matrix<double> get d {
    final result = Matrix<double>.filled(_n, _n, 0.0, type: DataType.float64);
    for (var i = 0; i < _n; i++) {
      result.setUnchecked(i, i, _d[i]);
      if (_e[i] > 0) {
        result.setUnchecked(i, i + 1, _e[i]);
      } else if (_e[i] < 0) {
        result.setUnchecked(i, i - 1, _e[i]);
      }
    }
    return result;
  }

  /// The real parts of the eigenvalues.
  List<double> get realEigenvalues => List<double>.unmodifiable(_d);

  /// The imaginary parts of the eigenvalues.
  List<double> get imagEigenvalues => List<double>.unmodifiable(_e);

  /// The complex eigenvalues.
  List<Complex> get eigenvalues => [
    for (var i = 0; i < _n; i++) Complex(_d[i], _e[i]),
  ];

  void _fillNaN() {
    _d.fillRange(0, _n, double.nan);
    _e.fillRange(0, _n, double.nan);
    for (var i = 0; i < _n; i++) {
      for (var j = 0; j < _n; j++) {
        _v.setUnchecked(j, i, double.nan);
      }
    }
  }

  void _orthes(Matrix<double> h, List<double> ort) {
    final high = _n - 1;
    for (var mIdx = 1; mIdx <= high - 1; mIdx++) {
      var scale = 0.0;
      for (var i = mIdx; i <= high; i++) {
        scale += h.getUnchecked(i, mIdx - 1).abs();
      }
      if (scale != 0.0) {
        var hVal = 0.0;
        for (var i = high; i >= mIdx; i--) {
          ort[i] = h.getUnchecked(i, mIdx - 1) / scale;
          hVal += ort[i] * ort[i];
        }
        var gVal = math.sqrt(hVal);
        if (ort[mIdx] > 0) gVal = -gVal;
        hVal -= ort[mIdx] * gVal;
        ort[mIdx] -= gVal;

        for (var j = mIdx; j < _n; j++) {
          var fVal = 0.0;
          for (var i = high; i >= mIdx; i--) {
            fVal += ort[i] * h.getUnchecked(i, j);
          }
          fVal /= hVal;
          for (var i = mIdx; i <= high; i++) {
            h.setUnchecked(i, j, h.getUnchecked(i, j) - fVal * ort[i]);
          }
        }
        for (var i = 0; i <= high; i++) {
          var fVal = 0.0;
          for (var j = high; j >= mIdx; j--) {
            fVal += ort[j] * h.getUnchecked(i, j);
          }
          fVal /= hVal;
          for (var j = mIdx; j <= high; j++) {
            h.setUnchecked(i, j, h.getUnchecked(i, j) - fVal * ort[j]);
          }
        }
        ort[mIdx] = scale * ort[mIdx];
        h.setUnchecked(mIdx, mIdx - 1, scale * gVal);
      }
    }

    for (var i = 0; i < _n; i++) {
      for (var j = 0; j < _n; j++) {
        _v.setUnchecked(i, j, i == j ? 1.0 : 0.0);
      }
    }
    for (var mIdx = high - 1; mIdx >= 1; mIdx--) {
      if (h.getUnchecked(mIdx, mIdx - 1) != 0.0) {
        for (var i = mIdx + 1; i <= high; i++) {
          ort[i] = h.getUnchecked(i, mIdx - 1);
        }
        for (var j = mIdx; j <= high; j++) {
          var gVal = 0.0;
          for (var i = mIdx; i <= high; i++) {
            gVal += ort[i] * _v.getUnchecked(i, j);
          }
          gVal = (gVal / ort[mIdx]) / h.getUnchecked(mIdx, mIdx - 1);
          for (var i = mIdx; i <= high; i++) {
            _v.setUnchecked(i, j, _v.getUnchecked(i, j) + gVal * ort[i]);
          }
        }
      }
    }
  }

  void _cdiv(double xr, double xi, double yr, double yi) {
    if (yr.abs() > yi.abs()) {
      final ratio = yi / yr;
      final denom = yr + ratio * yi;
      _cdivr = (xr + ratio * xi) / denom;
      _cdivi = (xi - ratio * xr) / denom;
    } else {
      final ratio = yr / yi;
      final denom = yi + ratio * yr;
      _cdivr = (ratio * xr + xi) / denom;
      _cdivi = (ratio * xi - xr) / denom;
    }
  }

  void _hqr2(Matrix<double> h) {
    final nn = _n;
    var nIdx = nn - 1;
    const low = 0;
    final high = nn - 1;
    const eps = 2.220446049250313e-16;
    var exshift = 0.0;
    var pVal = 0.0,
        qVal = 0.0,
        rVal = 0.0,
        sVal = 0.0,
        z = 0.0,
        tVal = 0.0,
        wVal = 0.0,
        x = 0.0,
        y = 0.0;

    var norm = 0.0;
    for (var i = 0; i < nn; i++) {
      for (var j = math.max(i - 1, 0); j < nn; j++) {
        norm += h.getUnchecked(i, j).abs();
      }
    }

    var iter = 0;
    var totalIter = 0;
    final maxIter = 30 * nn;
    var converged = true;
    while (nIdx >= low) {
      if (++totalIter > maxIter) {
        converged = false;
        break;
      }
      var lIdx = nIdx;
      while (lIdx > low) {
        sVal =
            h.getUnchecked(lIdx - 1, lIdx - 1).abs() +
            h.getUnchecked(lIdx, lIdx).abs();
        if (sVal == 0.0) sVal = norm;
        if (h.getUnchecked(lIdx, lIdx - 1).abs() <= eps * sVal) break;
        lIdx--;
      }

      if (lIdx == nIdx) {
        h.setUnchecked(nIdx, nIdx, h.getUnchecked(nIdx, nIdx) + exshift);
        _d[nIdx] = h.getUnchecked(nIdx, nIdx);
        _e[nIdx] = 0.0;
        nIdx--;
        iter = 0;
      } else if (lIdx == nIdx - 1) {
        wVal = h.getUnchecked(nIdx, nIdx - 1) * h.getUnchecked(nIdx - 1, nIdx);
        pVal =
            (h.getUnchecked(nIdx - 1, nIdx - 1) - h.getUnchecked(nIdx, nIdx)) /
            2.0;
        qVal = pVal * pVal + wVal;
        z = math.sqrt(qVal.abs());
        h.setUnchecked(nIdx, nIdx, h.getUnchecked(nIdx, nIdx) + exshift);
        h.setUnchecked(
          nIdx - 1,
          nIdx - 1,
          h.getUnchecked(nIdx - 1, nIdx - 1) + exshift,
        );
        x = h.getUnchecked(nIdx, nIdx);

        if (qVal >= 0) {
          z = pVal >= 0 ? pVal + z : pVal - z;
          _d[nIdx - 1] = x + z;
          _d[nIdx] = _d[nIdx - 1];
          if (z != 0.0) _d[nIdx] = x - wVal / z;
          _e[nIdx - 1] = 0.0;
          _e[nIdx] = 0.0;
          x = h.getUnchecked(nIdx, nIdx - 1);
          sVal = x.abs() + z.abs();
          pVal = x / sVal;
          qVal = z / sVal;
          rVal = math.sqrt(pVal * pVal + qVal * qVal);
          pVal /= rVal;
          qVal /= rVal;

          for (var j = nIdx - 1; j < nn; j++) {
            z = h.getUnchecked(nIdx - 1, j);
            h.setUnchecked(
              nIdx - 1,
              j,
              qVal * z + pVal * h.getUnchecked(nIdx, j),
            );
            h.setUnchecked(nIdx, j, qVal * h.getUnchecked(nIdx, j) - pVal * z);
          }
          for (var i = 0; i <= nIdx; i++) {
            z = h.getUnchecked(i, nIdx - 1);
            h.setUnchecked(
              i,
              nIdx - 1,
              qVal * z + pVal * h.getUnchecked(i, nIdx),
            );
            h.setUnchecked(i, nIdx, qVal * h.getUnchecked(i, nIdx) - pVal * z);
          }
          for (var i = low; i <= high; i++) {
            z = _v.getUnchecked(i, nIdx - 1);
            _v.setUnchecked(
              i,
              nIdx - 1,
              qVal * z + pVal * _v.getUnchecked(i, nIdx),
            );
            _v.setUnchecked(
              i,
              nIdx,
              qVal * _v.getUnchecked(i, nIdx) - pVal * z,
            );
          }
        } else {
          _d[nIdx - 1] = x + pVal;
          _d[nIdx] = x + pVal;
          _e[nIdx - 1] = z;
          _e[nIdx] = -z;
        }
        nIdx -= 2;
        iter = 0;
      } else {
        x = h.getUnchecked(nIdx, nIdx);
        y = 0.0;
        wVal = 0.0;
        if (lIdx < nIdx) {
          y = h.getUnchecked(nIdx - 1, nIdx - 1);
          wVal =
              h.getUnchecked(nIdx, nIdx - 1) * h.getUnchecked(nIdx - 1, nIdx);
        }
        if (iter == 10) {
          exshift += x;
          for (var i = low; i <= nIdx; i++) {
            h.setUnchecked(i, i, h.getUnchecked(i, i) - x);
          }
          sVal =
              h.getUnchecked(nIdx, nIdx - 1).abs() +
              h.getUnchecked(nIdx - 1, nIdx - 2).abs();
          x = y = 0.75 * sVal;
          wVal = -0.4375 * sVal * sVal;
        }
        if (iter == 30) {
          sVal = (y - x) / 2.0;
          sVal = sVal * sVal + wVal;
          if (sVal > 0) {
            sVal = math.sqrt(sVal);
            if (y < x) sVal = -sVal;
            sVal = x - wVal / ((y - x) / 2.0 + sVal);
            for (var i = low; i <= nIdx; i++) {
              h.setUnchecked(i, i, h.getUnchecked(i, i) - sVal);
            }
            exshift += sVal;
            x = y = wVal = 0.964;
          }
        }
        iter++;
        var mIdx = nIdx - 2;
        while (mIdx >= lIdx) {
          z = h.getUnchecked(mIdx, mIdx);
          rVal = x - z;
          sVal = y - z;
          pVal =
              (rVal * sVal - wVal) / h.getUnchecked(mIdx + 1, mIdx) +
              h.getUnchecked(mIdx, mIdx + 1);
          qVal = h.getUnchecked(mIdx + 1, mIdx + 1) - z - rVal - sVal;
          rVal = h.getUnchecked(mIdx + 2, mIdx + 1);
          sVal = pVal.abs() + qVal.abs() + rVal.abs();
          if (sVal == 0.0) break;
          pVal /= sVal;
          qVal /= sVal;
          rVal /= sVal;
          if (mIdx == lIdx) break;
          if (h.getUnchecked(mIdx, mIdx - 1).abs() * (qVal.abs() + rVal.abs()) <
              eps *
                  (pVal.abs() *
                      (h.getUnchecked(mIdx - 1, mIdx - 1).abs() +
                          z.abs() +
                          h.getUnchecked(mIdx + 1, mIdx + 1).abs()))) {
            break;
          }
          mIdx--;
        }
        for (var i = mIdx + 2; i <= nIdx; i++) {
          h.setUnchecked(i, i - 2, 0.0);
          if (i > mIdx + 2) h.setUnchecked(i, i - 3, 0.0);
        }
        for (var k = mIdx; k <= nIdx - 1; k++) {
          final notlast = k != nIdx - 1;
          if (k != mIdx) {
            pVal = h.getUnchecked(k, k - 1);
            qVal = h.getUnchecked(k + 1, k - 1);
            rVal = notlast ? h.getUnchecked(k + 2, k - 1) : 0.0;
            x = pVal.abs() + qVal.abs() + rVal.abs();
            if (x == 0.0) continue;
            pVal /= x;
            qVal /= x;
            rVal /= x;
          }
          sVal = math.sqrt(pVal * pVal + qVal * qVal + rVal * rVal);
          if (pVal < 0) sVal = -sVal;
          if (sVal != 0) {
            if (k != mIdx) {
              h.setUnchecked(k, k - 1, -sVal * x);
            } else if (lIdx != mIdx) {
              h.setUnchecked(k, k - 1, -h.getUnchecked(k, k - 1));
            }
            pVal += sVal;
            x = pVal / sVal;
            y = qVal / sVal;
            z = rVal / sVal;
            qVal /= pVal;
            rVal /= pVal;
            for (var j = k; j < nn; j++) {
              pVal = h.getUnchecked(k, j) + qVal * h.getUnchecked(k + 1, j);
              if (notlast) {
                pVal += rVal * h.getUnchecked(k + 2, j);
                h.setUnchecked(k + 2, j, h.getUnchecked(k + 2, j) - pVal * z);
              }
              h.setUnchecked(k, j, h.getUnchecked(k, j) - pVal * x);
              h.setUnchecked(k + 1, j, h.getUnchecked(k + 1, j) - pVal * y);
            }
            for (var i = 0; i <= math.min(nIdx, k + 3); i++) {
              pVal = x * h.getUnchecked(i, k) + y * h.getUnchecked(i, k + 1);
              if (notlast) {
                pVal += z * h.getUnchecked(i, k + 2);
                h.setUnchecked(
                  i,
                  k + 2,
                  h.getUnchecked(i, k + 2) - pVal * rVal,
                );
              }
              h.setUnchecked(i, k, h.getUnchecked(i, k) - pVal);
              h.setUnchecked(i, k + 1, h.getUnchecked(i, k + 1) - pVal * qVal);
            }
            for (var i = low; i <= high; i++) {
              pVal = x * _v.getUnchecked(i, k) + y * _v.getUnchecked(i, k + 1);
              if (notlast) {
                pVal += z * _v.getUnchecked(i, k + 2);
                _v.setUnchecked(
                  i,
                  k + 2,
                  _v.getUnchecked(i, k + 2) - pVal * rVal,
                );
              }
              _v.setUnchecked(i, k, _v.getUnchecked(i, k) - pVal);
              _v.setUnchecked(
                i,
                k + 1,
                _v.getUnchecked(i, k + 1) - pVal * qVal,
              );
            }
          }
        }
      }
    }

    if (!converged) {
      _fillNaN();
      return;
    }

    if (norm == 0.0) return;

    for (nIdx = nn - 1; nIdx >= 0; nIdx--) {
      pVal = _d[nIdx];
      qVal = _e[nIdx];
      if (qVal == 0) {
        var lIdx = nIdx;
        h.setUnchecked(nIdx, nIdx, 1.0);
        for (var i = nIdx - 1; i >= 0; i--) {
          wVal = h.getUnchecked(i, i) - pVal;
          rVal = 0.0;
          for (var j = lIdx; j <= nIdx; j++) {
            rVal += h.getUnchecked(i, j) * h.getUnchecked(j, nIdx);
          }
          if (_e[i] < 0.0) {
            z = wVal;
            sVal = rVal;
          } else {
            lIdx = i;
            if (_e[i] == 0.0) {
              h.setUnchecked(
                i,
                nIdx,
                wVal != 0.0
                    ? -rVal / wVal
                    : -rVal / math.max(eps * norm, double.minPositive),
              );
            } else {
              x = h.getUnchecked(i, i + 1);
              y = h.getUnchecked(i + 1, i);
              qVal = (_d[i] - pVal) * (_d[i] - pVal) + _e[i] * _e[i];
              tVal = (x * sVal - z * rVal) / qVal;
              h.setUnchecked(i, nIdx, tVal);
              if (x.abs() > z.abs()) {
                h.setUnchecked(i + 1, nIdx, (-rVal - wVal * tVal) / x);
              } else {
                h.setUnchecked(i + 1, nIdx, (-sVal - y * tVal) / z);
              }
            }
            tVal = h.getUnchecked(i, nIdx).abs();
            if ((eps * tVal) * tVal > 1) {
              for (var j = i; j <= nIdx; j++) {
                h.setUnchecked(j, nIdx, h.getUnchecked(j, nIdx) / tVal);
              }
            }
          }
        }
      } else if (qVal < 0) {
        var lIdx = nIdx - 1;
        if (h.getUnchecked(nIdx, nIdx - 1).abs() >
            h.getUnchecked(nIdx - 1, nIdx).abs()) {
          h.setUnchecked(
            nIdx - 1,
            nIdx - 1,
            qVal / h.getUnchecked(nIdx, nIdx - 1),
          );
          h.setUnchecked(
            nIdx - 1,
            nIdx,
            -(h.getUnchecked(nIdx, nIdx) - pVal) /
                h.getUnchecked(nIdx, nIdx - 1),
          );
        } else {
          _cdiv(
            0,
            -h.getUnchecked(nIdx - 1, nIdx),
            h.getUnchecked(nIdx - 1, nIdx - 1) - pVal,
            qVal,
          );
          h.setUnchecked(nIdx - 1, nIdx - 1, _cdivr);
          h.setUnchecked(nIdx - 1, nIdx, _cdivi);
        }
        h.setUnchecked(nIdx, nIdx - 1, 0.0);
        h.setUnchecked(nIdx, nIdx, 1.0);
        for (var i = nIdx - 2; i >= 0; i--) {
          var ra = 0.0, sa = 0.0;
          for (var j = lIdx; j <= nIdx; j++) {
            ra += h.getUnchecked(i, j) * h.getUnchecked(j, nIdx - 1);
            sa += h.getUnchecked(i, j) * h.getUnchecked(j, nIdx);
          }
          wVal = h.getUnchecked(i, i) - pVal;
          if (_e[i] < 0.0) {
            z = wVal;
            rVal = ra;
            sVal = sa;
          } else {
            lIdx = i;
            if (_e[i] == 0) {
              _cdiv(-ra, -sa, wVal, qVal);
              h.setUnchecked(i, nIdx - 1, _cdivr);
              h.setUnchecked(i, nIdx, _cdivi);
            } else {
              x = h.getUnchecked(i, i + 1);
              y = h.getUnchecked(i + 1, i);
              var vr =
                  (_d[i] - pVal) * (_d[i] - pVal) + _e[i] * _e[i] - qVal * qVal;
              final vi = (_d[i] - pVal) * 2.0 * qVal;
              if (vr == 0.0 && vi == 0.0) {
                vr =
                    eps *
                    norm *
                    (wVal.abs() + qVal.abs() + x.abs() + y.abs() + z.abs());
              }
              _cdiv(
                x * rVal - z * ra + qVal * sa,
                x * sVal - z * sa - qVal * ra,
                vr,
                vi,
              );
              h.setUnchecked(i, nIdx - 1, _cdivr);
              h.setUnchecked(i, nIdx, _cdivi);
              if (x.abs() > (z.abs() + qVal.abs())) {
                h.setUnchecked(
                  i + 1,
                  nIdx - 1,
                  (-ra -
                          wVal * h.getUnchecked(i, nIdx - 1) +
                          qVal * h.getUnchecked(i, nIdx)) /
                      x,
                );
                h.setUnchecked(
                  i + 1,
                  nIdx,
                  (-sa -
                          wVal * h.getUnchecked(i, nIdx) -
                          qVal * h.getUnchecked(i, nIdx - 1)) /
                      x,
                );
              } else {
                _cdiv(
                  -rVal - y * h.getUnchecked(i, nIdx - 1),
                  -sVal - y * h.getUnchecked(i, nIdx),
                  z,
                  qVal,
                );
                h.setUnchecked(i + 1, nIdx - 1, _cdivr);
                h.setUnchecked(i + 1, nIdx, _cdivi);
              }
            }
            tVal = math.max(
              h.getUnchecked(i, nIdx - 1).abs(),
              h.getUnchecked(i, nIdx).abs(),
            );
            if ((eps * tVal) * tVal > 1) {
              for (var j = i; j <= nIdx; j++) {
                h.setUnchecked(j, nIdx - 1, h.getUnchecked(j, nIdx - 1) / tVal);
                h.setUnchecked(j, nIdx, h.getUnchecked(j, nIdx) / tVal);
              }
            }
          }
        }
      }
    }

    for (var j = nn - 1; j >= low; j--) {
      for (var i = low; i <= high; i++) {
        z = 0.0;
        for (var k = low; k <= math.min(j, high); k++) {
          z += _v.getUnchecked(i, k) * h.getUnchecked(k, j);
        }
        _v.setUnchecked(i, j, z);
      }
    }
  }

  static bool _checkSymmetry(Matrix<num> a) {
    if (a.rowCount != a.colCount) return false;
    final count = a.rowCount;
    if (count <= 1) return true;
    var maxVal = 0.0;
    for (var i = 0; i < count; i++) {
      for (var j = 0; j < count; j++) {
        final val = a.getUnchecked(i, j).toDouble().abs();
        if (!val.isFinite) return false;
        if (val > maxVal) maxVal = val;
      }
    }
    if (maxVal == 0.0) return true;
    final tol = 1e-12 * maxVal;
    for (var i = 0; i < count; i++) {
      for (var j = i + 1; j < count; j++) {
        final aij = a.getUnchecked(i, j).toDouble();
        final aji = a.getUnchecked(j, i).toDouble();
        if ((aij - aji).abs() > tol) {
          return false;
        }
      }
    }
    return true;
  }
}
