import 'dart:typed_data';

import '../utils/dispatcher.dart';
import 'blas_dart.dart';
import 'blas_stub.dart' if (dart.library.ffi) 'blas_native.dart';
import 'blas_validation.dart';
import 'cblas_constants.dart';

export 'cblas_constants.dart';

/// Basic Linear Algebra Subprograms (BLAS) covering vector-vector (Level 1),
/// matrix-vector (Level 2), and matrix-matrix (Level 3) routines.
///
/// Automatically dispatches between native CBLAS (via FFI) and optimized pure
/// Dart implementations depending on acceleration mode.
abstract final class Blas {
  /// Whether native CBLAS acceleration is available on the current platform.
  static bool get isAvailable => BlasNative.isAvailable;

  // --- BLAS Level 1: Vector-Vector Operations ---

  /// Computes dot product of two [Float64List] vectors: $x \cdot y$.
  static double ddot({
    required int n,
    required Float64List x,
    int xOffset = 0,
    int incX = 1,
    required Float64List y,
    int yOffset = 0,
    int incY = 1,
  }) {
    checkBlasInc(incX, 'incX');
    checkBlasInc(incY, 'incY');
    checkBlasOffset(xOffset, x.length, 'xOffset');
    checkBlasOffset(yOffset, y.length, 'yOffset');
    checkBlasVectorBounds(x.length, n, xOffset, incX, 'x');
    checkBlasVectorBounds(y.length, n, yOffset, incY, 'y');
    return executeAccelerated(
      feature: 'BLAS',
      operation: 'ddot',
      isAvailable: isAvailable,
      accelerate: () => BlasNative.ddot(
        n: n,
        x: x,
        xOffset: xOffset,
        incX: incX,
        y: y,
        yOffset: yOffset,
        incY: incY,
      ),
      fallback: () => BlasDart.ddot(
        n: n,
        x: x,
        xOffset: xOffset,
        incX: incX,
        y: y,
        yOffset: yOffset,
        incY: incY,
      ),
    );
  }

  /// Computes dot product of two [Float32List] vectors: $x \cdot y$.
  static double sdot({
    required int n,
    required Float32List x,
    int xOffset = 0,
    int incX = 1,
    required Float32List y,
    int yOffset = 0,
    int incY = 1,
  }) {
    checkBlasInc(incX, 'incX');
    checkBlasInc(incY, 'incY');
    checkBlasOffset(xOffset, x.length, 'xOffset');
    checkBlasOffset(yOffset, y.length, 'yOffset');
    checkBlasVectorBounds(x.length, n, xOffset, incX, 'x');
    checkBlasVectorBounds(y.length, n, yOffset, incY, 'y');
    return executeAccelerated(
      feature: 'BLAS',
      operation: 'sdot',
      isAvailable: isAvailable,
      accelerate: () => BlasNative.sdot(
        n: n,
        x: x,
        xOffset: xOffset,
        incX: incX,
        y: y,
        yOffset: yOffset,
        incY: incY,
      ),
      fallback: () => BlasDart.sdot(
        n: n,
        x: x,
        xOffset: xOffset,
        incX: incX,
        y: y,
        yOffset: yOffset,
        incY: incY,
      ),
    );
  }

  /// Computes Euclidean norm of [Float64List] vector: $\|x\|_2$.
  static double dnrm2({
    required int n,
    required Float64List x,
    int xOffset = 0,
    int incX = 1,
  }) {
    checkBlasInc(incX, 'incX');
    checkBlasOffset(xOffset, x.length, 'xOffset');
    checkBlasVectorBounds(x.length, n, xOffset, incX, 'x');
    return executeAccelerated(
      feature: 'BLAS',
      operation: 'dnrm2',
      isAvailable: isAvailable,
      accelerate: () =>
          BlasNative.dnrm2(n: n, x: x, xOffset: xOffset, incX: incX),
      fallback: () => BlasDart.dnrm2(n: n, x: x, xOffset: xOffset, incX: incX),
    );
  }

  /// Computes Euclidean norm of [Float32List] vector: $\|x\|_2$.
  static double snrm2({
    required int n,
    required Float32List x,
    int xOffset = 0,
    int incX = 1,
  }) {
    checkBlasInc(incX, 'incX');
    checkBlasOffset(xOffset, x.length, 'xOffset');
    checkBlasVectorBounds(x.length, n, xOffset, incX, 'x');
    return executeAccelerated(
      feature: 'BLAS',
      operation: 'snrm2',
      isAvailable: isAvailable,
      accelerate: () =>
          BlasNative.snrm2(n: n, x: x, xOffset: xOffset, incX: incX),
      fallback: () => BlasDart.snrm2(n: n, x: x, xOffset: xOffset, incX: incX),
    );
  }

  /// Computes $y \leftarrow \alpha x + y$ for [Float64List] vectors.
  static bool daxpy({
    required int n,
    required double alpha,
    required Float64List x,
    int xOffset = 0,
    int incX = 1,
    required Float64List y,
    int yOffset = 0,
    int incY = 1,
  }) {
    checkBlasInc(incX, 'incX');
    checkBlasInc(incY, 'incY');
    checkBlasOffset(xOffset, x.length, 'xOffset');
    checkBlasOffset(yOffset, y.length, 'yOffset');
    checkBlasVectorBounds(x.length, n, xOffset, incX, 'x');
    checkBlasVectorBounds(y.length, n, yOffset, incY, 'y');
    return executeAcceleratedOperation(
      feature: 'BLAS',
      operation: 'daxpy',
      isAvailable: isAvailable,
      accelerate: () => BlasNative.daxpy(
        n: n,
        alpha: alpha,
        x: x,
        xOffset: xOffset,
        incX: incX,
        y: y,
        yOffset: yOffset,
        incY: incY,
      ),
      fallback: () => BlasDart.daxpy(
        n: n,
        alpha: alpha,
        x: x,
        xOffset: xOffset,
        incX: incX,
        y: y,
        yOffset: yOffset,
        incY: incY,
      ),
    );
  }

  /// Computes $y \leftarrow \alpha x + y$ for [Float32List] vectors.
  static bool saxpy({
    required int n,
    required double alpha,
    required Float32List x,
    int xOffset = 0,
    int incX = 1,
    required Float32List y,
    int yOffset = 0,
    int incY = 1,
  }) {
    checkBlasInc(incX, 'incX');
    checkBlasInc(incY, 'incY');
    checkBlasOffset(xOffset, x.length, 'xOffset');
    checkBlasOffset(yOffset, y.length, 'yOffset');
    checkBlasVectorBounds(x.length, n, xOffset, incX, 'x');
    checkBlasVectorBounds(y.length, n, yOffset, incY, 'y');
    return executeAcceleratedOperation(
      feature: 'BLAS',
      operation: 'saxpy',
      isAvailable: isAvailable,
      accelerate: () => BlasNative.saxpy(
        n: n,
        alpha: alpha,
        x: x,
        xOffset: xOffset,
        incX: incX,
        y: y,
        yOffset: yOffset,
        incY: incY,
      ),
      fallback: () => BlasDart.saxpy(
        n: n,
        alpha: alpha,
        x: x,
        xOffset: xOffset,
        incX: incX,
        y: y,
        yOffset: yOffset,
        incY: incY,
      ),
    );
  }

  /// Scales [Float64List] vector: $x \leftarrow \alpha x$.
  static bool dscal({
    required int n,
    required double alpha,
    required Float64List x,
    int xOffset = 0,
    int incX = 1,
  }) {
    checkBlasInc(incX, 'incX');
    checkBlasOffset(xOffset, x.length, 'xOffset');
    checkBlasVectorBounds(x.length, n, xOffset, incX, 'x');
    return executeAcceleratedOperation(
      feature: 'BLAS',
      operation: 'dscal',
      isAvailable: isAvailable,
      accelerate: () => BlasNative.dscal(
        n: n,
        alpha: alpha,
        x: x,
        xOffset: xOffset,
        incX: incX,
      ),
      fallback: () => BlasDart.dscal(
        n: n,
        alpha: alpha,
        x: x,
        xOffset: xOffset,
        incX: incX,
      ),
    );
  }

  /// Scales [Float32List] vector: $x \leftarrow \alpha x$.
  static bool sscal({
    required int n,
    required double alpha,
    required Float32List x,
    int xOffset = 0,
    int incX = 1,
  }) {
    checkBlasInc(incX, 'incX');
    checkBlasOffset(xOffset, x.length, 'xOffset');
    checkBlasVectorBounds(x.length, n, xOffset, incX, 'x');
    return executeAcceleratedOperation(
      feature: 'BLAS',
      operation: 'sscal',
      isAvailable: isAvailable,
      accelerate: () => BlasNative.sscal(
        n: n,
        alpha: alpha,
        x: x,
        xOffset: xOffset,
        incX: incX,
      ),
      fallback: () => BlasDart.sscal(
        n: n,
        alpha: alpha,
        x: x,
        xOffset: xOffset,
        incX: incX,
      ),
    );
  }

  // --- BLAS Level 2: Matrix-Vector Operations ---

  /// Computes matrix-vector product $y \leftarrow \alpha A x + \beta y$ or
  /// $y \leftarrow \alpha A^T x + \beta y$ for [Float64List].
  static bool dgemv({
    int transA = cblasNoTrans,
    required int m,
    required int n,
    double alpha = 1.0,
    required Float64List a,
    int aOffset = 0,
    required int lda,
    required Float64List x,
    int xOffset = 0,
    int incX = 1,
    double beta = 0.0,
    required Float64List y,
    int yOffset = 0,
    int incY = 1,
  }) {
    checkBlasTrans(transA, 'transA');
    checkBlasInc(incX, 'incX');
    checkBlasInc(incY, 'incY');
    checkBlasOffset(aOffset, a.length, 'aOffset');
    checkBlasOffset(xOffset, x.length, 'xOffset');
    checkBlasOffset(yOffset, y.length, 'yOffset');
    final lenY = transA == cblasTrans ? n : m;
    final lenX = transA == cblasTrans ? m : n;
    checkBlasMatrixLeadingDim(lda, 'lda', n);
    checkBlasMatrixBounds(a.length, m, n, aOffset, lda, 'a');
    checkBlasVectorBounds(x.length, lenX, xOffset, incX, 'x');
    checkBlasVectorBounds(y.length, lenY, yOffset, incY, 'y');
    return executeAcceleratedOperation(
      feature: 'BLAS',
      operation: 'dgemv',
      isAvailable: isAvailable,
      accelerate: () => BlasNative.dgemv(
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
      ),
      fallback: () => BlasDart.dgemv(
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
      ),
    );
  }

  /// Computes matrix-vector product $y \leftarrow \alpha A x + \beta y$ or
  /// $y \leftarrow \alpha A^T x + \beta y$ for [Float32List].
  static bool sgemv({
    int transA = cblasNoTrans,
    required int m,
    required int n,
    double alpha = 1.0,
    required Float32List a,
    int aOffset = 0,
    required int lda,
    required Float32List x,
    int xOffset = 0,
    int incX = 1,
    double beta = 0.0,
    required Float32List y,
    int yOffset = 0,
    int incY = 1,
  }) {
    checkBlasTrans(transA, 'transA');
    checkBlasInc(incX, 'incX');
    checkBlasInc(incY, 'incY');
    checkBlasOffset(aOffset, a.length, 'aOffset');
    checkBlasOffset(xOffset, x.length, 'xOffset');
    checkBlasOffset(yOffset, y.length, 'yOffset');
    final lenY = transA == cblasTrans ? n : m;
    final lenX = transA == cblasTrans ? m : n;
    checkBlasMatrixLeadingDim(lda, 'lda', n);
    checkBlasMatrixBounds(a.length, m, n, aOffset, lda, 'a');
    checkBlasVectorBounds(x.length, lenX, xOffset, incX, 'x');
    checkBlasVectorBounds(y.length, lenY, yOffset, incY, 'y');
    return executeAcceleratedOperation(
      feature: 'BLAS',
      operation: 'sgemv',
      isAvailable: isAvailable,
      accelerate: () => BlasNative.sgemv(
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
      ),
      fallback: () => BlasDart.sgemv(
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
      ),
    );
  }

  /// Performs symmetric rank-2 update: $A \leftarrow \alpha x y^T + \alpha y x^T + A$
  /// for [Float64List].
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
  }) {
    checkBlasUplo(uplo, 'uplo');
    checkBlasInc(incX, 'incX');
    checkBlasInc(incY, 'incY');
    checkBlasOffset(aOffset, a.length, 'aOffset');
    checkBlasOffset(xOffset, x.length, 'xOffset');
    checkBlasOffset(yOffset, y.length, 'yOffset');
    checkBlasMatrixLeadingDim(lda, 'lda', n);
    checkBlasMatrixBounds(a.length, n, n, aOffset, lda, 'a');
    checkBlasVectorBounds(x.length, n, xOffset, incX, 'x');
    checkBlasVectorBounds(y.length, n, yOffset, incY, 'y');
    return executeAcceleratedOperation(
      feature: 'BLAS',
      operation: 'dsyr2',
      isAvailable: isAvailable,
      accelerate: () => BlasNative.dsyr2(
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
      ),
      fallback: () => BlasDart.dsyr2(
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
      ),
    );
  }

  /// Performs symmetric rank-2 update: $A \leftarrow \alpha x y^T + \alpha y x^T + A$
  /// for [Float32List].
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
  }) {
    checkBlasUplo(uplo, 'uplo');
    checkBlasInc(incX, 'incX');
    checkBlasInc(incY, 'incY');
    checkBlasOffset(aOffset, a.length, 'aOffset');
    checkBlasOffset(xOffset, x.length, 'xOffset');
    checkBlasOffset(yOffset, y.length, 'yOffset');
    checkBlasMatrixLeadingDim(lda, 'lda', n);
    checkBlasMatrixBounds(a.length, n, n, aOffset, lda, 'a');
    checkBlasVectorBounds(x.length, n, xOffset, incX, 'x');
    checkBlasVectorBounds(y.length, n, yOffset, incY, 'y');
    return executeAcceleratedOperation(
      feature: 'BLAS',
      operation: 'ssyr2',
      isAvailable: isAvailable,
      accelerate: () => BlasNative.ssyr2(
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
      ),
      fallback: () => BlasDart.ssyr2(
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
      ),
    );
  }

  /// Computes triangular matrix-vector multiplication $x \leftarrow A x$ or
  /// $x \leftarrow A^T x$ for [Float64List].
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
  }) {
    checkBlasUplo(uplo, 'uplo');
    checkBlasTrans(trans, 'trans');
    checkBlasDiag(diag, 'diag');
    checkBlasInc(incX, 'incX');
    checkBlasOffset(aOffset, a.length, 'aOffset');
    checkBlasOffset(xOffset, x.length, 'xOffset');
    checkBlasMatrixLeadingDim(lda, 'lda', n);
    checkBlasMatrixBounds(a.length, n, n, aOffset, lda, 'a');
    checkBlasVectorBounds(x.length, n, xOffset, incX, 'x');
    return executeAcceleratedOperation(
      feature: 'BLAS',
      operation: 'dtrmv',
      isAvailable: isAvailable,
      accelerate: () => BlasNative.dtrmv(
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
      ),
      fallback: () => BlasDart.dtrmv(
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
      ),
    );
  }

  /// Computes triangular matrix-vector multiplication $x \leftarrow A x$ or
  /// $x \leftarrow A^T x$ for [Float32List].
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
  }) {
    checkBlasUplo(uplo, 'uplo');
    checkBlasTrans(trans, 'trans');
    checkBlasDiag(diag, 'diag');
    checkBlasInc(incX, 'incX');
    checkBlasOffset(aOffset, a.length, 'aOffset');
    checkBlasOffset(xOffset, x.length, 'xOffset');
    checkBlasMatrixLeadingDim(lda, 'lda', n);
    checkBlasMatrixBounds(a.length, n, n, aOffset, lda, 'a');
    checkBlasVectorBounds(x.length, n, xOffset, incX, 'x');
    return executeAcceleratedOperation(
      feature: 'BLAS',
      operation: 'strmv',
      isAvailable: isAvailable,
      accelerate: () => BlasNative.strmv(
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
      ),
      fallback: () => BlasDart.strmv(
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
      ),
    );
  }

  // --- BLAS Level 3: Matrix-Matrix Operations ---

  /// Computes general matrix multiplication $C \leftarrow \alpha A B + \beta C$
  /// for [Float64List].
  static bool dgemm({
    int transA = cblasNoTrans,
    int transB = cblasNoTrans,
    required int m,
    required int n,
    required int k,
    double alpha = 1.0,
    required Float64List a,
    int aOffset = 0,
    required int lda,
    required Float64List b,
    int bOffset = 0,
    required int ldb,
    double beta = 0.0,
    required Float64List c,
    int cOffset = 0,
    required int ldc,
  }) {
    checkBlasTrans(transA, 'transA');
    checkBlasTrans(transB, 'transB');
    checkBlasOffset(aOffset, a.length, 'aOffset');
    checkBlasOffset(bOffset, b.length, 'bOffset');
    checkBlasOffset(cOffset, c.length, 'cOffset');
    final aCols = transA == cblasNoTrans ? k : m;
    final aRows = transA == cblasNoTrans ? m : k;
    final bCols = transB == cblasNoTrans ? n : k;
    final bRows = transB == cblasNoTrans ? k : n;
    checkBlasMatrixLeadingDim(lda, 'lda', aCols);
    checkBlasMatrixLeadingDim(ldb, 'ldb', bCols);
    checkBlasMatrixLeadingDim(ldc, 'ldc', n);
    checkBlasMatrixBounds(a.length, aRows, aCols, aOffset, lda, 'a');
    checkBlasMatrixBounds(b.length, bRows, bCols, bOffset, ldb, 'b');
    checkBlasMatrixBounds(c.length, m, n, cOffset, ldc, 'c');
    return executeAcceleratedOperation(
      feature: 'BLAS',
      operation: 'dgemm',
      isAvailable: isAvailable,
      accelerate: () => BlasNative.dgemm(
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
      ),
      fallback: () => BlasDart.dgemm(
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
      ),
    );
  }

  /// Computes general matrix multiplication $C \leftarrow \alpha A B + \beta C$
  /// for [Float32List].
  static bool sgemm({
    int transA = cblasNoTrans,
    int transB = cblasNoTrans,
    required int m,
    required int n,
    required int k,
    double alpha = 1.0,
    required Float32List a,
    int aOffset = 0,
    required int lda,
    required Float32List b,
    int bOffset = 0,
    required int ldb,
    double beta = 0.0,
    required Float32List c,
    int cOffset = 0,
    required int ldc,
  }) {
    checkBlasTrans(transA, 'transA');
    checkBlasTrans(transB, 'transB');
    checkBlasOffset(aOffset, a.length, 'aOffset');
    checkBlasOffset(bOffset, b.length, 'bOffset');
    checkBlasOffset(cOffset, c.length, 'cOffset');
    final aCols = transA == cblasNoTrans ? k : m;
    final aRows = transA == cblasNoTrans ? m : k;
    final bCols = transB == cblasNoTrans ? n : k;
    final bRows = transB == cblasNoTrans ? k : n;
    checkBlasMatrixLeadingDim(lda, 'lda', aCols);
    checkBlasMatrixLeadingDim(ldb, 'ldb', bCols);
    checkBlasMatrixLeadingDim(ldc, 'ldc', n);
    checkBlasMatrixBounds(a.length, aRows, aCols, aOffset, lda, 'a');
    checkBlasMatrixBounds(b.length, bRows, bCols, bOffset, ldb, 'b');
    checkBlasMatrixBounds(c.length, m, n, cOffset, ldc, 'c');
    return executeAcceleratedOperation(
      feature: 'BLAS',
      operation: 'sgemm',
      isAvailable: isAvailable,
      accelerate: () => BlasNative.sgemm(
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
      ),
      fallback: () => BlasDart.sgemm(
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
      ),
    );
  }

  /// Performs symmetric rank-$k$ update: $C \leftarrow \alpha A A^T + \beta C$
  /// or $C \leftarrow \alpha A^T A + \beta C$ for [Float64List].
  static bool dsyrk({
    int uplo = cblasUpper,
    int trans = cblasNoTrans,
    required int n,
    required int k,
    double alpha = 1.0,
    required Float64List a,
    int aOffset = 0,
    required int lda,
    double beta = 0.0,
    required Float64List c,
    int cOffset = 0,
    required int ldc,
  }) {
    checkBlasUplo(uplo, 'uplo');
    checkBlasTrans(trans, 'trans');
    checkBlasOffset(aOffset, a.length, 'aOffset');
    checkBlasOffset(cOffset, c.length, 'cOffset');
    final aCols = trans == cblasNoTrans ? k : n;
    final aRows = trans == cblasNoTrans ? n : k;
    checkBlasMatrixLeadingDim(lda, 'lda', aCols);
    checkBlasMatrixLeadingDim(ldc, 'ldc', n);
    checkBlasMatrixBounds(a.length, aRows, aCols, aOffset, lda, 'a');
    checkBlasMatrixBounds(c.length, n, n, cOffset, ldc, 'c');
    return executeAcceleratedOperation(
      feature: 'BLAS',
      operation: 'dsyrk',
      isAvailable: isAvailable,
      accelerate: () => BlasNative.dsyrk(
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
      ),
      fallback: () => BlasDart.dsyrk(
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
      ),
    );
  }

  /// Performs symmetric rank-$k$ update: $C \leftarrow \alpha A A^T + \beta C$
  /// or $C \leftarrow \alpha A^T A + \beta C$ for [Float32List].
  static bool ssyrk({
    int uplo = cblasUpper,
    int trans = cblasNoTrans,
    required int n,
    required int k,
    double alpha = 1.0,
    required Float32List a,
    int aOffset = 0,
    required int lda,
    double beta = 0.0,
    required Float32List c,
    int cOffset = 0,
    required int ldc,
  }) {
    checkBlasUplo(uplo, 'uplo');
    checkBlasTrans(trans, 'trans');
    checkBlasOffset(aOffset, a.length, 'aOffset');
    checkBlasOffset(cOffset, c.length, 'cOffset');
    final aCols = trans == cblasNoTrans ? k : n;
    final aRows = trans == cblasNoTrans ? n : k;
    checkBlasMatrixLeadingDim(lda, 'lda', aCols);
    checkBlasMatrixLeadingDim(ldc, 'ldc', n);
    checkBlasMatrixBounds(a.length, aRows, aCols, aOffset, lda, 'a');
    checkBlasMatrixBounds(c.length, n, n, cOffset, ldc, 'c');
    return executeAcceleratedOperation(
      feature: 'BLAS',
      operation: 'ssyrk',
      isAvailable: isAvailable,
      accelerate: () => BlasNative.ssyrk(
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
      ),
      fallback: () => BlasDart.ssyrk(
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
      ),
    );
  }

  /// Computes symmetric matrix multiplication $C \leftarrow \alpha A B + \beta C$
  /// or $C \leftarrow \alpha B A + \beta C$ for [Float64List].
  static bool dsymm({
    int side = cblasLeft,
    int uplo = cblasUpper,
    required int m,
    required int n,
    double alpha = 1.0,
    required Float64List a,
    int aOffset = 0,
    required int lda,
    required Float64List b,
    int bOffset = 0,
    required int ldb,
    double beta = 0.0,
    required Float64List c,
    int cOffset = 0,
    required int ldc,
  }) {
    checkBlasSide(side, 'side');
    checkBlasUplo(uplo, 'uplo');
    checkBlasOffset(aOffset, a.length, 'aOffset');
    checkBlasOffset(bOffset, b.length, 'bOffset');
    checkBlasOffset(cOffset, c.length, 'cOffset');
    final aDim = side == cblasLeft ? m : n;
    checkBlasMatrixLeadingDim(lda, 'lda', aDim);
    checkBlasMatrixLeadingDim(ldb, 'ldb', n);
    checkBlasMatrixLeadingDim(ldc, 'ldc', n);
    checkBlasMatrixBounds(a.length, aDim, aDim, aOffset, lda, 'a');
    checkBlasMatrixBounds(b.length, m, n, bOffset, ldb, 'b');
    checkBlasMatrixBounds(c.length, m, n, cOffset, ldc, 'c');
    return executeAcceleratedOperation(
      feature: 'BLAS',
      operation: 'dsymm',
      isAvailable: isAvailable,
      accelerate: () => BlasNative.dsymm(
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
      ),
      fallback: () => BlasDart.dsymm(
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
      ),
    );
  }

  /// Computes symmetric matrix multiplication $C \leftarrow \alpha A B + \beta C$
  /// or $C \leftarrow \alpha B A + \beta C$ for [Float32List].
  static bool ssymm({
    int side = cblasLeft,
    int uplo = cblasUpper,
    required int m,
    required int n,
    double alpha = 1.0,
    required Float32List a,
    int aOffset = 0,
    required int lda,
    required Float32List b,
    int bOffset = 0,
    required int ldb,
    double beta = 0.0,
    required Float32List c,
    int cOffset = 0,
    required int ldc,
  }) {
    checkBlasSide(side, 'side');
    checkBlasUplo(uplo, 'uplo');
    checkBlasOffset(aOffset, a.length, 'aOffset');
    checkBlasOffset(bOffset, b.length, 'bOffset');
    checkBlasOffset(cOffset, c.length, 'cOffset');
    final aDim = side == cblasLeft ? m : n;
    checkBlasMatrixLeadingDim(lda, 'lda', aDim);
    checkBlasMatrixLeadingDim(ldb, 'ldb', n);
    checkBlasMatrixLeadingDim(ldc, 'ldc', n);
    checkBlasMatrixBounds(a.length, aDim, aDim, aOffset, lda, 'a');
    checkBlasMatrixBounds(b.length, m, n, bOffset, ldb, 'b');
    checkBlasMatrixBounds(c.length, m, n, cOffset, ldc, 'c');
    return executeAcceleratedOperation(
      feature: 'BLAS',
      operation: 'ssymm',
      isAvailable: isAvailable,
      accelerate: () => BlasNative.ssymm(
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
      ),
      fallback: () => BlasDart.ssymm(
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
      ),
    );
  }

  /// Computes triangular matrix-matrix multiplication $B \leftarrow \alpha A B$
  /// or $B \leftarrow \alpha B A$ for [Float64List].
  static bool dtrmm({
    int side = cblasLeft,
    int uplo = cblasUpper,
    int transA = cblasNoTrans,
    int diag = cblasNonUnit,
    required int m,
    required int n,
    double alpha = 1.0,
    required Float64List a,
    int aOffset = 0,
    required int lda,
    required Float64List b,
    int bOffset = 0,
    required int ldb,
  }) {
    checkBlasSide(side, 'side');
    checkBlasUplo(uplo, 'uplo');
    checkBlasTrans(transA, 'transA');
    checkBlasDiag(diag, 'diag');
    checkBlasOffset(aOffset, a.length, 'aOffset');
    checkBlasOffset(bOffset, b.length, 'bOffset');
    final aDim = side == cblasLeft ? m : n;
    checkBlasMatrixLeadingDim(lda, 'lda', aDim);
    checkBlasMatrixLeadingDim(ldb, 'ldb', n);
    checkBlasMatrixBounds(a.length, aDim, aDim, aOffset, lda, 'a');
    checkBlasMatrixBounds(b.length, m, n, bOffset, ldb, 'b');
    return executeAcceleratedOperation(
      feature: 'BLAS',
      operation: 'dtrmm',
      isAvailable: isAvailable,
      accelerate: () => BlasNative.dtrmm(
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
      ),
      fallback: () => BlasDart.dtrmm(
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
      ),
    );
  }

  /// Computes triangular matrix-matrix multiplication $B \leftarrow \alpha A B$
  /// or $B \leftarrow \alpha B A$ for [Float32List].
  static bool strmm({
    int side = cblasLeft,
    int uplo = cblasUpper,
    int transA = cblasNoTrans,
    int diag = cblasNonUnit,
    required int m,
    required int n,
    double alpha = 1.0,
    required Float32List a,
    int aOffset = 0,
    required int lda,
    required Float32List b,
    int bOffset = 0,
    required int ldb,
  }) {
    checkBlasSide(side, 'side');
    checkBlasUplo(uplo, 'uplo');
    checkBlasTrans(transA, 'transA');
    checkBlasDiag(diag, 'diag');
    checkBlasOffset(aOffset, a.length, 'aOffset');
    checkBlasOffset(bOffset, b.length, 'bOffset');
    final aDim = side == cblasLeft ? m : n;
    checkBlasMatrixLeadingDim(lda, 'lda', aDim);
    checkBlasMatrixLeadingDim(ldb, 'ldb', n);
    checkBlasMatrixBounds(a.length, aDim, aDim, aOffset, lda, 'a');
    checkBlasMatrixBounds(b.length, m, n, bOffset, ldb, 'b');
    return executeAcceleratedOperation(
      feature: 'BLAS',
      operation: 'strmm',
      isAvailable: isAvailable,
      accelerate: () => BlasNative.strmm(
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
      ),
      fallback: () => BlasDart.strmm(
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
      ),
    );
  }
}
