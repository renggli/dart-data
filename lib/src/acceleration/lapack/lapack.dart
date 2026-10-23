import 'dart:typed_data';

import '../blas/blas_validation.dart';
import '../blas/cblas_constants.dart';
import '../utils/dispatcher.dart';
import 'lapack_dart.dart';
import 'lapack_stub.dart' if (dart.library.ffi) 'lapack_native.dart';

/// Linear Algebra Package (LAPACK) decomposition, factorization, and system
/// solvers.
///
/// Automatically routes execution between native LAPACK (via FFI) and optimized
/// pure Dart fallbacks according to acceleration mode.
abstract final class Lapack {
  /// Whether native LAPACK is available on the current platform.
  static bool get isAvailable => LapackNative.isAvailable;

  /// Computes the Cholesky factorization of a symmetric positive-definite
  /// matrix A: $A = U^T U$ or $A = L L^T$.
  static bool dpotrf({
    int uplo = cblasUpper,
    required int n,
    required Float64List a,
    int aOffset = 0,
    required int lda,
  }) {
    checkBlasUplo(uplo);
    if (n < 0) {
      throw ArgumentError.value(n, 'n', 'Matrix size must be non-negative');
    }
    checkBlasMatrixLeadingDim(lda, 'lda', n);
    checkBlasMatrixBounds(a.length, n, n, aOffset, lda, 'a');

    return executeAccelerated<bool>(
      feature: 'LAPACK',
      operation: 'dpotrf',
      isAvailable: LapackNative.hasDpotrf,
      accelerate: () => LapackNative.dpotrf(
        uplo: uplo,
        n: n,
        a: a,
        aOffset: aOffset,
        lda: lda,
      ),
      fallback: () =>
          LapackDart.dpotrf(uplo: uplo, n: n, a: a, aOffset: aOffset, lda: lda),
    );
  }

  /// Solves the general linear system $A X = B$ for general square matrix A
  /// using LU decomposition with partial pivoting.
  static bool dgesv({
    required int n,
    required int nrhs,
    required Float64List a,
    int aOffset = 0,
    required int lda,
    required Float64List b,
    int bOffset = 0,
    required int ldb,
  }) {
    if (n < 0) {
      throw ArgumentError.value(n, 'n', 'Matrix size must be non-negative');
    }
    if (nrhs < 0) {
      throw ArgumentError.value(
        nrhs,
        'nrhs',
        'Number of right-hand sides must be non-negative',
      );
    }
    checkBlasMatrixLeadingDim(lda, 'lda', n);
    checkBlasMatrixBounds(a.length, n, n, aOffset, lda, 'a');
    checkBlasMatrixLeadingDim(ldb, 'ldb', nrhs);
    checkBlasMatrixBounds(b.length, n, nrhs, bOffset, ldb, 'b');

    return executeAccelerated<bool>(
      feature: 'LAPACK',
      operation: 'dgesv',
      isAvailable: LapackNative.hasDgesv,
      accelerate: () => LapackNative.dgesv(
        n: n,
        nrhs: nrhs,
        a: a,
        aOffset: aOffset,
        lda: lda,
        b: b,
        bOffset: bOffset,
        ldb: ldb,
      ),
      fallback: () => LapackDart.dgesv(
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
  }

  /// Solves overdetermined or underdetermined linear least squares
  /// $\min \|A X - B\|_2$ using QR or LQ factorization.
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
  }) {
    if (m < 0) {
      throw ArgumentError.value(m, 'm', 'Matrix rows must be non-negative');
    }
    if (n < 0) {
      throw ArgumentError.value(n, 'n', 'Matrix cols must be non-negative');
    }
    if (nrhs < 0) {
      throw ArgumentError.value(
        nrhs,
        'nrhs',
        'Number of right-hand sides must be non-negative',
      );
    }
    checkBlasMatrixLeadingDim(lda, 'lda', n);
    checkBlasMatrixBounds(a.length, m, n, aOffset, lda, 'a');
    final maxMN = m > n ? m : n;
    checkBlasMatrixLeadingDim(ldb, 'ldb', nrhs);
    checkBlasMatrixBounds(b.length, maxMN, nrhs, bOffset, ldb, 'b');

    return executeAccelerated<bool>(
      feature: 'LAPACK',
      operation: 'dgels',
      isAvailable: LapackNative.hasDgels,
      accelerate: () => LapackNative.dgels(
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
      fallback: () => LapackDart.dgels(
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
  }

  /// Computes all eigenvalues and, optionally, eigenvectors of a symmetric
  /// matrix for [Float64List].
  static bool dsyev({
    String jobz = 'V',
    int uplo = cblasUpper,
    required int n,
    required Float64List a,
    int aOffset = 0,
    required int lda,
    required Float64List w,
    int wOffset = 0,
  }) {
    final normJobz = jobz.toUpperCase();
    if (normJobz != 'V' && normJobz != 'N') {
      throw ArgumentError.value(jobz, 'jobz', "Must be 'V' or 'N'");
    }
    checkBlasUplo(uplo);
    if (n < 0) {
      throw ArgumentError.value(n, 'n', 'Matrix size must be non-negative');
    }
    checkBlasMatrixLeadingDim(lda, 'lda', n);
    checkBlasMatrixBounds(a.length, n, n, aOffset, lda, 'a');
    checkBlasVectorBounds(w.length, n, wOffset, 1, 'w');

    return executeAccelerated<bool>(
      feature: 'LAPACK',
      operation: 'dsyev',
      isAvailable: LapackNative.hasDsyev,
      accelerate: () => LapackNative.dsyev(
        jobz: jobz,
        uplo: uplo,
        n: n,
        a: a,
        aOffset: aOffset,
        lda: lda,
        w: w,
        wOffset: wOffset,
      ),
      fallback: () => LapackDart.dsyev(
        jobz: jobz,
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

  /// Computes all eigenvalues and, optionally, eigenvectors of a symmetric
  /// matrix for [Float32List].
  static bool ssyev({
    String jobz = 'V',
    int uplo = cblasUpper,
    required int n,
    required Float32List a,
    int aOffset = 0,
    required int lda,
    required Float32List w,
    int wOffset = 0,
  }) {
    final normJobz = jobz.toUpperCase();
    if (normJobz != 'V' && normJobz != 'N') {
      throw ArgumentError.value(jobz, 'jobz', "Must be 'V' or 'N'");
    }
    checkBlasUplo(uplo);
    if (n < 0) {
      throw ArgumentError.value(n, 'n', 'Matrix size must be non-negative');
    }
    checkBlasMatrixLeadingDim(lda, 'lda', n);
    checkBlasMatrixBounds(a.length, n, n, aOffset, lda, 'a');
    checkBlasVectorBounds(w.length, n, wOffset, 1, 'w');

    return executeAccelerated<bool>(
      feature: 'LAPACK',
      operation: 'ssyev',
      isAvailable: LapackNative.hasSsyev,
      accelerate: () => LapackNative.ssyev(
        jobz: jobz,
        uplo: uplo,
        n: n,
        a: a,
        aOffset: aOffset,
        lda: lda,
        w: w,
        wOffset: wOffset,
      ),
      fallback: () => LapackDart.ssyev(
        jobz: jobz,
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
