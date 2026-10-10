import 'dart:math' as math;

import '../../../type.dart';
import '../matrix.dart';
import '../vector.dart';

/// Extension methods providing Cholesky decomposition on numeric matrices.
extension CholeskyMatrixExtension<T extends num> on Matrix<T> {
  /// Computes the Cholesky decomposition of this symmetric positive-definite matrix.
  CholeskyDecomposition<double> get cholesky =>
      CholeskyDecomposition<double>(_toDoubleMatrix());

  Matrix<double> _toDoubleMatrix() => this is Matrix<double>
      ? this as Matrix<double>
      : Matrix<double>.generate(
          rowCount,
          colCount,
          (r, c) => getUnchecked(r, c).toDouble(),
          type: DataType.float64,
        );
}

/// Extension methods providing Cholesky decomposition on complex matrices.
extension CholeskyComplexMatrixExtension on Matrix<Complex> {
  /// Computes the Cholesky decomposition of this Hermitian positive-definite matrix.
  CholeskyDecomposition<Complex> get cholesky =>
      CholeskyDecomposition<Complex>(this);
}

/// Cholesky Decomposition of a symmetric (or Hermitian) positive-definite matrix $A$.
///
/// Factorizes $A = L L^*$ where $L$ is a lower triangular matrix with strictly
/// positive real diagonal entries.
class CholeskyDecomposition<T> {
  /// Computes the Cholesky decomposition of [matrix].
  new(Matrix<T> matrix)
    : _n = matrix.rowCount,
      _type = matrix.type,
      _l = Matrix<T>.filled(
        matrix.rowCount,
        matrix.rowCount,
        matrix.type.field.additiveIdentity,
        type: matrix.type,
      ),
      _isSymmetricPositiveDefinite = matrix.rowCount == matrix.colCount {
    if (matrix.rowCount != matrix.colCount) {
      return;
    }
    if (matrix is Matrix<double> && _l is Matrix<double>) {
      _decomposeFloat64(matrix as Matrix<double>, _l as Matrix<double>);
    } else {
      _decomposeGeneric(matrix);
    }
  }

  final int _n;
  final DataType<T> _type;
  final Matrix<T> _l;
  bool _isSymmetricPositiveDefinite;

  /// Whether the matrix is symmetric (or Hermitian) and positive definite.
  bool get isSymmetricPositiveDefinite => _isSymmetricPositiveDefinite;

  /// Returns the lower triangular factor $L$.
  Matrix<T> get l => _l.copy();

  /// Returns the determinant of $A = (\prod L_{ii})^2$.
  T get det {
    if (!_isSymmetricPositiveDefinite) {
      throw ArgumentError('Matrix is not symmetric positive definite.');
    }
    final field = _type.field;
    var detVal = field.multiplicativeIdentity;
    for (var i = 0; i < _n; i++) {
      detVal = field.mul(detVal, _l.getUnchecked(i, i));
    }
    return field.mul(detVal, field.conjugate(detVal));
  }

  /// Solves $A X = B$ for $X$ using forward and back substitution.
  Matrix<T> solve(Matrix<T> b) {
    if (b.rowCount != _n) {
      throw ArgumentError(
        'Matrix row dimensions must agree: expected $_n, got ${b.rowCount}.',
      );
    }
    if (!_isSymmetricPositiveDefinite) {
      throw ArgumentError('Matrix is not symmetric positive definite.');
    }
    if (b is Matrix<double> && _l is Matrix<double>) {
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

  void _decomposeFloat64(Matrix<double> matrix, Matrix<double> l) {
    for (var j = 0; j < _n; j++) {
      var diag = 0.0;
      for (var k = 0; k < j; k++) {
        var sum = 0.0;
        for (var i = 0; i < k; i++) {
          sum += l.getUnchecked(k, i) * l.getUnchecked(j, i);
        }
        sum = (matrix.getUnchecked(j, k) - sum) / l.getUnchecked(k, k);
        l.setUnchecked(j, k, sum);
        diag += sum * sum;
        _isSymmetricPositiveDefinite =
            _isSymmetricPositiveDefinite &&
            (matrix.getUnchecked(k, j) == matrix.getUnchecked(j, k));
      }
      diag = matrix.getUnchecked(j, j) - diag;
      _isSymmetricPositiveDefinite =
          _isSymmetricPositiveDefinite && (diag > 0.0);
      l.setUnchecked(j, j, math.sqrt(math.max(diag, 0.0)));
      for (var k = j + 1; k < _n; k++) {
        l.setUnchecked(j, k, 0.0);
      }
    }
  }

  void _decomposeGeneric(Matrix<T> matrix) {
    final field = _type.field;
    final equality = _type.equality;
    final zero = field.additiveIdentity;

    for (var j = 0; j < _n; j++) {
      var diagSum = zero;
      for (var k = 0; k < j; k++) {
        var sum = zero;
        for (var i = 0; i < k; i++) {
          sum = field.add(
            sum,
            field.mul(
              _l.getUnchecked(j, i),
              field.conjugate(_l.getUnchecked(k, i)),
            ),
          );
        }
        sum = field.div(
          field.sub(matrix.getUnchecked(j, k), sum),
          _l.getUnchecked(k, k),
        );
        _l.setUnchecked(j, k, sum);
        diagSum = field.add(diagSum, field.mul(sum, field.conjugate(sum)));

        // Check Hermitian symmetry A_kj == conjugate(A_jk)
        final akj = matrix.getUnchecked(k, j);
        final ajkConj = field.conjugate(matrix.getUnchecked(j, k));
        _isSymmetricPositiveDefinite =
            _isSymmetricPositiveDefinite &&
            equality.isClose(akj, ajkConj, 1e-6);
      }
      final diagVal = field.sub(matrix.getUnchecked(j, j), diagSum);
      final isPos = switch (diagVal) {
        final num val => val > 0.0,
        final Complex c => c.real > 0.0 && c.imaginary.abs() < 1e-6,
        _ => field.norm(diagVal) > 0.0,
      };
      _isSymmetricPositiveDefinite = _isSymmetricPositiveDefinite && isPos;

      final T sqrtVal;
      if (!isPos) {
        sqrtVal = zero;
      } else if (diagVal is Complex) {
        sqrtVal = Complex(math.sqrt(math.max(diagVal.real, 0.0)), 0.0) as T;
      } else {
        sqrtVal = field.sqrt(diagVal);
      }
      _l.setUnchecked(j, j, sqrtVal);
      for (var k = j + 1; k < _n; k++) {
        _l.setUnchecked(j, k, zero);
      }
    }
  }

  Matrix<double> _solveFloat64(Matrix<double> b) {
    final l = _l as Matrix<double>;
    final nx = b.colCount;
    final result = Matrix<double>.generate(
      _n,
      nx,
      (row, col) => b.getUnchecked(row, col),
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
                result.getUnchecked(i, j) * l.getUnchecked(k, i),
          );
        }
        result.setUnchecked(
          k,
          j,
          result.getUnchecked(k, j) / l.getUnchecked(k, k),
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
                result.getUnchecked(i, j) * l.getUnchecked(i, k),
          );
        }
        result.setUnchecked(
          k,
          j,
          result.getUnchecked(k, j) / l.getUnchecked(k, k),
        );
      }
    }
    return result;
  }

  Matrix<T> _solveGeneric(Matrix<T> b) {
    final field = _type.field;
    final nx = b.colCount;
    final result = b.copy();

    // Solve L * Y = B
    for (var k = 0; k < _n; k++) {
      for (var j = 0; j < nx; j++) {
        var sum = result.getUnchecked(k, j);
        for (var i = 0; i < k; i++) {
          sum = field.sub(
            sum,
            field.mul(_l.getUnchecked(k, i), result.getUnchecked(i, j)),
          );
        }
        result.setUnchecked(k, j, field.div(sum, _l.getUnchecked(k, k)));
      }
    }

    // Solve L^* * X = Y
    for (var k = _n - 1; k >= 0; k--) {
      for (var j = 0; j < nx; j++) {
        var sum = result.getUnchecked(k, j);
        for (var i = k + 1; i < _n; i++) {
          sum = field.sub(
            sum,
            field.mul(
              field.conjugate(_l.getUnchecked(i, k)),
              result.getUnchecked(i, j),
            ),
          );
        }
        result.setUnchecked(
          k,
          j,
          field.div(sum, field.conjugate(_l.getUnchecked(k, k))),
        );
      }
    }
    return result;
  }
}
