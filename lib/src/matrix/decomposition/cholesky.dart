library matrix.decomposition.cholesky;

import 'dart:math' as math;

import '../../shared/config.dart';
import '../matrix.dart';
import '../view/row_vector.dart';

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
  final Matrix<double> _l;

  /// Row and column dimension (square matrix).
  final int _n;

  /// Symmetric and positive definite flag.
  bool _isSymmetric;

  /// Cholesky algorithm for symmetric and positive definite matrix.
  /// Structure to access L and isspd flag.
  CholeskyDecomposition(Matrix a)
      : _l = Matrix.builder.withType(floatDataType)(a.rowCount, a.rowCount),
        _n = a.rowCount,
        _isSymmetric = a.rowCount == a.colCount {
    // Main loop.
    for (var j = 0; j < _n; j++) {
      final lrowj = _l.row(j);
      var d = 0.0;
      for (var k = 0; k < j; k++) {
        final lrowk = _l.row(k);
        var s = 0.0;
        for (var i = 0; i < k; i++) {
          s += lrowk[i] * lrowj[i];
        }
        lrowj[k] = s = (a.getUnchecked(j, k) - s) / _l.getUnchecked(k, k);
        d = d + s * s;
        _isSymmetric =
            _isSymmetric && (a.getUnchecked(k, j) == a.getUnchecked(j, k));
      }
      d = a.getUnchecked(j, j) - d;
      _isSymmetric = _isSymmetric && (d > 0.0);
      _l.setUnchecked(j, j, math.sqrt(math.max(d, 0.0)));
      for (var k = j + 1; k < _n; k++) {
        _l.setUnchecked(j, k, 0);
      }
    }
  }

  /// Is the matrix symmetric and positive definite?
  bool get isSPD => _isSymmetric;

  /// Return triangular factor.
  Matrix<double> get L => _l;

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
    final result = Matrix.builder.withType(floatDataType).fromMatrix(B);

    // Solve L*Y = B;
    for (var k = 0; k < _n; k++) {
      for (var j = 0; j < nx; j++) {
        for (var i = 0; i < k; i++) {
          result.setUnchecked(
              k,
              j,
              result.getUnchecked(k, j) -
                  result.getUnchecked(i, j) * _l.getUnchecked(k, i));
        }
        result.setUnchecked(
            k, j, result.getUnchecked(k, j) / _l.getUnchecked(k, k));
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
                  result.getUnchecked(i, j) * _l.getUnchecked(i, k));
        }
        result.setUnchecked(
            k, j, result.getUnchecked(k, j) / _l.getUnchecked(k, k));
      }
    }
    return result;
  }
}

extension CholeskyDecompositionExtension<T extends num> on Matrix<T> {
  /// Returns the Cholesky Decomposition.
  CholeskyDecomposition get cholesky => CholeskyDecomposition(this);
}
