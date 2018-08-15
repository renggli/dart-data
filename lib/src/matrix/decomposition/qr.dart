library matrix.decomposition.qr;

import '../../shared/config.dart';
import '../../shared/math.dart';
import '../matrix.dart';

/// QR Decomposition.
///
/// For an m-by-n matrix A with m >= n, the QR decomposition is an m-by-n
/// orthogonal matrix Q and an n-by-n upper triangular matrix R so that
/// A = Q*R.
///
/// The QR decomposition always exists, even if the matrix does not have
/// full rank, so the constructor will never fail.  The primary use of the
/// QR decomposition is in the least squares solution of nonsquare systems
/// of simultaneous linear equations.  This will fail if isFullRank()
/// returns false.
class QRDecomposition {
  /// Internal storage of decomposition.
  final Matrix<double> _qr;

  /// Row and column dimensions.
  final int _m, _n;

  /// Internal storage of diagonal of R.
  final List<double> _rdiag;

  QRDecomposition(Matrix<num> A)
      : _qr = Matrix.builder.rowMajor.withType(valueDataType).fromMatrix(A),
        _m = A.rowCount,
        _n = A.colCount,
        _rdiag = valueDataType.newList(A.colCount) {
    // Main loop.
    for (var k = 0; k < _n; k++) {
      // Compute 2-norm of k-th column without under/overflow.
      var nrm = 0.0;
      for (var i = k; i < _m; i++) {
        nrm = hypot(nrm, _qr.getUnchecked(i, k));
      }

      if (nrm != 0.0) {
        // Form k-th Householder vector.
        if (_qr.getUnchecked(k, k) < 0) {
          nrm = -nrm;
        }
        for (var i = k; i < _m; i++) {
          _qr.setUnchecked(i, k, _qr.getUnchecked(i, k) / nrm);
        }
        _qr.setUnchecked(k, k, _qr.getUnchecked(k, k) + 1.0);

        // Apply transformation to remaining columns.
        for (var j = k + 1; j < _n; j++) {
          var s = 0.0;
          for (var i = k; i < _m; i++) {
            s += _qr.getUnchecked(i, k) * _qr.getUnchecked(i, j);
          }
          s = -s / _qr.getUnchecked(k, k);
          for (var i = k; i < _m; i++) {
            _qr.setUnchecked(
                i, j, _qr.getUnchecked(i, j) + s * _qr.getUnchecked(i, k));
          }
        }
      }
      _rdiag[k] = -nrm;
    }
  }

  /// Is the matrix full rank?
  bool get isFullRank {
    for (var j = 0; j < _n; j++) {
      if (_rdiag[j] == 0) {
        return false;
      }
    }
    return true;
  }

  /// Returns the Householder vectors: Lower trapezoidal matrix whose columns
  /// define the reflections.
  Matrix<double> get H {
    final result = Matrix.builder.withType(valueDataType)(_m, _n);
    for (var i = 0; i < _m; i++) {
      for (var j = 0; j < _n; j++) {
        if (i >= j) {
          result.setUnchecked(i, j, _qr.getUnchecked(i, j));
        }
      }
    }
    return result;
  }

  /// Returns the upper triangular factor.
  Matrix<double> get R {
    final result = Matrix.builder.withType(valueDataType)(_n, _n);
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

  /// Returns the (economy-sized) orthogonal factor.
  Matrix<double> get Q {
    final result = Matrix.builder.withType(valueDataType)(_m, _n);
    for (var k = _n - 1; k >= 0; k--) {
      for (var i = 0; i < _m; i++) {
        result.setUnchecked(i, k, 0.0);
      }
      result.setUnchecked(k, k, 1.0);
      for (var j = k; j < _n; j++) {
        if (_qr.getUnchecked(k, k) != 0) {
          var s = 0.0;
          for (var i = k; i < _m; i++) {
            s += _qr.getUnchecked(i, k) * result.getUnchecked(i, j);
          }
          s = -s / _qr.getUnchecked(k, k);
          for (var i = k; i < _m; i++) {
            result.setUnchecked(
                i, j, result.getUnchecked(i, j) + s * _qr.getUnchecked(i, k));
          }
        }
      }
    }
    return result;
  }

  /// Least squares solution of A * X = B.
  ///
  /// A Matrix with as many rows as A and any number of columns.
  /// X that minimizes the two norm of Q*R*X-B.
  Matrix<double> solve(Matrix<num> B) {
    if (B.rowCount != _m) {
      throw ArgumentError('Matrix row dimensions must agree.');
    }
    if (!isFullRank) {
      throw ArgumentError('Matrix is rank deficient.');
    }

    // Copy right hand side
    final nx = B.colCount;
    final X = Matrix.builder.withType(valueDataType).fromMatrix(B);

    // Compute Y = transpose(Q)*B
    for (var k = 0; k < _n; k++) {
      for (var j = 0; j < nx; j++) {
        var s = 0.0;
        for (var i = k; i < _m; i++) {
          s += _qr.getUnchecked(i, k) * X.getUnchecked(i, j);
        }
        s = -s / _qr.getUnchecked(k, k);
        for (var i = k; i < _m; i++) {
          X.setUnchecked(
              i, j, X.getUnchecked(i, j) + s * _qr.getUnchecked(i, k));
        }
      }
    }

    // Solve R * X = Y;
    for (var k = _n - 1; k >= 0; k--) {
      for (var j = 0; j < nx; j++) {
        X.setUnchecked(k, j, X.getUnchecked(k, j) / _rdiag[k]);
      }
      for (var i = 0; i < k; i++) {
        for (var j = 0; j < nx; j++) {
          X.setUnchecked(
              i,
              j,
              X.getUnchecked(i, j) -
                  X.getUnchecked(k, j) * _qr.getUnchecked(i, k));
        }
      }
    }
    return X;
  }
}
