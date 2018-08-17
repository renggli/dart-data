library matrix.decomposition.lu;

import 'dart:math' as math;

import '../../shared/config.dart';
import '../matrix.dart';

/// LU Decomposition.
///
/// For an m-by-n matrix A with m >= n, the LU decomposition is an m-by-n
/// unit lower triangular matrix L, an n-by-n upper triangular matrix U,
/// and a permutation vector piv of length m so that A(piv,:) = L*U.
/// If m < n, then L is m-by-m and U is m-by-n.
///
/// The LU decomposition with pivoting always exists, even if the matrix is
/// singular, so the constructor will never fail.  The primary use of the
/// LU decomposition is in the solution of square systems of simultaneous
/// linear equations.  This will fail if [isNonsingular] returns false.
class LUDecomposition {
  /// Internal storage of decomposition.
  final Matrix<double> _lu;

  /// Internal row and column dimensions.
  final int _m, _n;

  /// Internal pivot sign.
  int _pivSign;

  /// Internal storage of pivot vector.
  final List<int> _piv;

  LUDecomposition(Matrix<num> A)
      : _lu = Matrix.builder.rowMajor.withType(valueDataType).fromMatrix(A),
        _m = A.rowCount,
        _n = A.colCount,
        _piv = indexDataType.newList(A.rowCount) {
    // Use a 'left-looking', dot-product, Crout/Doolittle algorithm.
    for (var i = 0; i < _m; i++) {
      _piv[i] = i;
    }
    _pivSign = 1;
    final lucolj = valueDataType.newList(_m);

    // Outer loop.
    for (var j = 0; j < _n; j++) {
      // Make a copy of the j-th column to localize references.
      for (var i = 0; i < _m; i++) {
        lucolj[i] = _lu.getUnchecked(i, j);
      }

      // Apply previous transformations.
      for (var i = 0; i < _m; i++) {
        final lurowi = _lu.row(i);

        // Most of the time is spent in the following dot product.
        final kmax = math.min(i, j);
        var s = 0.0;
        for (var k = 0; k < kmax; k++) {
          s += lurowi[k] * lucolj[k];
        }

        lurowi[j] = lucolj[i] -= s;
      }

      // Find pivot and exchange if necessary.
      var p = j;
      for (var i = j + 1; i < _m; i++) {
        if (lucolj[i].abs() > lucolj[p].abs()) {
          p = i;
        }
      }
      if (p != j) {
        for (var k = 0; k < _n; k++) {
          final t = _lu.getUnchecked(p, k);
          _lu.setUnchecked(p, k, _lu.getUnchecked(j, k));
          _lu.setUnchecked(j, k, t);
        }
        final k = _piv[p];
        _piv[p] = _piv[j];
        _piv[j] = k;
        _pivSign = -_pivSign;
      }

      // Compute multipliers.
      if (j < _m && _lu.getUnchecked(j, j) != 0.0) {
        for (var i = j + 1; i < _m; i++) {
          _lu.setUnchecked(
              i, j, _lu.getUnchecked(i, j) / _lu.getUnchecked(j, j));
        }
      }
    }
  }

  /// Is the matrix nonsingular?
  bool get isNonsingular {
    for (var j = 0; j < _n; j++) {
      if (_lu.getUnchecked(j, j) == 0.0) {
        return false;
      }
    }
    return true;
  }

  /// Returns the lower triangular factor.
  Matrix<double> get L {
    final X = Matrix.builder.diagonal.withType(valueDataType)(_m, _n);
    for (var i = 0; i < _m; i++) {
      for (var j = 0; j < _n; j++) {
        if (i > j) {
          L.setUnchecked(i, j, _lu.getUnchecked(i, j));
        } else if (i == j) {
          L.setUnchecked(i, j, 1.0);
        }
      }
    }
    return X;
  }

  /// Returns upper triangular factor.
  Matrix<double> get U {
    final X = Matrix.builder.diagonal.withType(valueDataType)(_n, _n);
    for (var i = 0; i < _n; i++) {
      for (var j = 0; j < _n; j++) {
        if (i <= j) {
          U.setUnchecked(i, j, _lu.getUnchecked(i, j));
        }
      }
    }
    return X;
  }

  /// Returns pivot permutation vector.
  List<int> get pivot => indexDataType.copyList(_piv);

  /// Returns the determinant.
  double get det {
    if (_m != _n) {
      throw ArgumentError('Matrix must be square.');
    }
    var d = 1.0;
    for (var j = 0; j < _n; j++) {
      d *= _lu.getUnchecked(j, j);
    }
    return d * _pivSign;
  }

  /// Solve A*X = B
  /// @param  B   A Matrix with as many rows as A and any number of columns.
  /// @return     X so that L*U*X = B(piv,:)
  /// @exception  IllegalArgumentException Matrix row dimensions must agree.
  /// @exception  RuntimeException  Matrix is singular.
  Matrix<double> solve(Matrix<num> B) {
    if (B.rowCount != _m) {
      throw ArgumentError('Matrix row dimensions must agree.');
    }
    if (!isNonsingular) {
      throw ArgumentError('Matrix is singular.');
    }

    // Copy right hand side with pivoting
    final nx = B.colCount;
    final X = Matrix.builder
        .withType(valueDataType)
        .fromIndexesAndRange(B, _piv, 0, nx);

    // Solve L*Y = B(piv,:)
    for (var k = 0; k < _n; k++) {
      for (var i = k + 1; i < _n; i++) {
        for (var j = 0; j < nx; j++) {
          X.setUnchecked(
              i,
              j,
              X.getUnchecked(i, j) -
                  X.getUnchecked(k, j) * _lu.getUnchecked(i, k));
        }
      }
    }

    // Solve U*X = Y;
    for (var k = _n - 1; k >= 0; k--) {
      for (var j = 0; j < nx; j++) {
        X.setUnchecked(k, j, X.getUnchecked(k, j) / _lu.getUnchecked(k, k));
      }
      for (var i = 0; i < k; i++) {
        for (var j = 0; j < nx; j++) {
          X.setUnchecked(
              i,
              j,
              X.getUnchecked(i, j) -
                  X.getUnchecked(k, j) * _lu.getUnchecked(i, k));
        }
      }
    }
    return X;
  }
}
