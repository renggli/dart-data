import 'dart:math' as math;

import '../operator.dart';
import '../vector.dart';

/// Solves a general square linear system A * x = b using restarted GMRES(m).
Vector<T> gmres<T>(
  LinearOperator<T> a,
  Vector<T> b, {
  Vector<T>? x0,
  int restart = 30,
  double tolerance = 1e-10,
  int maxIterations = 1000,
}) {
  if (a.rowCount != a.colCount) {
    throw ArgumentError(
      'Matrix A must be square, got ${a.rowCount} x ${a.colCount}',
    );
  }
  if (a.rowCount != b.length) {
    throw ArgumentError(
      'Matrix rowCount (${a.rowCount}) must match vector b length (${b.length})',
    );
  }

  final f = a.type.field;
  var x =
      x0?.copy() ??
      Vector<T>.filled(b.length, f.additiveIdentity, type: a.type);
  final n = b.length;
  final m = math.min(restart, n);
  var totalIter = 0;

  while (totalIter < maxIterations) {
    final r = b - a.apply(x);
    final beta = r.norm();
    if (beta < tolerance) {
      return x;
    }

    final v = <Vector<T>>[
      r.scale(
        f.div(
          f.multiplicativeIdentity,
          f.scale(f.multiplicativeIdentity, beta),
        ),
      ),
    ];
    // Upper Hessenberg matrix H of size (m+1) x m
    final h = List.generate(m + 1, (_) => List<double>.filled(m, 0.0));
    final cs = List<double>.filled(m, 0.0);
    final sn = List<double>.filled(m, 0.0);
    final g = List<double>.filled(m + 1, 0.0);
    g[0] = beta;

    var k = 0;
    for (; k < m && totalIter < maxIterations; k++, totalIter++) {
      var w = a.apply(v[k]);
      for (var i = 0; i <= k; i++) {
        final dotVal = w.dot(v[i]);
        final doubleDot = dotVal is num
            ? (dotVal as num).toDouble()
            : f.norm(dotVal);
        h[i][k] = doubleDot;
        w = w - v[i].scale(dotVal);
      }
      final wNorm = w.norm();
      h[k + 1][k] = wNorm;

      if (wNorm > 1e-15) {
        v.add(
          w.scale(
            f.div(
              f.multiplicativeIdentity,
              f.scale(f.multiplicativeIdentity, wNorm),
            ),
          ),
        );
      }

      // Apply previous Givens rotations to column k of H
      for (var i = 0; i < k; i++) {
        final temp = cs[i] * h[i][k] + sn[i] * h[i + 1][k];
        h[i + 1][k] = -sn[i] * h[i][k] + cs[i] * h[i + 1][k];
        h[i][k] = temp;
      }

      // Compute new Givens rotation to eliminate H[k+1][k]
      final hkk = h[k][k];
      final hk1k = h[k + 1][k];
      final denom = math.sqrt(hkk * hkk + hk1k * hk1k);
      if (denom > 1e-15) {
        cs[k] = hkk / denom;
        sn[k] = hk1k / denom;
      } else {
        cs[k] = 1.0;
        sn[k] = 0.0;
      }

      h[k][k] = cs[k] * hkk + sn[k] * hk1k;
      h[k + 1][k] = 0.0;

      // Update right-hand side vector g
      g[k + 1] = -sn[k] * g[k];
      g[k] = cs[k] * g[k];

      if (g[k + 1].abs() < tolerance) {
        k++;
        break;
      }
    }

    // Solve upper triangular system H[0..k-1, 0..k-1] * y = g[0..k-1]
    final y = List<double>.filled(k, 0.0);
    for (var i = k - 1; i >= 0; i--) {
      var sum = g[i];
      for (var j = i + 1; j < k; j++) {
        sum -= h[i][j] * y[j];
      }
      y[i] = h[i][i].abs() > 1e-15 ? sum / h[i][i] : 0.0;
    }

    // Update solution: x = x + sum(y[i] * v[i])
    for (var i = 0; i < k; i++) {
      x = x + v[i].scale(f.scale(f.multiplicativeIdentity, y[i]));
    }

    if (g[k].abs() < tolerance) {
      break;
    }
  }

  return x;
}
