import 'dart:typed_data';

import 'package:more/number.dart' show Complex;

import 'acceleration_mode.dart';
import 'blas/cblas.dart';
import 'routines/blas_level1.dart';
import 'routines/blas_level2.dart';
import 'routines/blas_level3.dart';
import 'routines/fft_routines.dart';
import 'routines/lapack.dart';
import 'routines/vforce_routines.dart';
import 'vdsp/vdsp.dart';

/// Central acceleration manager providing routing between native
/// BLAS/LAPACK/vDSP (via FFI), Dart SIMD, and pure Dart scalar algorithms
/// according to [mode].
class AccelerationManager {
  new _(); // coverage:ignore-line

  /// Current execution mode for acceleration. Default is
  /// [AccelerationMode.auto].
  static AccelerationMode mode = AccelerationMode.auto;

  static final BlasLibrary _blas = loadBlas();
  static final VdspLibrary _vdsp = loadVdsp();

  /// Whether native BLAS is loaded and available on the current platform.
  static bool get isBlasAvailable => _blas.isAvailable;

  /// Whether native vDSP or vForce acceleration is available on the current
  /// platform.
  static bool get isVdspAvailable => _vdsp.isAvailable;

  /// Whether native FFT acceleration is available on the current platform.
  static bool get isFftAvailable => _vdsp.hasFft;

  /// Whether native vForce transcendental acceleration is available on the
  /// current platform.
  static bool get isVForceAvailable => _vdsp.hasVForce;

  /// Whether hardware acceleration is currently active.
  static bool get isAccelerated =>
      mode != AccelerationMode.dart && (_blas.isAvailable || _vdsp.isAvailable);

  // --- BLAS Level 1: Vector-Vector Operations ---

  /// Computes dot product of two Float64List vectors.
  static double? ddot({
    required int n,
    required Float64List x,
    int xOffset = 0,
    int incX = 1,
    required Float64List y,
    int yOffset = 0,
    int incY = 1,
  }) => BlasLevel1.ddot(
    n: n,
    x: x,
    xOffset: xOffset,
    incX: incX,
    y: y,
    yOffset: yOffset,
    incY: incY,
    blas: _blas,
  );

  /// Computes dot product of two Float32List vectors.
  static double? sdot({
    required int n,
    required Float32List x,
    int xOffset = 0,
    int incX = 1,
    required Float32List y,
    int yOffset = 0,
    int incY = 1,
  }) => BlasLevel1.sdot(
    n: n,
    x: x,
    xOffset: xOffset,
    incX: incX,
    y: y,
    yOffset: yOffset,
    incY: incY,
    blas: _blas,
  );

  /// Computes Euclidean norm of Float64List vector.
  static double? dnrm2({
    required int n,
    required Float64List x,
    int xOffset = 0,
    int incX = 1,
  }) => BlasLevel1.dnrm2(n: n, x: x, xOffset: xOffset, incX: incX, blas: _blas);

  /// Computes Euclidean norm of Float32List vector.
  static double? snrm2({
    required int n,
    required Float32List x,
    int xOffset = 0,
    int incX = 1,
  }) => BlasLevel1.snrm2(n: n, x: x, xOffset: xOffset, incX: incX, blas: _blas);

  /// Computes y = alpha * x + y for Float64List vectors.
  static bool daxpy({
    required int n,
    required double alpha,
    required Float64List x,
    int xOffset = 0,
    int incX = 1,
    required Float64List y,
    int yOffset = 0,
    int incY = 1,
  }) => BlasLevel1.daxpy(
    n: n,
    alpha: alpha,
    x: x,
    xOffset: xOffset,
    incX: incX,
    y: y,
    yOffset: yOffset,
    incY: incY,
    blas: _blas,
  );

  /// Computes y = alpha * x + y for Float32List vectors.
  static bool saxpy({
    required int n,
    required double alpha,
    required Float32List x,
    int xOffset = 0,
    int incX = 1,
    required Float32List y,
    int yOffset = 0,
    int incY = 1,
  }) => BlasLevel1.saxpy(
    n: n,
    alpha: alpha,
    x: x,
    xOffset: xOffset,
    incX: incX,
    y: y,
    yOffset: yOffset,
    incY: incY,
    blas: _blas,
  );

  /// Scales vector x by scalar alpha for Float64List.
  static bool dscal({
    required int n,
    required double alpha,
    required Float64List x,
    int xOffset = 0,
    int incX = 1,
  }) => BlasLevel1.dscal(
    n: n,
    alpha: alpha,
    x: x,
    xOffset: xOffset,
    incX: incX,
    blas: _blas,
  );

  /// Scales vector x by scalar alpha for Float32List.
  static bool sscal({
    required int n,
    required double alpha,
    required Float32List x,
    int xOffset = 0,
    int incX = 1,
  }) => BlasLevel1.sscal(
    n: n,
    alpha: alpha,
    x: x,
    xOffset: xOffset,
    incX: incX,
    blas: _blas,
  );

  // --- BLAS Level 2: Matrix-Vector Operations ---

  /// Computes matrix-vector product y = alpha * op(A) * x + beta * y for
  /// Float64List.
  static bool dgemv({
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
  }) => BlasLevel2.dgemv(
    transA: transA,
    m: m,
    n: n,
    alpha: alpha,
    a: a,
    aOffset: aOffset,
    lda: lda,
    x: x,
    xOffset: xOffset,
    incX: incX,
    beta: beta,
    y: y,
    yOffset: yOffset,
    incY: incY,
    blas: _blas,
  );

  /// Computes matrix-vector product y = alpha * op(A) * x + beta * y for
  /// Float32List.
  static bool sgemv({
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
  }) => BlasLevel2.sgemv(
    transA: transA,
    m: m,
    n: n,
    alpha: alpha,
    a: a,
    aOffset: aOffset,
    lda: lda,
    x: x,
    xOffset: xOffset,
    incX: incX,
    beta: beta,
    y: y,
    yOffset: yOffset,
    incY: incY,
    blas: _blas,
  );

  /// Symmetric rank-2 update: A = alpha * x * y^T + alpha * y * x^T + A for
  /// Float64List.
  static bool dsyr2({
    int uplo = cblasUpper,
    required int n,
    required double alpha,
    required Float64List x,
    int xOffset = 0,
    int incX = 1,
    required Float64List y,
    int yOffset = 0,
    int incY = 1,
    required Float64List a,
    int aOffset = 0,
    required int lda,
  }) => BlasLevel2.dsyr2(
    uplo: uplo,
    n: n,
    alpha: alpha,
    x: x,
    xOffset: xOffset,
    incX: incX,
    y: y,
    yOffset: yOffset,
    incY: incY,
    a: a,
    aOffset: aOffset,
    lda: lda,
    blas: _blas,
  );

  /// Symmetric rank-2 update: A = alpha * x * y^T + alpha * y * x^T + A for
  /// Float32List.
  static bool ssyr2({
    int uplo = cblasUpper,
    required int n,
    required double alpha,
    required Float32List x,
    int xOffset = 0,
    int incX = 1,
    required Float32List y,
    int yOffset = 0,
    int incY = 1,
    required Float32List a,
    int aOffset = 0,
    required int lda,
  }) => BlasLevel2.ssyr2(
    uplo: uplo,
    n: n,
    alpha: alpha,
    x: x,
    xOffset: xOffset,
    incX: incX,
    y: y,
    yOffset: yOffset,
    incY: incY,
    a: a,
    aOffset: aOffset,
    lda: lda,
    blas: _blas,
  );

  /// Triangular matrix-vector product x = op(A) * x for Float64List.
  static bool dtrmv({
    int uplo = cblasUpper,
    int trans = cblasNoTrans,
    int diag = cblasNonUnit,
    required int n,
    required Float64List a,
    int aOffset = 0,
    required int lda,
    required Float64List x,
    int xOffset = 0,
    int incX = 1,
  }) => BlasLevel2.dtrmv(
    uplo: uplo,
    trans: trans,
    diag: diag,
    n: n,
    a: a,
    aOffset: aOffset,
    lda: lda,
    x: x,
    xOffset: xOffset,
    incX: incX,
    blas: _blas,
  );

  /// Triangular matrix-vector product x = op(A) * x for Float32List.
  static bool strmv({
    int uplo = cblasUpper,
    int trans = cblasNoTrans,
    int diag = cblasNonUnit,
    required int n,
    required Float32List a,
    int aOffset = 0,
    required int lda,
    required Float32List x,
    int xOffset = 0,
    int incX = 1,
  }) => BlasLevel2.strmv(
    uplo: uplo,
    trans: trans,
    diag: diag,
    n: n,
    a: a,
    aOffset: aOffset,
    lda: lda,
    x: x,
    xOffset: xOffset,
    incX: incX,
    blas: _blas,
  );

  // --- BLAS Level 3: Matrix-Matrix Operations ---

  /// Computes matrix multiplication C = alpha * op(A) * op(B) + beta * C for
  /// Float64List.
  static bool dgemm({
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
  }) => BlasLevel3.dgemm(
    transA: transA,
    transB: transB,
    m: m,
    n: n,
    k: k,
    alpha: alpha,
    a: a,
    aOffset: aOffset,
    lda: lda,
    b: b,
    bOffset: bOffset,
    ldb: ldb,
    beta: beta,
    c: c,
    cOffset: cOffset,
    ldc: ldc,
    blas: _blas,
  );

  /// Computes matrix multiplication C = alpha * op(A) * op(B) + beta * C for
  /// Float32List.
  static bool sgemm({
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
  }) => BlasLevel3.sgemm(
    transA: transA,
    transB: transB,
    m: m,
    n: n,
    k: k,
    alpha: alpha,
    a: a,
    aOffset: aOffset,
    lda: lda,
    b: b,
    bOffset: bOffset,
    ldb: ldb,
    beta: beta,
    c: c,
    cOffset: cOffset,
    ldc: ldc,
    blas: _blas,
  );

  /// Symmetric rank-k update: C = alpha * A * A^T + beta * C for Float64List.
  static bool dsyrk({
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
  }) => BlasLevel3.dsyrk(
    uplo: uplo,
    trans: trans,
    n: n,
    k: k,
    alpha: alpha,
    a: a,
    aOffset: aOffset,
    lda: lda,
    beta: beta,
    c: c,
    cOffset: cOffset,
    ldc: ldc,
    blas: _blas,
  );

  /// Symmetric rank-k update: C = alpha * A * A^T + beta * C for Float32List.
  static bool ssyrk({
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
  }) => BlasLevel3.ssyrk(
    uplo: uplo,
    trans: trans,
    n: n,
    k: k,
    alpha: alpha,
    a: a,
    aOffset: aOffset,
    lda: lda,
    beta: beta,
    c: c,
    cOffset: cOffset,
    ldc: ldc,
    blas: _blas,
  );

  /// Symmetric matrix-matrix product for Float64List.
  static bool dsymm({
    int side = cblasLeft,
    int uplo = cblasUpper,
    required int m,
    required int n,
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
  }) => BlasLevel3.dsymm(
    side: side,
    uplo: uplo,
    m: m,
    n: n,
    alpha: alpha,
    a: a,
    aOffset: aOffset,
    lda: lda,
    b: b,
    bOffset: bOffset,
    ldb: ldb,
    beta: beta,
    c: c,
    cOffset: cOffset,
    ldc: ldc,
    blas: _blas,
  );

  /// Symmetric matrix-matrix product for Float32List.
  static bool ssymm({
    int side = cblasLeft,
    int uplo = cblasUpper,
    required int m,
    required int n,
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
  }) => BlasLevel3.ssymm(
    side: side,
    uplo: uplo,
    m: m,
    n: n,
    alpha: alpha,
    a: a,
    aOffset: aOffset,
    lda: lda,
    b: b,
    bOffset: bOffset,
    ldb: ldb,
    beta: beta,
    c: c,
    cOffset: cOffset,
    ldc: ldc,
    blas: _blas,
  );

  /// Triangular matrix-matrix multiplication for Float64List.
  static bool dtrmm({
    int side = cblasLeft,
    int uplo = cblasUpper,
    int transA = cblasNoTrans,
    int diag = cblasNonUnit,
    required int m,
    required int n,
    required double alpha,
    required Float64List a,
    int aOffset = 0,
    required int lda,
    required Float64List b,
    int bOffset = 0,
    required int ldb,
  }) => BlasLevel3.dtrmm(
    side: side,
    uplo: uplo,
    transA: transA,
    diag: diag,
    m: m,
    n: n,
    alpha: alpha,
    a: a,
    aOffset: aOffset,
    lda: lda,
    b: b,
    bOffset: bOffset,
    ldb: ldb,
    blas: _blas,
  );

  /// Triangular matrix-matrix multiplication for Float32List.
  static bool strmm({
    int side = cblasLeft,
    int uplo = cblasUpper,
    int transA = cblasNoTrans,
    int diag = cblasNonUnit,
    required int m,
    required int n,
    required double alpha,
    required Float32List a,
    int aOffset = 0,
    required int lda,
    required Float32List b,
    int bOffset = 0,
    required int ldb,
  }) => BlasLevel3.strmm(
    side: side,
    uplo: uplo,
    transA: transA,
    diag: diag,
    m: m,
    n: n,
    alpha: alpha,
    a: a,
    aOffset: aOffset,
    lda: lda,
    b: b,
    bOffset: bOffset,
    ldb: ldb,
    blas: _blas,
  );

  // --- LAPACK Routines ---

  /// Computes the Cholesky factorization of a symmetric positive-definite
  /// matrix A.
  static bool dpotrf({
    int uplo = cblasUpper,
    required int n,
    required Float64List a,
    int aOffset = 0,
    required int lda,
  }) => LapackRoutines.dpotrf(
    uplo: uplo,
    n: n,
    a: a,
    aOffset: aOffset,
    lda: lda,
    blas: _blas,
  );

  /// Solves a system of linear equations A * X = B for Float64List.
  static bool dgesv({
    required int n,
    required int nrhs,
    required Float64List a,
    int aOffset = 0,
    required int lda,
    required Float64List b,
    int bOffset = 0,
    required int ldb,
  }) => LapackRoutines.dgesv(
    n: n,
    nrhs: nrhs,
    a: a,
    aOffset: aOffset,
    lda: lda,
    b: b,
    bOffset: bOffset,
    ldb: ldb,
    blas: _blas,
  );

  /// Solves overdetermined or underdetermined linear systems A * X = B using QR
  /// or LQ factorization.
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
  }) => LapackRoutines.dgels(
    m: m,
    n: n,
    nrhs: nrhs,
    a: a,
    aOffset: aOffset,
    lda: lda,
    b: b,
    bOffset: bOffset,
    ldb: ldb,
    blas: _blas,
  );

  /// Computes eigenvalues and, optionally, eigenvectors of a symmetric matrix A
  /// for Float64List.
  static bool dsyev({
    String jobz = 'V',
    int uplo = cblasUpper,
    required int n,
    required Float64List a,
    int aOffset = 0,
    required int lda,
    required Float64List w,
    int wOffset = 0,
  }) => LapackRoutines.dsyev(
    jobz: jobz,
    uplo: uplo,
    n: n,
    a: a,
    aOffset: aOffset,
    lda: lda,
    w: w,
    wOffset: wOffset,
    blas: _blas,
  );

  /// Computes eigenvalues and, optionally, eigenvectors of a symmetric matrix A
  /// for Float32List.
  static bool ssyev({
    String jobz = 'V',
    int uplo = cblasUpper,
    required int n,
    required Float32List a,
    int aOffset = 0,
    required int lda,
    required Float32List w,
    int wOffset = 0,
  }) => LapackRoutines.ssyev(
    jobz: jobz,
    uplo: uplo,
    n: n,
    a: a,
    aOffset: aOffset,
    lda: lda,
    w: w,
    wOffset: wOffset,
    blas: _blas,
  );

  // --- FFT and Signal Processing ---

  /// Computes the 1-dimensional Discrete Fourier Transform (FFT) of [input].
  static List<Complex> fft(Iterable<Complex> input) =>
      FftRoutines.fft(input, vdsp: _vdsp, inverse: false);

  /// Computes the 1-dimensional Inverse Discrete Fourier Transform (IFFT) of
  /// [input].
  static List<Complex> ifft(Iterable<Complex> input) =>
      FftRoutines.fft(input, vdsp: _vdsp, inverse: true);

  /// Computes the 1-dimensional Discrete Fourier Transform for real-valued
  /// [input].
  static List<Complex> rfft(Iterable<num> input) =>
      FftRoutines.rfft(input, vdsp: _vdsp);

  /// Computes the Inverse Discrete Fourier Transform for real-valued signals.
  static List<double> irfft(List<Complex> input, [int? n]) =>
      FftRoutines.irfft(input, vdsp: _vdsp, n: n);

  /// Computes the 2-dimensional Discrete Fourier Transform of [matrix].
  static List<List<Complex>> fft2(List<List<Complex>> matrix) =>
      FftRoutines.fft2(matrix, vdsp: _vdsp, inverse: false);

  /// Computes the 2-dimensional Inverse Discrete Fourier Transform of [matrix].
  static List<List<Complex>> ifft2(List<List<Complex>> matrix) =>
      FftRoutines.fft2(matrix, vdsp: _vdsp, inverse: true);

  // --- Elementwise Transcendental Functions ---

  /// Computes elementwise sine: `output[i] = sin(input[i])`.
  static Float64List vsin(Float64List input) =>
      VforceRoutines.vsin(input, vdsp: _vdsp);

  /// Computes elementwise cosine: `output[i] = cos(input[i])`.
  static Float64List vcos(Float64List input) =>
      VforceRoutines.vcos(input, vdsp: _vdsp);

  /// Computes elementwise exponential: `output[i] = exp(input[i])`.
  static Float64List vexp(Float64List input) =>
      VforceRoutines.vexp(input, vdsp: _vdsp);

  /// Computes elementwise natural logarithm: `output[i] = ln(input[i])`.
  static Float64List vlog(Float64List input) =>
      VforceRoutines.vlog(input, vdsp: _vdsp);

  /// Computes elementwise square root: `output[i] = sqrt(input[i])`.
  static Float64List vsqrt(Float64List input) =>
      VforceRoutines.vsqrt(input, vdsp: _vdsp);

  /// Computes elementwise power: `output[i] = pow(base[i], exponent[i])`.
  static Float64List vpow(Float64List base, Float64List exponent) =>
      VforceRoutines.vpow(base, exponent, vdsp: _vdsp);

  // --- Vector Reductions ---

  /// Computes sum of elements in [x].
  static double sum(Float64List x) => VforceRoutines.sum(x, vdsp: _vdsp);

  /// Computes arithmetic mean of elements in [x].
  static double mean(Float64List x) => VforceRoutines.mean(x, vdsp: _vdsp);

  /// Computes sample or population variance of elements in [x].
  static double variance(Float64List x, {bool sample = true}) =>
      VforceRoutines.variance(x, vdsp: _vdsp, sample: sample);

  // --- Signal Processing ---

  /// Computes 1-dimensional valid linear convolution of [signal] and [filter].
  static Float64List convolve(Float64List signal, Float64List filter) =>
      VforceRoutines.convolve(signal, filter, vdsp: _vdsp);

  /// Computes 1-dimensional valid cross-correlation of [signal] and [filter].
  static Float64List correlate(Float64List signal, Float64List filter) =>
      VforceRoutines.correlate(signal, filter, vdsp: _vdsp);
}
