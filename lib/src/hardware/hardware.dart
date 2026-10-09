import 'dart:typed_data';

import 'cblas.dart';

/// Central hardware acceleration manager providing transparent routing between
/// native BLAS/LAPACK (via FFI), Dart SIMD, and pure Dart scalar algorithms.
class HardwareManager {
  new _();

  static final BlasLibrary _blas = loadBlas();

  /// Whether hardware acceleration is globally enabled. Can be disabled for benchmarking or testing fallbacks.
  static bool isEnabled = true;

  /// Whether native BLAS is loaded and available on the current platform.
  static bool get isNativeAvailable => _blas.isAvailable;

  /// Whether hardware acceleration is currently active.
  static bool get isAccelerated => isEnabled && _blas.isAvailable;

  /// Computes matrix multiplication C = alpha * A * B + beta * C for Float64List.
  static bool dgemm({
    required int m,
    required int n,
    required int k,
    required double alpha,
    required Float64List a,
    required int lda,
    required Float64List b,
    required int ldb,
    required double beta,
    required Float64List c,
    required int ldc,
  }) {
    if (!isAccelerated) return false;
    return _blas.dgemm(
      m: m,
      n: n,
      k: k,
      alpha: alpha,
      a: a,
      lda: lda,
      b: b,
      ldb: ldb,
      beta: beta,
      c: c,
      ldc: ldc,
    );
  }

  /// Computes matrix multiplication C = alpha * A * B + beta * C for Float32List.
  static bool sgemm({
    required int m,
    required int n,
    required int k,
    required double alpha,
    required Float32List a,
    required int lda,
    required Float32List b,
    required int ldb,
    required double beta,
    required Float32List c,
    required int ldc,
  }) {
    if (!isAccelerated) return false;
    return _blas.sgemm(
      m: m,
      n: n,
      k: k,
      alpha: alpha,
      a: a,
      lda: lda,
      b: b,
      ldb: ldb,
      beta: beta,
      c: c,
      ldc: ldc,
    );
  }

  /// Computes matrix-vector product y = alpha * A * x + beta * y for Float64List.
  static bool dgemv({
    required int m,
    required int n,
    required double alpha,
    required Float64List a,
    required int lda,
    required Float64List x,
    required int incX,
    required double beta,
    required Float64List y,
    required int incY,
  }) {
    if (!isAccelerated) return false;
    return _blas.dgemv(
      m: m,
      n: n,
      alpha: alpha,
      a: a,
      lda: lda,
      x: x,
      incX: incX,
      beta: beta,
      y: y,
      incY: incY,
    );
  }

  /// Computes dot product of two Float64List vectors.
  static double? ddot({
    required int n,
    required Float64List x,
    int incX = 1,
    required Float64List y,
    int incY = 1,
  }) {
    if (!isAccelerated) return null;
    return _blas.ddot(n: n, x: x, incX: incX, y: y, incY: incY);
  }

  /// Computes Euclidean norm of a Float64List vector.
  static double? dnrm2({required int n, required Float64List x, int incX = 1}) {
    if (!isAccelerated) return null;
    return _blas.dnrm2(n: n, x: x, incX: incX);
  }

  /// Solves A * X = B for general square matrix A using LU decomposition.
  static bool dgesv({
    required int n,
    required int nrhs,
    required Float64List a,
    required int lda,
    required Float64List b,
    required int ldb,
  }) {
    if (!isAccelerated) return false;
    return _blas.dgesv(n: n, nrhs: nrhs, a: a, lda: lda, b: b, ldb: ldb);
  }
}
