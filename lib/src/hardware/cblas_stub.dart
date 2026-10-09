import 'dart:typed_data';

/// Stub implementation of BLAS library when FFI is unavailable (e.g. Web).
class BlasLibrary {
  bool get isAvailable => false;

  bool dgemm({
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
  }) => false;

  bool sgemm({
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
  }) => false;

  bool dgemv({
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
  }) => false;

  double? ddot({
    required int n,
    required Float64List x,
    required int incX,
    required Float64List y,
    required int incY,
  }) => null;

  double? dnrm2({required int n, required Float64List x, required int incX}) =>
      null;

  bool daxpy({
    required int n,
    required double alpha,
    required Float64List x,
    required int incX,
    required Float64List y,
    required int incY,
  }) => false;

  bool dgesv({
    required int n,
    required int nrhs,
    required Float64List a,
    required int lda,
    required Float64List b,
    required int ldb,
  }) => false;
}

/// Loads the platform BLAS library (stub implementation).
BlasLibrary loadBlas() => BlasLibrary();
