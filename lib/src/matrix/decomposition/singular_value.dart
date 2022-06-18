import 'dart:math' as math;

import '../../../type.dart';

import '../../shared/math.dart';
import '../matrix.dart';
import '../matrix_format.dart';
import '../view/cast_matrix.dart';

/// Singular Value Decomposition.
///
/// For an m-by-n matrix A with m >= n, the singular value decomposition is
/// an m-by-n orthogonal matrix U, an n-by-n diagonal matrix S, and
/// an n-by-n orthogonal matrix V so that A = U*S*V'.
///
/// The singular values, sigma(k) = S.getUnchecked(k, k), are ordered so that
/// sigma[0] >= sigma[1] >= ... >= sigma[n-1].
///
/// The singular value decomposition always exists, so the constructor will
/// never fail.  The matrix condition number and the effective numerical
/// rank can be computed from this decomposition.
class SingularValueDecomposition {
  /// Construct the singular value decomposition Structure to access U, S and V.
  SingularValueDecomposition(Matrix<num> input)
      : _u = Matrix(DataType.float, input.rowCount,
            math.min(input.rowCount, input.columnCount)),
        _v = Matrix(DataType.float, input.columnCount, input.columnCount),
        _s = DataType.float
            .newList(math.min(input.rowCount + 1, input.columnCount)),
        _m = input.rowCount,
        _n = input.columnCount {
    // Initialize.
    final A = input.cast(DataType.float).toMatrix();
    final e = DataType.float.newList(_n);
    final work = DataType.float.newList(_m);

    // Reduce A to bi-diagonal form, storing the diagonal elements
    // in s and the super-diagonal elements in e.
    final nct = math.min(_m - 1, _n);
    final nrt = math.max(0, math.min(_n - 2, _m));
    for (var k = 0; k < math.max(nct, nrt); k++) {
      if (k < nct) {
        // Compute the transformation for the k-th column and
        // place the k-th diagonal in s[k].
        // Compute 2-norm of k-th column without under/overflow.
        _s[k] = 0.0;
        for (var i = k; i < _m; i++) {
          _s[k] = hypot(_s[k], A.getUnchecked(i, k));
        }
        if (_s[k] != 0.0) {
          if (A.getUnchecked(k, k) < 0.0) {
            _s[k] = -_s[k];
          }
          for (var i = k; i < _m; i++) {
            A.setUnchecked(i, k, A.getUnchecked(i, k) / _s[k]);
          }
          A.setUnchecked(k, k, A.getUnchecked(k, k) + 1.0);
        }
        _s[k] = -_s[k];
      }
      for (var j = k + 1; j < _n; j++) {
        if ((k < nct) && (_s[k] != 0.0)) {
          // Apply the transformation.
          var t = 0.0;
          for (var i = k; i < _m; i++) {
            t += A.getUnchecked(i, k) * A.getUnchecked(i, j);
          }
          t = -t / A.getUnchecked(k, k);
          for (var i = k; i < _m; i++) {
            A.setUnchecked(
                i, j, A.getUnchecked(i, j) + t * A.getUnchecked(i, k));
          }
        }
        // Place the k-th row of A into e for the
        // subsequent calculation of the row transformation.
        e[j] = A.getUnchecked(k, j);
      }
      if (k < nct) {
        // Place the transformation in U for subsequent back
        // multiplication.
        for (var i = k; i < _m; i++) {
          _u.setUnchecked(i, k, A.getUnchecked(i, k));
        }
      }
      if (k < nrt) {
        // Compute the k-th row transformation and place the
        // k-th super-diagonal in e[k].
        // Compute 2-norm without under/overflow.
        e[k] = 0.0;
        for (var i = k + 1; i < _n; i++) {
          e[k] = hypot(e[k], e[i]);
        }
        if (e[k] != 0.0) {
          if (e[k + 1] < 0.0) {
            e[k] = -e[k];
          }
          for (var i = k + 1; i < _n; i++) {
            e[i] /= e[k];
          }
          e[k + 1] += 1.0;
        }
        e[k] = -e[k];
        if ((k + 1 < _m) && (e[k] != 0.0)) {
          // Apply the transformation.
          for (var i = k + 1; i < _m; i++) {
            work[i] = 0.0;
          }
          for (var j = k + 1; j < _n; j++) {
            for (var i = k + 1; i < _m; i++) {
              work[i] += e[j] * A.getUnchecked(i, j);
            }
          }
          for (var j = k + 1; j < _n; j++) {
            final t = -e[j] / e[k + 1];
            for (var i = k + 1; i < _m; i++) {
              A.setUnchecked(i, j, A.getUnchecked(i, j) + t * work[i]);
            }
          }
        }
        // Place the transformation in V for subsequent
        // back multiplication.
        for (var i = k + 1; i < _n; i++) {
          _v.setUnchecked(i, k, e[i]);
        }
      }
    }

    // Set up the final bi-diagonal matrix or order p.
    var p = math.min(_n, _m + 1);
    if (nct < _n) {
      _s[nct] = A.getUnchecked(nct, nct);
    }
    if (_m < p) {
      _s[p - 1] = 0.0;
    }
    if (nrt + 1 < p) {
      e[nrt] = A.getUnchecked(nrt, p - 1);
    }
    e[p - 1] = 0.0;

    // If required, generate U.

    for (var j = nct; j < _u.columnCount; j++) {
      for (var i = 0; i < _m; i++) {
        _u.setUnchecked(i, j, 0);
      }
      _u.setUnchecked(j, j, 1);
    }
    for (var k = nct - 1; k >= 0; k--) {
      if (_s[k] != 0.0) {
        for (var j = k + 1; j < _u.columnCount; j++) {
          var t = 0.0;
          for (var i = k; i < _m; i++) {
            t += _u.getUnchecked(i, k) * _u.getUnchecked(i, j);
          }
          t = -t / _u.getUnchecked(k, k);
          for (var i = k; i < _m; i++) {
            _u.setUnchecked(
                i, j, _u.getUnchecked(i, j) + t * _u.getUnchecked(i, k));
          }
        }
        for (var i = k; i < _m; i++) {
          _u.setUnchecked(i, k, -_u.getUnchecked(i, k));
        }
        _u.setUnchecked(k, k, 1.0 + _u.getUnchecked(k, k));
        for (var i = 0; i < k - 1; i++) {
          _u.setUnchecked(i, k, 0);
        }
      } else {
        for (var i = 0; i < _m; i++) {
          _u.setUnchecked(i, k, 0);
        }
        _u.setUnchecked(k, k, 1);
      }
    }

    // If required, generate V.
    for (var k = _n - 1; k >= 0; k--) {
      if ((k < nrt) && (e[k] != 0.0)) {
        for (var j = k + 1; j < _u.columnCount; j++) {
          var t = 0.0;
          for (var i = k + 1; i < _n; i++) {
            t += _v.getUnchecked(i, k) * _v.getUnchecked(i, j);
          }
          t = -t / _v.getUnchecked(k + 1, k);
          for (var i = k + 1; i < _n; i++) {
            _v.setUnchecked(
                i, j, _v.getUnchecked(i, j) + t * _v.getUnchecked(i, k));
          }
        }
      }
      for (var i = 0; i < _n; i++) {
        _v.setUnchecked(i, k, 0);
      }
      _v.setUnchecked(k, k, 1);
    }

    // Main iteration loop for the singular values.
    final pp = p - 1;
    var iter = 0;
    final eps = math.pow(2.0, -52.0);
    final tiny = math.pow(2.0, -966.0);
    while (p > 0) {
      int k, kase;

      // Here is where a test for too many iterations would go.

      // This section of the program inspects for
      // negligible elements in the s and e arrays.  On
      // completion the variables kase and k are set as follows.

      // kase = 1     if s(p) and e[k-1] are negligible and k<p
      // kase = 2     if s(k) is negligible and k<p
      // kase = 3     if e[k-1] is negligible, k<p, and
      //              s(k), ..., s(p) are not negligible (qr step).
      // kase = 4     if e(p-1) is negligible (convergence).
      for (k = p - 2; k >= -1; k--) {
        if (k == -1) {
          break;
        }
        if (e[k].abs() <= tiny + eps * (_s[k].abs() + _s[k + 1].abs())) {
          e[k] = 0.0;
          break;
        }
      }
      if (k == p - 2) {
        kase = 4;
      } else {
        int ks;
        for (ks = p - 1; ks >= k; ks--) {
          if (ks == k) {
            break;
          }
          final t = (ks != p ? e[ks].abs() : 0.0) +
              (ks != k + 1 ? e[ks - 1].abs() : 0.0);
          if (_s[ks].abs() <= tiny + eps * t) {
            _s[ks] = 0.0;
            break;
          }
        }
        if (ks == k) {
          kase = 3;
        } else if (ks == p - 1) {
          kase = 1;
        } else {
          kase = 2;
          k = ks;
        }
      }
      k++;

      // Perform the task indicated by kase.
      switch (kase) {
        // Deflate negligible s(p).
        case 1:
          {
            var f = e[p - 2];
            e[p - 2] = 0.0;
            for (var j = p - 2; j >= k; j--) {
              var t = hypot(_s[j], f);
              final cs = _s[j] / t;
              final sn = f / t;
              _s[j] = t;
              if (j != k) {
                f = -sn * e[j - 1];
                e[j - 1] = cs * e[j - 1];
              }
              for (var i = 0; i < _n; i++) {
                t = cs * _v.getUnchecked(i, j) + sn * _v.getUnchecked(i, p - 1);
                _v.setUnchecked(
                    i,
                    p - 1,
                    -sn * _v.getUnchecked(i, j) +
                        cs * _v.getUnchecked(i, p - 1));
                _v.setUnchecked(i, j, t);
              }
            }
          }
          break;

        // Split at negligible s(k).
        case 2:
          {
            var f = e[k - 1];
            e[k - 1] = 0.0;
            for (var j = k; j < p; j++) {
              var t = hypot(_s[j], f);
              final cs = _s[j] / t;
              final sn = f / t;
              _s[j] = t;
              f = -sn * e[j];
              e[j] = cs * e[j];

              for (var i = 0; i < _m; i++) {
                t = cs * _u.getUnchecked(i, j) + sn * _u.getUnchecked(i, k - 1);
                _u.setUnchecked(
                    i,
                    k - 1,
                    -sn * _u.getUnchecked(i, j) +
                        cs * _u.getUnchecked(i, k - 1));
                _u.setUnchecked(i, j, t);
              }
            }
          }
          break;

        // Perform one qr step.
        case 3:
          {
            // Calculate the shift.
            final scale = math.max(
                math.max(
                    math.max(math.max(_s[p - 1].abs(), _s[p - 2].abs()),
                        e[p - 2].abs()),
                    _s[k].abs()),
                e[k].abs());
            final sp = _s[p - 1] / scale;
            final spm1 = _s[p - 2] / scale;
            final epm1 = e[p - 2] / scale;
            final sk = _s[k] / scale;
            final ek = e[k] / scale;
            final b = ((spm1 + sp) * (spm1 - sp) + epm1 * epm1) / 2.0;
            final c = (sp * epm1) * (sp * epm1);
            var shift = 0.0;
            if ((b != 0.0) || (c != 0.0)) {
              shift = math.sqrt(b * b + c);
              if (b < 0.0) {
                shift = -shift;
              }
              shift = c / (b + shift);
            }
            var f = (sk + sp) * (sk - sp) + shift;
            var g = sk * ek;

            // Chase zeros.
            for (var j = k; j < p - 1; j++) {
              var t = hypot(f, g);
              var cs = f / t;
              var sn = g / t;
              if (j != k) {
                e[j - 1] = t;
              }
              f = cs * _s[j] + sn * e[j];
              e[j] = cs * e[j] - sn * _s[j];
              g = sn * _s[j + 1];
              _s[j + 1] = cs * _s[j + 1];
              for (var i = 0; i < _n; i++) {
                t = cs * _v.getUnchecked(i, j) + sn * _v.getUnchecked(i, j + 1);
                _v.setUnchecked(
                    i,
                    j + 1,
                    -sn * _v.getUnchecked(i, j) +
                        cs * _v.getUnchecked(i, j + 1));
                _v.setUnchecked(i, j, t);
              }
              t = hypot(f, g);
              cs = f / t;
              sn = g / t;
              _s[j] = t;
              f = cs * e[j] + sn * _s[j + 1];
              _s[j + 1] = -sn * e[j] + cs * _s[j + 1];
              g = sn * e[j + 1];
              e[j + 1] = cs * e[j + 1];
              if (j < _m - 1) {
                for (var i = 0; i < _m; i++) {
                  t = cs * _u.getUnchecked(i, j) +
                      sn * _u.getUnchecked(i, j + 1);
                  _u.setUnchecked(
                      i,
                      j + 1,
                      -sn * _u.getUnchecked(i, j) +
                          cs * _u.getUnchecked(i, j + 1));
                  _u.setUnchecked(i, j, t);
                }
              }
            }
            e[p - 2] = f;
            iter = iter + 1;
          }
          break;

        // Convergence.
        case 4:
          {
            // Make the singular values positive.
            if (_s[k] <= 0.0) {
              _s[k] = _s[k] < 0.0 ? -_s[k] : 0.0;

              for (var i = 0; i <= pp; i++) {
                _v.setUnchecked(i, k, -_v.getUnchecked(i, k));
              }
            }

            // Order the singular values.
            while (k < pp) {
              if (_s[k] >= _s[k + 1]) {
                break;
              }
              var t = _s[k];
              _s[k] = _s[k + 1];
              _s[k + 1] = t;
              if (k < _n - 1) {
                for (var i = 0; i < _n; i++) {
                  t = _v.getUnchecked(i, k + 1);
                  _v.setUnchecked(i, k + 1, _v.getUnchecked(i, k));
                  _v.setUnchecked(i, k, t);
                }
              }
              if (k < _m - 1) {
                for (var i = 0; i < _m; i++) {
                  t = _u.getUnchecked(i, k + 1);
                  _u.setUnchecked(i, k + 1, _u.getUnchecked(i, k));
                  _u.setUnchecked(i, k, t);
                }
              }
              k++;
            }
            iter = 0;
            p--;
          }
          break;
      }
    }
  }

  /// internal storage of U and V.
  final Matrix<double> _u, _v;

  /// Array for internal storage of singular values.
  final List<double> _s;

  /// Row and column dimensions.
  final int _m, _n;

  /// Return the left singular vectors.
  Matrix<double> get U => _u.toMatrix();

  /// Return the right singular vectors.
  Matrix<double> get V => _v.toMatrix();

  /// Return the one-dimensional array of singular values.
  List<double> get s => DataType.float.copyList(_s);

  /// Return the diagonal matrix of singular values.
  Matrix<double> get S {
    final result =
        Matrix(DataType.float, _n, _n, format: MatrixFormat.diagonal);
    for (var i = 0; i < _n; i++) {
      result.setUnchecked(i, i, _s[i]);
    }
    return result;
  }

  /// Return the two norm.
  double get norm2 => _s[0];

  /// Return the two norm condition number.
  double get cond => _s[0] / _s[math.min(_m, _n) - 1];

  /// Return the effective numerical matrix rank.
  int get rank {
    final eps = math.pow(2.0, -52.0);
    final tol = math.max(_m, _n) * s[0] * eps;
    var r = 0;
    for (var i = 0; i < _s.length; i++) {
      if (_s[i] > tol) {
        r++;
      }
    }
    return r;
  }
}

extension SingularValueDecompositionExtension<T extends num> on Matrix<T> {
  /// Returns the Singular Value Decomposition of this [Matrix].
  SingularValueDecomposition get singularValue =>
      SingularValueDecomposition(this);

  /// Returns the rank, the effective numerical rank of this [Matrix].
  int get rank => singularValue.rank;

  /// Returns the condition, the ratio of largest to smallest singular value of
  /// this [Matrix].
  double get cond => singularValue.cond;
}
