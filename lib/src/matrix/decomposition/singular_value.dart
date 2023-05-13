import 'dart:math';
import 'dart:typed_data';

import 'package:more/feature.dart' show isJavaScript;

import '../../../matrix.dart';
import '../../../type.dart';
import '../../../vector.dart';

/// A class which encapsulates the functionality of the singular value
/// decomposition (SVD) for [Matrix].
///
/// Suppose M is an m-by-n matrix whose entries are real numbers. Then there
/// exists a factorization of the form M = U Σ V T where:
///
/// - U is an m-by-m unitary matrix;
/// - Σ is m-by-n diagonal matrix with non-negative real numbers on the
///   diagonal;
/// - VT denotes transpose of V, an n-by-n unitary matrix.
///
/// Such a factorization is called a singular-value decomposition of M. A common
/// convention is to order the diagonal entries Σ(i,i) in descending order. In
/// this case, the diagonal matrix Σ is uniquely determined by M (though the
/// matrices U and V are not). The diagonal entries of Σ are known as the
/// singular values of M.
class SingularValueDecomposition {
  /// Initializes a new instance of the [SingularValueDecomposition].
  SingularValueDecomposition._(
      this._s, this._u, this._vt, this._w, this.vectorsComputed);

  /// Initializes a new instance of the [SingularValueDecomposition].
  /// This object will compute the singular value decomposition
  /// when the constructor is called and cache it's decomposition.
  factory SingularValueDecomposition(Matrix<num> matrix,
      {bool computeVectors = true}) {
    final nm = min(matrix.rowCount, matrix.colCount);

    final uValues = DataType.float64.newList(matrix.rowCount * matrix.rowCount);
    final sValues = DataType.float64.newList(nm);
    final vtValues =
        DataType.float64.newList(matrix.colCount * matrix.colCount);

    _singularValueDecomposition(computeVectors, _columnMajorValuesOf(matrix),
        matrix.rowCount, matrix.colCount, sValues, uValues, vtValues);

    final u = Matrix<double>.fromPackedColumns(
        DataType.float64, matrix.rowCount, matrix.rowCount, uValues);
    final s = Vector<double>.fromList(DataType.float64, sValues);
    final vt = Matrix<double>.fromPackedColumns(
        DataType.float64, matrix.colCount, matrix.colCount, vtValues);
    final w = Matrix<double>.generate(
        DataType.float64, u.rowCount, vt.colCount, (r, c) => r == c ? s[r] : 0);

    return SingularValueDecomposition._(s, u, vt, w, computeVectors);
  }

  final Vector<double> _s;
  final Matrix<double> _u;
  final Matrix<double> _vt;
  final Matrix<double> _w;

  /// Indicating whether U and VT matrices have been computed during SVD
  /// factorization.
  final bool vectorsComputed;

  /// Gets the singular values (Σ) of matrix in ascending value.
  Vector<double> get S => _s;

  /// Gets the left singular vectors (U - m-by-m real orthogonal matrix).
  Matrix<double> get U => _u;

  /// Gets the transpose right singular vectors (transpose of V, an n-by-n real
  /// orthogonal matrix).
  // ignore: non_constant_identifier_names
  Matrix<double> get VT => _vt;

  /// Returns the singular values as a diagonal Matrix.
  Matrix<double> get W => _w;

  /// Gets the effective numerical matrix rank.
  int get rank {
    final tolerance =
        _epsilonOf(max(_u.rowCount, _vt.rowCount) * _s.iterable.reduce(max));
    return _s.iterable.where((t) => t.abs() > tolerance).length;
  }

  /// Gets the two norm of the Matrix.
  double get norm2 => _s[0].abs();

  /// Gets the condition number max(S) / min(S).
  double get cond {
    var tmp = min(_u.rowCount, _vt.colCount) - 1;
    return _s[0].abs() / _s[tmp].abs();
  }

  /// Gets the determinant of the square matrix for which the SVD was computed.
  double get determinant {
    if (_u.rowCount != _vt.colCount) {
      throw ArgumentError('Matrix must be square.');
    }

    var det = 1.0;
    for (var value in _s.iterable) {
      det *= value;
      if (_almostEqual(value.abs(), 0.0)) {
        return 0;
      }
    }

    return det.abs();
  }

  /// Computes the singular value decomposition of A.
  static void _singularValueDecomposition(
      bool computeVectors,
      List<double> a,
      int rowsA,
      int columnsA,
      List<double> s,
      List<double> u,
      List<double> vt) {
    assert(u.length == rowsA * rowsA,
        'The array arguments must have the same length.');
    assert(vt.length == columnsA * columnsA,
        'The array arguments must have the same length.');
    assert(s.length == min(rowsA, columnsA),
        'The array arguments must have the same length.');

    final work = DataType.float64.newList(rowsA);

    const maxIterations = 1000;

    final e = DataType.float64.newList(columnsA);
    final v = DataType.float64.newList(vt.length);
    final stemp = DataType.float64.newList(min(rowsA + 1, columnsA));

    double t;

    final ncu = rowsA;

    // Reduce matrix to bi-diagonal form, storing the diagonal elements in "s"
    // and the super-diagonal elements in "e".
    final nct = min(rowsA - 1, columnsA);
    final nrt = max(0, min(columnsA - 2, rowsA));
    final lu = max(nct, nrt);

    for (var l = 0; l < lu; l++) {
      var lp1 = l + 1;
      if (l < nct) {
        // Compute the transformation for the l-th column and place the l-th
        // diagonal in vector s[l].
        var sum = 0.0;
        for (var i1 = l; i1 < rowsA; i1++) {
          sum += a[(l * rowsA) + i1] * a[(l * rowsA) + i1];
        }

        stemp[l] = sqrt(sum);

        if (stemp[l] != 0.0) {
          if (a[(l * rowsA) + l] != 0.0) {
            stemp[l] = stemp[l].abs() *
                (a[(l * rowsA) + l] / a[(l * rowsA) + l].abs());
          }

          // A part of column "l" of Matrix A from row "l" to end multiply by
          // 1.0 / s[l].
          for (var i = l; i < rowsA; i++) {
            a[(l * rowsA) + i] = a[(l * rowsA) + i] * (1.0 / stemp[l]);
          }

          a[(l * rowsA) + l] = 1.0 + a[(l * rowsA) + l];
        }

        stemp[l] = -stemp[l];
      }

      for (var j = lp1; j < columnsA; j++) {
        if (l < nct) {
          if (stemp[l] != 0.0) {
            // Apply the transformation.
            t = 0.0;
            for (var i = l; i < rowsA; i++) {
              t += a[(j * rowsA) + i] * a[(l * rowsA) + i];
            }

            t = -t / a[(l * rowsA) + l];

            for (var ii = l; ii < rowsA; ii++) {
              a[(j * rowsA) + ii] += t * a[(l * rowsA) + ii];
            }
          }
        }

        // Place the l-th row of matrix into "e" for the subsequent calculation
        // of the row transformation.
        e[j] = a[(j * rowsA) + l];
      }

      if (computeVectors && l < nct) {
        // Place the transformation in "u" for subsequent back multiplication.
        for (var i = l; i < rowsA; i++) {
          u[(l * rowsA) + i] = a[(l * rowsA) + i];
        }
      }

      if (l >= nrt) {
        continue;
      }

      // Compute the l-th row transformation and place the l-th super-diagonal
      // in e(l).
      var enorm = 0.0;
      for (var i = lp1; i < e.length; i++) {
        enorm += e[i] * e[i];
      }

      e[l] = sqrt(enorm);
      if (e[l] != 0.0) {
        if (e[lp1] != 0.0) {
          e[l] = e[l].abs() * (e[lp1] / e[lp1].abs());
        }

        // Scale vector "e" from "lp1" by 1.0 / e[l].
        for (var i = lp1; i < e.length; i++) {
          e[i] = e[i] * (1.0 / e[l]);
        }

        e[lp1] = 1.0 + e[lp1];
      }

      e[l] = -e[l];

      if (lp1 < rowsA && e[l] != 0.0) {
        // Apply the transformation.
        for (var i = lp1; i < rowsA; i++) {
          work[i] = 0.0;
        }

        for (var j = lp1; j < columnsA; j++) {
          for (var ii = lp1; ii < rowsA; ii++) {
            work[ii] += e[j] * a[(j * rowsA) + ii];
          }
        }

        for (var j = lp1; j < columnsA; j++) {
          var ww = -e[j] / e[lp1];
          for (var ii = lp1; ii < rowsA; ii++) {
            a[(j * rowsA) + ii] += ww * work[ii];
          }
        }
      }

      if (!computeVectors) {
        continue;
      }

      // Place the transformation in v for subsequent back multiplication.
      for (var i = lp1; i < columnsA; i++) {
        v[(l * columnsA) + i] = e[i];
      }
    }

    // Set up the final bi-diagonal matrix or order m.
    var m = min(columnsA, rowsA + 1);
    final nctp1 = nct + 1;
    final nrtp1 = nrt + 1;
    if (nct < columnsA) {
      stemp[nctp1 - 1] = a[((nctp1 - 1) * rowsA) + (nctp1 - 1)];
    }

    if (rowsA < m) {
      stemp[m - 1] = 0.0;
    }

    if (nrtp1 < m) {
      e[nrtp1 - 1] = a[((m - 1) * rowsA) + (nrtp1 - 1)];
    }

    e[m - 1] = 0.0;

    // If required, generate "u".
    if (computeVectors) {
      for (var j = nctp1 - 1; j < ncu; j++) {
        for (var i = 0; i < rowsA; i++) {
          u[(j * rowsA) + i] = 0.0;
        }

        u[(j * rowsA) + j] = 1.0;
      }

      for (var l = nct - 1; l >= 0; l--) {
        if (stemp[l] != 0.0) {
          for (var j = l + 1; j < ncu; j++) {
            t = 0.0;
            for (var i = l; i < rowsA; i++) {
              t += u[(j * rowsA) + i] * u[(l * rowsA) + i];
            }

            t = -t / u[(l * rowsA) + l];

            for (var ii = l; ii < rowsA; ii++) {
              u[(j * rowsA) + ii] += t * u[(l * rowsA) + ii];
            }
          }

          // A part of column "l" of matrix A from row "l" to end multiply
          // by -1.0.
          for (var i = l; i < rowsA; i++) {
            u[(l * rowsA) + i] = u[(l * rowsA) + i] * -1.0;
          }

          u[(l * rowsA) + l] = 1.0 + u[(l * rowsA) + l];
          for (var i = 0; i < l; i++) {
            u[(l * rowsA) + i] = 0.0;
          }
        } else {
          for (var i = 0; i < rowsA; i++) {
            u[(l * rowsA) + i] = 0.0;
          }

          u[(l * rowsA) + l] = 1.0;
        }
      }
    }

    // If it is required, generate v.
    if (computeVectors) {
      for (var l = columnsA - 1; l >= 0; l--) {
        var lp1 = l + 1;
        if (l < nrt) {
          if (e[l] != 0.0) {
            for (var j = lp1; j < columnsA; j++) {
              t = 0.0;
              for (var i = lp1; i < columnsA; i++) {
                t += v[(j * columnsA) + i] * v[(l * columnsA) + i];
              }

              t = -t / v[(l * columnsA) + lp1];
              for (var ii = l; ii < columnsA; ii++) {
                v[(j * columnsA) + ii] += t * v[(l * columnsA) + ii];
              }
            }
          }
        }

        for (var i = 0; i < columnsA; i++) {
          v[(l * columnsA) + i] = 0.0;
        }

        v[(l * columnsA) + l] = 1.0;
      }
    }

    // Transform "s" and "e" so that they are double.
    for (var i = 0; i < m; i++) {
      double r;
      if (stemp[i] != 0.0) {
        t = stemp[i];
        r = stemp[i] / t;
        stemp[i] = t;
        if (i < m - 1) {
          e[i] = e[i] / r;
        }

        if (computeVectors) {
          // A part of column "i" of matrix U from row 0 to end multiply by r.
          for (var j = 0; j < rowsA; j++) {
            u[(i * rowsA) + j] = u[(i * rowsA) + j] * r;
          }
        }
      }

      // Exit
      if (i == m - 1) {
        break;
      }

      if (e[i] == 0.0) {
        continue;
      }

      t = e[i];
      r = t / e[i];
      e[i] = t;
      stemp[i + 1] = stemp[i + 1] * r;
      if (!computeVectors) {
        continue;
      }

      // A part of column "i+1" of matrix VT from row 0 to end multiply by r.
      for (var j = 0; j < columnsA; j++) {
        v[((i + 1) * columnsA) + j] = v[((i + 1) * columnsA) + j] * r;
      }
    }

    // Main iteration loop for the singular values.
    var mn = m;
    var iter = 0;

    while (m > 0) {
      // Quit if all the singular values have been found.
      // If too many iterations have been performed throw exception.
      if (iter >= maxIterations) {
        throw ArgumentError('Non convergence exception');
      }

      // This section of the program inspects for negligible elements in the s
      // and e arrays, on completion the variables case and l are set as
      // follows:
      //
      // case = 1: if mS[m] and e[l-1] are negligible and l < m
      // case = 2: if mS[l] is negligible and l < m
      // case = 3: if e[l-1] is negligible, l < m, and mS[l, ..., mS[m] are not
      //           negligible (qr step).
      // case = 4: if e[m-1] is negligible (convergence).
      double ztest;
      double test;
      int l;
      for (l = m - 2; l >= 0; l--) {
        test = stemp[l].abs() + stemp[l + 1].abs();
        ztest = test + e[l].abs();
        if (_almostEqualRelative(ztest, test, 15)) {
          e[l] = 0.0;
          break;
        }
      }

      int kase;
      if (l == m - 2) {
        kase = 4;
      } else {
        int ls;
        for (ls = m - 1; ls > l; ls--) {
          test = 0.0;
          if (ls != m - 1) {
            test = test + e[ls].abs();
          }

          if (ls != l + 1) {
            test = test + e[ls - 1].abs();
          }

          ztest = test + stemp[ls].abs();
          if (_almostEqualRelative(ztest, test, 15)) {
            stemp[ls] = 0.0;
            break;
          }
        }

        if (ls == l) {
          kase = 3;
        } else if (ls == m - 1) {
          kase = 1;
        } else {
          kase = 2;
          l = ls;
        }
      }

      l = l + 1;

      // Perform the task indicated by case.
      int k;
      double f;
      double cs;
      double sn;
      switch (kase) {
        // Deflate negligible s[m].
        case 1:
          f = e[m - 2];
          e[m - 2] = 0.0;
          double t1;
          for (var kk = l; kk < m - 1; kk++) {
            k = m - 2 - kk + l;
            t1 = stemp[k];

            final rotg = _rotg(t1, f);
            t1 = rotg.da;
            f = rotg.db;
            cs = rotg.c;
            sn = rotg.s;

            stemp[k] = t1;
            if (k != l) {
              f = -sn * e[k - 1];
              e[k - 1] = cs * e[k - 1];
            }

            if (computeVectors) {
              // Rotate
              for (var i = 0; i < columnsA; i++) {
                var z = (cs * v[(k * columnsA) + i]) +
                    (sn * v[((m - 1) * columnsA) + i]);
                v[((m - 1) * columnsA) + i] =
                    (cs * v[((m - 1) * columnsA) + i]) -
                        (sn * v[(k * columnsA) + i]);
                v[(k * columnsA) + i] = z;
              }
            }
          }

          break;

        // Split at negligible s[l].
        case 2:
          f = e[l - 1];
          e[l - 1] = 0.0;
          for (var k = l; k < m; k++) {
            var t1 = stemp[k];
            final rotg = _rotg(t1, f);
            t1 = rotg.da;
            f = rotg.db;
            cs = rotg.c;
            sn = rotg.s;

            stemp[k] = t1;
            f = -sn * e[k];
            e[k] = cs * e[k];
            if (computeVectors) {
              // Rotate
              for (var i = 0; i < rowsA; i++) {
                var z =
                    (cs * u[(k * rowsA) + i]) + (sn * u[((l - 1) * rowsA) + i]);
                u[((l - 1) * rowsA) + i] =
                    (cs * u[((l - 1) * rowsA) + i]) - (sn * u[(k * rowsA) + i]);
                u[(k * rowsA) + i] = z;
              }
            }
          }

          break;

        // Perform one qr step.
        case 3:

          // calculate the shift.
          var scale = 0.0;
          scale = max(scale, stemp[m - 1].abs());
          scale = max(scale, stemp[m - 2].abs());
          scale = max(scale, e[m - 2].abs());
          scale = max(scale, stemp[l].abs());
          scale = max(scale, e[l].abs());
          var sm = stemp[m - 1] / scale;
          var smm1 = stemp[m - 2] / scale;
          var emm1 = e[m - 2] / scale;
          var sl = stemp[l] / scale;
          var el = e[l] / scale;
          var b = (((smm1 + sm) * (smm1 - sm)) + (emm1 * emm1)) / 2.0;
          var c = (sm * emm1) * (sm * emm1);
          var shift = 0.0;
          if (b != 0.0 || c != 0.0) {
            shift = sqrt((b * b) + c);
            if (b < 0.0) {
              shift = -shift;
            }

            shift = c / (b + shift);
          }

          f = ((sl + sm) * (sl - sm)) + shift;
          var g = sl * el;

          // Chase zeros.
          for (var k = l; k < m - 1; k++) {
            var rotg = _rotg(f, g);
            f = rotg.da;
            g = rotg.db;
            cs = rotg.c;
            sn = rotg.s;

            if (k != l) {
              e[k - 1] = f;
            }

            f = (cs * stemp[k]) + (sn * e[k]);
            e[k] = (cs * e[k]) - (sn * stemp[k]);
            g = sn * stemp[k + 1];
            stemp[k + 1] = cs * stemp[k + 1];
            if (computeVectors) {
              for (var i = 0; i < columnsA; i++) {
                var z = (cs * v[(k * columnsA) + i]) +
                    (sn * v[((k + 1) * columnsA) + i]);
                v[((k + 1) * columnsA) + i] =
                    (cs * v[((k + 1) * columnsA) + i]) -
                        (sn * v[(k * columnsA) + i]);
                v[(k * columnsA) + i] = z;
              }
            }

            rotg = _rotg(f, g);
            f = rotg.da;
            g = rotg.db;
            cs = rotg.c;
            sn = rotg.s;

            stemp[k] = f;
            f = (cs * e[k]) + (sn * stemp[k + 1]);
            stemp[k + 1] = -(sn * e[k]) + (cs * stemp[k + 1]);
            g = sn * e[k + 1];
            e[k + 1] = cs * e[k + 1];
            if (computeVectors && k < rowsA) {
              for (var i = 0; i < rowsA; i++) {
                var z =
                    (cs * u[(k * rowsA) + i]) + (sn * u[((k + 1) * rowsA) + i]);
                u[((k + 1) * rowsA) + i] =
                    (cs * u[((k + 1) * rowsA) + i]) - (sn * u[(k * rowsA) + i]);
                u[(k * rowsA) + i] = z;
              }
            }
          }

          e[m - 2] = f;
          iter = iter + 1;
          break;

        // Convergence.
        case 4:

          // Make the singular value  positive.
          if (stemp[l] < 0.0) {
            stemp[l] = -stemp[l];
            if (computeVectors) {
              // A part of column "l" of matrix VT from row 0 to end multiply
              // by -1.
              for (var i = 0; i < columnsA; i++) {
                v[(l * columnsA) + i] = v[(l * columnsA) + i] * -1.0;
              }
            }
          }

          // Order the singular value.
          while (l != mn - 1) {
            if (stemp[l] >= stemp[l + 1]) {
              break;
            }

            t = stemp[l];
            stemp[l] = stemp[l + 1];
            stemp[l + 1] = t;
            if (computeVectors && l < columnsA) {
              // Swap columns l, l + 1
              for (var i = 0; i < columnsA; i++) {
                var a = v[((l + 1) * columnsA) + i];
                var b = v[(l * columnsA) + i];
                v[(l * columnsA) + i] = a;
                v[((l + 1) * columnsA) + i] = b;
              }
            }

            if (computeVectors && l < rowsA) {
              // Swap columns l, l + 1
              for (var i = 0; i < rowsA; i++) {
                var a = u[((l + 1) * rowsA) + i];
                var b = u[(l * rowsA) + i];
                u[(l * rowsA) + i] = a;
                u[((l + 1) * rowsA) + i] = b;
              }
            }

            l = l + 1;
          }

          iter = 0;
          m = m - 1;
          break;
      }
    }

    if (computeVectors) {
      // Finally transpose "v" to get "vt" matrix.
      for (var i = 0; i < columnsA; i++) {
        for (var j = 0; j < columnsA; j++) {
          vt[(j * columnsA) + i] = v[(i * columnsA) + j];
        }
      }
    }

    // Copy stemp to s with size adjustment. We are using ported copy of
    // linpack's svd code and it uses a singular vector of length rows+1 when
    // rows < columns. The last element is not used and needs to be removed.
    // We should port lapack's svd routine to remove this problem.
    for (var i = 0; i < min(rowsA, columnsA); i++) {
      s[i] = stemp[i];
    }
  }

  /// Solves a system of linear equations, AX = B, with a SVD factorized.
  Matrix<double> solve(/*Vector<double>|Matrix<double>*/ Object B) {
    if (B is Matrix<num>) {
      return solveMatrix(B);
    } else if (B is Vector<num>) {
      return solveVector(B);
    } else {
      throw ArgumentError.value(B, 'B', 'Not supported input.');
    }
  }

  Matrix<double> solveMatrix(Matrix<num> input) {
    if (!vectorsComputed) {
      throw Exception('The singular vectors were not computed.');
    }
    // The dimension compatibility conditions for X = A\B require the two
    // matrices A and B to have the same number of rows.
    if (_u.rowCount != input.rowCount) {
      throw ArgumentError('Matrix row dimensions must agree.');
    }

    final result =
        Matrix<double>(DataType.float64, _vt.colCount, input.colCount);

    var mn = min(_u.rowCount, _vt.colCount);
    var bn = input.colCount;

    var tmp = List.filled(_vt.colCount, 0.0);

    for (var k = 0; k < bn; k++) {
      for (var j = 0; j < _vt.colCount; j++) {
        var value = 0.0;
        if (j < mn) {
          for (var i = 0; i < _u.rowCount; i++) {
            value += _u.getUnchecked(i, j) * input.getUnchecked(i, k);
          }

          value /= _s[j];
        }

        tmp[j] = value;
      }

      for (var j = 0; j < _vt.colCount; j++) {
        var value = 0.0;
        for (var i = 0; i < _vt.colCount; i++) {
          value += _vt.getUnchecked(i, j) * tmp[i];
        }

        result.setUnchecked(j, k, value);
      }
    }

    return result;
  }

  Matrix<double> solveVector(Vector<num> input) {
    if (!vectorsComputed) {
      throw Exception('The singular vectors were not computed.');
    }
    // Ax=b where A is an m x n matrix.
    // Check that b is a column vector with m entries.
    if (_u.rowCount != input.count) {
      throw ArgumentError('All vectors must have the same dimensionality.');
    }

    final result = Vector<double>(DataType.float64, _vt.colCount);

    var mn = min(_u.rowCount, _vt.colCount);
    var tmp = List.filled(_vt.colCount, 0.0);
    double value;
    for (var j = 0; j < _vt.colCount; j++) {
      value = 0;
      if (j < mn) {
        for (var i = 0; i < _u.rowCount; i++) {
          value += _u.getUnchecked(i, j) * input[i];
        }

        value /= _s[j];
      }

      tmp[j] = value;
    }

    for (var j = 0; j < _vt.colCount; j++) {
      value = 0;
      for (var i = 0; i < _vt.colCount; i++) {
        value += _vt.getUnchecked(i, j) * tmp[i];
      }

      result[j] = value;
    }

    return result.columnMatrix;
  }

  /// Returns values of a given matrix in column major order.
  static List<double> _columnMajorValuesOf(Matrix<num> matrix) {
    final list = List.filled(matrix.rowCount * matrix.colCount, 0.0);
    var index = 0;
    for (var col = 0; col < matrix.colCount; col++) {
      for (var row = 0; row < matrix.rowCount; row++) {
        list[index++] = matrix.getUnchecked(row, col).toDouble();
      }
    }
    return list;
  }

  /// Given the Cartesian coordinates (da, db) of a point p, these function
  /// return the parameters da, db, c, and s associated with the Givens rotation
  /// that zeros the y-coordinate of the point.
  static ({double da, double db, double c, double s}) _rotg(
      double da, double db) {
    double c, s; // out

    final absda = da.abs();
    final absdb = db.abs();
    final roe = (absda > absdb) ? da : db;
    final scale = absda + absdb;

    double r, z;
    if (scale == 0.0) {
      c = 1.0;
      s = 0.0;
      r = 0.0;
      z = 0.0;
    } else {
      final sda = da / scale;
      final sdb = db / scale;
      r = scale * sqrt((sda * sda) + (sdb * sdb));
      if (roe < 0.0) {
        r = -r;
      }

      c = da / r;
      s = db / r;
      z = 1.0;
      if (absda > absdb) {
        z = s;
      }

      if (absdb >= absda && c != 0.0) {
        z = 1.0 / c;
      }
    }

    return (da: r, db: z, c: c, s: s);
  }

  /// Standard epsilon, the maximum relative precision of IEEE 754 double-
  /// precision floating numbers (64 bit). According to the definition of Prof.
  /// Demmel and used in LAPACK and Scilab.
  static final _doublePrecision = pow(2, -53).toDouble();

  /// Value representing 10 * 2^(-53) = 1.11022302462516E-15
  static final _defaultDoubleAccuracy = _doublePrecision * 10;

  /// Evaluates the minimum distance to the next distinguishable number near the
  /// argument value. Note: Bytedata.setInt64 and getInt64 are not supported in
  /// JavaScript.
  static double _epsilonOf(double value) {
    if (value.isInfinite || value.isNaN) {
      return double.nan;
    }

    // javascript is not supporting Int64.
    if (isJavaScript) {
      return value * _defaultDoubleAccuracy;
    }

    var byteData = ByteData(8);
    byteData.setFloat64(0, value);
    var signed64 = byteData.getInt64(0);
    if (signed64 == 0) {
      signed64++;
      byteData.setInt64(0, signed64);
      return byteData.getFloat64(0) - value;
    }
    if (signed64-- < 0) {
      byteData.setInt64(0, signed64);
      return byteData.getFloat64(0) - value;
    }
    byteData.setInt64(0, signed64);
    return value - byteData.getFloat64(0);
  }

  /// Checks whether two real numbers are almost equal. Returns true if the two
  /// values differ by no more than 10 * 2^(-52); false otherwise.
  static bool _almostEqual(double a, double b) => DataType.float64.equality
      .isClose((a - b).abs(), 0.0, _defaultDoubleAccuracy);

  /// Returns the magnitude of the number.
  ///
  /// magnitude(1E10) returns 10.
  /// magnitude(1E-10) returns -10.
  /// magnitude(1.1E5) returns 5.
  /// magnitude(-1.1E5) returns 5.
  static int _magnitude(double value) {
    // Can't do this with zero because the 10-log of zero doesn't exist.
    if (value == 0.0) {
      return 0;
    }

    // Note that we need the absolute value of the input because Log10 doesn't
    // work for negative numbers (obviously).
    final magnitude = log(value.abs()) / ln10;
    final truncated = magnitude.truncate();

    // To get the right number we need to know if the value is negative or
    // positive truncating a positive number will always give use the correct
    // magnitude truncating a negative number will give us a magnitude that is
    // off by 1 (unless integer)
    return magnitude < 0 && truncated != magnitude ? truncated - 1 : truncated;
  }

  /// Compares two doubles and determines if they are equal to within the
  /// specified number of decimal places or not. If the numbers are very close
  /// to zero an absolute difference is compared, otherwise the relative
  /// difference is compared.
  static bool _almostEqualRelative(double a, double b, int decimalPlaces) {
    if (decimalPlaces < 0) {
      // Can't have a negative number of decimal places
      throw ArgumentError(decimalPlaces);
    }

    // If A or B are a NAN, return false. NANs are equal to nothing, not even
    // themselves.
    if (a.isNaN || b.isNaN) {
      return false;
    }

    // If A or B are infinity (positive or negative) then only return true if
    // they are exactly equal to each other - that is, if they are both
    // infinities of the same sign.
    if (a.isInfinite || b.isInfinite) {
      return a == b;
    }

    // If both numbers are equal, get out now. This should remove the
    // possibility of both numbers being zero and any problems associated with
    // that.
    if (a == b) {
      return true;
    }

    // If one is almost zero, fall back to absolute equality
    if (a.abs() < _doublePrecision || b.abs() < _doublePrecision) {
      // The values are equal if the difference between the two numbers is
      // smaller than 10^(-numberOfDecimalPlaces). We divide by two so that we
      // have half the range on each side of the numbers, e.g. if decimalPlaces
      // == 2, then 0.01 will equal between 0.005 and 0.015, but not 0.02 and
      // not 0.00.
      return (a - b).abs() < pow(10, -decimalPlaces) * 0.5;
    }

    // If the magnitudes of the two numbers are equal to within one magnitude
    // the numbers could potentially be equal.
    final magnitudeOfFirst = _magnitude(a);
    final magnitudeOfSecond = _magnitude(b);
    final magnitudeOfMax = max(magnitudeOfFirst, magnitudeOfSecond);
    if (magnitudeOfMax > (min(magnitudeOfFirst, magnitudeOfSecond) + 1)) {
      return false;
    }

    // The values are equal if the difference between the two numbers is smaller
    // than 10^(-numberOfDecimalPlaces). We divide by two so that we have half
    // the range on each side of the numbers, e.g. if decimalPlaces == 2, then
    // 0.01 will equal between 0.00995 and 0.01005, but not 0.0015 and not
    // 0.0095.
    return (a - b).abs() < pow(10, magnitudeOfMax - decimalPlaces) * 0.5;
  }
}

extension SingularValueDecompositionExtension<T extends num> on Matrix<T> {
  /// Gets the singular value decomposition of this [Matrix].
  SingularValueDecomposition get singularValue =>
      singularValueDecomposition(computeVectors: true);

  /// Gets the singular value decomposition of this [Matrix].
  SingularValueDecomposition singularValueDecomposition(
          {bool computeVectors = true}) =>
      SingularValueDecomposition(this, computeVectors: computeVectors);

  /// Gets the rank, the effective numerical rank of this [Matrix].
  int get rank => singularValueDecomposition(computeVectors: false).rank;

  /// Calculates the nullity of the matrix.
  int get nullity => colCount - rank;

  /// Returns the condition, the ratio of largest to smallest singular value of
  /// this [Matrix].
  double get cond => singularValueDecomposition(computeVectors: false).cond;
}
