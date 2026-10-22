import 'dart:typed_data';

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
  }) => executeAccelerated<bool>(
    feature: 'LAPACK',
    operation: 'dpotrf',
    isAvailable: LapackNative.hasDpotrf,
    accelerate: () =>
        LapackNative.dpotrf(uplo: uplo, n: n, a: a, aOffset: aOffset, lda: lda),
    fallback: () =>
        LapackDart.dpotrf(uplo: uplo, n: n, a: a, aOffset: aOffset, lda: lda),
  );

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
  }) => executeAccelerated<bool>(
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
  }) => executeAccelerated<bool>(
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
  }) => executeAccelerated<bool>(
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
  }) => executeAccelerated<bool>(
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
