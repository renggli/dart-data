import 'dart:math' as math;
import 'dart:typed_data';

import '../acceleration_manager.dart';
import '../acceleration_mode.dart';
import '../blas/cblas.dart';
import '../fallback/pure_dart_lapack.dart';

/// LAPACK decomposition and solver routines.
abstract final class LapackRoutines {
  /// Computes the Cholesky factorization of a symmetric positive-definite
  /// matrix A. Overwrites the upper or lower triangle of A with the factor U or
  /// L.
  static bool dpotrf({
    int uplo = cblasUpper,
    required int n,
    required Float64List a,
    int aOffset = 0,
    required int lda,
    required BlasLibrary blas,
  }) {
    if (AccelerationManager.mode == AccelerationMode.accelerated) {
      if (!blas.isAvailable) {
        throw StateError(
          'Native acceleration is required in AccelerationMode.accelerated, but native BLAS/LAPACK is unavailable.',
        );
      }
      final success = blas.dpotrf(
        uplo: uplo,
        n: n,
        a: a,
        aOffset: aOffset,
        lda: lda,
      );
      if (!success) {
        throw StateError('dpotrf failed in AccelerationMode.accelerated.');
      }
      return true;
    } else if (AccelerationManager.mode == AccelerationMode.auto &&
        blas.isAvailable) {
      final success = blas.dpotrf(
        uplo: uplo,
        n: n,
        a: a,
        aOffset: aOffset,
        lda: lda,
      );
      if (success) return true;
    }

    // Pure Dart fallback Cholesky factorization
    final lower = Float64List(n * n);
    for (var i = 0; i < n; i++) {
      for (var j = 0; j <= i; j++) {
        var sum = 0.0;
        for (var k = 0; k < j; k++) {
          sum += lower[i * n + k] * lower[j * n + k];
        }
        if (i == j) {
          final val = a[aOffset + i * lda + i] - sum;
          if (val <= 0.0) return false;
          lower[i * n + j] = math.sqrt(val);
        } else {
          final denom = lower[j * n + j];
          if (denom == 0.0) return false;
          lower[i * n + j] = (a[aOffset + i * lda + j] - sum) / denom;
        }
      }
    }

    if (uplo == cblasUpper) {
      for (var i = 0; i < n; i++) {
        for (var j = i; j < n; j++) {
          a[aOffset + i * lda + j] = lower[j * n + i];
        }
      }
    } else {
      for (var i = 0; i < n; i++) {
        for (var j = 0; j <= i; j++) {
          a[aOffset + i * lda + j] = lower[i * n + j];
        }
      }
    }
    return true;
  }

  /// Solves A * X = B for general square matrix A using LU decomposition.
  static bool dgesv({
    required int n,
    required int nrhs,
    required Float64List a,
    int aOffset = 0,
    required int lda,
    required Float64List b,
    int bOffset = 0,
    required int ldb,
    required BlasLibrary blas,
  }) {
    if (n < 0 || nrhs < 0 || lda < n || (nrhs > 0 && ldb < nrhs)) return false;
    if (n == 0 || nrhs == 0) return true;
    final aRequired = aOffset + (n - 1) * lda + n;
    final bRequired = bOffset + (n - 1) * ldb + nrhs;
    if (a.length < aRequired || b.length < bRequired) return false;

    if (AccelerationManager.mode == AccelerationMode.accelerated) {
      if (!blas.isAvailable) {
        throw StateError(
          'Native acceleration is required in AccelerationMode.accelerated, but native BLAS/LAPACK is unavailable.',
        );
      }
      final success = blas.dgesv(
        n: n,
        nrhs: nrhs,
        a: a,
        aOffset: aOffset,
        lda: lda,
        b: b,
        bOffset: bOffset,
        ldb: ldb,
      );
      if (!success) {
        throw StateError('dgesv failed in AccelerationMode.accelerated.');
      }
      return true;
    } else if (AccelerationManager.mode == AccelerationMode.auto &&
        blas.isAvailable) {
      final success = blas.dgesv(
        n: n,
        nrhs: nrhs,
        a: a,
        aOffset: aOffset,
        lda: lda,
        b: b,
        bOffset: bOffset,
        ldb: ldb,
      );
      if (success) return true;
    }
    return PureDartLapack.luSolve(n, nrhs, a, aOffset, lda, b, bOffset, ldb);
  }

  /// Solves overdetermined linear least squares min ||A * X - B||_2 using
  /// LAPACK dgels.
  static bool dgels({
    required int m,
    required int n,
    required int nrhs,
    required Float64List a,
    int aOffset = 0,
    required int lda,
    required Float64List b,
    int bOffset = 0,
    required int ldb,
    required BlasLibrary blas,
  }) {
    if (AccelerationManager.mode == AccelerationMode.accelerated) {
      if (!blas.isAvailable) {
        throw StateError(
          'Native acceleration is required in AccelerationMode.accelerated, but native BLAS/LAPACK is unavailable.',
        );
      }
      final success = blas.dgels(
        m: m,
        n: n,
        nrhs: nrhs,
        a: a,
        aOffset: aOffset,
        lda: lda,
        b: b,
        bOffset: bOffset,
        ldb: ldb,
      );
      if (!success) {
        throw StateError('dgels failed in AccelerationMode.accelerated.');
      }
      return true;
    } else if (AccelerationManager.mode == AccelerationMode.auto &&
        blas.isAvailable) {
      return blas.dgels(
        m: m,
        n: n,
        nrhs: nrhs,
        a: a,
        aOffset: aOffset,
        lda: lda,
        b: b,
        bOffset: bOffset,
        ldb: ldb,
      );
    }
    return false;
  }

  /// Computes all eigenvalues and, optionally, eigenvectors of a real symmetric
  /// matrix A.
  static bool dsyev({
    String jobz = 'V',
    int uplo = cblasUpper,
    required int n,
    required Float64List a,
    int aOffset = 0,
    required int lda,
    required Float64List w,
    int wOffset = 0,
    required BlasLibrary blas,
  }) {
    if (n < 0 || lda < n) return false;
    final normJobz = jobz.toUpperCase();
    if (normJobz != 'V' && normJobz != 'N') return false;
    if (uplo != cblasUpper && uplo != cblasLower) return false;
    if (n == 0) return true;
    final aReq = aOffset + (n - 1) * lda + n;
    final wReq = wOffset + n;
    if (a.length < aReq || w.length < wReq) return false;

    if (AccelerationManager.mode == AccelerationMode.accelerated) {
      if (!blas.isAvailable) {
        throw StateError(
          'Native acceleration is required in AccelerationMode.accelerated, but native BLAS/LAPACK is unavailable.',
        );
      }
      final success = blas.dsyev(
        jobz: normJobz,
        uplo: uplo,
        n: n,
        a: a,
        aOffset: aOffset,
        lda: lda,
        w: w,
        wOffset: wOffset,
      );
      if (!success) {
        throw StateError('dsyev failed in AccelerationMode.accelerated.');
      }
      return true;
    } else if (AccelerationManager.mode == AccelerationMode.auto &&
        blas.isAvailable) {
      final success = blas.dsyev(
        jobz: normJobz,
        uplo: uplo,
        n: n,
        a: a,
        aOffset: aOffset,
        lda: lda,
        w: w,
        wOffset: wOffset,
      );
      if (success) return true;
    }

    return PureDartLapack.dsyev(
      jobz: normJobz,
      uplo: uplo,
      n: n,
      a: a,
      aOffset: aOffset,
      lda: lda,
      w: w,
      wOffset: wOffset,
    );
  }

  /// Computes all eigenvalues and eigenvectors of a single-precision symmetric
  /// matrix.
  static bool ssyev({
    String jobz = 'V',
    int uplo = cblasUpper,
    required int n,
    required Float32List a,
    int aOffset = 0,
    required int lda,
    required Float32List w,
    int wOffset = 0,
    required BlasLibrary blas,
  }) {
    if (n < 0 || lda < n) return false;
    final normJobz = jobz.toUpperCase();
    if (normJobz != 'V' && normJobz != 'N') return false;
    if (uplo != cblasUpper && uplo != cblasLower) return false;
    if (n == 0) return true;
    final aReq = aOffset + (n - 1) * lda + n;
    final wReq = wOffset + n;
    if (a.length < aReq || w.length < wReq) return false;

    if (AccelerationManager.mode == AccelerationMode.accelerated) {
      if (!blas.isAvailable) {
        throw StateError(
          'Native acceleration is required in AccelerationMode.accelerated, but native BLAS/LAPACK is unavailable.',
        );
      }
      final success = blas.ssyev(
        jobz: normJobz,
        uplo: uplo,
        n: n,
        a: a,
        aOffset: aOffset,
        lda: lda,
        w: w,
        wOffset: wOffset,
      );
      if (!success) {
        throw StateError('ssyev failed in AccelerationMode.accelerated.');
      }
      return true;
    } else if (AccelerationManager.mode == AccelerationMode.auto &&
        blas.isAvailable) {
      final success = blas.ssyev(
        jobz: normJobz,
        uplo: uplo,
        n: n,
        a: a,
        aOffset: aOffset,
        lda: lda,
        w: w,
        wOffset: wOffset,
      );
      if (success) return true;
    }

    return PureDartLapack.ssyev(
      jobz: normJobz,
      uplo: uplo,
      n: n,
      a: a,
      aOffset: aOffset,
      lda: lda,
      w: w,
      wOffset: wOffset,
    );
  }
}
