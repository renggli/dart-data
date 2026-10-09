// ignore_for_file: constant_identifier_names

import 'dart:typed_data';

/// CBLAS Matrix Layout Order.
const int cblasRowMajor = 101;
const int cblasColMajor = 102;
const int CblasRowMajor = 101;
const int CblasColMajor = 102;

/// CBLAS Transposition options.
const int cblasNoTrans = 111;
const int cblasTrans = 112;
const int cblasConjTrans = 113;
const int CblasNoTrans = 111;
const int CblasTrans = 112;
const int CblasConjTrans = 113;

/// CBLAS Upper/Lower triangular matrix options.
const int cblasUpper = 121;
const int cblasLower = 122;
const int CblasUpper = 121;
const int CblasLower = 122;

/// Stub implementation of BLAS library when FFI is unavailable (e.g. Web).
class BlasLibrary {
  bool get isAvailable => false;

  bool dgemm({
    int transA = cblasNoTrans,
    int transB = cblasNoTrans,
    required int m,
    required int n,
    required int k,
    required double alpha,
    required Float64List a,
    int aOffset = 0,
    required int lda,
    required Float64List b,
    int bOffset = 0,
    required int ldb,
    required double beta,
    required Float64List c,
    int cOffset = 0,
    required int ldc,
  }) => false;

  bool sgemm({
    int transA = cblasNoTrans,
    int transB = cblasNoTrans,
    required int m,
    required int n,
    required int k,
    required double alpha,
    required Float32List a,
    int aOffset = 0,
    required int lda,
    required Float32List b,
    int bOffset = 0,
    required int ldb,
    required double beta,
    required Float32List c,
    int cOffset = 0,
    required int ldc,
  }) => false;

  bool dgemv({
    int transA = cblasNoTrans,
    required int m,
    required int n,
    required double alpha,
    required Float64List a,
    int aOffset = 0,
    required int lda,
    required Float64List x,
    int xOffset = 0,
    required int incX,
    required double beta,
    required Float64List y,
    int yOffset = 0,
    required int incY,
  }) => false;

  bool sgemv({
    int transA = cblasNoTrans,
    required int m,
    required int n,
    required double alpha,
    required Float32List a,
    int aOffset = 0,
    required int lda,
    required Float32List x,
    int xOffset = 0,
    required int incX,
    required double beta,
    required Float32List y,
    int yOffset = 0,
    required int incY,
  }) => false;

  double? ddot({
    required int n,
    required Float64List x,
    int xOffset = 0,
    required int incX,
    required Float64List y,
    int yOffset = 0,
    required int incY,
  }) => null;

  double? sdot({
    required int n,
    required Float32List x,
    int xOffset = 0,
    required int incX,
    required Float32List y,
    int yOffset = 0,
    required int incY,
  }) => null;

  double? dnrm2({
    required int n,
    required Float64List x,
    int xOffset = 0,
    required int incX,
  }) => null;

  double? snrm2({
    required int n,
    required Float32List x,
    int xOffset = 0,
    required int incX,
  }) => null;

  bool daxpy({
    required int n,
    required double alpha,
    required Float64List x,
    int xOffset = 0,
    required int incX,
    required Float64List y,
    int yOffset = 0,
    required int incY,
  }) => false;

  bool saxpy({
    required int n,
    required double alpha,
    required Float32List x,
    int xOffset = 0,
    required int incX,
    required Float32List y,
    int yOffset = 0,
    required int incY,
  }) => false;

  bool dscal({
    required int n,
    required double alpha,
    required Float64List x,
    int xOffset = 0,
    required int incX,
  }) => false;

  bool sscal({
    required int n,
    required double alpha,
    required Float32List x,
    int xOffset = 0,
    required int incX,
  }) => false;

  bool dsyrk({
    int uplo = cblasUpper,
    int trans = cblasNoTrans,
    required int n,
    required int k,
    required double alpha,
    required Float64List a,
    int aOffset = 0,
    required int lda,
    required double beta,
    required Float64List c,
    int cOffset = 0,
    required int ldc,
  }) => false;

  bool ssyrk({
    int uplo = cblasUpper,
    int trans = cblasNoTrans,
    required int n,
    required int k,
    required double alpha,
    required Float32List a,
    int aOffset = 0,
    required int lda,
    required double beta,
    required Float32List c,
    int cOffset = 0,
    required int ldc,
  }) => false;

  bool dsyr2({
    int uplo = cblasUpper,
    required int n,
    required double alpha,
    required Float64List x,
    int xOffset = 0,
    required int incX,
    required Float64List y,
    int yOffset = 0,
    required int incY,
    required Float64List a,
    int aOffset = 0,
    required int lda,
  }) => false;

  bool ssyr2({
    int uplo = cblasUpper,
    required int n,
    required double alpha,
    required Float32List x,
    int xOffset = 0,
    required int incX,
    required Float32List y,
    int yOffset = 0,
    required int incY,
    required Float32List a,
    int aOffset = 0,
    required int lda,
  }) => false;

  bool dpotrf({
    int uplo = cblasUpper,
    required int n,
    required Float64List a,
    int aOffset = 0,
    required int lda,
  }) => false;

  bool dgesv({
    required int n,
    required int nrhs,
    required Float64List a,
    int aOffset = 0,
    required int lda,
    required Float64List b,
    int bOffset = 0,
    required int ldb,
  }) => false;

  bool dgels({
    required int m,
    required int n,
    required int nrhs,
    required Float64List a,
    int aOffset = 0,
    required int lda,
    required Float64List b,
    int bOffset = 0,
    required int ldb,
  }) => false;
}

/// Loads the platform BLAS library (stub implementation).
BlasLibrary loadBlas() => BlasLibrary();
