import 'dart:math' as math;

import '../../type/data_type.dart';
import '../operator.dart';
import '../vector.dart';

/// Iterative solver method for linear systems $A x = b$.
enum IterativeMethod {
  /// Conjugate Gradient algorithm for symmetric positive-definite systems.
  conjugateGradient,

  /// Generalized Minimal Residual (GMRES) algorithm for general square systems.
  gmres,
}

/// Solves a square linear system $A x = b$ using the specified iterative
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
  final x =
      x0?.copy() ??
      Vector<T>.filled(b.length, field.additiveIdentity, type: a.type);
  final residual = b - a.apply(x);
  final direction = residual.copy();
  var rsOld = residual.dot(residual);

  final bNorm = b.norm();
  final tolNorm = bNorm == 0.0 ? tolerance : math.max(tolerance * bNorm, 1e-15);
  final tolSq = tolNorm * tolNorm;

  if (field.norm(rsOld) <= tolSq) {
    return x;
  }

  var converged = false;
  for (var i = 0; i < maxIterations; i++) {
    final ap = a.apply(direction);
    final pap = direction.dot(ap);
    if (field.norm(pap) == 0.0) break;
    final alpha = field.div(rsOld, pap);
    x.addScaled(direction, alpha);
    residual.addScaled(ap, field.neg(alpha));
    final rsNew = residual.dot(residual);
    if (field.norm(rsNew) <= tolSq) {
      converged = true;
      break;
    }
    final beta = field.div(rsNew, rsOld);
    direction.scaleInPlace(beta);
    direction.addScaled(residual, field.multiplicativeIdentity);
    rsOld = rsNew;
  }

  if (!converged && field.norm(residual.dot(residual)) > tolSq) {
    throw StateError(
      'Conjugate gradient failed to converge after $maxIterations iterations.',
    );
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
  final x =
      x0?.copy() ??
      Vector<T>.filled(b.length, field.additiveIdentity, type: a.type);
  final dim = b.length;
  final maxBasis = math.min(restart, dim);
  var totalIter = 0;

  final bNorm = b.norm();
  final tolNorm = bNorm == 0.0 ? tolerance : math.max(tolerance * bNorm, 1e-15);

  while (totalIter < maxIterations) {
    final residual = b - a.apply(x);
    final beta = residual.norm();
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
      for (var i = 0; i <= k; i++) {
        final dotVal = basisVec.dot(krylovBasis[i]);
        final doubleDot = (dotVal as num).toDouble();
        hessenberg[i][k] = doubleDot;
        basisVec.addScaled(krylovBasis[i], field.neg(dotVal));
      }
      final wNorm = basisVec.norm();
      hessenberg[k + 1][k] = wNorm;

      if (wNorm <= 1e-15) {
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
      y[i] = hessenberg[i][i].abs() > 1e-15 ? sum / hessenberg[i][i] : 0.0;
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
  if (finalRes > tolNorm) {
    throw StateError(
      'GMRES failed to converge after $maxIterations iterations.',
    );
  }

  return x;
}
