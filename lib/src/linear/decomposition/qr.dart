import 'dart:math' as math;

import '../../../type.dart';
import '../matrix.dart';
import '../vector.dart';

/// QR Decomposition of an [m x n] matrix $A$ with $m \ge n$.
///
/// Factorizes $A = Q R$ where $Q$ is an [m x n] orthogonal matrix and $R$ is an
/// [n x n] upper triangular matrix.
class QRDecomposition {
  /// Computes the QR decomposition of [matrix].
  new(Matrix<num> matrix)
    : _m = matrix.rowCount,
      _n = matrix.colCount,
      _qr = Matrix<double>.generate(
        matrix.rowCount,
        matrix.colCount,
        (row, col) => matrix.getUnchecked(row, col).toDouble(),
        type: DataType.float64,
      ),
      _rdiag = List<double>.filled(matrix.colCount, 0.0) {
    if (_m < _n) {
      throw ArgumentError(
        'QR decomposition requires rowCount ($m) >= colCount ($n).',
      );
    }
    for (var k = 0; k < _n; k++) {
      var scale = 0.0;
      var sumsq = 1.0;
      for (var i = k; i < _m; i++) {
        final val = _qr.getUnchecked(i, k);
        if (val != 0.0) {
          final absVal = val.abs();
          if (scale < absVal) {
            sumsq = 1.0 + sumsq * (scale / absVal) * (scale / absVal);
            scale = absVal;
          } else {
            sumsq += (absVal / scale) * (absVal / scale);
          }
        }
      }
      var nrm = scale * math.sqrt(sumsq);

      if (nrm != 0.0) {
        if (_qr.getUnchecked(k, k) < 0) {
          nrm = -nrm;
        }
        for (var i = k; i < _m; i++) {
          _qr.setUnchecked(i, k, _qr.getUnchecked(i, k) / nrm);
        }
        _qr.setUnchecked(k, k, _qr.getUnchecked(k, k) + 1.0);

        for (var j = k + 1; j < _n; j++) {
          var sum = 0.0;
          for (var i = k; i < _m; i++) {
            sum += _qr.getUnchecked(i, k) * _qr.getUnchecked(i, j);
          }
          sum = -sum / _qr.getUnchecked(k, k);
          for (var i = k; i < _m; i++) {
            _qr.setUnchecked(
              i,
              j,
              _qr.getUnchecked(i, j) + sum * _qr.getUnchecked(i, k),
            );
          }
        }
      }
      _rdiag[k] = -nrm;
    }
  }

  final int _m;
  final int _n;
  final Matrix<double> _qr;
  final List<double> _rdiag;

  /// Number of rows.
  int get m => _m;

  /// Number of columns.
  int get n => _n;

  /// Whether the matrix has full rank.
  bool get isFullRank {
    for (var j = 0; j < _n; j++) {
      if (_rdiag[j] == 0.0) {
        return false;
      }
    }
    return true;
  }

  /// Returns the upper triangular factor $R$.
  Matrix<double> get r {
    final result = Matrix<double>.filled(_n, _n, 0.0, type: DataType.float64);
    for (var i = 0; i < _n; i++) {
      for (var j = i; j < _n; j++) {
        if (i < j) {
          result.setUnchecked(i, j, _qr.getUnchecked(i, j));
        } else if (i == j) {
          result.setUnchecked(i, j, _rdiag[i]);
        }
      }
    }
    return result;
  }

  /// Returns the economy-sized orthogonal factor $Q$ of size [m x n].
  Matrix<double> get q {
    final result = Matrix<double>.filled(_m, _n, 0.0, type: DataType.float64);
    for (var k = _n - 1; k >= 0; k--) {
      for (var i = 0; i < _m; i++) {
        result.setUnchecked(i, k, 0.0);
      }
      result.setUnchecked(k, k, 1.0);
      for (var j = k; j < _n; j++) {
        if (_qr.getUnchecked(k, k) != 0.0) {
          var sum = 0.0;
          for (var i = k; i < _m; i++) {
            sum += _qr.getUnchecked(i, k) * result.getUnchecked(i, j);
          }
          sum = -sum / _qr.getUnchecked(k, k);
          for (var i = k; i < _m; i++) {
            result.setUnchecked(
              i,
              j,
              result.getUnchecked(i, j) + sum * _qr.getUnchecked(i, k),
            );
          }
        }
      }
    }
    return result;
  }

  /// Solves the least squares problem $A x \approx b$ for vector [b].
  Vector<double> solveVector(Vector<num> b) {
    if (b.length != _m) {
      throw ArgumentError(
        'Vector length (${b.length}) must match rowCount ($_m).',
      );
    }
    if (!isFullRank) {
      throw StateError('Matrix is rank deficient.');
    }
    final x = List<double>.generate(_m, (i) => b.getUnchecked(i).toDouble());

    // Compute Y = Q^T * b
    for (var k = 0; k < _n; k++) {
      var sum = 0.0;
      for (var i = k; i < _m; i++) {
        sum += _qr.getUnchecked(i, k) * x[i];
      }
      sum = -sum / _qr.getUnchecked(k, k);
      for (var i = k; i < _m; i++) {
        x[i] += sum * _qr.getUnchecked(i, k);
      }
    }

    // Solve R * X = Y
    for (var k = _n - 1; k >= 0; k--) {
      x[k] /= _rdiag[k];
      for (var i = 0; i < k; i++) {
        x[i] -= x[k] * _qr.getUnchecked(i, k);
      }
    }

    return Vector<double>.fromList(x.sublist(0, _n), type: DataType.float64);
  }

  /// Solves the least squares problem $A X \approx B$ for matrix [b].
  Matrix<double> solveMatrix(Matrix<num> b) {
    if (b.rowCount != _m) {
      throw ArgumentError(
        'Matrix row count (${b.rowCount}) must match rowCount ($_m).',
      );
    }
    if (!isFullRank) {
      throw StateError('Matrix is rank deficient.');
    }
    final nx = b.colCount;
    final x = Matrix<double>.generate(
      _m,
      nx,
      (row, col) => b.getUnchecked(row, col).toDouble(),
      type: DataType.float64,
    );

    // Compute Y = Q^T * B
    for (var k = 0; k < _n; k++) {
      for (var j = 0; j < nx; j++) {
        var sum = 0.0;
        for (var i = k; i < _m; i++) {
          sum += _qr.getUnchecked(i, k) * x.getUnchecked(i, j);
        }
        sum = -sum / _qr.getUnchecked(k, k);
        for (var i = k; i < _m; i++) {
          x.setUnchecked(
            i,
            j,
            x.getUnchecked(i, j) + sum * _qr.getUnchecked(i, k),
          );
        }
      }
    }

    // Solve R * X = Y
    for (var k = _n - 1; k >= 0; k--) {
      for (var j = 0; j < nx; j++) {
        x.setUnchecked(k, j, x.getUnchecked(k, j) / _rdiag[k]);
      }
      for (var i = 0; i < k; i++) {
        for (var j = 0; j < nx; j++) {
          x.setUnchecked(
            i,
            j,
            x.getUnchecked(i, j) -
                x.getUnchecked(k, j) * _qr.getUnchecked(i, k),
          );
        }
      }
    }

    return x.subMatrix(rowStart: 0, rowEnd: _n, colStart: 0, colEnd: nx);
  }
}
