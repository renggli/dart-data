import 'dart:math' as math;

import '../../../type.dart';
import '../matrix.dart';
import '../vector.dart';

/// LU Decomposition of an [m x n] matrix $A$.
///
/// Factorizes $P A = L U$ with partial row pivoting, where:
/// - $P$ is a permutation matrix represented by [pivot]
/// - $L$ is a unit lower triangular matrix
/// - $U$ is an upper triangular matrix
class LUDecomposition {
  /// Computes the LU decomposition of [matrix].
  new(Matrix<num> matrix)
    : _m = matrix.rowCount,
      _n = matrix.colCount,
      _lu = Matrix<double>.generate(
        matrix.rowCount,
        matrix.colCount,
        (row, col) => matrix.getUnchecked(row, col).toDouble(),
        type: DataType.float64,
      ),
      _piv = List<int>.generate(matrix.rowCount, (i) => i) {
    _pivSign = 1;

    for (var j = 0; j < _n; j++) {
      for (var i = 0; i < _m; i++) {
        final kmax = math.min(i, j);
        var sum = 0.0;
        for (var k = 0; k < kmax; k++) {
          sum += _lu.getUnchecked(i, k) * _lu.getUnchecked(k, j);
        }
        _lu.setUnchecked(i, j, _lu.getUnchecked(i, j) - sum);
      }

      var pivot = j;
      for (var i = j + 1; i < _m; i++) {
        if (_lu.getUnchecked(i, j).abs() > _lu.getUnchecked(pivot, j).abs()) {
          pivot = i;
        }
      }
      if (pivot != j) {
        for (var k = 0; k < _n; k++) {
          final temp = _lu.getUnchecked(pivot, k);
          _lu.setUnchecked(pivot, k, _lu.getUnchecked(j, k));
          _lu.setUnchecked(j, k, temp);
        }
        final k = _piv[pivot];
        _piv[pivot] = _piv[j];
        _piv[j] = k;
        _pivSign = -_pivSign;
      }

      if (j < _m && _lu.getUnchecked(j, j) != 0.0) {
        for (var i = j + 1; i < _m; i++) {
          _lu.setUnchecked(
            i,
            j,
            _lu.getUnchecked(i, j) / _lu.getUnchecked(j, j),
          );
        }
      }
    }
  }

  final int _m;
  final int _n;
  final Matrix<double> _lu;
  final List<int> _piv;
  int _pivSign = 1;

  /// Whether the matrix is square and non-singular ($\det \ne 0$).
  bool get isNonsingular {
    if (_m != _n) return false;
    for (var j = 0; j < _n; j++) {
      if (_lu.getUnchecked(j, j) == 0.0) {
        return false;
      }
    }
    return true;
  }

  /// Returns the unit lower triangular factor $L$.
  Matrix<double> get lower {
    final result = Matrix<double>.filled(_m, _n, 0.0, type: DataType.float64);
    for (var i = 0; i < _m; i++) {
      for (var j = 0; j < _n; j++) {
        if (i > j) {
          result.setUnchecked(i, j, _lu.getUnchecked(i, j));
        } else if (i == j) {
          result.setUnchecked(i, j, 1.0);
        }
      }
    }
    return result;
  }

  /// Returns the upper triangular factor $U$.
  Matrix<double> get upper {
    final result = Matrix<double>.filled(_n, _n, 0.0, type: DataType.float64);
    for (var i = 0; i < _n; i++) {
      for (var j = 0; j < _n; j++) {
        if (i <= j) {
          result.setUnchecked(i, j, _lu.getUnchecked(i, j));
        }
      }
    }
    return result;
  }

  /// Returns a copy of the pivot permutation vector.
  List<int> get pivot => List<int>.from(_piv);

  /// Returns the determinant of this matrix.
  double get det {
    if (_m != _n) {
      throw ArgumentError('Matrix must be square to compute determinant.');
    }
    var detVal = 1.0;
    for (var j = 0; j < _n; j++) {
      detVal *= _lu.getUnchecked(j, j);
    }
    return detVal * _pivSign;
  }

  /// Solves $A X = B$ for $X$.
  Matrix<double> solve(Matrix<num> b) {
    if (b.rowCount != _m) {
      throw ArgumentError(
        'Matrix row dimensions must agree: expected $_m, got ${b.rowCount}.',
      );
    }
    if (!isNonsingular) {
      throw ArgumentError('Matrix is singular.');
    }

    final nx = b.colCount;
    final x = Matrix<double>.generate(
      _m,
      nx,
      (row, col) => b.getUnchecked(_piv[row], col).toDouble(),
      type: DataType.float64,
    );

    // Solve L * Y = B(piv,:)
    for (var k = 0; k < _n; k++) {
      for (var i = k + 1; i < _n; i++) {
        for (var j = 0; j < nx; j++) {
          x.setUnchecked(
            i,
            j,
            x.getUnchecked(i, j) -
                x.getUnchecked(k, j) * _lu.getUnchecked(i, k),
          );
        }
      }
    }

    // Solve U * X = Y
    for (var k = _n - 1; k >= 0; k--) {
      for (var j = 0; j < nx; j++) {
        x.setUnchecked(k, j, x.getUnchecked(k, j) / _lu.getUnchecked(k, k));
      }
      for (var i = 0; i < k; i++) {
        for (var j = 0; j < nx; j++) {
          x.setUnchecked(
            i,
            j,
            x.getUnchecked(i, j) -
                x.getUnchecked(k, j) * _lu.getUnchecked(i, k),
          );
        }
      }
    }
    return x;
  }

  /// Solves $A x = b$ for vector $x$.
  Vector<double> solveVector(Vector<num> b) {
    final mat = solve(b.toMatrix());
    return mat.column(0);
  }
}
