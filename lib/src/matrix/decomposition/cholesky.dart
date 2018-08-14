library matrix.decomposition.cholesky;

import 'dart:math' as math;

import '../matrix.dart';
import '../utils.dart';

/// Cholesky Decomposition.
///
/// For a symmetric, positive definite matrix A, the Cholesky decomposition
/// is an lower triangular matrix L so that A = L*L'.
///
/// If the matrix is not symmetric or positive definite, the constructor
/// returns a partial decomposition and sets an internal flag that may
/// be queried by the isSPD() method.
class CholeskyDecomposition {
  /// internal storage of decomposition.
  Matrix<double> _L;

  /// Row and column dimension (square matrix).
  final int _n;

  /// Symmetric and positive definite flag.
  bool _isSymmetric;

  /// Cholesky algorithm for symmetric and positive definite matrix.
  /// Structure to access L and isspd flag.
  CholeskyDecomposition(Matrix A)
      : _L = Matrix.builder.withType(valueDataType)(A.rowCount, A.rowCount),
        _n = A.rowCount,
        _isSymmetric = A.rowCount == A.colCount {
    // Main loop.
    for (var j = 0; j < _n; j++) {
      var Lrowj = _L.row(j);
      var d = 0.0;
      for (var k = 0; k < j; k++) {
        var Lrowk = _L.row(k);
        var s = 0.0;
        for (var i = 0; i < k; i++) {
          s += Lrowk[i] * Lrowj[i];
        }
        Lrowj[k] = s = (A.getUnchecked(j, k) - s) / _L.getUnchecked(k, k);
        d = d + s * s;
        _isSymmetric =
            _isSymmetric && (A.getUnchecked(k, j) == A.getUnchecked(j, k));
      }
      d = A.getUnchecked(j, j) - d;
      _isSymmetric = _isSymmetric && (d > 0.0);
      _L.setUnchecked(j, j, math.sqrt(math.max(d, 0.0)));
      for (var k = j + 1; k < _n; k++) {
        _L.setUnchecked(j, k, 0.0);
      }
    }
  }

  /// Is the matrix symmetric and positive definite?
  bool get isSPD => _isSymmetric;

  /// Return triangular factor.
  Matrix<double> get L => _L;

  /// Solve A*X = B
  /// @param  B   A Matrix with as many rows as A and any number of columns.
  /// @return     X so that L*L'*X = B
  /// @exception  IllegalArgumentException  Matrix row dimensions must agree.
  /// @exception  RuntimeException  Matrix is not symmetric positive definite.
  Matrix<double> solve(Matrix<num> B) {
    if (B.rowCount != _n) {
      throw ArgumentError('Matrix row dimensions must agree.');
    }
    if (!_isSymmetric) {
      throw ArgumentError('Matrix is not symmetric positive definite.');
    }

    // Copy right hand side.
    final nx = B.colCount;
    final result = Matrix.builder.withType(valueDataType).from(B);

    // Solve L*Y = B;
    for (var k = 0; k < _n; k++) {
      for (var j = 0; j < nx; j++) {
        for (var i = 0; i < k; i++) {
          result.setUnchecked(
              k,
              j,
              result.getUnchecked(k, j) -
                  result.getUnchecked(i, j) * _L.getUnchecked(k, i));
        }
        result.setUnchecked(
            k, j, result.getUnchecked(k, j) / _L.getUnchecked(k, k));
      }
    }

    // Solve L'*X = Y;
    for (var k = _n - 1; k >= 0; k--) {
      for (var j = 0; j < nx; j++) {
        for (var i = k + 1; i < _n; i++) {
          result.setUnchecked(
              k,
              j,
              result.getUnchecked(k, j) -
                  result.getUnchecked(i, j) * _L.getUnchecked(i, k));
        }
        result.setUnchecked(
            k, j, result.getUnchecked(k, j) / _L.getUnchecked(k, k));
      }
    }
    return result;
  }
}
