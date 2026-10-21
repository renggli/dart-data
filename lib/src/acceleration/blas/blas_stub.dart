// coverage:ignore-file
import 'dart:typed_data';

/// Stub for native BLAS when FFI is unavailable.
abstract final class BlasNative {
  static bool get isAvailable => false;
  static bool get hasDgemm => false;
  static bool get hasSgemm => false;

  static double? ddot({
    required int n,
    required Float64List x,
    required int xOffset,
    required int incX,
    required Float64List y,
    required int yOffset,
    required int incY,
  }) => null;

  static double? sdot({
    required int n,
    required Float32List x,
    required int xOffset,
    required int incX,
    required Float32List y,
    required int yOffset,
    required int incY,
  }) => null;

  static double? dnrm2({
    required int n,
    required Float64List x,
    required int xOffset,
    required int incX,
  }) => null;

  static double? snrm2({
    required int n,
    required Float32List x,
    required int xOffset,
    required int incX,
  }) => null;

  static bool daxpy({
    required int n,
    required double alpha,
    required Float64List x,
    required int xOffset,
    required int incX,
    required Float64List y,
    required int yOffset,
    required int incY,
  }) => false;

  static bool saxpy({
    required int n,
    required double alpha,
    required Float32List x,
    required int xOffset,
    required int incX,
    required Float32List y,
    required int yOffset,
    required int incY,
  }) => false;

  static bool dscal({
    required int n,
    required double alpha,
    required Float64List x,
    required int xOffset,
    required int incX,
  }) => false;

  static bool sscal({
    required int n,
    required double alpha,
    required Float32List x,
    required int xOffset,
    required int incX,
  }) => false;

  static bool dgemv({
    required int transA,
    required int m,
    required int n,
    required double alpha,
    required Float64List a,
    required int aOffset,
    required int lda,
    required Float64List x,
    required int xOffset,
    required int incX,
    required double beta,
    required Float64List y,
    required int yOffset,
    required int incY,
  }) => false;

  static bool sgemv({
    required int transA,
    required int m,
    required int n,
    required double alpha,
    required Float32List a,
    required int aOffset,
    required int lda,
    required Float32List x,
    required int xOffset,
    required int incX,
    required double beta,
    required Float32List y,
    required int yOffset,
    required int incY,
  }) => false;

  static bool dsyr2({
    required int uplo,
    required int n,
    required double alpha,
    required Float64List x,
    required int xOffset,
    required int incX,
    required Float64List y,
    required int yOffset,
    required int incY,
    required Float64List a,
    required int aOffset,
    required int lda,
  }) => false;

  static bool ssyr2({
    required int uplo,
    required int n,
    required double alpha,
    required Float32List x,
    required int xOffset,
    required int incX,
    required Float32List y,
    required int yOffset,
    required int incY,
    required Float32List a,
    required int aOffset,
    required int lda,
  }) => false;

  static bool dtrmv({
    required int uplo,
    required int trans,
    required int diag,
    required int n,
    required Float64List a,
    required int aOffset,
    required int lda,
    required Float64List x,
    required int xOffset,
    required int incX,
  }) => false;

  static bool strmv({
    required int uplo,
    required int trans,
    required int diag,
    required int n,
    required Float32List a,
    required int aOffset,
    required int lda,
    required Float32List x,
    required int xOffset,
    required int incX,
  }) => false;

  static bool dgemm({
    required int transA,
    required int transB,
    required int m,
    required int n,
    required int k,
    required double alpha,
    required Float64List a,
    required int aOffset,
    required int lda,
    required Float64List b,
    required int bOffset,
    required int ldb,
    required double beta,
    required Float64List c,
    required int cOffset,
    required int ldc,
  }) => false;

  static bool sgemm({
    required int transA,
    required int transB,
    required int m,
    required int n,
    required int k,
    required double alpha,
    required Float32List a,
    required int aOffset,
    required int lda,
    required Float32List b,
    required int bOffset,
    required int ldb,
    required double beta,
    required Float32List c,
    required int cOffset,
    required int ldc,
  }) => false;

  static bool dsyrk({
    required int uplo,
    required int trans,
    required int n,
    required int k,
    required double alpha,
    required Float64List a,
    required int aOffset,
    required int lda,
    required double beta,
    required Float64List c,
    required int cOffset,
    required int ldc,
  }) => false;

  static bool ssyrk({
    required int uplo,
    required int trans,
    required int n,
    required int k,
    required double alpha,
    required Float32List a,
    required int aOffset,
    required int lda,
    required double beta,
    required Float32List c,
    required int cOffset,
    required int ldc,
  }) => false;

  static bool dsymm({
    required int side,
    required int uplo,
    required int m,
    required int n,
    required double alpha,
    required Float64List a,
    required int aOffset,
    required int lda,
    required Float64List b,
    required int bOffset,
    required int ldb,
    required double beta,
    required Float64List c,
    required int cOffset,
    required int ldc,
  }) => false;

  static bool ssymm({
    required int side,
    required int uplo,
    required int m,
    required int n,
    required double alpha,
    required Float32List a,
    required int aOffset,
    required int lda,
    required Float32List b,
    required int bOffset,
    required int ldb,
    required double beta,
    required Float32List c,
    required int cOffset,
    required int ldc,
  }) => false;

  static bool dtrmm({
    required int side,
    required int uplo,
    required int transA,
    required int diag,
    required int m,
    required int n,
    required double alpha,
    required Float64List a,
    required int aOffset,
    required int lda,
    required Float64List b,
    required int bOffset,
    required int ldb,
  }) => false;

  static bool strmm({
    required int side,
    required int uplo,
    required int transA,
    required int diag,
    required int m,
    required int n,
    required double alpha,
    required Float32List a,
    required int aOffset,
    required int lda,
    required Float32List b,
    required int bOffset,
    required int ldb,
  }) => false;
}
