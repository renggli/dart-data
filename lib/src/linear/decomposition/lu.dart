import 'dart:math' as math;

import '../../../type.dart';
import '../matrix.dart';
import '../vector.dart';

/// Extension methods providing LU decomposition on numeric matrices.
extension LuMatrixExtension<T extends num> on Matrix<T> {
  /// Computes the LU decomposition of this matrix.
  LUDecomposition<double> get lu => LUDecomposition<double>(_toDoubleMatrix());

  Matrix<double> _toDoubleMatrix() => this is Matrix<double>
      ? this as Matrix<double>
      : Matrix<double>.generate(
          rowCount,
          colCount,
          (r, c) => getUnchecked(r, c).toDouble(),
          type: DataType.float64,
        );
}

/// Extension methods providing LU decomposition on complex matrices.
extension LuComplexMatrixExtension on Matrix<Complex> {
  /// Computes the LU decomposition of this complex matrix.
  LUDecomposition<Complex> get lu => LUDecomposition<Complex>(this);
}

/// LU Decomposition of an [m x n] matrix $A$.
///
/// Factorizes $P A = L U$ with partial row pivoting, where:
/// - $P$ is a permutation matrix represented by [pivot]
/// - $L$ is a unit lower triangular matrix
/// - $U$ is an upper triangular matrix
class LUDecomposition<T> {
  /// Computes the LU decomposition of [matrix].
  new(Matrix<T> matrix)
    : _m = matrix.rowCount,
      _n = matrix.colCount,
      _type = matrix.type,
      _lu = matrix.copy(),
      _piv = List<int>.generate(matrix.rowCount, (i) => i) {
    if (_lu is Matrix<double>) {
      _decomposeFloat64();
    } else {
      _decomposeGeneric();
    }
  }

  final int _m;
  final int _n;
  final DataType<T> _type;
  final Matrix<T> _lu;
  final List<int> _piv;
  int _pivSign = 1;

  /// Number of rows.
  int get m => _m;

  /// Number of columns.
  int get n => _n;

  /// Whether the matrix is square and non-singular ($\det \ne 0$).
  bool get isNonsingular {
    if (_m != _n) return false;
    final zero = _type.field.additiveIdentity;
    for (var j = 0; j < _n; j++) {
      if (_lu.getUnchecked(j, j) == zero) {
        return false;
      }
    }
    return true;
  }

  /// Returns the unit lower triangular factor $L$.
  Matrix<T> get lower {
    final field = _type.field;
    final zero = field.additiveIdentity;
    final one = field.multiplicativeIdentity;
    final result = Matrix<T>.filled(_m, _n, zero, type: _type);
    for (var i = 0; i < _m; i++) {
      for (var j = 0; j < _n; j++) {
        if (i > j) {
          result.setUnchecked(i, j, _lu.getUnchecked(i, j));
        } else if (i == j) {
          result.setUnchecked(i, j, one);
        }
      }
    }
    return result;
  }

  /// Returns the upper triangular factor $U$.
  Matrix<T> get upper {
    final field = _type.field;
    final zero = field.additiveIdentity;
    final result = Matrix<T>.filled(_n, _n, zero, type: _type);
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
  T get det {
    if (_m != _n) {
      throw ArgumentError('Matrix must be square to compute determinant.');
    }
    final field = _type.field;
    var detVal = field.multiplicativeIdentity;
    for (var j = 0; j < _n; j++) {
      detVal = field.mul(detVal, _lu.getUnchecked(j, j));
    }
    return _pivSign == 1 ? detVal : field.neg(detVal);
  }

  /// Solves $A X = B$ for $X$.
  Matrix<T> solve(Matrix<T> b) {
    if (b.rowCount != _m) {
      throw ArgumentError(
        'Matrix row dimensions must agree: expected $_m, got ${b.rowCount}.',
      );
    }
    if (!isNonsingular) {
      throw ArgumentError('Matrix is singular.');
    }
    if (b is Matrix<double> && _lu is Matrix<double>) {
      return _solveFloat64(b as Matrix<double>) as Matrix<T>;
    } else {
      return _solveGeneric(b);
    }
  }

  /// Solves $A x = b$ for vector $x$.
  Vector<T> solveVector(Vector<T> b) {
    final mat = solve(b.toMatrix());
    return mat.col(0);
  }

  void _decomposeFloat64() {
    final lu = _lu as Matrix<double>;
    _pivSign = 1;

    for (var j = 0; j < _n; j++) {
      for (var i = 0; i < _m; i++) {
        final kmax = math.min(i, j);
        var sum = 0.0;
        for (var k = 0; k < kmax; k++) {
          sum += lu.getUnchecked(i, k) * lu.getUnchecked(k, j);
        }
        lu.setUnchecked(i, j, lu.getUnchecked(i, j) - sum);
      }

      var pivot = j;
      for (var i = j + 1; i < _m; i++) {
        if (lu.getUnchecked(i, j).abs() > lu.getUnchecked(pivot, j).abs()) {
          pivot = i;
        }
      }
      if (pivot != j) {
        for (var k = 0; k < _n; k++) {
          final temp = lu.getUnchecked(pivot, k);
          lu.setUnchecked(pivot, k, lu.getUnchecked(j, k));
          lu.setUnchecked(j, k, temp);
        }
        final k = _piv[pivot];
        _piv[pivot] = _piv[j];
        _piv[j] = k;
        _pivSign = -_pivSign;
      }

      if (j < _m && lu.getUnchecked(j, j) != 0.0) {
        for (var i = j + 1; i < _m; i++) {
          lu.setUnchecked(i, j, lu.getUnchecked(i, j) / lu.getUnchecked(j, j));
        }
      }
    }
  }

  void _decomposeGeneric() {
    final field = _type.field;
    final zero = field.additiveIdentity;
    _pivSign = 1;

    for (var j = 0; j < _n; j++) {
      for (var i = 0; i < _m; i++) {
        final kmax = math.min(i, j);
        var sum = zero;
        for (var k = 0; k < kmax; k++) {
          sum = field.add(
            sum,
            field.mul(_lu.getUnchecked(i, k), _lu.getUnchecked(k, j)),
          );
        }
        _lu.setUnchecked(i, j, field.sub(_lu.getUnchecked(i, j), sum));
      }

      var pivot = j;
      var maxNorm = field.norm(_lu.getUnchecked(pivot, j));
      for (var i = j + 1; i < _m; i++) {
        final norm = field.norm(_lu.getUnchecked(i, j));
        if (norm > maxNorm) {
          pivot = i;
          maxNorm = norm;
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

      if (j < _m && _lu.getUnchecked(j, j) != zero) {
        final ujj = _lu.getUnchecked(j, j);
        for (var i = j + 1; i < _m; i++) {
          _lu.setUnchecked(i, j, field.div(_lu.getUnchecked(i, j), ujj));
        }
      }
    }
  }

  Matrix<double> _solveFloat64(Matrix<double> b) {
    final lu = _lu as Matrix<double>;
    final nx = b.colCount;
    final x = Matrix<double>.generate(
      _m,
      nx,
      (row, col) => b.getUnchecked(_piv[row], col),
      type: DataType.float64,
    );

    // Solve L * Y = B(piv,:)
    for (var k = 0; k < _n; k++) {
      for (var i = k + 1; i < _n; i++) {
        for (var j = 0; j < nx; j++) {
          x.setUnchecked(
            i,
            j,
            x.getUnchecked(i, j) - x.getUnchecked(k, j) * lu.getUnchecked(i, k),
          );
        }
      }
    }

    // Solve U * X = Y
    for (var k = _n - 1; k >= 0; k--) {
      for (var j = 0; j < nx; j++) {
        x.setUnchecked(k, j, x.getUnchecked(k, j) / lu.getUnchecked(k, k));
      }
      for (var i = 0; i < k; i++) {
        for (var j = 0; j < nx; j++) {
          x.setUnchecked(
            i,
            j,
            x.getUnchecked(i, j) - x.getUnchecked(k, j) * lu.getUnchecked(i, k),
          );
        }
      }
    }
    return x;
  }

  Matrix<T> _solveGeneric(Matrix<T> b) {
    final field = _type.field;
    final nx = b.colCount;
    final x = Matrix<T>.generate(
      _m,
      nx,
      (row, col) => b.getUnchecked(_piv[row], col),
      type: _type,
    );

    // Solve L * Y = B(piv,:)
    for (var k = 0; k < _n; k++) {
      for (var i = k + 1; i < _n; i++) {
        final lik = _lu.getUnchecked(i, k);
        for (var j = 0; j < nx; j++) {
          x.setUnchecked(
            i,
            j,
            field.sub(
              x.getUnchecked(i, j),
              field.mul(lik, x.getUnchecked(k, j)),
            ),
          );
        }
      }
    }

    // Solve U * X = Y
    for (var k = _n - 1; k >= 0; k--) {
      final ukk = _lu.getUnchecked(k, k);
      for (var j = 0; j < nx; j++) {
        x.setUnchecked(k, j, field.div(x.getUnchecked(k, j), ukk));
      }
      for (var i = 0; i < k; i++) {
        final uik = _lu.getUnchecked(i, k);
        for (var j = 0; j < nx; j++) {
          x.setUnchecked(
            i,
            j,
            field.sub(
              x.getUnchecked(i, j),
              field.mul(uik, x.getUnchecked(k, j)),
            ),
          );
        }
      }
    }
    return x;
  }
}
