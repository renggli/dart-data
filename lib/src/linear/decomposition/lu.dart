import 'dart:math' as math;

import '../../type/data_type.dart';
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
        (r, c) => matrix.get(r, c).toDouble(),
        type: DataType.float64,
      ),
      _piv = List<int>.generate(matrix.rowCount, (i) => i) {
    _pivSign = 1;

    for (var j = 0; j < _n; j++) {
      for (var i = 0; i < _m; i++) {
        final kmax = math.min(i, j);
        var s = 0.0;
        for (var k = 0; k < kmax; k++) {
          s += _lu.get(i, k) * _lu.get(k, j);
        }
        _lu.set(i, j, _lu.get(i, j) - s);
      }

      var p = j;
      for (var i = j + 1; i < _m; i++) {
        if (_lu.get(i, j).abs() > _lu.get(p, j).abs()) {
          p = i;
        }
      }
      if (p != j) {
        for (var k = 0; k < _n; k++) {
          final t = _lu.get(p, k);
          _lu.set(p, k, _lu.get(j, k));
          _lu.set(j, k, t);
        }
        final k = _piv[p];
        _piv[p] = _piv[j];
        _piv[j] = k;
        _pivSign = -_pivSign;
      }

      if (j < _m && _lu.get(j, j) != 0.0) {
        for (var i = j + 1; i < _m; i++) {
          _lu.set(i, j, _lu.get(i, j) / _lu.get(j, j));
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
      if (_lu.get(j, j) == 0.0) {
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
          result.set(i, j, _lu.get(i, j));
        } else if (i == j) {
          result.set(i, j, 1.0);
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
          result.set(i, j, _lu.get(i, j));
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
    var d = 1.0;
    for (var j = 0; j < _n; j++) {
      d *= _lu.get(j, j);
    }
    return d * _pivSign;
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
      (r, c) => b.get(_piv[r], c).toDouble(),
      type: DataType.float64,
    );

    // Solve L * Y = B(piv,:)
    for (var k = 0; k < _n; k++) {
      for (var i = k + 1; i < _n; i++) {
        for (var j = 0; j < nx; j++) {
          x.set(i, j, x.get(i, j) - x.get(k, j) * _lu.get(i, k));
        }
      }
    }

    // Solve U * X = Y
    for (var k = _n - 1; k >= 0; k--) {
      for (var j = 0; j < nx; j++) {
        x.set(k, j, x.get(k, j) / _lu.get(k, k));
      }
      for (var i = 0; i < k; i++) {
        for (var j = 0; j < nx; j++) {
          x.set(i, j, x.get(i, j) - x.get(k, j) * _lu.get(i, k));
        }
      }
    }
    return x;
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
