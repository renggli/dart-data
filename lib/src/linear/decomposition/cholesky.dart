import 'dart:math' as math;

import '../../type/data_type.dart';
import '../matrix.dart';
import '../vector.dart';

/// Cholesky Decomposition of a symmetric, positive-definite matrix $A$.
///
/// Factorizes $A = L L^T$ where $L$ is a lower triangular matrix with strictly
/// positive diagonal entries.
class CholeskyDecomposition {
  /// Computes the Cholesky decomposition of [matrix].
  new(Matrix<num> matrix)
    : _n = matrix.rowCount,
      _l = Matrix<double>.filled(
        matrix.rowCount,
        matrix.rowCount,
        0.0,
        type: DataType.float64,
      ),
      _isSymmetricPositiveDefinite = matrix.rowCount == matrix.colCount {
    if (matrix.rowCount != matrix.colCount) {
      return;
    }
    for (var j = 0; j < _n; j++) {
      var d = 0.0;
      for (var k = 0; k < j; k++) {
        var s = 0.0;
        for (var i = 0; i < k; i++) {
          s += _l.get(k, i) * _l.get(j, i);
        }
        s = (matrix.get(j, k).toDouble() - s) / _l.get(k, k);
        _l.set(j, k, s);
        d += s * s;
        _isSymmetricPositiveDefinite =
            _isSymmetricPositiveDefinite &&
            (matrix.get(k, j).toDouble() == matrix.get(j, k).toDouble());
      }
      d = matrix.get(j, j).toDouble() - d;
      _isSymmetricPositiveDefinite = _isSymmetricPositiveDefinite && (d > 0.0);
      _l.set(j, j, math.sqrt(math.max(d, 0.0)));
      for (var k = j + 1; k < _n; k++) {
        _l.set(j, k, 0.0);
      }
    }
  }

  final int _n;
  final Matrix<double> _l;
  bool _isSymmetricPositiveDefinite;

  /// Whether the matrix is symmetric and positive definite.
  bool get isSymmetricPositiveDefinite => _isSymmetricPositiveDefinite;

  /// Returns the lower triangular factor $L$.
  Matrix<double> get l => _l.copy();

  /// Returns the lower triangular factor $L$ (alias).
  Matrix<double> get L => l;

  /// Returns the determinant of $A = (\prod L_{ii})^2$.
  double get det {
    if (!_isSymmetricPositiveDefinite) {
      throw ArgumentError('Matrix is not symmetric positive definite.');
    }
    var d = 1.0;
    for (var i = 0; i < _n; i++) {
      d *= _l.get(i, i);
    }
    return d * d;
  }

  /// Solves $A X = B$ for $X$ using forward and back substitution.
  Matrix<double> solve(Matrix<num> b) {
    if (b.rowCount != _n) {
      throw ArgumentError(
        'Matrix row dimensions must agree: expected $_n, got ${b.rowCount}.',
      );
    }
    if (!_isSymmetricPositiveDefinite) {
      throw ArgumentError('Matrix is not symmetric positive definite.');
    }

    final nx = b.colCount;
    final result = Matrix<double>.generate(
      _n,
      nx,
      (r, c) => b.get(r, c).toDouble(),
      type: DataType.float64,
    );

    // Solve L * Y = B
    for (var k = 0; k < _n; k++) {
      for (var j = 0; j < nx; j++) {
        for (var i = 0; i < k; i++) {
          result.set(k, j, result.get(k, j) - result.get(i, j) * _l.get(k, i));
        }
        result.set(k, j, result.get(k, j) / _l.get(k, k));
      }
    }

    // Solve L^T * X = Y
    for (var k = _n - 1; k >= 0; k--) {
      for (var j = 0; j < nx; j++) {
        for (var i = k + 1; i < _n; i++) {
          result.set(k, j, result.get(k, j) - result.get(i, j) * _l.get(i, k));
        }
        result.set(k, j, result.get(k, j) / _l.get(k, k));
      }
    }
    return result;
  }

  /// Solves $A x = b$ for vector $x$.
  Vector<double> solveVector(Vector<num> b) {
    final mat = solve(
      Matrix<num>.fromColumns([
        [for (var i = 0; i < b.length; i++) b[i]],
      ]),
    );
    return mat.column(0);
  }
}
