library matrix.decomposition.qr;

import 'package:data/type.dart';

import '../matrix.dart';
import '../operators.dart';
import '../utils.dart';

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
  final Matrix<double> QR;

  /// Row and column dimensions.
  final int m, n;

  /// Internal storage of diagonal of R.
  final List<double> Rdiag;

  QRDecomposition(Matrix<num> A)
      : QR = Matrix.builder.rowMajor.withType(valueDataType).from(A),
        m = A.rowCount,
        n = A.colCount,
        Rdiag = valueDataType.newList(A.colCount) {
    // Main loop.
    for (var k = 0; k < n; k++) {
      // Compute 2-norm of k-th column without under/overflow.
      var nrm = 0.0;
      for (var i = k; i < m; i++) {
        nrm = hypot(nrm, QR.getUnchecked(i, k));
      }

      if (nrm != 0.0) {
        // Form k-th Householder vector.
        if (QR.getUnchecked(k, k) < 0) {
          nrm = -nrm;
        }
        for (var i = k; i < m; i++) {
          QR.setUnchecked(i, k, QR.getUnchecked(i, k) / nrm);
        }
        QR.setUnchecked(k, k, QR.getUnchecked(k, k) + 1.0);

        // Apply transformation to remaining columns.
        for (var j = k + 1; j < n; j++) {
          var s = 0.0;
          for (var i = k; i < m; i++) {
            s += QR.getUnchecked(i, k) * QR.getUnchecked(i, j);
          }
          s = -s / QR.getUnchecked(k, k);
          for (var i = k; i < m; i++) {
            QR.setUnchecked(
                i, j, QR.getUnchecked(i, j) + s * QR.getUnchecked(i, k));
          }
        }
      }
      Rdiag[k] = -nrm;
    }
  }

  /// Is the matrix full rank?
  bool get isFullRank {
    for (var j = 0; j < n; j++) {
      if (Rdiag[j] == 0) {
        return false;
      }
    }
    return true;
  }

  /// Returns the Householder vectors: Lower trapezoidal matrix whose columns
  /// define the reflections.
  Matrix<double> get H {
    final result = Matrix.builder.withType(valueDataType)(m, n);
    for (var i = 0; i < m; i++) {
      for (var j = 0; j < n; j++) {
        if (i >= j) {
          result.setUnchecked(i, j, QR.getUnchecked(i, j));
        }
      }
    }
    return result;
  }

  /// Returns the upper triangular factor.
  Matrix<double> get R {
    final result = Matrix.builder.withType(valueDataType)(n, n);
    for (var i = 0; i < n; i++) {
      for (var j = i; j < n; j++) {
        if (i < j) {
          result.setUnchecked(i, j, QR.getUnchecked(i, j));
        } else if (i == j) {
          result.setUnchecked(i, j, Rdiag[i]);
        }
      }
    }
    return result;
  }

  /// Returns the (economy-sized) orthogonal factor.
  Matrix<double> get Q {
    final result = Matrix.builder.withType(valueDataType)(m, n);
    for (var k = n - 1; k >= 0; k--) {
      for (var i = 0; i < m; i++) {
        result.setUnchecked(i, k, 0.0);
      }
      result.setUnchecked(k, k, 1.0);
      for (var j = k; j < n; j++) {
        if (QR.getUnchecked(k, k) != 0) {
          var s = 0.0;
          for (var i = k; i < m; i++) {
            s += QR.getUnchecked(i, k) * result.getUnchecked(i, j);
          }
          s = -s / QR.getUnchecked(k, k);
          for (var i = k; i < m; i++) {
            result.setUnchecked(
                i, j, result.getUnchecked(i, j) + s * QR.getUnchecked(i, k));
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
    if (B.rowCount != m) {
      throw ArgumentError('Matrix row dimensions must agree.');
    }
    if (!isFullRank) {
      throw ArgumentError('Matrix is rank deficient.');
    }

    // Copy right hand side
    final nx = B.colCount;
    final X = Matrix.builder.withType(valueDataType).from(B);

    // Compute Y = transpose(Q)*B
    for (var k = 0; k < n; k++) {
      for (var j = 0; j < nx; j++) {
        var s = 0.0;
        for (var i = k; i < m; i++) {
          s += QR.getUnchecked(i, k) * X.getUnchecked(i, j);
        }
        s = -s / QR.getUnchecked(k, k);
        for (var i = k; i < m; i++) {
          X.setUnchecked(
              i, j, X.getUnchecked(i, j) + s * QR.getUnchecked(i, k));
        }
      }
    }

    // Solve R * X = Y;
    for (var k = n - 1; k >= 0; k--) {
      for (var j = 0; j < nx; j++) {
        X.setUnchecked(k, j, X.getUnchecked(k, j) / Rdiag[k]);
      }
      for (var i = 0; i < k; i++) {
        for (var j = 0; j < nx; j++) {
          X.setUnchecked(
              i,
              j,
              X.getUnchecked(i, j) -
                  X.getUnchecked(k, j) * QR.getUnchecked(i, k));
        }
      }
    }
    return X;
  }
}
