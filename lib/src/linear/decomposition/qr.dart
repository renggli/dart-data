import 'dart:math' as math;
import 'dart:typed_data';

import 'package:more/number.dart' show Complex;

import '../../type/data_type.dart';
import '../matrix.dart';
import '../vector.dart';

/// Extension methods providing QR decomposition on numeric matrices.
extension QrMatrixExtension<T extends num> on Matrix<T> {
  /// Computes the QR decomposition of this matrix.
  QRDecomposition<double> get qr => QRDecomposition<double>(_toDoubleMatrix());

  Matrix<double> _toDoubleMatrix() => this is Matrix<double>
      ? this as Matrix<double>
      : Matrix<double>.generate(
          rowCount,
          colCount,
          (r, c) => getUnchecked(r, c).toDouble(),
          type: DataType.float64,
        );
}

/// Extension methods providing QR decomposition on complex matrices.
extension QrComplexMatrixExtension on Matrix<Complex> {
  /// Computes the QR decomposition of this complex matrix.
  QRDecomposition<Complex> get qr => QRDecomposition<Complex>(this);
}

/// QR Decomposition of an $m \times n$ matrix $A$ with $m \ge n$.
///
/// Conceptually, QR decomposition untangles a matrix into mutually
/// perpendicular (orthogonal) coordinate directions and an upper-triangular
/// scaling matrix, making least-squares data fitting simple and numerically
/// stable. More formally, it computes the Householder reflection factorization
/// $A = Q R$ where $Q \in \mathbb{R}^{m \times n}$ has orthonormal columns
/// ($Q^T Q = I_n$) and $R \in \mathbb{R}^{n \times n}$ is upper triangular.
///
/// ```dart
/// final a = Matrix<double>.fromRows([
///   [1.0, 2.0],
///   [3.0, 4.0],
///   [5.0, 6.0],
/// ]);
/// final qr = a.qr;
/// final q = qr.q;
/// final r = qr.r;
/// ```
class QRDecomposition<T> {
  /// Computes the QR decomposition of [matrix].
  new(Matrix<T> matrix)
    : _m = matrix.rowCount,
      _n = matrix.colCount,
      _type = matrix.type,
      _qr = matrix.copy(),
      _rdiag = List<T>.filled(
        matrix.colCount,
        matrix.type.field.additiveIdentity,
      ),
      _tau = List<double>.filled(matrix.colCount, 0.0) {
    if (_m < _n) {
      throw ArgumentError(
        'QR decomposition requires rowCount ($m) >= colCount ($n).',
      );
    }
    if (matrix is Matrix<double>) {
      _decomposeFloat64(matrix as Matrix<double>);
    } else {
      _decomposeGeneric();
    }
  }

  final int _m;
  final int _n;
  final DataType<T> _type;
  final Matrix<T> _qr;
  final List<T> _rdiag;
  final List<double> _tau;

  /// Number of rows.
  int get m => _m;

  /// Number of columns.
  int get n => _n;

  /// Whether the matrix has full rank.
  bool get isFullRank {
    if (_n == 0) return true;
    final field = _type.field;
    final zero = field.additiveIdentity;
    var maxDiag = 0.0;
    for (var j = 0; j < _n; j++) {
      final norm = field.norm(_rdiag[j]);
      if (norm > maxDiag) maxDiag = norm;
    }
    if (maxDiag == 0.0) return false;
    final maxDim = math.max(_m, _n);
    final tol = maxDim * 2.220446049250313e-16 * maxDiag;
    for (var j = 0; j < _n; j++) {
      if (_rdiag[j] == zero || field.norm(_rdiag[j]) <= tol) {
        return false;
      }
    }
    return true;
  }

  /// Returns the upper triangular factor $R$.
  Matrix<T> get r {
    final field = _type.field;
    final zero = field.additiveIdentity;
    final result = Matrix<T>.filled(_n, _n, zero, type: _type);
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

  /// Returns the economy-sized orthogonal (or unitary) factor $Q$ of size
  /// $m \times n$.
  Matrix<T> get q {
    if (_qr is Matrix<double>) {
      return _qFloat64() as Matrix<T>;
    }
    final field = _type.field;
    final zero = field.additiveIdentity;
    final one = field.multiplicativeIdentity;
    final result = Matrix<T>.filled(_m, _n, zero, type: _type);
    for (var i = 0; i < _n; i++) {
      result.setUnchecked(i, i, one);
    }
    for (var k = _n - 1; k >= 0; k--) {
      final tauK = _tau[k];
      if (tauK == 0.0) continue;
      final tauT = _type.cast(tauK);
      for (var j = k; j < _n; j++) {
        var s = result.getUnchecked(k, j);
        for (var i = k + 1; i < _m; i++) {
          s = field.add(
            s,
            field.mul(
              field.conjugate(_qr.getUnchecked(i, k)),
              result.getUnchecked(i, j),
            ),
          );
        }
        final tauS = field.mul(tauT, s);
        result.setUnchecked(k, j, field.sub(result.getUnchecked(k, j), tauS));
        for (var i = k + 1; i < _m; i++) {
          result.setUnchecked(
            i,
            j,
            field.sub(
              result.getUnchecked(i, j),
              field.mul(tauS, _qr.getUnchecked(i, k)),
            ),
          );
        }
      }
    }
    return result;
  }

  /// Solves the least squares problem $A x \approx b$ for vector [b].
  Vector<T> solveVector(Vector<T> b) {
    if (b.length != _m) {
      throw ArgumentError(
        'Vector length (${b.length}) must match rowCount ($_m).',
      );
    }
    if (!isFullRank) {
      throw StateError('Matrix is rank deficient.');
    }
    final mat = solve(b.toMatrix());
    return mat.col(0);
  }

  /// Solves the least squares problem $A X \approx B$ for matrix [b].
  Matrix<T> solve(Matrix<T> b) {
    if (b.rowCount != _m) {
      throw ArgumentError(
        'Matrix row count (${b.rowCount}) must match rowCount ($_m).',
      );
    }
    if (!isFullRank) {
      throw StateError('Matrix is rank deficient.');
    }
    if (b is Matrix<double> && _qr is Matrix<double>) {
      return _solveFloat64(b as Matrix<double>) as Matrix<T>;
    }
    final field = _type.field;
    final nx = b.colCount;
    final x = b.copy();

    // Compute Y = Q^* * B
    for (var k = 0; k < _n; k++) {
      final tauK = _tau[k];
      if (tauK == 0.0) continue;
      final tauT = _type.cast(tauK);
      for (var j = 0; j < nx; j++) {
        var s = x.getUnchecked(k, j);
        for (var i = k + 1; i < _m; i++) {
          s = field.add(
            s,
            field.mul(
              field.conjugate(_qr.getUnchecked(i, k)),
              x.getUnchecked(i, j),
            ),
          );
        }
        final tauS = field.mul(tauT, s);
        x.setUnchecked(k, j, field.sub(x.getUnchecked(k, j), tauS));
        for (var i = k + 1; i < _m; i++) {
          x.setUnchecked(
            i,
            j,
            field.sub(
              x.getUnchecked(i, j),
              field.mul(tauS, _qr.getUnchecked(i, k)),
            ),
          );
        }
      }
    }

    // Solve R * X = Y
    for (var k = _n - 1; k >= 0; k--) {
      final rkk = _rdiag[k];
      for (var j = 0; j < nx; j++) {
        x.setUnchecked(k, j, field.div(x.getUnchecked(k, j), rkk));
      }
      for (var i = 0; i < k; i++) {
        final rik = _qr.getUnchecked(i, k);
        for (var j = 0; j < nx; j++) {
          x.setUnchecked(
            i,
            j,
            field.sub(
              x.getUnchecked(i, j),
              field.mul(rik, x.getUnchecked(k, j)),
            ),
          );
        }
      }
    }

    return x.subMatrix(rowStart: 0, rowEnd: _n, colStart: 0, colEnd: nx);
  }

  void _decomposeFloat64(Matrix<double> matrix) {
    final qrData = _qr.tensor.data as Float64List;
    final rdiag = _rdiag as List<double>;

    for (var k = 0; k < _n; k++) {
      var scale = 0.0;
      var sumsq = 1.0;
      for (var i = k; i < _m; i++) {
        final val = qrData[i * _n + k];
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
        if (qrData[k * _n + k] < 0) {
          nrm = -nrm;
        }
        for (var i = k; i < _m; i++) {
          qrData[i * _n + k] /= nrm;
        }
        qrData[k * _n + k] += 1.0;

        final qkk = qrData[k * _n + k];
        for (var j = k + 1; j < _n; j++) {
          var sum = 0.0;
          for (var i = k; i < _m; i++) {
            sum += qrData[i * _n + k] * qrData[i * _n + j];
          }
          sum = -sum / qkk;
          for (var i = k; i < _m; i++) {
            qrData[i * _n + j] += sum * qrData[i * _n + k];
          }
        }
      }
      rdiag[k] = -nrm;
    }
  }

  void _decomposeGeneric() {
    final field = _type.field;
    final zero = field.additiveIdentity;

    for (var k = 0; k < _n; k++) {
      var sumsq = 0.0;
      for (var i = k; i < _m; i++) {
        final norm = field.norm(_qr.getUnchecked(i, k));
        sumsq += norm * norm;
      }
      final nrm = math.sqrt(sumsq);

      if (nrm != 0.0) {
        final xk = _qr.getUnchecked(k, k);
        final normXk = field.norm(xk);
        final T mu;
        if (normXk != 0.0) {
          mu = field.div(xk, _type.cast(normXk));
        } else {
          mu = field.multiplicativeIdentity;
        }

        final vk = field.add(xk, field.mul(mu, _type.cast(nrm)));
        for (var i = k + 1; i < _m; i++) {
          _qr.setUnchecked(i, k, field.div(_qr.getUnchecked(i, k), vk));
        }
        final tau = (nrm + normXk) / nrm;
        _tau[k] = tau;
        final tauT = _type.cast(tau);

        for (var j = k + 1; j < _n; j++) {
          var s = _qr.getUnchecked(k, j);
          for (var i = k + 1; i < _m; i++) {
            s = field.add(
              s,
              field.mul(
                field.conjugate(_qr.getUnchecked(i, k)),
                _qr.getUnchecked(i, j),
              ),
            );
          }
          final tauS = field.mul(tauT, s);
          _qr.setUnchecked(k, j, field.sub(_qr.getUnchecked(k, j), tauS));
          for (var i = k + 1; i < _m; i++) {
            _qr.setUnchecked(
              i,
              j,
              field.sub(
                _qr.getUnchecked(i, j),
                field.mul(tauS, _qr.getUnchecked(i, k)),
              ),
            );
          }
        }
        _rdiag[k] = field.neg(field.mul(mu, _type.cast(nrm)));
      } else {
        _rdiag[k] = zero;
        _tau[k] = 0.0;
      }
    }
  }

  Matrix<double> _qFloat64() {
    final qrData = _qr.tensor.data as Float64List;
    final result = Matrix<double>.filled(_m, _n, 0.0, type: DataType.float64);
    final resData = result.tensor.data as Float64List;
    for (var k = _n - 1; k >= 0; k--) {
      for (var i = 0; i < _m; i++) {
        resData[i * _n + k] = 0.0;
      }
      resData[k * _n + k] = 1.0;
      final qkk = qrData[k * _n + k];
      if (qkk != 0.0) {
        for (var j = k; j < _n; j++) {
          var sum = 0.0;
          for (var i = k; i < _m; i++) {
            sum += qrData[i * _n + k] * resData[i * _n + j];
          }
          sum = -sum / qkk;
          for (var i = k; i < _m; i++) {
            resData[i * _n + j] += sum * qrData[i * _n + k];
          }
        }
      }
    }
    return result;
  }

  Matrix<double> _solveFloat64(Matrix<double> b) {
    final qrData = _qr.tensor.data as Float64List;
    final rdiag = _rdiag as List<double>;
    final nx = b.colCount;
    final x = Matrix<double>.generate(
      _m,
      nx,
      (row, col) => b.getUnchecked(row, col),
      type: DataType.float64,
    );
    final xData = x.tensor.data as Float64List;

    // Compute Y = Q^T * B
    for (var k = 0; k < _n; k++) {
      final qkk = qrData[k * _n + k];
      for (var j = 0; j < nx; j++) {
        var sum = 0.0;
        for (var i = k; i < _m; i++) {
          sum += qrData[i * _n + k] * xData[i * nx + j];
        }
        sum = -sum / qkk;
        for (var i = k; i < _m; i++) {
          xData[i * nx + j] += sum * qrData[i * _n + k];
        }
      }
    }

    // Solve R * X = Y
    for (var k = _n - 1; k >= 0; k--) {
      final rk = rdiag[k];
      final kOffset = k * nx;
      for (var j = 0; j < nx; j++) {
        xData[kOffset + j] /= rk;
      }
      for (var i = 0; i < k; i++) {
        final qik = qrData[i * _n + k];
        final iOffset = i * nx;
        for (var j = 0; j < nx; j++) {
          xData[iOffset + j] -= xData[kOffset + j] * qik;
        }
      }
    }

    return x.subMatrix(rowStart: 0, rowEnd: _n, colStart: 0, colEnd: nx);
  }
}
