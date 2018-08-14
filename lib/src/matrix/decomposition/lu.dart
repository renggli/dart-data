library matrix.decomposition.lu;

import 'dart:math' as math;

import '../matrix.dart';
import '../utils.dart';

/// LU Decomposition.
///
/// For an m-by-n matrix A with m >= n, the LU decomposition is an m-by-n
/// unit lower triangular matrix L, an n-by-n upper triangular matrix U,
/// and a permutation vector piv of length m so that A(piv,:) = L*U.
/// If m < n, then L is m-by-m and U is m-by-n.
///
/// The LU decomposition with pivoting always exists, even if the matrix is
/// singular, so the constructor will never fail.  The primary use of the
/// LU decomposition is in the solution of square systems of simultaneous
/// linear equations.  This will fail if [isNonsingular] returns false.
class LUDecomposition {
  /// Internal storage of decomposition.
  final Matrix<double> LU;

  /// Internal row and column dimensions.
  final int m, n;

  /// Internal pivot sign.
  int pivsign;

  /// Internal storage of pivot vector.
  final List<int> piv;

  LUDecomposition(Matrix<num> A)
      : LU = Matrix.builder.rowMajor.withType(valueDataType).from(A),
        m = A.rowCount,
        n = A.colCount,
        piv = indexDataType.newList(A.rowCount) {
    // Use a 'left-looking', dot-product, Crout/Doolittle algorithm.
    for (var i = 0; i < m; i++) {
      piv[i] = i;
    }
    pivsign = 1;
    final LUcolj = valueDataType.newList(m);

    // Outer loop.
    for (var j = 0; j < n; j++) {
      // Make a copy of the j-th column to localize references.
      for (var i = 0; i < m; i++) {
        LUcolj[i] = LU.getUnchecked(i, j);
      }

      // Apply previous transformations.
      for (var i = 0; i < m; i++) {
        final LUrowi = LU.row(i);

        // Most of the time is spent in the following dot product.
        var kmax = math.min(i, j);
        var s = 0.0;
        for (var k = 0; k < kmax; k++) {
          s += LUrowi[k] * LUcolj[k];
        }

        LUrowi[j] = LUcolj[i] -= s;
      }

      // Find pivot and exchange if necessary.
      var p = j;
      for (var i = j + 1; i < m; i++) {
        if (LUcolj[i].abs() > LUcolj[p].abs()) {
          p = i;
        }
      }
      if (p != j) {
        for (var k = 0; k < n; k++) {
          final t = LU.getUnchecked(p, k);
          LU.setUnchecked(p, k, LU.getUnchecked(j, k));
          LU.setUnchecked(j, k, t);
        }
        final k = piv[p];
        piv[p] = piv[j];
        piv[j] = k;
        pivsign = -pivsign;
      }

      // Compute multipliers.
      if (j < m && LU.getUnchecked(j, j) != 0.0) {
        for (var i = j + 1; i < m; i++) {
          LU.setUnchecked(i, j, LU.getUnchecked(i, j) / LU.getUnchecked(j, j));
        }
      }
    }
  }

  /// Is the matrix nonsingular?
  bool get isNonsingular {
    for (var j = 0; j < n; j++) {
      if (LU.getUnchecked(j, j) == 0.0) {
        return false;
      }
    }
    return true;
  }

  /// Returns the lower triangular factor.
  Matrix<double> get L {
    final X = Matrix.builder.diagonal.withType(valueDataType)(m, n);
    for (var i = 0; i < m; i++) {
      for (var j = 0; j < n; j++) {
        if (i > j) {
          L.setUnchecked(i, j, LU.getUnchecked(i, j));
        } else if (i == j) {
          L.setUnchecked(i, j, 1.0);
        }
      }
    }
    return X;
  }

  /// Returns upper triangular factor.
  Matrix<double> get U {
    final X = Matrix.builder.diagonal.withType(valueDataType)(n, n);
    for (var i = 0; i < n; i++) {
      for (var j = 0; j < n; j++) {
        if (i <= j) {
          U.setUnchecked(i, j, LU.getUnchecked(i, j));
        }
      }
    }
    return X;
  }

  /// Returns pivot permutation vector.
  List<int> get pivot => indexDataType.copyList(piv);

  /// Returns the determinant.
  double get det {
    if (m != n) {
      throw ArgumentError('Matrix must be square.');
    }
    var d = 1.0;
    for (var j = 0; j < n; j++) {
      d *= LU.getUnchecked(j, j);
    }
    return d * pivsign;
  }

  /// Solve A*X = B
  /// @param  B   A Matrix with as many rows as A and any number of columns.
  /// @return     X so that L*U*X = B(piv,:)
  /// @exception  IllegalArgumentException Matrix row dimensions must agree.
  /// @exception  RuntimeException  Matrix is singular.
  Matrix<double> solve(Matrix<num> B) {
    if (B.rowCount != m) {
      throw ArgumentError('Matrix row dimensions must agree.');
    }
    if (!isNonsingular) {
      throw ArgumentError('Matrix is singular.');
    }

    // Copy right hand side with pivoting
    final nx = B.colCount;
    final X = Matrix.builder
        .withType(valueDataType)
        .fromIndicesAndRange(B, piv, 0, nx);

    // Solve L*Y = B(piv,:)
    for (var k = 0; k < n; k++) {
      for (var i = k + 1; i < n; i++) {
        for (var j = 0; j < nx; j++) {
          X.setUnchecked(
              i,
              j,
              X.getUnchecked(i, j) -
                  X.getUnchecked(k, j) * LU.getUnchecked(i, k));
        }
      }
    }

    // Solve U*X = Y;
    for (var k = n - 1; k >= 0; k--) {
      for (var j = 0; j < nx; j++) {
        X.setUnchecked(k, j, X.getUnchecked(k, j) / LU.getUnchecked(k, k));
      }
      for (var i = 0; i < k; i++) {
        for (var j = 0; j < nx; j++) {
          X.setUnchecked(
              i,
              j,
              X.getUnchecked(i, j) -
                  X.getUnchecked(k, j) * LU.getUnchecked(i, k));
        }
      }
    }
    return X;
  }
}
