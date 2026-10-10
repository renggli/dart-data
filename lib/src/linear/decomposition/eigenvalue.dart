import 'dart:math' as math;

import '../../../type.dart';
import '../matrix.dart';

/// Eigenvalues and eigenvectors of a real square matrix.
///
/// If $A$ is symmetric, then $A = V D V^T$ where $D$ is diagonal and $V$ is
/// orthogonal. If $A$ is not symmetric, eigenvalues are computed in Schur
/// form where complex conjugate pairs form $2 \times 2$ blocks.
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
      ),
      _h = Matrix<double>.filled(
        matrix.colCount,
        matrix.colCount,
        0.0,
        type: DataType.float64,
      ),
      _ort = List<double>.filled(matrix.colCount, 0.0) {
    if (matrix.rowCount != matrix.colCount) {
      throw ArgumentError(
        'Matrix must be square, got ${matrix.rowCount} x ${matrix.colCount}.',
      );
    }
    if (_isSymmetric) {
      for (var i = 0; i < _n; i++) {
        for (var j = 0; j < _n; j++) {
          _v.set(i, j, matrix.get(i, j).toDouble());
        }
      }
      _tred2();
      _tql2();
    } else {
      for (var j = 0; j < _n; j++) {
        for (var i = 0; i < _n; i++) {
          _h.set(i, j, matrix.get(i, j).toDouble());
        }
      }
      _orthes();
      _hqr2();
    }
  }

  final int _n;
  final bool _isSymmetric;
  final List<double> _d;
  final List<double> _e;
  final Matrix<double> _v;
  final Matrix<double> _h;
  final List<double> _ort;
  double _cdivr = 0.0;
  double _cdivi = 0.0;

  /// The eigenvector matrix $V$.
  Matrix<double> get v => _v;

  /// The block diagonal eigenvalue matrix $D$.
  Matrix<double> get d {
    final result = Matrix<double>.filled(_n, _n, 0.0, type: DataType.float64);
    for (var i = 0; i < _n; i++) {
      result.set(i, i, _d[i]);
      if (_e[i] > 0) {
        result.set(i, i + 1, _e[i]);
      } else if (_e[i] < 0) {
        result.set(i, i - 1, _e[i]);
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

  void _tred2() {
    for (var j = 0; j < _n; j++) {
      _d[j] = _v.get(_n - 1, j);
    }
    for (var i = _n - 1; i > 0; i--) {
      var scale = 0.0;
      var hVal = 0.0;
      for (var k = 0; k < i; k++) {
        scale += _d[k].abs();
      }
      if (scale == 0.0) {
        _e[i] = _d[i - 1];
        for (var j = 0; j < i; j++) {
          _d[j] = _v.get(i - 1, j);
          _v.set(i, j, 0.0);
          _v.set(j, i, 0.0);
        }
      } else {
        for (var k = 0; k < i; k++) {
          _d[k] /= scale;
          hVal += _d[k] * _d[k];
        }
        var fVal = _d[i - 1];
        var gVal = math.sqrt(hVal);
        if (fVal > 0) gVal = -gVal;
        _e[i] = scale * gVal;
        hVal -= fVal * gVal;
        _d[i - 1] = fVal - gVal;
        for (var j = 0; j < i; j++) {
          _e[j] = 0.0;
        }
        for (var j = 0; j < i; j++) {
          fVal = _d[j];
          _v.set(j, i, fVal);
          gVal = _e[j] + _v.get(j, j) * fVal;
          for (var k = j + 1; k <= i - 1; k++) {
            gVal += _v.get(k, j) * _d[k];
            _e[k] += _v.get(k, j) * fVal;
          }
          _e[j] = gVal;
        }
        fVal = 0.0;
        for (var j = 0; j < i; j++) {
          _e[j] /= hVal;
          fVal += _e[j] * _d[j];
        }
        final hh = fVal / (hVal + hVal);
        for (var j = 0; j < i; j++) {
          _e[j] -= hh * _d[j];
        }
        for (var j = 0; j < i; j++) {
          fVal = _d[j];
          gVal = _e[j];
          for (var k = j; k <= i - 1; k++) {
            _v.set(k, j, _v.get(k, j) - (fVal * _e[k] + gVal * _d[k]));
          }
          _d[j] = _v.get(i - 1, j);
          _v.set(i, j, 0.0);
        }
      }
      _d[i] = hVal;
    }

    for (var i = 0; i < _n - 1; i++) {
      _v.set(_n - 1, i, _v.get(i, i));
      _v.set(i, i, 1.0);
      final hVal = _d[i + 1];
      if (hVal != 0.0) {
        for (var k = 0; k <= i; k++) {
          _d[k] = _v.get(k, i + 1) / hVal;
        }
        for (var j = 0; j <= i; j++) {
          var gVal = 0.0;
          for (var k = 0; k <= i; k++) {
            gVal += _v.get(k, i + 1) * _v.get(k, j);
          }
          for (var k = 0; k <= i; k++) {
            _v.set(k, j, _v.get(k, j) - gVal * _d[k]);
          }
        }
      }
      for (var k = 0; k <= i; k++) {
        _v.set(k, i + 1, 0.0);
      }
    }
    for (var j = 0; j < _n; j++) {
      _d[j] = _v.get(_n - 1, j);
      _v.set(_n - 1, j, 0.0);
    }
    _v.set(_n - 1, _n - 1, 1.0);
    _e[0] = 0.0;
  }

  void _tql2() {
    for (var i = 1; i < _n; i++) {
      _e[i - 1] = _e[i];
    }
    _e[_n - 1] = 0.0;

    var fVal = 0.0;
    var tst1 = 0.0;
    const eps = 2.220446049250313e-16;
    for (var lIdx = 0; lIdx < _n; lIdx++) {
      tst1 = math.max(tst1, _d[lIdx].abs() + _e[lIdx].abs());
      var mIdx = lIdx;
      while (mIdx < _n) {
        if (_e[mIdx].abs() <= eps * tst1) break;
        mIdx++;
      }
      if (mIdx > lIdx) {
        do {
          var gVal = _d[lIdx];
          var pVal = (_d[lIdx + 1] - gVal) / (2.0 * _e[lIdx]);
          var rVal = _hypot(pVal, 1.0);
          if (pVal < 0) rVal = -rVal;
          _d[lIdx] = _e[lIdx] / (pVal + rVal);
          _d[lIdx + 1] = _e[lIdx] * (pVal + rVal);
          final dl1 = _d[lIdx + 1];
          var hVal = gVal - _d[lIdx];
          for (var i = lIdx + 2; i < _n; i++) {
            _d[i] -= hVal;
          }
          fVal += hVal;

          pVal = _d[mIdx];
          var cosVal = 1.0;
          var cos2Val = cosVal;
          var cos3Val = cosVal;
          final el1 = _e[lIdx + 1];
          var sinVal = 0.0;
          var sin2Val = 0.0;
          for (var i = mIdx - 1; i >= lIdx; i--) {
            cos3Val = cos2Val;
            cos2Val = cosVal;
            sin2Val = sinVal;
            gVal = cosVal * _e[i];
            hVal = cosVal * pVal;
            rVal = _hypot(pVal, _e[i]);
            _e[i + 1] = sinVal * rVal;
            sinVal = _e[i] / rVal;
            cosVal = pVal / rVal;
            pVal = cosVal * _d[i] - sinVal * gVal;
            _d[i + 1] = hVal + sinVal * (cosVal * gVal + sinVal * _d[i]);

            for (var k = 0; k < _n; k++) {
              hVal = _v.get(k, i + 1);
              _v.set(k, i + 1, sinVal * _v.get(k, i) + cosVal * hVal);
              _v.set(k, i, cosVal * _v.get(k, i) - sinVal * hVal);
            }
          }
          pVal = -sinVal * sin2Val * cos3Val * el1 * _e[lIdx] / dl1;
          _e[lIdx] = sinVal * pVal;
          _d[lIdx] = cosVal * pVal;
        } while (_e[lIdx].abs() > eps * tst1);
      }
      _d[lIdx] += fVal;
      _e[lIdx] = 0.0;
    }

    for (var i = 0; i < _n - 1; i++) {
      var k = i;
      var pVal = _d[i];
      for (var j = i + 1; j < _n; j++) {
        if (_d[j] < pVal) {
          k = j;
          pVal = _d[j];
        }
      }
      if (k != i) {
        _d[k] = _d[i];
        _d[i] = pVal;
        for (var j = 0; j < _n; j++) {
          pVal = _v.get(j, i);
          _v.set(j, i, _v.get(j, k));
          _v.set(j, k, pVal);
        }
      }
    }
  }

  void _orthes() {
    final high = _n - 1;
    for (var mIdx = 1; mIdx <= high - 1; mIdx++) {
      var scale = 0.0;
      for (var i = mIdx; i <= high; i++) {
        scale += _h.get(i, mIdx - 1).abs();
      }
      if (scale != 0.0) {
        var hVal = 0.0;
        for (var i = high; i >= mIdx; i--) {
          _ort[i] = _h.get(i, mIdx - 1) / scale;
          hVal += _ort[i] * _ort[i];
        }
        var gVal = math.sqrt(hVal);
        if (_ort[mIdx] > 0) gVal = -gVal;
        hVal -= _ort[mIdx] * gVal;
        _ort[mIdx] -= gVal;

        for (var j = mIdx; j < _n; j++) {
          var fVal = 0.0;
          for (var i = high; i >= mIdx; i--) {
            fVal += _ort[i] * _h.get(i, j);
          }
          fVal /= hVal;
          for (var i = mIdx; i <= high; i++) {
            _h.set(i, j, _h.get(i, j) - fVal * _ort[i]);
          }
        }
        for (var i = 0; i <= high; i++) {
          var fVal = 0.0;
          for (var j = high; j >= mIdx; j--) {
            fVal += _ort[j] * _h.get(i, j);
          }
          fVal /= hVal;
          for (var j = mIdx; j <= high; j++) {
            _h.set(i, j, _h.get(i, j) - fVal * _ort[j]);
          }
        }
        _ort[mIdx] = scale * _ort[mIdx];
        _h.set(mIdx, mIdx - 1, scale * gVal);
      }
    }

    for (var i = 0; i < _n; i++) {
      for (var j = 0; j < _n; j++) {
        _v.set(i, j, i == j ? 1.0 : 0.0);
      }
    }
    for (var mIdx = high - 1; mIdx >= 1; mIdx--) {
      if (_h.get(mIdx, mIdx - 1) != 0.0) {
        for (var i = mIdx + 1; i <= high; i++) {
          _ort[i] = _h.get(i, mIdx - 1);
        }
        for (var j = mIdx; j <= high; j++) {
          var gVal = 0.0;
          for (var i = mIdx; i <= high; i++) {
            gVal += _ort[i] * _v.get(i, j);
          }
          gVal = (gVal / _ort[mIdx]) / _h.get(mIdx, mIdx - 1);
          for (var i = mIdx; i <= high; i++) {
            _v.set(i, j, _v.get(i, j) + gVal * _ort[i]);
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

  void _hqr2() {
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
      // coverage:ignore-start
      if (i < low || i > high) {
        _d[i] = _h.get(i, i);
        _e[i] = 0.0;
      }
      // coverage:ignore-end
      for (var j = math.max(i - 1, 0); j < nn; j++) {
        norm += _h.get(i, j).abs();
      }
    }

    var iter = 0;
    while (nIdx >= low) {
      var lIdx = nIdx;
      while (lIdx > low) {
        sVal = _h.get(lIdx - 1, lIdx - 1).abs() + _h.get(lIdx, lIdx).abs();
        if (sVal == 0.0) sVal = norm;
        if (_h.get(lIdx, lIdx - 1).abs() < eps * sVal) break;
        lIdx--;
      }

      if (lIdx == nIdx) {
        _h.set(nIdx, nIdx, _h.get(nIdx, nIdx) + exshift);
        _d[nIdx] = _h.get(nIdx, nIdx);
        _e[nIdx] = 0.0;
        nIdx--;
        iter = 0;
      } else if (lIdx == nIdx - 1) {
        wVal = _h.get(nIdx, nIdx - 1) * _h.get(nIdx - 1, nIdx);
        pVal = (_h.get(nIdx - 1, nIdx - 1) - _h.get(nIdx, nIdx)) / 2.0;
        qVal = pVal * pVal + wVal;
        z = math.sqrt(qVal.abs());
        _h.set(nIdx, nIdx, _h.get(nIdx, nIdx) + exshift);
        _h.set(nIdx - 1, nIdx - 1, _h.get(nIdx - 1, nIdx - 1) + exshift);
        x = _h.get(nIdx, nIdx);

        if (qVal >= 0) {
          z = pVal >= 0 ? pVal + z : pVal - z;
          _d[nIdx - 1] = x + z;
          _d[nIdx] = _d[nIdx - 1];
          if (z != 0.0) _d[nIdx] = x - wVal / z;
          _e[nIdx - 1] = 0.0;
          _e[nIdx] = 0.0;
          x = _h.get(nIdx, nIdx - 1);
          sVal = x.abs() + z.abs();
          pVal = x / sVal;
          qVal = z / sVal;
          rVal = math.sqrt(pVal * pVal + qVal * qVal);
          pVal /= rVal;
          qVal /= rVal;

          for (var j = nIdx - 1; j < nn; j++) {
            z = _h.get(nIdx - 1, j);
            _h.set(nIdx - 1, j, qVal * z + pVal * _h.get(nIdx, j));
            _h.set(nIdx, j, qVal * _h.get(nIdx, j) - pVal * z);
          }
          for (var i = 0; i <= nIdx; i++) {
            z = _h.get(i, nIdx - 1);
            _h.set(i, nIdx - 1, qVal * z + pVal * _h.get(i, nIdx));
            _h.set(i, nIdx, qVal * _h.get(i, nIdx) - pVal * z);
          }
          for (var i = low; i <= high; i++) {
            z = _v.get(i, nIdx - 1);
            _v.set(i, nIdx - 1, qVal * z + pVal * _v.get(i, nIdx));
            _v.set(i, nIdx, qVal * _v.get(i, nIdx) - pVal * z);
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
        x = _h.get(nIdx, nIdx);
        y = 0.0;
        wVal = 0.0;
        if (lIdx < nIdx) {
          y = _h.get(nIdx - 1, nIdx - 1);
          wVal = _h.get(nIdx, nIdx - 1) * _h.get(nIdx - 1, nIdx);
        }
        if (iter == 10) {
          exshift += x;
          for (var i = low; i <= nIdx; i++) {
            _h.set(i, i, _h.get(i, i) - x);
          }
          sVal =
              _h.get(nIdx, nIdx - 1).abs() + _h.get(nIdx - 1, nIdx - 2).abs();
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
              _h.set(i, i, _h.get(i, i) - sVal);
            }
            exshift += sVal;
            x = y = wVal = 0.964;
          }
        }
        iter++;
        var mIdx = nIdx - 2;
        while (mIdx >= lIdx) {
          z = _h.get(mIdx, mIdx);
          rVal = x - z;
          sVal = y - z;
          pVal =
              (rVal * sVal - wVal) / _h.get(mIdx + 1, mIdx) +
              _h.get(mIdx, mIdx + 1);
          qVal = _h.get(mIdx + 1, mIdx + 1) - z - rVal - sVal;
          rVal = _h.get(mIdx + 2, mIdx + 1);
          sVal = pVal.abs() + qVal.abs() + rVal.abs();
          pVal /= sVal;
          qVal /= sVal;
          rVal /= sVal;
          if (mIdx == lIdx) break;
          if (_h.get(mIdx, mIdx - 1).abs() * (qVal.abs() + rVal.abs()) <
              eps *
                  (pVal.abs() *
                      (_h.get(mIdx - 1, mIdx - 1).abs() +
                          z.abs() +
                          _h.get(mIdx + 1, mIdx + 1).abs()))) {
            break;
          }
          mIdx--;
        }
        for (var i = mIdx + 2; i <= nIdx; i++) {
          _h.set(i, i - 2, 0.0);
          if (i > mIdx + 2) _h.set(i, i - 3, 0.0);
        }
        for (var k = mIdx; k <= nIdx - 1; k++) {
          final notlast = k != nIdx - 1;
          if (k != mIdx) {
            pVal = _h.get(k, k - 1);
            qVal = _h.get(k + 1, k - 1);
            rVal = notlast ? _h.get(k + 2, k - 1) : 0.0;
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
              _h.set(k, k - 1, -sVal * x);
            } else if (lIdx != mIdx) {
              _h.set(k, k - 1, -_h.get(k, k - 1));
            }
            pVal += sVal;
            x = pVal / sVal;
            y = qVal / sVal;
            z = rVal / sVal;
            qVal /= pVal;
            rVal /= pVal;
            for (var j = k; j < nn; j++) {
              pVal = _h.get(k, j) + qVal * _h.get(k + 1, j);
              if (notlast) {
                pVal += rVal * _h.get(k + 2, j);
                _h.set(k + 2, j, _h.get(k + 2, j) - pVal * z);
              }
              _h.set(k, j, _h.get(k, j) - pVal * x);
              _h.set(k + 1, j, _h.get(k + 1, j) - pVal * y);
            }
            for (var i = 0; i <= math.min(nIdx, k + 3); i++) {
              pVal = x * _h.get(i, k) + y * _h.get(i, k + 1);
              if (notlast) {
                pVal += z * _h.get(i, k + 2);
                _h.set(i, k + 2, _h.get(i, k + 2) - pVal * rVal);
              }
              _h.set(i, k, _h.get(i, k) - pVal);
              _h.set(i, k + 1, _h.get(i, k + 1) - pVal * qVal);
            }
            for (var i = low; i <= high; i++) {
              pVal = x * _v.get(i, k) + y * _v.get(i, k + 1);
              if (notlast) {
                pVal += z * _v.get(i, k + 2);
                _v.set(i, k + 2, _v.get(i, k + 2) - pVal * rVal);
              }
              _v.set(i, k, _v.get(i, k) - pVal);
              _v.set(i, k + 1, _v.get(i, k + 1) - pVal * qVal);
            }
          }
        }
      }
    }

    if (norm == 0.0) return;

    for (nIdx = nn - 1; nIdx >= 0; nIdx--) {
      pVal = _d[nIdx];
      qVal = _e[nIdx];
      if (qVal == 0) {
        var lIdx = nIdx;
        _h.set(nIdx, nIdx, 1.0);
        for (var i = nIdx - 1; i >= 0; i--) {
          wVal = _h.get(i, i) - pVal;
          rVal = 0.0;
          for (var j = lIdx; j <= nIdx; j++) {
            rVal += _h.get(i, j) * _h.get(j, nIdx);
          }
          if (_e[i] < 0.0) {
            z = wVal;
            sVal = rVal;
          } else {
            lIdx = i;
            if (_e[i] == 0.0) {
              _h.set(
                i,
                nIdx,
                wVal != 0.0 ? -rVal / wVal : -rVal / (eps * norm),
              );
            } else {
              x = _h.get(i, i + 1);
              y = _h.get(i + 1, i);
              qVal = (_d[i] - pVal) * (_d[i] - pVal) + _e[i] * _e[i];
              tVal = (x * sVal - z * rVal) / qVal;
              _h.set(i, nIdx, tVal);
              if (x.abs() > z.abs()) {
                _h.set(i + 1, nIdx, (-rVal - wVal * tVal) / x);
              } else {
                _h.set(i + 1, nIdx, (-sVal - y * tVal) / z);
              }
            }
            tVal = _h.get(i, nIdx).abs();
            if ((eps * tVal) * tVal > 1) {
              for (var j = i; j <= nIdx; j++) {
                _h.set(j, nIdx, _h.get(j, nIdx) / tVal);
              }
            }
          }
        }
      } else if (qVal < 0) {
        var lIdx = nIdx - 1;
        if (_h.get(nIdx, nIdx - 1).abs() > _h.get(nIdx - 1, nIdx).abs()) {
          _h.set(nIdx - 1, nIdx - 1, qVal / _h.get(nIdx, nIdx - 1));
          _h.set(
            nIdx - 1,
            nIdx,
            -(_h.get(nIdx, nIdx) - pVal) / _h.get(nIdx, nIdx - 1),
          );
        } else {
          _cdiv(
            0,
            -_h.get(nIdx - 1, nIdx),
            _h.get(nIdx - 1, nIdx - 1) - pVal,
            qVal,
          );
          _h.set(nIdx - 1, nIdx - 1, _cdivr);
          _h.set(nIdx - 1, nIdx, _cdivi);
        }
        _h.set(nIdx, nIdx - 1, 0.0);
        _h.set(nIdx, nIdx, 1.0);
        for (var i = nIdx - 2; i >= 0; i--) {
          var ra = 0.0, sa = 0.0;
          for (var j = lIdx; j <= nIdx; j++) {
            ra += _h.get(i, j) * _h.get(j, nIdx - 1);
            sa += _h.get(i, j) * _h.get(j, nIdx);
          }
          wVal = _h.get(i, i) - pVal;
          if (_e[i] < 0.0) {
            z = wVal;
            rVal = ra;
            sVal = sa;
          } else {
            lIdx = i;
            if (_e[i] == 0) {
              _cdiv(-ra, -sa, wVal, qVal);
              _h.set(i, nIdx - 1, _cdivr);
              _h.set(i, nIdx, _cdivi);
            } else {
              x = _h.get(i, i + 1);
              y = _h.get(i + 1, i);
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
              _h.set(i, nIdx - 1, _cdivr);
              _h.set(i, nIdx, _cdivi);
              if (x.abs() > (z.abs() + qVal.abs())) {
                _h.set(
                  i + 1,
                  nIdx - 1,
                  (-ra - wVal * _h.get(i, nIdx - 1) + qVal * _h.get(i, nIdx)) /
                      x,
                );
                _h.set(
                  i + 1,
                  nIdx,
                  (-sa - wVal * _h.get(i, nIdx) - qVal * _h.get(i, nIdx - 1)) /
                      x,
                );
              } else {
                _cdiv(
                  -rVal - y * _h.get(i, nIdx - 1),
                  -sVal - y * _h.get(i, nIdx),
                  z,
                  qVal,
                );
                _h.set(i + 1, nIdx - 1, _cdivr);
                _h.set(i + 1, nIdx, _cdivi);
              }
            }
            tVal = math.max(_h.get(i, nIdx - 1).abs(), _h.get(i, nIdx).abs());
            if ((eps * tVal) * tVal > 1) {
              for (var j = i; j <= nIdx; j++) {
                _h.set(j, nIdx - 1, _h.get(j, nIdx - 1) / tVal);
                _h.set(j, nIdx, _h.get(j, nIdx) / tVal);
              }
            }
          }
        }
      }
    }

    // coverage:ignore-start
    for (var i = 0; i < nn; i++) {
      if (i < low || i > high) {
        for (var j = i; j < nn; j++) {
          _v.set(i, j, _h.get(i, j));
        }
      }
    }
    // coverage:ignore-end

    for (var j = nn - 1; j >= low; j--) {
      for (var i = low; i <= high; i++) {
        z = 0.0;
        for (var k = low; k <= math.min(j, high); k++) {
          z += _v.get(i, k) * _h.get(k, j);
        }
        _v.set(i, j, z);
      }
    }
  }

  static bool _checkSymmetry(Matrix<num> a) {
    final count = a.rowCount;
    for (var i = 0; i < count; i++) {
      for (var j = i + 1; j < count; j++) {
        if (a.get(i, j) != a.get(j, i)) return false;
      }
    }
    return true;
  }
}
