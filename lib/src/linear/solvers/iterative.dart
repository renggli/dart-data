import 'dart:math' as math;

import '../../acceleration/utils/norm_accumulator.dart';
import '../../type/data_type.dart';
import '../operator.dart';
import '../vector.dart';

/// Iterative solver method for linear systems `A * x = b`.
enum IterativeMethod {
  /// Conjugate Gradient algorithm for symmetric positive-definite systems.
  conjugateGradient,

  /// Generalized Minimal Residual (GMRES) algorithm for general square systems.
  gmres,
}

/// Solves a square linear system `A * x = b` using the specified iterative
/// [method].
///
/// Conceptually, when an equation system has thousands of variables, direct
/// factorization is computationally expensive. Iterative solvers refine
/// successive approximations, converging rapidly toward the exact solution.
///
/// For symmetric positive-definite systems, select
/// [IterativeMethod.conjugateGradient]. For general nonsymmetric square
/// systems, select [IterativeMethod.gmres] (the default).
///
/// ```dart
/// final a = Matrix<double>.fromRows([
///   [4.0, 1.0],
///   [1.0, 3.0],
/// ]);
/// final b = Vector<double>.fromList([1.0, 2.0]);
/// final x = solveIterative(a, b, method: IterativeMethod.conjugateGradient);
/// ```
Vector<T> solveIterative<T>(
  LinearOperator<T> a,
  Vector<T> b, {
  IterativeMethod method = IterativeMethod.gmres,
  Vector<T>? x0,
  int restart = 30,
  double tolerance = 1e-10,
  int maxIterations = 1000,
}) {
  if (a.type is! DataType<num>) {
    throw ArgumentError(
      'Iterative solvers only support real numeric types, got ${a.type}',
    );
  }
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
  if (x0 != null && x0.length != b.length) {
    throw ArgumentError(
      'Initial guess x0 length (${x0.length}) must match vector b length (${b.length})',
    );
  }
  if (tolerance.isNaN || tolerance < 0.0) {
    throw ArgumentError.value(
      tolerance,
      'tolerance',
      'Tolerance must be non-negative and non-NaN',
    );
  }
  if (maxIterations < 0) {
    throw ArgumentError.value(
      maxIterations,
      'maxIterations',
      'maxIterations must be non-negative',
    );
  }
  if (restart <= 0) {
    throw ArgumentError.value(restart, 'restart', 'restart must be positive');
  }
  switch (method) {
    case IterativeMethod.conjugateGradient:
      return _conjugateGradient(
        a,
        b,
        x0: x0,
        tolerance: tolerance,
        maxIterations: maxIterations,
      );
    case IterativeMethod.gmres:
      return _gmres(
        a,
        b,
        x0: x0,
        restart: restart,
        tolerance: tolerance,
        maxIterations: maxIterations,
      );
  }
}

Vector<T> _conjugateGradient<T>(
  LinearOperator<T> a,
  Vector<T> b, {
  Vector<T>? x0,
  double tolerance = 1e-10,
  int maxIterations = 1000,
}) {
  final field = a.type.field;
  final x =
      x0?.copy() ??
      Vector<T>.filled(b.length, field.additiveIdentity, type: a.type);
  final residual = b - a.apply(x);
  final direction = residual.copy();
  var rsOld = residual.dot(residual);

  final bNorm = b.norm();
  final tolNorm = bNorm == 0.0 ? tolerance : tolerance * bNorm;
  final initialRNorm = residual.norm();
  if (!initialRNorm.isFinite) {
    throw StateError(
      'Conjugate gradient encountered non-finite residual norm: $initialRNorm.',
    );
  }
  if (initialRNorm <= tolNorm) {
    return x;
  }

  var converged = false;
  for (var i = 0; i < maxIterations; i++) {
    final ap = a.apply(direction);
    final pap = direction.dot(ap);
    final papNorm = field.norm(pap);
    if (!papNorm.isFinite || papNorm == 0.0) break;
    final alpha = field.div(rsOld, pap);
    x.addScaled(direction, alpha);
    residual.addScaled(ap, field.neg(alpha));
    final rNorm = residual.norm();
    if (!rNorm.isFinite) {
      throw StateError(
        'Conjugate gradient encountered non-finite residual norm: $rNorm.',
      );
    }
    if (rNorm <= tolNorm) {
      converged = true;
      break;
    }
    final rsNew = residual.dot(residual);
    final beta = field.div(rsNew, rsOld);
    direction.scaleInPlace(beta);
    direction.addScaled(residual, field.multiplicativeIdentity);
    rsOld = rsNew;
  }

  if (!converged) {
    final finalNorm = residual.norm();
    if (!finalNorm.isFinite || finalNorm > tolNorm) {
      throw StateError(
        'Conjugate gradient failed to converge after $maxIterations iterations.',
      );
    }
  }

  return x;
}

Vector<T> _gmres<T>(
  LinearOperator<T> a,
  Vector<T> b, {
  Vector<T>? x0,
  int restart = 30,
  double tolerance = 1e-10,
  int maxIterations = 1000,
}) {
  final field = a.type.field;
  final x =
      x0?.copy() ??
      Vector<T>.filled(b.length, field.additiveIdentity, type: a.type);
  final dim = b.length;
  final maxBasis = math.min(restart, dim);
  var totalIter = 0;

  final bNorm = b.norm();
  final tolNorm = bNorm == 0.0 ? tolerance : tolerance * bNorm;

  while (totalIter < maxIterations) {
    final residual = b - a.apply(x);
    final beta = residual.norm();
    if (!beta.isFinite) {
      throw StateError('GMRES encountered non-finite residual norm: $beta.');
    }
    if (beta <= tolNorm) {
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
      final hColAcc = ScaledNormAccumulator();
      for (var i = 0; i <= k; i++) {
        final dotVal = basisVec.dot(krylovBasis[i]);
        final doubleDot = (dotVal as num).toDouble();
        hessenberg[i][k] = doubleDot;
        hColAcc.add(doubleDot);
        basisVec.addScaled(krylovBasis[i], field.neg(dotVal));
      }
      final wNorm = basisVec.norm();
      if (!wNorm.isFinite) {
        throw StateError('GMRES encountered non-finite residual norm: $wNorm.');
      }
      hessenberg[k + 1][k] = wNorm;
      final hColNorm = hColAcc.norm;

      if (wNorm == 0.0 || (hColNorm > 0.0 && wNorm <= 1e-15 * hColNorm)) {
        // Krylov breakdown: invariant subspace reached.
        for (var i = 0; i < k; i++) {
          final temp = cs[i] * hessenberg[i][k] + sn[i] * hessenberg[i + 1][k];
          hessenberg[i + 1][k] =
              -sn[i] * hessenberg[i][k] + cs[i] * hessenberg[i + 1][k];
          hessenberg[i][k] = temp;
        }
        k++;
        break;
      }

      krylovBasis.add(
        basisVec.scale(
          field.div(
            field.multiplicativeIdentity,
            field.scale(field.multiplicativeIdentity, wNorm),
          ),
        ),
      );

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
      final denom = _hypot(hkk, hk1k);
      if (denom > 0.0) {
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

      if (rhs[k + 1].abs() <= tolNorm) {
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
      y[i] = hessenberg[i][i] != 0.0 ? sum / hessenberg[i][i] : 0.0;
    }

    // Update solution: x = x + sum(y[i] * krylovBasis[i])
    for (var i = 0; i < k; i++) {
      x.addScaled(
        krylovBasis[i],
        field.scale(field.multiplicativeIdentity, y[i]),
      );
    }

    if (rhs[k].abs() <= tolNorm) {
      break;
    }
  }

  final finalRes = (b - a.apply(x)).norm();
  if (!finalRes.isFinite || finalRes > tolNorm) {
    throw StateError(
      'GMRES failed to converge after $maxIterations iterations.',
    );
  }

  return x;
}

double _hypot(double a, double b) {
  final absA = a.abs();
  final absB = b.abs();
  if (absA == 0.0) return absB;
  if (absB == 0.0) return absA;
  final hi = math.max(absA, absB);
  final lo = math.min(absA, absB);
  if (hi.isInfinite) return double.infinity;
  final ratio = lo / hi;
  return hi * math.sqrt(1.0 + ratio * ratio);
}
