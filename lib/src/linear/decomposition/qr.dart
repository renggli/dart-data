import 'dart:math' as math;

import '../../type/data_type.dart';
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
        (r, c) => matrix.get(r, c).toDouble(),
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
        final val = _qr.get(i, k);
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
        if (_qr.get(k, k) < 0) {
          nrm = -nrm;
        }
        for (var i = k; i < _m; i++) {
          _qr.set(i, k, _qr.get(i, k) / nrm);
        }
        _qr.set(k, k, _qr.get(k, k) + 1.0);

        for (var j = k + 1; j < _n; j++) {
          var s = 0.0;
          for (var i = k; i < _m; i++) {
            s += _qr.get(i, k) * _qr.get(i, j);
          }
          s = -s / _qr.get(k, k);
          for (var i = k; i < _m; i++) {
            _qr.set(i, j, _qr.get(i, j) + s * _qr.get(i, k));
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
          result.set(i, j, _qr.get(i, j));
        } else if (i == j) {
          result.set(i, j, _rdiag[i]);
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
        result.set(i, k, 0.0);
      }
      result.set(k, k, 1.0);
      for (var j = k; j < _n; j++) {
        if (_qr.get(k, k) != 0.0) {
          var s = 0.0;
          for (var i = k; i < _m; i++) {
            s += _qr.get(i, k) * result.get(i, j);
          }
          s = -s / _qr.get(k, k);
          for (var i = k; i < _m; i++) {
            result.set(i, j, result.get(i, j) + s * _qr.get(i, k));
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
    final x = List<double>.generate(_m, (i) => b[i].toDouble());

    // Compute Y = Q^T * b
    for (var k = 0; k < _n; k++) {
      var s = 0.0;
      for (var i = k; i < _m; i++) {
        s += _qr.get(i, k) * x[i];
      }
      s = -s / _qr.get(k, k);
      for (var i = k; i < _m; i++) {
        x[i] += s * _qr.get(i, k);
      }
    }

    // Solve R * X = Y
    for (var k = _n - 1; k >= 0; k--) {
      x[k] /= _rdiag[k];
      for (var i = 0; i < k; i++) {
        x[i] -= x[k] * _qr.get(i, k);
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
      (r, c) => b.get(r, c).toDouble(),
      type: DataType.float64,
    );

    // Compute Y = Q^T * B
    for (var k = 0; k < _n; k++) {
      for (var j = 0; j < nx; j++) {
        var s = 0.0;
        for (var i = k; i < _m; i++) {
          s += _qr.get(i, k) * x.get(i, j);
        }
        s = -s / _qr.get(k, k);
        for (var i = k; i < _m; i++) {
          x.set(i, j, x.get(i, j) + s * _qr.get(i, k));
        }
      }
    }

    // Solve R * X = Y
    for (var k = _n - 1; k >= 0; k--) {
      for (var j = 0; j < nx; j++) {
        x.set(k, j, x.get(k, j) / _rdiag[k]);
      }
      for (var i = 0; i < k; i++) {
        for (var j = 0; j < nx; j++) {
          x.set(i, j, x.get(i, j) - x.get(k, j) * _qr.get(i, k));
        }
      }
    }

    return x.subMatrix(rowStart: 0, rowEnd: _n, colStart: 0, colEnd: nx);
  }
}
