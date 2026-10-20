import 'dart:typed_data';

import '../blas/cblas.dart';
import '../fallback/pure_dart_lapack.dart';
import 'dispatcher.dart';

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
  }) => executeAcceleratedOperation(
    feature: 'LAPACK',
    operation: 'dpotrf',
    isAvailable: blas.isAvailable,
    failOnError: false,
    accelerate: () =>
        blas.dpotrf(uplo: uplo, n: n, a: a, aOffset: aOffset, lda: lda),
    fallback: () => PureDartLapack.dpotrf(
      uplo: uplo,
      n: n,
      a: a,
      aOffset: aOffset,
      lda: lda,
    ),
  );

  /// Solves `A * X = B` for general square matrix A using LU decomposition.
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

    return executeAcceleratedOperation(
      feature: 'LAPACK',
      operation: 'dgesv',
      isAvailable: blas.isAvailable,
      failOnError: false,
      accelerate: () => blas.dgesv(
        n: n,
        nrhs: nrhs,
        a: a,
        aOffset: aOffset,
        lda: lda,
        b: b,
        bOffset: bOffset,
        ldb: ldb,
      ),
      fallback: () =>
          PureDartLapack.luSolve(n, nrhs, a, aOffset, lda, b, bOffset, ldb),
    );
  }

  /// Solves overdetermined linear least squares `min ||A * X - B||_2` using
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
  }) => executeAcceleratedOperation(
    feature: 'LAPACK',
    operation: 'dgels',
    isAvailable: blas.isAvailable,
    accelerate: () => blas.dgels(
      m: m,
      n: n,
      nrhs: nrhs,
      a: a,
      aOffset: aOffset,
      lda: lda,
      b: b,
      bOffset: bOffset,
      ldb: ldb,
    ),
    fallback: () => PureDartLapack.dgels(
      m: m,
      n: n,
      nrhs: nrhs,
      a: a,
      aOffset: aOffset,
      lda: lda,
      b: b,
      bOffset: bOffset,
      ldb: ldb,
    ),
  );

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

    return executeAcceleratedOperation(
      feature: 'LAPACK',
      operation: 'dsyev',
      isAvailable: blas.isAvailable,
      accelerate: () => blas.dsyev(
        jobz: normJobz,
        uplo: uplo,
        n: n,
        a: a,
        aOffset: aOffset,
        lda: lda,
        w: w,
        wOffset: wOffset,
      ),
      fallback: () => PureDartLapack.dsyev(
        jobz: normJobz,
        uplo: uplo,
        n: n,
        a: a,
        aOffset: aOffset,
        lda: lda,
        w: w,
        wOffset: wOffset,
      ),
    );
  }

  /// Computes all eigenvalues and, optionally, eigenvectors of a real symmetric
  /// matrix A for [Float32List].
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

    return executeAcceleratedOperation(
      feature: 'LAPACK',
      operation: 'ssyev',
      isAvailable: blas.isAvailable,
      accelerate: () => blas.ssyev(
        jobz: normJobz,
        uplo: uplo,
        n: n,
        a: a,
        aOffset: aOffset,
        lda: lda,
        w: w,
        wOffset: wOffset,
      ),
      fallback: () => PureDartLapack.ssyev(
        jobz: normJobz,
        uplo: uplo,
        n: n,
        a: a,
        aOffset: aOffset,
        lda: lda,
        w: w,
        wOffset: wOffset,
      ),
    );
  }
}
