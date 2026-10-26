import 'dart:math' as math;

import '../../type/data_type.dart';
import '../matrix.dart';
import '../vector.dart';

/// Extension methods providing Singular Value Decomposition (SVD) on numeric
/// matrices.
extension SvdMatrixExtension<T extends num> on Matrix<T> {
  /// Computes the Singular Value Decomposition (SVD) of this matrix.
  SingularValueDecomposition get svd =>
      SingularValueDecomposition(_toDoubleMatrix());

  Matrix<double> _toDoubleMatrix() => this is Matrix<double>
      ? this as Matrix<double>
      : Matrix<double>.generate(
          rowCount,
          colCount,
          (r, c) => getUnchecked(r, c).toDouble(),
          type: DataType.float64,
        );
}

/// Singular Value Decomposition (SVD) of an $m \times n$ matrix $A$.
///
/// Conceptually, SVD breaks any matrix down into three intuitive geometric
/// steps: an initial rotation ($V^T$), scaling along coordinate axes
/// ($\Sigma$), and a second rotation ($U$). More formally, it computes
/// $A = U \Sigma V^T$ where $U \in \mathbb{R}^{m \times m}$ and
/// $V \in \mathbb{R}^{n \times n}$ are orthogonal matrices and $\Sigma$
/// contains singular values $\sigma_1 \ge \sigma_2 \ge \dots \ge 0$ in
/// non-increasing order.
///
/// ```dart
/// final a = Matrix<double>.fromRows([
///   [3.0, 0.0],
///   [0.0, 4.0],
/// ]);
/// final svd = a.svd;
/// print(svd.s); // [4.0, 3.0]
/// ```
class SingularValueDecomposition {
  /// Computes the SVD of [matrix].
  factory(Matrix<num> matrix, {bool computeVectors = true}) {
    final rowsA = matrix.rowCount;
    final colsA = matrix.colCount;
    final nm = math.min(rowsA, colsA);

    final aVals = List<double>.generate(rowsA * colsA, (idx) {
      final col = idx ~/ rowsA;
      final row = idx % rowsA;
      return matrix.getUnchecked(row, col).toDouble();
    });

    final uVals = List<double>.filled(rowsA * rowsA, 0.0);
    final sVals = List<double>.filled(nm, 0.0);
    final vtVals = List<double>.filled(colsA * colsA, 0.0);

    _computeSvd(computeVectors, aVals, rowsA, colsA, sVals, uVals, vtVals);

    final uMatrix = Matrix<double>.generate(
      rowsA,
      rowsA,
      (row, col) => uVals[col * rowsA + row],
      type: DataType.float64,
    );
    final sVector = Vector<double>.fromList(sVals, type: DataType.float64);
    final vtMatrix = Matrix<double>.generate(
      colsA,
      colsA,
      (row, col) => vtVals[col * colsA + row],
      type: DataType.float64,
    );

    return SingularValueDecomposition._(
      sVector,
      uMatrix,
      vtMatrix,
      computeVectors,
    );
  }

  const new _(this.s, this.u, this.vt, this.vectorsComputed);

  /// The singular values in descending order.
  final Vector<double> s;

  /// The left singular vectors as an $m \times m$ orthogonal matrix.
  final Matrix<double> u;

  /// The transpose of right singular vectors as an $n \times n$ orthogonal
  /// matrix.
  final Matrix<double> vt;

  /// Whether singular vectors were computed.
  final bool vectorsComputed;

  /// The right singular vectors as an $n \times n$ orthogonal matrix.
  Matrix<double> get v => vt.transposed;

  /// Returns the diagonal matrix of singular values of size $m \times n$.
  Matrix<double> get sigma => Matrix<double>.generate(
    u.rowCount,
    vt.colCount,
    (row, col) => row == col && row < s.length ? s[row] : 0.0,
    type: DataType.float64,
  );

  /// The effective numerical rank of the matrix.
  int get rank {
    if (s.length == 0) return 0;
    final maxDim = math.max(u.rowCount, vt.colCount);
    final maxS = s[0].abs();
    final tol = maxDim * maxS * 2.220446049250313e-16;
    var count = 0;
    for (var i = 0; i < s.length; i++) {
      if (s[i].abs() > tol) count++;
    }
    return count;
  }

  /// The 2-norm (largest singular value).
  double get norm2 => s.length > 0 ? s[0].abs() : 0.0;

  /// Condition number $\sigma_{\max} / \sigma_{\min}$.
  double get cond {
    if (s.length == 0) return 0.0;
    final minS = s[s.length - 1].abs();
    return minS == 0.0 ? double.infinity : s[0].abs() / minS;
  }

  /// Solves the linear system $A x \approx b$ using minimum norm least squares.
  Vector<double> solveVector(Vector<num> b, {double? tolerance}) {
    if (!vectorsComputed) {
      throw StateError('Singular vectors were not computed.');
    }
    if (u.rowCount != b.length) {
      throw ArgumentError(
        'Vector length (${b.length}) must match rowCount (${u.rowCount}).',
      );
    }
    final cols = vt.colCount;
    final mn = math.min(u.rowCount, cols);
    final tmp = List<double>.filled(cols, 0.0);
    final maxDim = math.max(u.rowCount, cols);
    final maxS = s.length > 0 ? s[0].abs() : 0.0;
    final tol = tolerance ?? maxDim * maxS * 2.220446049250313e-16;

    for (var j = 0; j < cols; j++) {
      var val = 0.0;
      if (j < mn) {
        for (var i = 0; i < u.rowCount; i++) {
          val += u.getUnchecked(i, j) * b.getUnchecked(i).toDouble();
        }
        val = s[j].abs() > tol ? val / s[j] : 0.0;
      }
      tmp[j] = val;
    }

    final result = List<double>.filled(cols, 0.0);
    for (var j = 0; j < cols; j++) {
      var val = 0.0;
      for (var i = 0; i < cols; i++) {
        val += vt.getUnchecked(i, j) * tmp[i];
      }
      result[j] = val;
    }

    return Vector<double>.fromList(result, type: DataType.float64);
  }

  /// Solves the linear system $A X \approx B$ using minimum norm least squares.
  Matrix<double> solve(Matrix<num> b, {double? tolerance}) {
    if (!vectorsComputed) {
      throw StateError('Singular vectors were not computed.');
    }
    if (u.rowCount != b.rowCount) {
      throw ArgumentError(
        'Matrix row count (${b.rowCount}) must match rowCount (${u.rowCount}).',
      );
    }
    final cols = vt.colCount;
    final nrhs = b.colCount;
    final mn = math.min(u.rowCount, cols);
    final maxDim = math.max(u.rowCount, cols);
    final maxS = s.length > 0 ? s[0].abs() : 0.0;
    final tol = tolerance ?? maxDim * maxS * 2.220446049250313e-16;

    final result = Matrix<double>.filled(
      cols,
      nrhs,
      0.0,
      type: DataType.float64,
    );
    final tmp = List<double>.filled(cols, 0.0);

    for (var col = 0; col < nrhs; col++) {
      for (var j = 0; j < cols; j++) {
        var val = 0.0;
        if (j < mn) {
          for (var i = 0; i < u.rowCount; i++) {
            val += u.getUnchecked(i, j) * b.getUnchecked(i, col).toDouble();
          }
          val = s[j].abs() > tol ? val / s[j] : 0.0;
        }
        tmp[j] = val;
      }

      for (var j = 0; j < cols; j++) {
        var val = 0.0;
        for (var i = 0; i < cols; i++) {
          val += vt.getUnchecked(i, j) * tmp[i];
        }
        result.setUnchecked(j, col, val);
      }
    }

    return result;
  }

  static ({double da, double db, double cosVal, double sinVal}) _rotg(
    double da,
    double db,
  ) {
    final absda = da.abs();
    final absdb = db.abs();
    final roe = (absda > absdb) ? da : db;
    final scale = absda + absdb;

    double rVal, zVal, cosVal, sinVal;
    if (scale == 0.0) {
      cosVal = 1.0;
      sinVal = 0.0;
      rVal = 0.0;
      zVal = 0.0;
    } else {
      final sda = da / scale;
      final sdb = db / scale;
      rVal = scale * math.sqrt(sda * sda + sdb * sdb);
      if (roe < 0.0) rVal = -rVal;
      cosVal = da / rVal;
      sinVal = db / rVal;
      zVal = 1.0;
      if (absda > absdb) zVal = sinVal;
      if (absdb >= absda && cosVal != 0.0) zVal = 1.0 / cosVal;
    }
    return (da: rVal, db: zVal, cosVal: cosVal, sinVal: sinVal);
  }

  static void _computeSvd(
    bool computeVectors,
    List<double> a,
    int rowsA,
    int colsA,
    List<double> sVals,
    List<double> uVals,
    List<double> vtVals,
  ) {
    final work = List<double>.filled(rowsA, 0.0);
    final eList = List<double>.filled(colsA, 0.0);
    final vList = List<double>.filled(colsA * colsA, 0.0);
    final stemp = List<double>.filled(math.min(rowsA + 1, colsA), 0.0);

    final ncu = rowsA;
    final nct = math.min(rowsA - 1, colsA);
    final nrt = math.max(0, math.min(colsA - 2, rowsA));
    final lu = math.max(nct, nrt);

    for (var lIdx = 0; lIdx < lu; lIdx++) {
      final lp1 = lIdx + 1;
      if (lIdx < nct) {
        var sum = 0.0;
        for (var i = lIdx; i < rowsA; i++) {
          final val = a[lIdx * rowsA + i];
          sum += val * val;
        }
        stemp[lIdx] = math.sqrt(sum);
        if (stemp[lIdx] != 0.0) {
          if (a[lIdx * rowsA + lIdx] != 0.0) {
            stemp[lIdx] =
                stemp[lIdx].abs() *
                (a[lIdx * rowsA + lIdx] / a[lIdx * rowsA + lIdx].abs());
          }
          for (var i = lIdx; i < rowsA; i++) {
            a[lIdx * rowsA + i] /= stemp[lIdx];
          }
          a[lIdx * rowsA + lIdx] += 1.0;
        }
        stemp[lIdx] = -stemp[lIdx];
      }

      for (var j = lp1; j < colsA; j++) {
        if (lIdx < nct && stemp[lIdx] != 0.0) {
          var tVal = 0.0;
          for (var i = lIdx; i < rowsA; i++) {
            tVal += a[j * rowsA + i] * a[lIdx * rowsA + i];
          }
          tVal = -tVal / a[lIdx * rowsA + lIdx];
          for (var ii = lIdx; ii < rowsA; ii++) {
            a[j * rowsA + ii] += tVal * a[lIdx * rowsA + ii];
          }
        }
        eList[j] = a[j * rowsA + lIdx];
      }

      if (computeVectors && lIdx < nct) {
        for (var i = lIdx; i < rowsA; i++) {
          uVals[lIdx * rowsA + i] = a[lIdx * rowsA + i];
        }
      }

      if (lIdx < nrt) {
        var enorm = 0.0;
        for (var i = lp1; i < eList.length; i++) {
          enorm += eList[i] * eList[i];
        }
        eList[lIdx] = math.sqrt(enorm);
        if (eList[lIdx] != 0.0) {
          if (eList[lp1] != 0.0) {
            eList[lIdx] = eList[lIdx].abs() * (eList[lp1] / eList[lp1].abs());
          }
          for (var i = lp1; i < eList.length; i++) {
            eList[i] /= eList[lIdx];
          }
          eList[lp1] += 1.0;
        }
        eList[lIdx] = -eList[lIdx];

        if (lp1 < rowsA && eList[lIdx] != 0.0) {
          for (var i = lp1; i < rowsA; i++) {
            work[i] = 0.0;
          }
          for (var j = lp1; j < colsA; j++) {
            for (var ii = lp1; ii < rowsA; ii++) {
              work[ii] += eList[j] * a[j * rowsA + ii];
            }
          }
          for (var j = lp1; j < colsA; j++) {
            final ww = -eList[j] / eList[lp1];
            for (var ii = lp1; ii < rowsA; ii++) {
              a[j * rowsA + ii] += ww * work[ii];
            }
          }
        }

        if (computeVectors) {
          for (var i = lp1; i < colsA; i++) {
            vList[lIdx * colsA + i] = eList[i];
          }
        }
      }
    }

    var mDim = math.min(colsA, rowsA + 1);
    final nctp1 = nct + 1;
    final nrtp1 = nrt + 1;
    if (nct < colsA) {
      stemp[nctp1 - 1] = a[(nctp1 - 1) * rowsA + (nctp1 - 1)];
    }
    if (rowsA < mDim) {
      stemp[mDim - 1] = 0.0;
    }
    if (nrtp1 < mDim) {
      eList[nrtp1 - 1] = a[(mDim - 1) * rowsA + (nrtp1 - 1)];
    }
    eList[mDim - 1] = 0.0;

    if (computeVectors) {
      for (var j = nctp1 - 1; j < ncu; j++) {
        for (var i = 0; i < rowsA; i++) {
          uVals[j * rowsA + i] = 0.0;
        }
        uVals[j * rowsA + j] = 1.0;
      }
      for (var lIdx = nct - 1; lIdx >= 0; lIdx--) {
        if (stemp[lIdx] != 0.0) {
          for (var j = lIdx + 1; j < ncu; j++) {
            var tVal = 0.0;
            for (var i = lIdx; i < rowsA; i++) {
              tVal += uVals[j * rowsA + i] * uVals[lIdx * rowsA + i];
            }
            tVal = -tVal / uVals[lIdx * rowsA + lIdx];
            for (var ii = lIdx; ii < rowsA; ii++) {
              uVals[j * rowsA + ii] += tVal * uVals[lIdx * rowsA + ii];
            }
          }
          for (var i = lIdx; i < rowsA; i++) {
            uVals[lIdx * rowsA + i] = -uVals[lIdx * rowsA + i];
          }
          uVals[lIdx * rowsA + lIdx] = 1.0 + uVals[lIdx * rowsA + lIdx];
          for (var i = 0; i < lIdx; i++) {
            uVals[lIdx * rowsA + i] = 0.0;
          }
        } else {
          for (var i = 0; i < rowsA; i++) {
            uVals[lIdx * rowsA + i] = 0.0;
          }
          uVals[lIdx * rowsA + lIdx] = 1.0;
        }
      }

      for (var lIdx = colsA - 1; lIdx >= 0; lIdx--) {
        final lp1 = lIdx + 1;
        if (lIdx < nrt && eList[lIdx] != 0.0) {
          for (var j = lp1; j < colsA; j++) {
            var tVal = 0.0;
            for (var i = lp1; i < colsA; i++) {
              tVal += vList[j * colsA + i] * vList[lIdx * colsA + i];
            }
            tVal = -tVal / vList[lIdx * colsA + lp1];
            for (var ii = lIdx; ii < colsA; ii++) {
              vList[j * colsA + ii] += tVal * vList[lIdx * colsA + ii];
            }
          }
        }
        for (var i = 0; i < colsA; i++) {
          vList[lIdx * colsA + i] = 0.0;
        }
        vList[lIdx * colsA + lIdx] = 1.0;
      }
    }

    final mn = mDim;
    var iter = 0;
    while (mDim > 0) {
      if (iter >= 1000) break;

      int lIdx;
      for (lIdx = mDim - 2; lIdx >= 0; lIdx--) {
        final test = stemp[lIdx].abs() + stemp[lIdx + 1].abs();
        final ztest = test + eList[lIdx].abs();
        if ((ztest - test).abs() < 1e-15 * test) {
          eList[lIdx] = 0.0;
          break;
        }
      }

      int kase;
      if (lIdx == mDim - 2) {
        kase = 4;
      } else {
        int lsIdx;
        for (lsIdx = mDim - 1; lsIdx > lIdx; lsIdx--) {
          var test = 0.0;
          if (lsIdx != mDim - 1) test += eList[lsIdx].abs();
          if (lsIdx != lIdx + 1) test += eList[lsIdx - 1].abs();
          final ztest = test + stemp[lsIdx].abs();
          if ((ztest - test).abs() < 1e-15 * test) {
            stemp[lsIdx] = 0.0;
            break;
          }
        }
        if (lsIdx == lIdx) {
          kase = 3;
        } else if (lsIdx == mDim - 1) {
          kase = 1;
        } else {
          kase = 2;
          lIdx = lsIdx;
        }
      }
      lIdx = lIdx + 1;

      switch (kase) {
        case 1:
          var fVal = eList[mDim - 2];
          eList[mDim - 2] = 0.0;
          for (var kk = lIdx; kk < mDim - 1; kk++) {
            final k = mDim - 2 - kk + lIdx;
            var t1 = stemp[k];
            final rotg = _rotg(t1, fVal);
            t1 = rotg.da;
            fVal = rotg.db;
            final cs = rotg.cosVal;
            final sn = rotg.sinVal;
            stemp[k] = t1;
            if (k != lIdx) {
              fVal = -sn * eList[k - 1];
              eList[k - 1] = cs * eList[k - 1];
            }
            if (computeVectors) {
              for (var i = 0; i < colsA; i++) {
                final z =
                    cs * vList[k * colsA + i] +
                    sn * vList[(mDim - 1) * colsA + i];
                vList[(mDim - 1) * colsA + i] =
                    cs * vList[(mDim - 1) * colsA + i] -
                    sn * vList[k * colsA + i];
                vList[k * colsA + i] = z;
              }
            }
          }
        case 2:
          var fVal = eList[lIdx - 1];
          eList[lIdx - 1] = 0.0;
          for (var k = lIdx; k < mDim; k++) {
            var t1 = stemp[k];
            final rotg = _rotg(t1, fVal);
            t1 = rotg.da;
            fVal = rotg.db;
            final cs = rotg.cosVal;
            final sn = rotg.sinVal;
            stemp[k] = t1;
            fVal = -sn * eList[k];
            eList[k] = cs * eList[k];
            if (computeVectors) {
              for (var i = 0; i < rowsA; i++) {
                final z =
                    cs * uVals[k * rowsA + i] +
                    sn * uVals[(lIdx - 1) * rowsA + i];
                uVals[(lIdx - 1) * rowsA + i] =
                    cs * uVals[(lIdx - 1) * rowsA + i] -
                    sn * uVals[k * rowsA + i];
                uVals[k * rowsA + i] = z;
              }
            }
          }
        case 3:
          var scale = 0.0;
          scale = math.max(scale, stemp[mDim - 1].abs());
          scale = math.max(scale, stemp[mDim - 2].abs());
          scale = math.max(scale, eList[mDim - 2].abs());
          scale = math.max(scale, stemp[lIdx].abs());
          scale = math.max(scale, eList[lIdx].abs());
          final sm = stemp[mDim - 1] / scale;
          final smm1 = stemp[mDim - 2] / scale;
          final emm1 = eList[mDim - 2] / scale;
          final sl = stemp[lIdx] / scale;
          final el = eList[lIdx] / scale;
          final b = ((smm1 + sm) * (smm1 - sm) + emm1 * emm1) / 2.0;
          final cVal = (sm * emm1) * (sm * emm1);
          var shift = 0.0;
          if (b != 0.0 || cVal != 0.0) {
            shift = math.sqrt(b * b + cVal);
            if (b < 0.0) shift = -shift;
            shift = cVal / (b + shift);
          }
          var fVal = (sl + sm) * (sl - sm) + shift;
          var gVal = sl * el;
          for (var k = lIdx; k < mDim - 1; k++) {
            var rotg = _rotg(fVal, gVal);
            fVal = rotg.da;
            gVal = rotg.db;
            var cs = rotg.cosVal;
            var sn = rotg.sinVal;
            if (k != lIdx) eList[k - 1] = fVal;
            fVal = cs * stemp[k] + sn * eList[k];
            eList[k] = cs * eList[k] - sn * stemp[k];
            gVal = sn * stemp[k + 1];
            stemp[k + 1] = cs * stemp[k + 1];
            if (computeVectors) {
              for (var i = 0; i < colsA; i++) {
                final z =
                    cs * vList[k * colsA + i] + sn * vList[(k + 1) * colsA + i];
                vList[(k + 1) * colsA + i] =
                    cs * vList[(k + 1) * colsA + i] - sn * vList[k * colsA + i];
                vList[k * colsA + i] = z;
              }
            }
            rotg = _rotg(fVal, gVal);
            fVal = rotg.da;
            gVal = rotg.db;
            cs = rotg.cosVal;
            sn = rotg.sinVal;
            stemp[k] = fVal;
            fVal = cs * eList[k] + sn * stemp[k + 1];
            stemp[k + 1] = -sn * eList[k] + cs * stemp[k + 1];
            gVal = sn * eList[k + 1];
            eList[k + 1] = cs * eList[k + 1];
            if (computeVectors && k < rowsA) {
              for (var i = 0; i < rowsA; i++) {
                final z =
                    cs * uVals[k * rowsA + i] + sn * uVals[(k + 1) * rowsA + i];
                uVals[(k + 1) * rowsA + i] =
                    cs * uVals[(k + 1) * rowsA + i] - sn * uVals[k * rowsA + i];
                uVals[k * rowsA + i] = z;
              }
            }
          }
          eList[mDim - 2] = fVal;
          iter++;
        case 4:
          if (stemp[lIdx] < 0.0) {
            stemp[lIdx] = -stemp[lIdx];
            if (computeVectors) {
              for (var i = 0; i < colsA; i++) {
                vList[lIdx * colsA + i] = -vList[lIdx * colsA + i];
              }
            }
          }
          while (lIdx != mn - 1) {
            if (stemp[lIdx] >= stemp[lIdx + 1]) break;
            final temp = stemp[lIdx];
            stemp[lIdx] = stemp[lIdx + 1];
            stemp[lIdx + 1] = temp;
            if (computeVectors && lIdx < colsA) {
              for (var i = 0; i < colsA; i++) {
                final aVal = vList[(lIdx + 1) * colsA + i];
                final bVal = vList[lIdx * colsA + i];
                vList[lIdx * colsA + i] = aVal;
                vList[(lIdx + 1) * colsA + i] = bVal;
              }
            }
            if (computeVectors && lIdx < rowsA) {
              for (var i = 0; i < rowsA; i++) {
                final aVal = uVals[(lIdx + 1) * rowsA + i];
                final bVal = uVals[lIdx * rowsA + i];
                uVals[lIdx * rowsA + i] = aVal;
                uVals[(lIdx + 1) * rowsA + i] = bVal;
              }
            }
            lIdx++;
          }
          iter = 0;
          mDim--;
      }
    }

    if (computeVectors) {
      for (var i = 0; i < colsA; i++) {
        for (var j = 0; j < colsA; j++) {
          vtVals[j * colsA + i] = vList[i * colsA + j];
        }
      }
    }

    for (var i = 0; i < math.min(rowsA, colsA); i++) {
      sVals[i] = stemp[i];
    }
  }
}
