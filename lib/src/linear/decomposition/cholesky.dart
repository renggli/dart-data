import 'dart:math' as math;

import '../../../type.dart';
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
      var diag = 0.0;
      for (var k = 0; k < j; k++) {
        var sum = 0.0;
        for (var i = 0; i < k; i++) {
          sum += _l.getUnchecked(k, i) * _l.getUnchecked(j, i);
        }
        sum =
            (matrix.getUnchecked(j, k).toDouble() - sum) /
            _l.getUnchecked(k, k);
        _l.setUnchecked(j, k, sum);
        diag += sum * sum;
        _isSymmetricPositiveDefinite =
            _isSymmetricPositiveDefinite &&
            (matrix.getUnchecked(k, j).toDouble() ==
                matrix.getUnchecked(j, k).toDouble());
      }
      diag = matrix.getUnchecked(j, j).toDouble() - diag;
      _isSymmetricPositiveDefinite =
          _isSymmetricPositiveDefinite && (diag > 0.0);
      _l.setUnchecked(j, j, math.sqrt(math.max(diag, 0.0)));
      for (var k = j + 1; k < _n; k++) {
        _l.setUnchecked(j, k, 0.0);
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
    var detVal = 1.0;
    for (var i = 0; i < _n; i++) {
      detVal *= _l.getUnchecked(i, i);
    }
    return detVal * detVal;
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
      (row, col) => b.getUnchecked(row, col).toDouble(),
      type: DataType.float64,
    );

    // Solve L * Y = B
    for (var k = 0; k < _n; k++) {
      for (var j = 0; j < nx; j++) {
        for (var i = 0; i < k; i++) {
          result.setUnchecked(
            k,
            j,
            result.getUnchecked(k, j) -
                result.getUnchecked(i, j) * _l.getUnchecked(k, i),
          );
        }
        result.setUnchecked(
          k,
          j,
          result.getUnchecked(k, j) / _l.getUnchecked(k, k),
        );
      }
    }

    // Solve L^T * X = Y
    for (var k = _n - 1; k >= 0; k--) {
      for (var j = 0; j < nx; j++) {
        for (var i = k + 1; i < _n; i++) {
          result.setUnchecked(
            k,
            j,
            result.getUnchecked(k, j) -
                result.getUnchecked(i, j) * _l.getUnchecked(i, k),
          );
        }
        result.setUnchecked(
          k,
          j,
          result.getUnchecked(k, j) / _l.getUnchecked(k, k),
        );
      }
    }
    return result;
  }

  /// Solves $A x = b$ for vector $x$.
  Vector<double> solveVector(Vector<num> b) {
    final mat = solve(b.toMatrix());
    return mat.column(0);
  }
}
