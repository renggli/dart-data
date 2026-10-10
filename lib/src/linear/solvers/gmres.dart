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

  final field = a.type.field;
  var x =
      x0?.copy() ??
      Vector<T>.filled(b.length, field.additiveIdentity, type: a.type);
  final dim = b.length;
  final maxBasis = math.min(restart, dim);
  var totalIter = 0;

  while (totalIter < maxIterations) {
    final residual = b - a.apply(x);
    final beta = residual.norm();
    if (beta < tolerance) {
      return x;
    }

    final krylovBasis = <Vector<T>>[
      residual.scale(
        field.div(
          field.multiplicativeIdentity,
          field.scale(field.multiplicativeIdentity, beta),
        ),
      ),
    ];
    // Upper Hessenberg matrix H of size (maxBasis+1) x maxBasis
    final hessenberg = List.generate(
      maxBasis + 1,
      (_) => List<double>.filled(maxBasis, 0.0),
    );
    final cs = List<double>.filled(maxBasis, 0.0);
    final sn = List<double>.filled(maxBasis, 0.0);
    final rhs = List<double>.filled(maxBasis + 1, 0.0);
    rhs[0] = beta;

    var k = 0;
    for (; k < maxBasis && totalIter < maxIterations; k++, totalIter++) {
      final basisVec = a.apply(krylovBasis[k]);
      for (var i = 0; i <= k; i++) {
        final dotVal = basisVec.dot(krylovBasis[i]);
        final doubleDot = dotVal is num
            ? (dotVal as num).toDouble()
            : field.norm(dotVal);
        hessenberg[i][k] = doubleDot;
        basisVec.addScaled(krylovBasis[i], field.neg(dotVal));
      }
      final wNorm = basisVec.norm();
      hessenberg[k + 1][k] = wNorm;

      if (wNorm > 1e-15) {
        krylovBasis.add(
          basisVec.scale(
            field.div(
              field.multiplicativeIdentity,
              field.scale(field.multiplicativeIdentity, wNorm),
            ),
          ),
        );
      }

      // Apply previous Givens rotations to column k of H
      for (var i = 0; i < k; i++) {
        final temp = cs[i] * hessenberg[i][k] + sn[i] * hessenberg[i + 1][k];
        hessenberg[i + 1][k] =
            -sn[i] * hessenberg[i][k] + cs[i] * hessenberg[i + 1][k];
        hessenberg[i][k] = temp;
      }

      // Compute new Givens rotation to eliminate H[k+1][k]
      final hkk = hessenberg[k][k];
      final hk1k = hessenberg[k + 1][k];
      final denom = math.sqrt(hkk * hkk + hk1k * hk1k);
      if (denom > 1e-15) {
        cs[k] = hkk / denom;
        sn[k] = hk1k / denom;
      } else {
        cs[k] = 1.0;
        sn[k] = 0.0;
      }

      hessenberg[k][k] = cs[k] * hkk + sn[k] * hk1k;
      hessenberg[k + 1][k] = 0.0;

      // Update right-hand side vector rhs
      rhs[k + 1] = -sn[k] * rhs[k];
      rhs[k] = cs[k] * rhs[k];

      if (rhs[k + 1].abs() < tolerance) {
        k++;
        break;
      }
    }

    // Solve upper triangular system H[0..k-1, 0..k-1] * y = rhs[0..k-1]
    final y = List<double>.filled(k, 0.0);
    for (var i = k - 1; i >= 0; i--) {
      var sum = rhs[i];
      for (var j = i + 1; j < k; j++) {
        sum -= hessenberg[i][j] * y[j];
      }
      y[i] = hessenberg[i][i].abs() > 1e-15 ? sum / hessenberg[i][i] : 0.0;
    }

    // Update solution: x = x + sum(y[i] * krylovBasis[i])
    for (var i = 0; i < k; i++) {
      x =
          x +
          krylovBasis[i].scale(field.scale(field.multiplicativeIdentity, y[i]));
    }

    if (rhs[k].abs() < tolerance) {
      break;
    }
  }

  return x;
}
