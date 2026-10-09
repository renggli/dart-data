import 'dart:math' as math;

import 'package:more/number.dart' show Complex;

import '../../type/data_type.dart';
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
      final r = b / a;
      return a.abs() * math.sqrt(1 + r * r);
    } else if (b != 0) {
      final r = a / b;
      return b.abs() * math.sqrt(1 + r * r);
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
      var h = 0.0;
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
          h += _d[k] * _d[k];
        }
        var f = _d[i - 1];
        var g = math.sqrt(h);
        if (f > 0) g = -g;
        _e[i] = scale * g;
        h -= f * g;
        _d[i - 1] = f - g;
        for (var j = 0; j < i; j++) {
          _e[j] = 0.0;
        }
        for (var j = 0; j < i; j++) {
          f = _d[j];
          _v.set(j, i, f);
          g = _e[j] + _v.get(j, j) * f;
          for (var k = j + 1; k <= i - 1; k++) {
            g += _v.get(k, j) * _d[k];
            _e[k] += _v.get(k, j) * f;
          }
          _e[j] = g;
        }
        f = 0.0;
        for (var j = 0; j < i; j++) {
          _e[j] /= h;
          f += _e[j] * _d[j];
        }
        final hh = f / (h + h);
        for (var j = 0; j < i; j++) {
          _e[j] -= hh * _d[j];
        }
        for (var j = 0; j < i; j++) {
          f = _d[j];
          g = _e[j];
          for (var k = j; k <= i - 1; k++) {
            _v.set(k, j, _v.get(k, j) - (f * _e[k] + g * _d[k]));
          }
          _d[j] = _v.get(i - 1, j);
          _v.set(i, j, 0.0);
        }
      }
      _d[i] = h;
    }

    for (var i = 0; i < _n - 1; i++) {
      _v.set(_n - 1, i, _v.get(i, i));
      _v.set(i, i, 1.0);
      final h = _d[i + 1];
      if (h != 0.0) {
        for (var k = 0; k <= i; k++) {
          _d[k] = _v.get(k, i + 1) / h;
        }
        for (var j = 0; j <= i; j++) {
          var g = 0.0;
          for (var k = 0; k <= i; k++) {
            g += _v.get(k, i + 1) * _v.get(k, j);
          }
          for (var k = 0; k <= i; k++) {
            _v.set(k, j, _v.get(k, j) - g * _d[k]);
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

    var f = 0.0;
    var tst1 = 0.0;
    const eps = 2.220446049250313e-16;
    for (var l = 0; l < _n; l++) {
      tst1 = math.max(tst1, _d[l].abs() + _e[l].abs());
      var m = l;
      while (m < _n) {
        if (_e[m].abs() <= eps * tst1) break;
        m++;
      }
      if (m > l) {
        do {
          var g = _d[l];
          var p = (_d[l + 1] - g) / (2.0 * _e[l]);
          var r = _hypot(p, 1.0);
          if (p < 0) r = -r;
          _d[l] = _e[l] / (p + r);
          _d[l + 1] = _e[l] * (p + r);
          final dl1 = _d[l + 1];
          var h = g - _d[l];
          for (var i = l + 2; i < _n; i++) {
            _d[i] -= h;
          }
          f += h;

          p = _d[m];
          var c = 1.0;
          var c2 = c;
          var c3 = c;
          final el1 = _e[l + 1];
          var s = 0.0;
          var s2 = 0.0;
          for (var i = m - 1; i >= l; i--) {
            c3 = c2;
            c2 = c;
            s2 = s;
            g = c * _e[i];
            h = c * p;
            r = _hypot(p, _e[i]);
            _e[i + 1] = s * r;
            s = _e[i] / r;
            c = p / r;
            p = c * _d[i] - s * g;
            _d[i + 1] = h + s * (c * g + s * _d[i]);

            for (var k = 0; k < _n; k++) {
              h = _v.get(k, i + 1);
              _v.set(k, i + 1, s * _v.get(k, i) + c * h);
              _v.set(k, i, c * _v.get(k, i) - s * h);
            }
          }
          p = -s * s2 * c3 * el1 * _e[l] / dl1;
          _e[l] = s * p;
          _d[l] = c * p;
        } while (_e[l].abs() > eps * tst1);
      }
      _d[l] += f;
      _e[l] = 0.0;
    }

    for (var i = 0; i < _n - 1; i++) {
      var k = i;
      var p = _d[i];
      for (var j = i + 1; j < _n; j++) {
        if (_d[j] < p) {
          k = j;
          p = _d[j];
        }
      }
      if (k != i) {
        _d[k] = _d[i];
        _d[i] = p;
        for (var j = 0; j < _n; j++) {
          p = _v.get(j, i);
          _v.set(j, i, _v.get(j, k));
          _v.set(j, k, p);
        }
      }
    }
  }

  void _orthes() {
    final high = _n - 1;
    for (var m = 1; m <= high - 1; m++) {
      var scale = 0.0;
      for (var i = m; i <= high; i++) {
        scale += _h.get(i, m - 1).abs();
      }
      if (scale != 0.0) {
        var h = 0.0;
        for (var i = high; i >= m; i--) {
          _ort[i] = _h.get(i, m - 1) / scale;
          h += _ort[i] * _ort[i];
        }
        var g = math.sqrt(h);
        if (_ort[m] > 0) g = -g;
        h -= _ort[m] * g;
        _ort[m] -= g;

        for (var j = m; j < _n; j++) {
          var f = 0.0;
          for (var i = high; i >= m; i--) {
            f += _ort[i] * _h.get(i, j);
          }
          f /= h;
          for (var i = m; i <= high; i++) {
            _h.set(i, j, _h.get(i, j) - f * _ort[i]);
          }
        }
        for (var i = 0; i <= high; i++) {
          var f = 0.0;
          for (var j = high; j >= m; j--) {
            f += _ort[j] * _h.get(i, j);
          }
          f /= h;
          for (var j = m; j <= high; j++) {
            _h.set(i, j, _h.get(i, j) - f * _ort[j]);
          }
        }
        _ort[m] = scale * _ort[m];
        _h.set(m, m - 1, scale * g);
      }
    }

    for (var i = 0; i < _n; i++) {
      for (var j = 0; j < _n; j++) {
        _v.set(i, j, i == j ? 1.0 : 0.0);
      }
    }
    for (var m = high - 1; m >= 1; m--) {
      if (_h.get(m, m - 1) != 0.0) {
        for (var i = m + 1; i <= high; i++) {
          _ort[i] = _h.get(i, m - 1);
        }
        for (var j = m; j <= high; j++) {
          var g = 0.0;
          for (var i = m; i <= high; i++) {
            g += _ort[i] * _v.get(i, j);
          }
          g = (g / _ort[m]) / _h.get(m, m - 1);
          for (var i = m; i <= high; i++) {
            _v.set(i, j, _v.get(i, j) + g * _ort[i]);
          }
        }
      }
    }
  }

  void _cdiv(double xr, double xi, double yr, double yi) {
    if (yr.abs() > yi.abs()) {
      final r = yi / yr;
      final d = yr + r * yi;
      _cdivr = (xr + r * xi) / d;
      _cdivi = (xi - r * xr) / d;
    } else {
      final r = yr / yi;
      final d = yi + r * yr;
      _cdivr = (r * xr + xi) / d;
      _cdivi = (r * xi - xr) / d;
    }
  }

  void _hqr2() {
    final nn = _n;
    var n = nn - 1;
    const low = 0;
    final high = nn - 1;
    const eps = 2.220446049250313e-16;
    var exshift = 0.0;
    var p = 0.0,
        q = 0.0,
        r = 0.0,
        s = 0.0,
        z = 0.0,
        t = 0.0,
        w = 0.0,
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
    while (n >= low) {
      var l = n;
      while (l > low) {
        s = _h.get(l - 1, l - 1).abs() + _h.get(l, l).abs();
        if (s == 0.0) s = norm;
        if (_h.get(l, l - 1).abs() < eps * s) break;
        l--;
      }

      if (l == n) {
        _h.set(n, n, _h.get(n, n) + exshift);
        _d[n] = _h.get(n, n);
        _e[n] = 0.0;
        n--;
        iter = 0;
      } else if (l == n - 1) {
        w = _h.get(n, n - 1) * _h.get(n - 1, n);
        p = (_h.get(n - 1, n - 1) - _h.get(n, n)) / 2.0;
        q = p * p + w;
        z = math.sqrt(q.abs());
        _h.set(n, n, _h.get(n, n) + exshift);
        _h.set(n - 1, n - 1, _h.get(n - 1, n - 1) + exshift);
        x = _h.get(n, n);

        if (q >= 0) {
          z = p >= 0 ? p + z : p - z;
          _d[n - 1] = x + z;
          _d[n] = _d[n - 1];
          if (z != 0.0) _d[n] = x - w / z;
          _e[n - 1] = 0.0;
          _e[n] = 0.0;
          x = _h.get(n, n - 1);
          s = x.abs() + z.abs();
          p = x / s;
          q = z / s;
          r = math.sqrt(p * p + q * q);
          p /= r;
          q /= r;

          for (var j = n - 1; j < nn; j++) {
            z = _h.get(n - 1, j);
            _h.set(n - 1, j, q * z + p * _h.get(n, j));
            _h.set(n, j, q * _h.get(n, j) - p * z);
          }
          for (var i = 0; i <= n; i++) {
            z = _h.get(i, n - 1);
            _h.set(i, n - 1, q * z + p * _h.get(i, n));
            _h.set(i, n, q * _h.get(i, n) - p * z);
          }
          for (var i = low; i <= high; i++) {
            z = _v.get(i, n - 1);
            _v.set(i, n - 1, q * z + p * _v.get(i, n));
            _v.set(i, n, q * _v.get(i, n) - p * z);
          }
        } else {
          _d[n - 1] = x + p;
          _d[n] = x + p;
          _e[n - 1] = z;
          _e[n] = -z;
        }
        n -= 2;
        iter = 0;
      } else {
        x = _h.get(n, n);
        y = 0.0;
        w = 0.0;
        if (l < n) {
          y = _h.get(n - 1, n - 1);
          w = _h.get(n, n - 1) * _h.get(n - 1, n);
        }
        if (iter == 10) {
          exshift += x;
          for (var i = low; i <= n; i++) {
            _h.set(i, i, _h.get(i, i) - x);
          }
          s = _h.get(n, n - 1).abs() + _h.get(n - 1, n - 2).abs();
          x = y = 0.75 * s;
          w = -0.4375 * s * s;
        }
        if (iter == 30) {
          s = (y - x) / 2.0;
          s = s * s + w;
          if (s > 0) {
            s = math.sqrt(s);
            if (y < x) s = -s;
            s = x - w / ((y - x) / 2.0 + s);
            for (var i = low; i <= n; i++) {
              _h.set(i, i, _h.get(i, i) - s);
            }
            exshift += s;
            x = y = w = 0.964;
          }
        }
        iter++;
        var m = n - 2;
        while (m >= l) {
          z = _h.get(m, m);
          r = x - z;
          s = y - z;
          p = (r * s - w) / _h.get(m + 1, m) + _h.get(m, m + 1);
          q = _h.get(m + 1, m + 1) - z - r - s;
          r = _h.get(m + 2, m + 1);
          s = p.abs() + q.abs() + r.abs();
          p /= s;
          q /= s;
          r /= s;
          if (m == l) break;
          if (_h.get(m, m - 1).abs() * (q.abs() + r.abs()) <
              eps *
                  (p.abs() *
                      (_h.get(m - 1, m - 1).abs() +
                          z.abs() +
                          _h.get(m + 1, m + 1).abs()))) {
            break;
          }
          m--;
        }
        for (var i = m + 2; i <= n; i++) {
          _h.set(i, i - 2, 0.0);
          if (i > m + 2) _h.set(i, i - 3, 0.0);
        }
        for (var k = m; k <= n - 1; k++) {
          final notlast = k != n - 1;
          if (k != m) {
            p = _h.get(k, k - 1);
            q = _h.get(k + 1, k - 1);
            r = notlast ? _h.get(k + 2, k - 1) : 0.0;
            x = p.abs() + q.abs() + r.abs();
            if (x == 0.0) continue;
            p /= x;
            q /= x;
            r /= x;
          }
          s = math.sqrt(p * p + q * q + r * r);
          if (p < 0) s = -s;
          if (s != 0) {
            if (k != m) {
              _h.set(k, k - 1, -s * x);
            } else if (l != m) {
              _h.set(k, k - 1, -_h.get(k, k - 1));
            }
            p += s;
            x = p / s;
            y = q / s;
            z = r / s;
            q /= p;
            r /= p;
            for (var j = k; j < nn; j++) {
              p = _h.get(k, j) + q * _h.get(k + 1, j);
              if (notlast) {
                p += r * _h.get(k + 2, j);
                _h.set(k + 2, j, _h.get(k + 2, j) - p * z);
              }
              _h.set(k, j, _h.get(k, j) - p * x);
              _h.set(k + 1, j, _h.get(k + 1, j) - p * y);
            }
            for (var i = 0; i <= math.min(n, k + 3); i++) {
              p = x * _h.get(i, k) + y * _h.get(i, k + 1);
              if (notlast) {
                p += z * _h.get(i, k + 2);
                _h.set(i, k + 2, _h.get(i, k + 2) - p * r);
              }
              _h.set(i, k, _h.get(i, k) - p);
              _h.set(i, k + 1, _h.get(i, k + 1) - p * q);
            }
            for (var i = low; i <= high; i++) {
              p = x * _v.get(i, k) + y * _v.get(i, k + 1);
              if (notlast) {
                p += z * _v.get(i, k + 2);
                _v.set(i, k + 2, _v.get(i, k + 2) - p * r);
              }
              _v.set(i, k, _v.get(i, k) - p);
              _v.set(i, k + 1, _v.get(i, k + 1) - p * q);
            }
          }
        }
      }
    }

    if (norm == 0.0) return;

    for (n = nn - 1; n >= 0; n--) {
      p = _d[n];
      q = _e[n];
      if (q == 0) {
        var l = n;
        _h.set(n, n, 1.0);
        for (var i = n - 1; i >= 0; i--) {
          w = _h.get(i, i) - p;
          r = 0.0;
          for (var j = l; j <= n; j++) {
            r += _h.get(i, j) * _h.get(j, n);
          }
          if (_e[i] < 0.0) {
            z = w;
            s = r;
          } else {
            l = i;
            if (_e[i] == 0.0) {
              _h.set(i, n, w != 0.0 ? -r / w : -r / (eps * norm));
            } else {
              x = _h.get(i, i + 1);
              y = _h.get(i + 1, i);
              q = (_d[i] - p) * (_d[i] - p) + _e[i] * _e[i];
              t = (x * s - z * r) / q;
              _h.set(i, n, t);
              if (x.abs() > z.abs()) {
                _h.set(i + 1, n, (-r - w * t) / x);
              } else {
                _h.set(i + 1, n, (-s - y * t) / z);
              }
            }
            t = _h.get(i, n).abs();
            if ((eps * t) * t > 1) {
              for (var j = i; j <= n; j++) {
                _h.set(j, n, _h.get(j, n) / t);
              }
            }
          }
        }
      } else if (q < 0) {
        var l = n - 1;
        if (_h.get(n, n - 1).abs() > _h.get(n - 1, n).abs()) {
          _h.set(n - 1, n - 1, q / _h.get(n, n - 1));
          _h.set(n - 1, n, -(_h.get(n, n) - p) / _h.get(n, n - 1));
        } else {
          _cdiv(0, -_h.get(n - 1, n), _h.get(n - 1, n - 1) - p, q);
          _h.set(n - 1, n - 1, _cdivr);
          _h.set(n - 1, n, _cdivi);
        }
        _h.set(n, n - 1, 0.0);
        _h.set(n, n, 1.0);
        for (var i = n - 2; i >= 0; i--) {
          var ra = 0.0, sa = 0.0;
          for (var j = l; j <= n; j++) {
            ra += _h.get(i, j) * _h.get(j, n - 1);
            sa += _h.get(i, j) * _h.get(j, n);
          }
          w = _h.get(i, i) - p;
          if (_e[i] < 0.0) {
            z = w;
            r = ra;
            s = sa;
          } else {
            l = i;
            if (_e[i] == 0) {
              _cdiv(-ra, -sa, w, q);
              _h.set(i, n - 1, _cdivr);
              _h.set(i, n, _cdivi);
            } else {
              x = _h.get(i, i + 1);
              y = _h.get(i + 1, i);
              var vr = (_d[i] - p) * (_d[i] - p) + _e[i] * _e[i] - q * q;
              final vi = (_d[i] - p) * 2.0 * q;
              if (vr == 0.0 && vi == 0.0) {
                vr =
                    eps *
                    norm *
                    (w.abs() + q.abs() + x.abs() + y.abs() + z.abs());
              }
              _cdiv(x * r - z * ra + q * sa, x * s - z * sa - q * ra, vr, vi);
              _h.set(i, n - 1, _cdivr);
              _h.set(i, n, _cdivi);
              if (x.abs() > (z.abs() + q.abs())) {
                _h.set(
                  i + 1,
                  n - 1,
                  (-ra - w * _h.get(i, n - 1) + q * _h.get(i, n)) / x,
                );
                _h.set(
                  i + 1,
                  n,
                  (-sa - w * _h.get(i, n) - q * _h.get(i, n - 1)) / x,
                );
              } else {
                _cdiv(-r - y * _h.get(i, n - 1), -s - y * _h.get(i, n), z, q);
                _h.set(i + 1, n - 1, _cdivr);
                _h.set(i + 1, n, _cdivi);
              }
            }
            t = math.max(_h.get(i, n - 1).abs(), _h.get(i, n).abs());
            if ((eps * t) * t > 1) {
              for (var j = i; j <= n; j++) {
                _h.set(j, n - 1, _h.get(j, n - 1) / t);
                _h.set(j, n, _h.get(j, n) / t);
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
    final n = a.rowCount;
    for (var i = 0; i < n; i++) {
      for (var j = i + 1; j < n; j++) {
        if (a.get(i, j) != a.get(j, i)) return false;
      }
    }
    return true;
  }
}
