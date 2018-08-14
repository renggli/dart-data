library matrix.decomposition.eigen;

import 'dart:math' as math;

import '../matrix.dart';
import '../utils.dart';

/// Eigenvalues and eigenvectors of a real matrix.
///
/// If A is symmetric, then A = V*D*V' where the eigenvalue matrix D is
/// diagonal and the eigenvector matrix V is orthogonal.
/// I.e. A = V.times(D.times(V.transpose())) and
/// V.times(V.transpose()) equals the identity matrix.
///
/// If A is not symmetric, then the eigenvalue matrix D is block diagonal
/// with the real eigenvalues in 1-by-1 blocks and any complex eigenvalues,
/// lambda + i*mu, in 2-by-2 blocks, [lambda, mu; -mu, lambda].  The
/// columns of V represent the eigenvectors in the sense that A*V = V*D,
/// i.e. A.times(V) equals V.times(D).  The matrix V may be badly
/// conditioned, or even singular, so the validity of the equation
/// A = V*D*inverse(V) depends upon V.cond().
class EigenvalueDecomposition {
  /// Row and column dimension (square matrix).
  final int _n;

  /// Symmetry flag.
  bool _isSymmetric;

  /// Arrays for internal storage of eigenvalues.
  final List<double> _d, _e;

  /// Array for internal storage of eigenvectors.
  final Matrix<double> _V;

  /// Array for internal storage of nonsymmetric Hessenberg form.
  final Matrix<double> _H;

  /// Working storage for nonsymmetric algorithm.
  final List<double> _ort;

  /// Check for symmetry, then construct the eigenvalue decomposition
  //  Structure to access D and V.
  EigenvalueDecomposition(Matrix<num> A)
      : _n = A.colCount,
        _isSymmetric = true,
        _d = valueDataType.newList(A.colCount),
        _e = valueDataType.newList(A.colCount),
        _V = Matrix.builder.rowMajor.withType(valueDataType)(
            A.colCount, A.colCount),
        _H = Matrix.builder.rowMajor.withType(valueDataType)(
            A.colCount, A.colCount),
        _ort = null {
    _isSymmetric = true;
    for (var j = 0; (j < _n) && _isSymmetric; j++) {
      for (var i = 0; (i < _n) && _isSymmetric; i++) {
        _isSymmetric = A.getUnchecked(i, j) == A.getUnchecked(j, i);
      }
    }

    if (_isSymmetric) {
      for (var i = 0; i < _n; i++) {
        for (var j = 0; j < _n; j++) {
          _V.setUnchecked(i, j, A.getUnchecked(i, j));
        }
      }
      // Tridiagonalize.
      _tred2();
      // Diagonalize.
      _tql2();
    } else {
      for (var j = 0; j < _n; j++) {
        for (var i = 0; i < _n; i++) {
          _H.setUnchecked(i, j, A.getUnchecked(i, j));
        }
      }
      // Reduce to Hessenberg form.
      _orthes();
      // Reduce Hessenberg to real Schur form.
      _hqr2();
    }
  }

  // Symmetric Householder reduction to tridiagonal form.
  void _tred2() {
    //  This is derived from the Algol procedures tred2 by
    //  Bowdler, Martin, Reinsch, and Wilkinson, Handbook for
    //  Auto. Comp., Vol.ii-Linear Algebra, and the corresponding
    //  Fortran subroutine in EISPACK.

    for (var j = 0; j < _n; j++) {
      _d[j] = _V.getUnchecked(_n - 1, j);
    }

    // Householder reduction to tridiagonal form.

    for (var i = _n - 1; i > 0; i--) {
      // Scale to avoid under/overflow.

      var scale = 0.0;
      var h = 0.0;
      for (var k = 0; k < i; k++) {
        scale = scale + _d[k].abs();
      }
      if (scale == 0.0) {
        _e[i] = _d[i - 1];
        for (var j = 0; j < i; j++) {
          _d[j] = _V.getUnchecked(i - 1, j);
          _V.setUnchecked(i, j, 0.0);
          _V.setUnchecked(j, i, 0.0);
        }
      } else {
        // Generate Householder vector.

        for (var k = 0; k < i; k++) {
          _d[k] /= scale;
          h += _d[k] * _d[k];
        }
        var f = _d[i - 1];
        var g = math.sqrt(h);
        if (f > 0) {
          g = -g;
        }
        _e[i] = scale * g;
        h = h - f * g;
        _d[i - 1] = f - g;
        for (var j = 0; j < i; j++) {
          _e[j] = 0.0;
        }

        // Apply similarity transformation to remaining columns.

        for (var j = 0; j < i; j++) {
          f = _d[j];
          _V.setUnchecked(j, i, f);
          g = _e[j] + _V.getUnchecked(j, j) * f;
          for (var k = j + 1; k <= i - 1; k++) {
            g += _V.getUnchecked(k, j) * _d[k];
            _e[k] += _V.getUnchecked(k, j) * f;
          }
          _e[j] = g;
        }
        f = 0.0;
        for (var j = 0; j < i; j++) {
          _e[j] /= h;
          f += _e[j] * _d[j];
        }
        var hh = f / (h + h);
        for (var j = 0; j < i; j++) {
          _e[j] -= hh * _d[j];
        }
        for (var j = 0; j < i; j++) {
          f = _d[j];
          g = _e[j];
          for (var k = j; k <= i - 1; k++) {
            _V.setUnchecked(
                k, j, _V.getUnchecked(k, j) - (f * _e[k] + g * _d[k]));
          }
          _d[j] = _V.getUnchecked(i - 1, j);
          _V.setUnchecked(i, j, 0.0);
        }
      }
      _d[i] = h;
    }

    // Accumulate transformations.

    for (var i = 0; i < _n - 1; i++) {
      _V.setUnchecked(_n - 1, i, _V.getUnchecked(i, i));
      _V.setUnchecked(i, i, 1.0);
      var h = _d[i + 1];
      if (h != 0.0) {
        for (var k = 0; k <= i; k++) {
          _d[k] = _V.getUnchecked(k, i + 1) / h;
        }
        for (var j = 0; j <= i; j++) {
          var g = 0.0;
          for (var k = 0; k <= i; k++) {
            g += _V.getUnchecked(k, i + 1) * _V.getUnchecked(k, j);
          }
          for (var k = 0; k <= i; k++) {
            _V.setUnchecked(k, j, _V.getUnchecked(k, j) - g * _d[k]);
          }
        }
      }
      for (var k = 0; k <= i; k++) {
        _V.setUnchecked(k, i + 1, 0.0);
      }
    }
    for (var j = 0; j < _n; j++) {
      _d[j] = _V.getUnchecked(_n - 1, j);
      _V.setUnchecked(_n - 1, j, 0.0);
    }
    _V.setUnchecked(_n - 1, _n - 1, 1.0);
    _e[0] = 0.0;
  }

  // Symmetric tridiagonal QL algorithm.

  void _tql2() {
    //  This is derived from the Algol procedures tql2, by
    //  Bowdler, Martin, Reinsch, and Wilkinson, Handbook for
    //  Auto. Comp., Vol.ii-Linear Algebra, and the corresponding
    //  Fortran subroutine in EISPACK.

    for (var i = 1; i < _n; i++) {
      _e[i - 1] = _e[i];
    }
    _e[_n - 1] = 0.0;

    var f = 0.0;
    var tst1 = 0.0;
    var eps = math.pow(2.0, -52.0);
    for (var l = 0; l < _n; l++) {
      // Find small subdiagonal element

      tst1 = math.max(tst1, _d[l].abs() + _e[l].abs());
      var m = l;
      while (m < _n) {
        if (_e[m].abs() <= eps * tst1) {
          break;
        }
        m++;
      }

      // If m == l, d[l] is an eigenvalue,
      // otherwise, iterate.

      if (m > l) {
        var iter = 0;
        do {
          iter = iter + 1; // (Could check iteration count here.)

          // Compute implicit shift

          var g = _d[l];
          var p = (_d[l + 1] - g) / (2.0 * _e[l]);
          var r = hypot(p, 1.0);
          if (p < 0) {
            r = -r;
          }
          _d[l] = _e[l] / (p + r);
          _d[l + 1] = _e[l] * (p + r);
          var dl1 = _d[l + 1];
          var h = g - _d[l];
          for (var i = l + 2; i < _n; i++) {
            _d[i] -= h;
          }
          f = f + h;

          // Implicit QL transformation.

          p = _d[m];
          var c = 1.0;
          var c2 = c;
          var c3 = c;
          var el1 = _e[l + 1];
          var s = 0.0;
          var s2 = 0.0;
          for (var i = m - 1; i >= l; i--) {
            c3 = c2;
            c2 = c;
            s2 = s;
            g = c * _e[i];
            h = c * p;
            r = hypot(p, _e[i]);
            _e[i + 1] = s * r;
            s = _e[i] / r;
            c = p / r;
            p = c * _d[i] - s * g;
            _d[i + 1] = h + s * (c * g + s * _d[i]);

            // Accumulate transformation.

            for (var k = 0; k < _n; k++) {
              h = _V.getUnchecked(k, i + 1);
              _V.setUnchecked(k, i + 1, s * _V.getUnchecked(k, i) + c * h);
              _V.setUnchecked(k, i, c * _V.getUnchecked(k, i) - s * h);
            }
          }
          p = -s * s2 * c3 * el1 * _e[l] / dl1;
          _e[l] = s * p;
          _d[l] = c * p;

          // Check for convergence.

        } while (_e[l].abs() > eps * tst1);
      }
      _d[l] = _d[l] + f;
      _e[l] = 0.0;
    }

    // Sort eigenvalues and corresponding vectors.

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
          p = _V.getUnchecked(j, i);
          _V.setUnchecked(j, i, _V.getUnchecked(j, k));
          _V.setUnchecked(j, k, p);
        }
      }
    }
  }

  // Nonsymmetric reduction to Hessenberg form.

  void _orthes() {
    //  This is derived from the Algol procedures orthes and ortran,
    //  by Martin and Wilkinson, Handbook for Auto. Comp.,
    //  Vol.ii-Linear Algebra, and the corresponding
    //  Fortran subroutines in EISPACK.

    var low = 0;
    var high = _n - 1;

    for (var m = low + 1; m <= high - 1; m++) {
      // Scale column.

      var scale = 0.0;
      for (var i = m; i <= high; i++) {
        scale = scale + _H.getUnchecked(i, m - 1).abs();
      }
      if (scale != 0.0) {
        // Compute Householder transformation.

        var h = 0.0;
        for (var i = high; i >= m; i--) {
          _ort[i] = _H.getUnchecked(i, m - 1) / scale;
          h += _ort[i] * _ort[i];
        }
        var g = math.sqrt(h);
        if (_ort[m] > 0) {
          g = -g;
        }
        h = h - _ort[m] * g;
        _ort[m] = _ort[m] - g;

        // Apply Householder similarity transformation
        // H = (I-u*u'/h)*H*(I-u*u')/h)

        for (var j = m; j < _n; j++) {
          var f = 0.0;
          for (var i = high; i >= m; i--) {
            f += _ort[i] * _H.getUnchecked(i, j);
          }
          f = f / h;
          for (var i = m; i <= high; i++) {
            _H.setUnchecked(i, j, _H.getUnchecked(i, j) - f * _ort[i]);
          }
        }

        for (var i = 0; i <= high; i++) {
          var f = 0.0;
          for (var j = high; j >= m; j--) {
            f += _ort[j] * _H.getUnchecked(i, j);
          }
          f = f / h;
          for (var j = m; j <= high; j++) {
            _H.setUnchecked(i, j, _H.getUnchecked(i, j) - f * _ort[j]);
          }
        }
        _ort[m] = scale * _ort[m];
        _H.setUnchecked(m, m - 1, scale * g);
      }
    }

    // Accumulate transformations (Algol's ortran).

    for (var i = 0; i < _n; i++) {
      for (var j = 0; j < _n; j++) {
        _V.setUnchecked(i, j, i == j ? 1.0 : 0.0);
      }
    }

    for (var m = high - 1; m >= low + 1; m--) {
      if (_H.getUnchecked(m, m - 1) != 0.0) {
        for (var i = m + 1; i <= high; i++) {
          _ort[i] = _H.getUnchecked(i, m - 1);
        }
        for (var j = m; j <= high; j++) {
          var g = 0.0;
          for (var i = m; i <= high; i++) {
            g += _ort[i] * _V.getUnchecked(i, j);
          }
          // Double division avoids possible underflow
          g = (g / _ort[m]) / _H.getUnchecked(m, m - 1);
          for (var i = m; i <= high; i++) {
            _V.setUnchecked(i, j, _V.getUnchecked(i, j) + g * _ort[i]);
          }
        }
      }
    }
  }

  // Complex scalar division.
  double cdivr, cdivi;

  void _cdiv(double xr, double xi, double yr, double yi) {
    var r, d;
    if (yr.abs() > yi.abs()) {
      r = yi / yr;
      d = yr + r * yi;
      cdivr = (xr + r * xi) / d;
      cdivi = (xi - r * xr) / d;
    } else {
      r = yr / yi;
      d = yi + r * yr;
      cdivr = (r * xr + xi) / d;
      cdivi = (r * xi - xr) / d;
    }
  }

  // Nonsymmetric reduction from Hessenberg to real Schur form.

  void _hqr2() {
    //  This is derived from the Algol procedure hqr2,
    //  by Martin and Wilkinson, Handbook for Auto. Comp.,
    //  Vol.ii-Linear Algebra, and the corresponding
    //  Fortran subroutine in EISPACK.

    // Initialize

    var nn = this._n;
    var n = nn - 1;
    var low = 0;
    var high = nn - 1;
    var eps = math.pow(2.0, -52.0);
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

    // Store roots isolated by balanc and compute matrix norm

    var norm = 0.0;
    for (var i = 0; i < nn; i++) {
      if (i < low || i > high) {
        _d[i] = _H.getUnchecked(i, i);
        _e[i] = 0.0;
      }
      for (var j = math.max(i - 1, 0); j < nn; j++) {
        norm = norm + _H.getUnchecked(i, j).abs();
      }
    }

    // Outer loop over eigenvalue index

    var iter = 0;
    while (n >= low) {
      // Look for single small sub-diagonal element

      var l = n;
      while (l > low) {
        s = _H.getUnchecked(l - 1, l - 1).abs() + _H.getUnchecked(l, l).abs();
        if (s == 0.0) {
          s = norm;
        }
        if (_H.getUnchecked(l, l - 1).abs() < eps * s) {
          break;
        }
        l--;
      }

      // Check for convergence
      // One root found

      if (l == n) {
        _H.setUnchecked(n, n, _H.getUnchecked(n, n) + exshift);
        _d[n] = _H.getUnchecked(n, n);
        _e[n] = 0.0;
        n--;
        iter = 0;

        // Two roots found

      } else if (l == n - 1) {
        w = _H.getUnchecked(n, n - 1) * _H.getUnchecked(n - 1, n);
        p = (_H.getUnchecked(n - 1, n - 1) - _H.getUnchecked(n, n)) / 2.0;
        q = p * p + w;
        z = math.sqrt(q.abs());
        _H.setUnchecked(n, n, _H.getUnchecked(n, n) + exshift);
        _H.setUnchecked(n - 1, n - 1, _H.getUnchecked(n - 1, n - 1) + exshift);
        x = _H.getUnchecked(n, n);

        // Real pair

        if (q >= 0) {
          if (p >= 0) {
            z = p + z;
          } else {
            z = p - z;
          }
          _d[n - 1] = x + z;
          _d[n] = _d[n - 1];
          if (z != 0.0) {
            _d[n] = x - w / z;
          }
          _e[n - 1] = 0.0;
          _e[n] = 0.0;
          x = _H.getUnchecked(n, n - 1);
          s = x.abs() + z.abs();
          p = x / s;
          q = z / s;
          r = math.sqrt(p * p + q * q);
          p = p / r;
          q = q / r;

          // Row modification

          for (var j = n - 1; j < nn; j++) {
            z = _H.getUnchecked(n - 1, j);
            _H.setUnchecked(n - 1, j, q * z + p * _H.getUnchecked(n, j));
            _H.setUnchecked(n, j, q * _H.getUnchecked(n, j) - p * z);
          }

          // Column modification

          for (var i = 0; i <= n; i++) {
            z = _H.getUnchecked(i, n - 1);
            _H.setUnchecked(i, n - 1, q * z + p * _H.getUnchecked(i, n));
            _H.setUnchecked(i, n, q * _H.getUnchecked(i, n) - p * z);
          }

          // Accumulate transformations

          for (var i = low; i <= high; i++) {
            z = _V.getUnchecked(i, n - 1);
            _V.setUnchecked(i, n - 1, q * z + p * _V.getUnchecked(i, n));
            _V.setUnchecked(i, n, q * _V.getUnchecked(i, n) - p * z);
          }

          // Complex pair

        } else {
          _d[n - 1] = x + p;
          _d[n] = x + p;
          _e[n - 1] = z;
          _e[n] = -z;
        }
        n = n - 2;
        iter = 0;

        // No convergence yet

      } else {
        // Form shift

        x = _H.getUnchecked(n, n);
        y = 0.0;
        w = 0.0;
        if (l < n) {
          y = _H.getUnchecked(n - 1, n - 1);
          w = _H.getUnchecked(n, n - 1) * _H.getUnchecked(n - 1, n);
        }

        // Wilkinson's original ad hoc shift

        if (iter == 10) {
          exshift += x;
          for (var i = low; i <= n; i++) {
            _H.setUnchecked(i, i, _H.getUnchecked(i, i) - x);
          }
          s = _H.getUnchecked(n, n - 1).abs() +
              _H.getUnchecked(n - 1, n - 2).abs();
          x = y = 0.75 * s;
          w = -0.4375 * s * s;
        }

        // MATLAB's new ad hoc shift

        if (iter == 30) {
          s = (y - x) / 2.0;
          s = s * s + w;
          if (s > 0) {
            s = math.sqrt(s);
            if (y < x) {
              s = -s;
            }
            s = x - w / ((y - x) / 2.0 + s);
            for (var i = low; i <= n; i++) {
              _H.setUnchecked(i, i, _H.getUnchecked(i, i) - s);
            }
            exshift += s;
            x = y = w = 0.964;
          }
        }

        iter = iter + 1; // (Could check iteration count here.)

        // Look for two consecutive small sub-diagonal elements

        var m = n - 2;
        while (m >= l) {
          z = _H.getUnchecked(m, m);
          r = x - z;
          s = y - z;
          p = (r * s - w) / _H.getUnchecked(m + 1, m) + _H.getUnchecked(m, m + 1);
          q = _H.getUnchecked(m + 1, m + 1) - z - r - s;
          r = _H.getUnchecked(m + 2, m + 1);
          s = p.abs() + q.abs() + r.abs();
          p = p / s;
          q = q / s;
          r = r / s;
          if (m == l) {
            break;
          }
          if (_H.getUnchecked(m, m - 1).abs() * (q.abs() + r.abs()) <
              eps *
                  (p.abs() *
                      (_H.getUnchecked(m - 1, m - 1).abs() +
                          z.abs() +
                          _H.getUnchecked(m + 1, m + 1).abs()))) {
            break;
          }
          m--;
        }

        for (var i = m + 2; i <= n; i++) {
          _H.setUnchecked(i, i - 2, 0.0);
          if (i > m + 2) {
            _H.setUnchecked(i, i - 3, 0.0);
          }
        }

        // Double QR step involving rows l:n and columns m:n

        for (var k = m; k <= n - 1; k++) {
          final notlast = (k != n - 1);
          if (k != m) {
            p = _H.getUnchecked(k, k - 1);
            q = _H.getUnchecked(k + 1, k - 1);
            r = (notlast ? _H.getUnchecked(k + 2, k - 1) : 0.0);
            x = p.abs() + q.abs() + r.abs();
            if (x == 0.0) {
              continue;
            }
            p = p / x;
            q = q / x;
            r = r / x;
          }

          s = math.sqrt(p * p + q * q + r * r);
          if (p < 0) {
            s = -s;
          }
          if (s != 0) {
            if (k != m) {
              _H.setUnchecked(k, k - 1, -s * x);
            } else if (l != m) {
              _H.setUnchecked(k, k - 1, -_H.getUnchecked(k, k - 1));
            }
            p = p + s;
            x = p / s;
            y = q / s;
            z = r / s;
            q = q / p;
            r = r / p;

            // Row modification

            for (var j = k; j < nn; j++) {
              p = _H.getUnchecked(k, j) + q * _H.getUnchecked(k + 1, j);
              if (notlast) {
                p = p + r * _H.getUnchecked(k + 2, j);
                _H.setUnchecked(k + 2, j, _H.getUnchecked(k + 2, j) - p * z);
              }
              _H.setUnchecked(k, j, _H.getUnchecked(k, j) - p * x);
              _H.setUnchecked(k + 1, j, _H.getUnchecked(k + 1, j) - p * y);
            }

            // Column modification

            for (var i = 0; i <= math.min(n, k + 3); i++) {
              p = x * _H.getUnchecked(i, k) + y * _H.getUnchecked(i, k + 1);
              if (notlast) {
                p = p + z * _H.getUnchecked(i, k + 2);
                _H.setUnchecked(i, k + 2, _H.getUnchecked(i, k + 2) - p * r);
              }
              _H.setUnchecked(i, k, _H.getUnchecked(i, k) - p);
              _H.setUnchecked(i, k + 1, _H.getUnchecked(i, k + 1) - p * q);
            }

            // Accumulate transformations

            for (var i = low; i <= high; i++) {
              p = x * _V.getUnchecked(i, k) + y * _V.getUnchecked(i, k + 1);
              if (notlast) {
                p = p + z * _V.getUnchecked(i, k + 2);
                _V.setUnchecked(i, k + 2, _V.getUnchecked(i, k + 2) - p * r);
              }
              _V.setUnchecked(i, k, _V.getUnchecked(i, k) - p);
              _V.setUnchecked(i, k + 1, _V.getUnchecked(i, k + 1) - p * q);
            }
          } // (s != 0)
        } // k loop
      } // check convergence
    } // while (n >= low)

    // Backsubstitute to find vectors of upper triangular form

    if (norm == 0.0) {
      return;
    }

    for (n = nn - 1; n >= 0; n--) {
      p = _d[n];
      q = _e[n];

      // Real vector

      if (q == 0) {
        var l = n;
        _H.setUnchecked(n, n, 1.0);
        for (var i = n - 1; i >= 0; i--) {
          w = _H.getUnchecked(i, i) - p;
          r = 0.0;
          for (var j = l; j <= n; j++) {
            r = r + _H.getUnchecked(i, j) * _H.getUnchecked(j, n);
          }
          if (_e[i] < 0.0) {
            z = w;
            s = r;
          } else {
            l = i;
            if (_e[i] == 0.0) {
              if (w != 0.0) {
                _H.setUnchecked(i, n, -r / w);
              } else {
                _H.setUnchecked(i, n, -r / (eps * norm));
              }

              // Solve real equations

            } else {
              x = _H.getUnchecked(i, i + 1);
              y = _H.getUnchecked(i + 1, i);
              q = (_d[i] - p) * (_d[i] - p) + _e[i] * _e[i];
              t = (x * s - z * r) / q;
              _H.setUnchecked(i, n, t);
              if (x.abs() > z.abs()) {
                _H.setUnchecked(i + 1, n, (-r - w * t) / x);
              } else {
                _H.setUnchecked(i + 1, n, (-s - y * t) / z);
              }
            }

            // Overflow control

            t = _H.getUnchecked(i, n).abs();
            if ((eps * t) * t > 1) {
              for (var j = i; j <= n; j++) {
                _H.setUnchecked(j, n, _H.getUnchecked(j, n) / t);
              }
            }
          }
        }

        // Complex vector

      } else if (q < 0) {
        var l = n - 1;

        // Last vector component imaginary so matrix is triangular

        if (_H.getUnchecked(n, n - 1).abs() > _H.getUnchecked(n - 1, n).abs()) {
          _H.setUnchecked(n - 1, n - 1, q / _H.getUnchecked(n, n - 1));
          _H.setUnchecked(
              n - 1, n, -(_H.getUnchecked(n, n) - p) / _H.getUnchecked(n, n - 1));
        } else {
          _cdiv(0.0, -_H.getUnchecked(n - 1, n),
              _H.getUnchecked(n - 1, n - 1) - p, q);
          _H.setUnchecked(n - 1, n - 1, cdivr);
          _H.setUnchecked(n - 1, n, cdivi);
        }
        _H.setUnchecked(n, n - 1, 0.0);
        _H.setUnchecked(n, n, 1.0);
        for (var i = n - 2; i >= 0; i--) {
          var ra, sa, vr, vi;
          ra = 0.0;
          sa = 0.0;
          for (var j = l; j <= n; j++) {
            ra = ra + _H.getUnchecked(i, j) * _H.getUnchecked(j, n - 1);
            sa = sa + _H.getUnchecked(i, j) * _H.getUnchecked(j, n);
          }
          w = _H.getUnchecked(i, i) - p;

          if (_e[i] < 0.0) {
            z = w;
            r = ra;
            s = sa;
          } else {
            l = i;
            if (_e[i] == 0) {
              _cdiv(-ra, -sa, w, q);
              _H.setUnchecked(i, n - 1, cdivr);
              _H.setUnchecked(i, n, cdivi);
            } else {
              // Solve complex equations

              x = _H.getUnchecked(i, i + 1);
              y = _H.getUnchecked(i + 1, i);
              vr = (_d[i] - p) * (_d[i] - p) + _e[i] * _e[i] - q * q;
              vi = (_d[i] - p) * 2.0 * q;
              if (vr == 0.0 && vi == 0.0) {
                vr = eps *
                    norm *
                    (w.abs() + q.abs() + x.abs() + y.abs() + z.abs());
              }
              _cdiv(x * r - z * ra + q * sa, x * s - z * sa - q * ra, vr, vi);
              _H.setUnchecked(i, n - 1, cdivr);
              _H.setUnchecked(i, n, cdivi);
              if (x.abs() > (z.abs() + q.abs())) {
                _H.setUnchecked(
                    i + 1,
                    n - 1,
                    (-ra -
                            w * _H.getUnchecked(i, n - 1) +
                            q * _H.getUnchecked(i, n)) /
                        x);
                _H.setUnchecked(
                    i + 1,
                    n,
                    (-sa -
                            w * _H.getUnchecked(i, n) -
                            q * _H.getUnchecked(i, n - 1)) /
                        x);
              } else {
                _cdiv(-r - y * _H.getUnchecked(i, n - 1),
                    -s - y * _H.getUnchecked(i, n), z, q);
                _H.setUnchecked(i + 1, n - 1, cdivr);
                _H.setUnchecked(i + 1, n, cdivi);
              }
            }

            // Overflow control

            t = math.max(
                _H.getUnchecked(i, n - 1).abs(), _H.getUnchecked(i, n).abs());
            if ((eps * t) * t > 1) {
              for (var j = i; j <= n; j++) {
                _H.setUnchecked(j, n - 1, _H.getUnchecked(j, n - 1) / t);
                _H.setUnchecked(j, n, _H.getUnchecked(j, n) / t);
              }
            }
          }
        }
      }
    }

    // Vectors of isolated roots

    for (var i = 0; i < nn; i++) {
      if (i < low || i > high) {
        for (var j = i; j < nn; j++) {
          _V.setUnchecked(i, j, _H.getUnchecked(i, j));
        }
      }
    }

    // Back transformation to get eigenvectors of original matrix

    for (var j = nn - 1; j >= low; j--) {
      for (var i = low; i <= high; i++) {
        z = 0.0;
        for (var k = low; k <= math.min(j, high); k++) {
          z = z + _V.getUnchecked(i, k) * _H.getUnchecked(k, j);
        }
        _V.setUnchecked(i, j, z);
      }
    }
  }

  /// Return the eigenvector matrix
  Matrix<double> get V => _V;

  /// Return the block diagonal eigenvalue matrix
  Matrix<double> get D {
    final result = Matrix.builder.diagonal.withType(valueDataType)(_n, _n);
    for (var i = 0; i < _n; i++) {
      D.setUnchecked(i, i, _d[i]);
      if (_e[i] > 0) {
        D.setUnchecked(i, i + 1, _e[i]);
      } else if (_e[i] < 0) {
        D.setUnchecked(i, i - 1, _e[i]);
      }
    }
    return result;
  }

  /// Return the real parts of the eigenvalues.
  List<double> get realEigenvalues => _d;

  /// Return the imaginary parts of the eigenvalues.
  List<double> get imagEigenvalues => _e;
}
