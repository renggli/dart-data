import 'dart:math' as math;

import '../../type/data_type.dart';
import '../matrix.dart';
import '../vector.dart';

/// Singular Value Decomposition (SVD) of an [m x n] matrix $A$.
///
/// Factorizes $A = U \Sigma V^T$ where:
/// - $U$ is an [m x m] orthogonal matrix
/// - $\Sigma$ is an [m x n] diagonal matrix with singular values $\sigma_1 \ge \sigma_2 \ge \dots \ge 0$
/// - $V$ is an [n x n] orthogonal matrix ($V^T$ is its transpose)
class SingularValueDecomposition {
  /// Computes the SVD of [matrix].
  factory(Matrix<num> matrix, {bool computeVectors = true}) {
    final rowsA = matrix.rowCount;
    final colsA = matrix.colCount;
    final nm = math.min(rowsA, colsA);

    final aVals = List<double>.generate(rowsA * colsA, (idx) {
      final col = idx ~/ rowsA;
      final row = idx % rowsA;
      return matrix.get(row, col).toDouble();
    });

    final uVals = List<double>.filled(rowsA * rowsA, 0.0);
    final sVals = List<double>.filled(nm, 0.0);
    final vtVals = List<double>.filled(colsA * colsA, 0.0);

    _computeSvd(computeVectors, aVals, rowsA, colsA, sVals, uVals, vtVals);

    final u = Matrix<double>.generate(
      rowsA,
      rowsA,
      (r, c) => uVals[c * rowsA + r],
      type: DataType.float64,
    );
    final s = Vector<double>.fromList(sVals, type: DataType.float64);
    final vt = Matrix<double>.generate(
      colsA,
      colsA,
      (r, c) => vtVals[c * colsA + r],
      type: DataType.float64,
    );

    return SingularValueDecomposition._(s, u, vt, computeVectors);
  }

  const new _(this.s, this.u, this.vt, this.vectorsComputed);

  /// The singular values in descending order.
  final Vector<double> s;

  /// The left singular vectors ([m x m] orthogonal matrix).
  final Matrix<double> u;

  /// The transpose of right singular vectors ([n x n] orthogonal matrix).
  final Matrix<double> vt;

  /// The right singular vectors ([n x n] orthogonal matrix).
  Matrix<double> get v => vt.transposed;

  /// Whether singular vectors were computed.
  final bool vectorsComputed;

  /// Returns the diagonal matrix of singular values of size [m x n].
  Matrix<double> get sigma => Matrix<double>.generate(
    u.rowCount,
    vt.colCount,
    (r, c) => r == c && r < s.length ? s[r] : 0.0,
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
  Vector<double> solveVector(Vector<num> b) {
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

    for (var j = 0; j < cols; j++) {
      var val = 0.0;
      if (j < mn) {
        for (var i = 0; i < u.rowCount; i++) {
          val += u.get(i, j) * b[i].toDouble();
        }
        val = s[j].abs() > 1e-15 ? val / s[j] : 0.0;
      }
      tmp[j] = val;
    }

    final result = List<double>.filled(cols, 0.0);
    for (var j = 0; j < cols; j++) {
      var val = 0.0;
      for (var i = 0; i < cols; i++) {
        val += vt.get(i, j) * tmp[i];
      }
      result[j] = val;
    }

    return Vector<double>.fromList(result, type: DataType.float64);
  }

  static ({double da, double db, double c, double s}) _rotg(
    double da,
    double db,
  ) {
    final absda = da.abs();
    final absdb = db.abs();
    final roe = (absda > absdb) ? da : db;
    final scale = absda + absdb;

    double r, z, c, s;
    if (scale == 0.0) {
      c = 1.0;
      s = 0.0;
      r = 0.0;
      z = 0.0;
    } else {
      final sda = da / scale;
      final sdb = db / scale;
      r = scale * math.sqrt(sda * sda + sdb * sdb);
      if (roe < 0.0) r = -r;
      c = da / r;
      s = db / r;
      z = 1.0;
      if (absda > absdb) z = s;
      if (absdb >= absda && c != 0.0) z = 1.0 / c;
    }
    return (da: r, db: z, c: c, s: s);
  }

  static void _computeSvd(
    bool computeVectors,
    List<double> a,
    int rowsA,
    int colsA,
    List<double> s,
    List<double> u,
    List<double> vt,
  ) {
    final work = List<double>.filled(rowsA, 0.0);
    final e = List<double>.filled(colsA, 0.0);
    final v = List<double>.filled(colsA * colsA, 0.0);
    final stemp = List<double>.filled(math.min(rowsA + 1, colsA), 0.0);

    final ncu = rowsA;
    final nct = math.min(rowsA - 1, colsA);
    final nrt = math.max(0, math.min(colsA - 2, rowsA));
    final lu = math.max(nct, nrt);

    for (var l = 0; l < lu; l++) {
      final lp1 = l + 1;
      if (l < nct) {
        var sum = 0.0;
        for (var i = l; i < rowsA; i++) {
          final val = a[l * rowsA + i];
          sum += val * val;
        }
        stemp[l] = math.sqrt(sum);
        if (stemp[l] != 0.0) {
          if (a[l * rowsA + l] != 0.0) {
            stemp[l] =
                stemp[l].abs() * (a[l * rowsA + l] / a[l * rowsA + l].abs());
          }
          for (var i = l; i < rowsA; i++) {
            a[l * rowsA + i] /= stemp[l];
          }
          a[l * rowsA + l] += 1.0;
        }
        stemp[l] = -stemp[l];
      }

      for (var j = lp1; j < colsA; j++) {
        if (l < nct && stemp[l] != 0.0) {
          var t = 0.0;
          for (var i = l; i < rowsA; i++) {
            t += a[j * rowsA + i] * a[l * rowsA + i];
          }
          t = -t / a[l * rowsA + l];
          for (var ii = l; ii < rowsA; ii++) {
            a[j * rowsA + ii] += t * a[l * rowsA + ii];
          }
        }
        e[j] = a[j * rowsA + l];
      }

      if (computeVectors && l < nct) {
        for (var i = l; i < rowsA; i++) {
          u[l * rowsA + i] = a[l * rowsA + i];
        }
      }

      if (l < nrt) {
        var enorm = 0.0;
        for (var i = lp1; i < e.length; i++) {
          enorm += e[i] * e[i];
        }
        e[l] = math.sqrt(enorm);
        if (e[l] != 0.0) {
          if (e[lp1] != 0.0) {
            e[l] = e[l].abs() * (e[lp1] / e[lp1].abs());
          }
          for (var i = lp1; i < e.length; i++) {
            e[i] /= e[l];
          }
          e[lp1] += 1.0;
        }
        e[l] = -e[l];

        if (lp1 < rowsA && e[l] != 0.0) {
          for (var i = lp1; i < rowsA; i++) {
            work[i] = 0.0;
          }
          for (var j = lp1; j < colsA; j++) {
            for (var ii = lp1; ii < rowsA; ii++) {
              work[ii] += e[j] * a[j * rowsA + ii];
            }
          }
          for (var j = lp1; j < colsA; j++) {
            final ww = -e[j] / e[lp1];
            for (var ii = lp1; ii < rowsA; ii++) {
              a[j * rowsA + ii] += ww * work[ii];
            }
          }
        }

        if (computeVectors) {
          for (var i = lp1; i < colsA; i++) {
            v[l * colsA + i] = e[i];
          }
        }
      }
    }

    var m = math.min(colsA, rowsA + 1);
    final nctp1 = nct + 1;
    final nrtp1 = nrt + 1;
    if (nct < colsA) {
      stemp[nctp1 - 1] = a[(nctp1 - 1) * rowsA + (nctp1 - 1)];
    }
    if (rowsA < m) {
      stemp[m - 1] = 0.0;
    }
    if (nrtp1 < m) {
      e[nrtp1 - 1] = a[(m - 1) * rowsA + (nrtp1 - 1)];
    }
    e[m - 1] = 0.0;

    if (computeVectors) {
      for (var j = nctp1 - 1; j < ncu; j++) {
        for (var i = 0; i < rowsA; i++) {
          u[j * rowsA + i] = 0.0;
        }
        u[j * rowsA + j] = 1.0;
      }
      for (var l = nct - 1; l >= 0; l--) {
        if (stemp[l] != 0.0) {
          for (var j = l + 1; j < ncu; j++) {
            var t = 0.0;
            for (var i = l; i < rowsA; i++) {
              t += u[j * rowsA + i] * u[l * rowsA + i];
            }
            t = -t / u[l * rowsA + l];
            for (var ii = l; ii < rowsA; ii++) {
              u[j * rowsA + ii] += t * u[l * rowsA + ii];
            }
          }
          for (var i = l; i < rowsA; i++) {
            u[l * rowsA + i] = -u[l * rowsA + i];
          }
          u[l * rowsA + l] = 1.0 + u[l * rowsA + l];
          for (var i = 0; i < l; i++) {
            u[l * rowsA + i] = 0.0;
          }
        } else {
          for (var i = 0; i < rowsA; i++) {
            u[l * rowsA + i] = 0.0;
          }
          u[l * rowsA + l] = 1.0;
        }
      }

      for (var l = colsA - 1; l >= 0; l--) {
        final lp1 = l + 1;
        if (l < nrt && e[l] != 0.0) {
          for (var j = lp1; j < colsA; j++) {
            var t = 0.0;
            for (var i = lp1; i < colsA; i++) {
              t += v[j * colsA + i] * v[l * colsA + i];
            }
            t = -t / v[l * colsA + lp1];
            for (var ii = l; ii < colsA; ii++) {
              v[j * colsA + ii] += t * v[l * colsA + ii];
            }
          }
        }
        for (var i = 0; i < colsA; i++) {
          v[l * colsA + i] = 0.0;
        }
        v[l * colsA + l] = 1.0;
      }
    }

    for (var i = 0; i < m; i++) {
      if (stemp[i] != 0.0) {
        final t = stemp[i];
        final r = stemp[i] / t;
        stemp[i] = t;
        if (i < m - 1) e[i] /= r;
        if (computeVectors) {
          for (var j = 0; j < rowsA; j++) {
            u[i * rowsA + j] *= r;
          }
        }
      }
      if (i == m - 1) break;
      if (e[i] != 0.0) {
        final t = e[i];
        final r = t / e[i];
        e[i] = t;
        stemp[i + 1] *= r;
        if (computeVectors) {
          for (var j = 0; j < colsA; j++) {
            v[(i + 1) * colsA + j] *= r;
          }
        }
      }
    }

    final mn = m;
    var iter = 0;
    while (m > 0) {
      if (iter >= 1000) break;

      int l;
      for (l = m - 2; l >= 0; l--) {
        final test = stemp[l].abs() + stemp[l + 1].abs();
        final ztest = test + e[l].abs();
        if ((ztest - test).abs() < 1e-15 * test) {
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
          var test = 0.0;
          if (ls != m - 1) test += e[ls].abs();
          if (ls != l + 1) test += e[ls - 1].abs();
          final ztest = test + stemp[ls].abs();
          if ((ztest - test).abs() < 1e-15 * test) {
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

      switch (kase) {
        case 1:
          var f = e[m - 2];
          e[m - 2] = 0.0;
          for (var kk = l; kk < m - 1; kk++) {
            final k = m - 2 - kk + l;
            var t1 = stemp[k];
            final rotg = _rotg(t1, f);
            t1 = rotg.da;
            f = rotg.db;
            final cs = rotg.c;
            final sn = rotg.s;
            stemp[k] = t1;
            if (k != l) {
              f = -sn * e[k - 1];
              e[k - 1] = cs * e[k - 1];
            }
            if (computeVectors) {
              for (var i = 0; i < colsA; i++) {
                final z = cs * v[k * colsA + i] + sn * v[(m - 1) * colsA + i];
                v[(m - 1) * colsA + i] =
                    cs * v[(m - 1) * colsA + i] - sn * v[k * colsA + i];
                v[k * colsA + i] = z;
              }
            }
          }
        case 2:
          var f = e[l - 1];
          e[l - 1] = 0.0;
          for (var k = l; k < m; k++) {
            var t1 = stemp[k];
            final rotg = _rotg(t1, f);
            t1 = rotg.da;
            f = rotg.db;
            final cs = rotg.c;
            final sn = rotg.s;
            stemp[k] = t1;
            f = -sn * e[k];
            e[k] = cs * e[k];
            if (computeVectors) {
              for (var i = 0; i < rowsA; i++) {
                final z = cs * u[k * rowsA + i] + sn * u[(l - 1) * rowsA + i];
                u[(l - 1) * rowsA + i] =
                    cs * u[(l - 1) * rowsA + i] - sn * u[k * rowsA + i];
                u[k * rowsA + i] = z;
              }
            }
          }
        case 3:
          var scale = 0.0;
          scale = math.max(scale, stemp[m - 1].abs());
          scale = math.max(scale, stemp[m - 2].abs());
          scale = math.max(scale, e[m - 2].abs());
          scale = math.max(scale, stemp[l].abs());
          scale = math.max(scale, e[l].abs());
          final sm = stemp[m - 1] / scale;
          final smm1 = stemp[m - 2] / scale;
          final emm1 = e[m - 2] / scale;
          final sl = stemp[l] / scale;
          final el = e[l] / scale;
          final b = ((smm1 + sm) * (smm1 - sm) + emm1 * emm1) / 2.0;
          final c = (sm * emm1) * (sm * emm1);
          var shift = 0.0;
          if (b != 0.0 || c != 0.0) {
            shift = math.sqrt(b * b + c);
            if (b < 0.0) shift = -shift;
            shift = c / (b + shift);
          }
          var f = (sl + sm) * (sl - sm) + shift;
          var g = sl * el;
          for (var k = l; k < m - 1; k++) {
            var rotg = _rotg(f, g);
            f = rotg.da;
            g = rotg.db;
            var cs = rotg.c;
            var sn = rotg.s;
            if (k != l) e[k - 1] = f;
            f = cs * stemp[k] + sn * e[k];
            e[k] = cs * e[k] - sn * stemp[k];
            g = sn * stemp[k + 1];
            stemp[k + 1] = cs * stemp[k + 1];
            if (computeVectors) {
              for (var i = 0; i < colsA; i++) {
                final z = cs * v[k * colsA + i] + sn * v[(k + 1) * colsA + i];
                v[(k + 1) * colsA + i] =
                    cs * v[(k + 1) * colsA + i] - sn * v[k * colsA + i];
                v[k * colsA + i] = z;
              }
            }
            rotg = _rotg(f, g);
            f = rotg.da;
            g = rotg.db;
            cs = rotg.c;
            sn = rotg.s;
            stemp[k] = f;
            f = cs * e[k] + sn * stemp[k + 1];
            stemp[k + 1] = -sn * e[k] + cs * stemp[k + 1];
            g = sn * e[k + 1];
            e[k + 1] = cs * e[k + 1];
            if (computeVectors && k < rowsA) {
              for (var i = 0; i < rowsA; i++) {
                final z = cs * u[k * rowsA + i] + sn * u[(k + 1) * rowsA + i];
                u[(k + 1) * rowsA + i] =
                    cs * u[(k + 1) * rowsA + i] - sn * u[k * rowsA + i];
                u[k * rowsA + i] = z;
              }
            }
          }
          e[m - 2] = f;
          iter++;
        case 4:
          if (stemp[l] < 0.0) {
            stemp[l] = -stemp[l];
            if (computeVectors) {
              for (var i = 0; i < colsA; i++) {
                v[l * colsA + i] = -v[l * colsA + i];
              }
            }
          }
          while (l != mn - 1) {
            if (stemp[l] >= stemp[l + 1]) break;
            final t = stemp[l];
            stemp[l] = stemp[l + 1];
            stemp[l + 1] = t;
            if (computeVectors && l < colsA) {
              for (var i = 0; i < colsA; i++) {
                final aVal = v[(l + 1) * colsA + i];
                final bVal = v[l * colsA + i];
                v[l * colsA + i] = aVal;
                v[(l + 1) * colsA + i] = bVal;
              }
            }
            if (computeVectors && l < rowsA) {
              for (var i = 0; i < rowsA; i++) {
                final aVal = u[(l + 1) * rowsA + i];
                final bVal = u[l * rowsA + i];
                u[l * rowsA + i] = aVal;
                u[(l + 1) * rowsA + i] = bVal;
              }
            }
            l++;
          }
          iter = 0;
          m--;
      }
    }

    if (computeVectors) {
      for (var i = 0; i < colsA; i++) {
        for (var j = 0; j < colsA; j++) {
          vt[j * colsA + i] = v[i * colsA + j];
        }
      }
    }

    for (var i = 0; i < math.min(rowsA, colsA); i++) {
      s[i] = stemp[i];
    }
  }
}
