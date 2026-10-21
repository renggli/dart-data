// coverage:ignore-file
import 'dart:ffi' as ffi;
import 'dart:typed_data';

import '../utils/library_loader_ffi.dart';
import 'cblas_constants.dart';

/// Native CBLAS bindings via dart:ffi using leaf native calls.
abstract final class BlasNative {
  static final List<ffi.DynamicLibrary> _libs = platformBlasLibraries;

  static final bool _hasDdot = hasSymbol('cblas_ddot', _libs);
  static final bool _hasSdot = hasSymbol('cblas_sdot', _libs);
  static final bool _hasDnrm2 = hasSymbol('cblas_dnrm2', _libs);
  static final bool _hasSnrm2 = hasSymbol('cblas_snrm2', _libs);
  static final bool _hasDaxpy = hasSymbol('cblas_daxpy', _libs);
  static final bool _hasSaxpy = hasSymbol('cblas_saxpy', _libs);
  static final bool _hasDscal = hasSymbol('cblas_dscal', _libs);
  static final bool _hasSscal = hasSymbol('cblas_sscal', _libs);

  static final bool _hasDgemv = hasSymbol('cblas_dgemv', _libs);
  static final bool _hasSgemv = hasSymbol('cblas_sgemv', _libs);
  static final bool _hasDsyr2 = hasSymbol('cblas_dsyr2', _libs);
  static final bool _hasSsyr2 = hasSymbol('cblas_ssyr2', _libs);
  static final bool _hasDtrmv = hasSymbol('cblas_dtrmv', _libs);
  static final bool _hasStrmv = hasSymbol('cblas_strmv', _libs);

  static final bool _hasDgemm = hasSymbol('cblas_dgemm', _libs);
  static final bool _hasSgemm = hasSymbol('cblas_sgemm', _libs);
  static final bool _hasDsyrk = hasSymbol('cblas_dsyrk', _libs);
  static final bool _hasSsyrk = hasSymbol('cblas_ssyrk', _libs);
  static final bool _hasDsymm = hasSymbol('cblas_dsymm', _libs);
  static final bool _hasSsymm = hasSymbol('cblas_ssymm', _libs);
  static final bool _hasDtrmm = hasSymbol('cblas_dtrmm', _libs);
  static final bool _hasStrmm = hasSymbol('cblas_strmm', _libs);

  /// Whether native BLAS is loaded and available.
  static bool get isAvailable => _libs.isNotEmpty && _hasDgemm;

  static bool get hasDgemm => _hasDgemm;
  static bool get hasSgemm => _hasSgemm;

  // --- BLAS Level 1 ---

  static double? ddot({
    required int n,
    required Float64List x,
    required int xOffset,
    required int incX,
    required Float64List y,
    required int yOffset,
    required int incY,
  }) {
    if (!_hasDdot) return null;
    final xView = xOffset == 0 ? x : Float64List.sublistView(x, xOffset);
    final yView = yOffset == 0 ? y : Float64List.sublistView(y, yOffset);
    return _cblasDdot(n, xView.address, incX, yView.address, incY);
  }

  static double? sdot({
    required int n,
    required Float32List x,
    required int xOffset,
    required int incX,
    required Float32List y,
    required int yOffset,
    required int incY,
  }) {
    if (!_hasSdot) return null;
    final xView = xOffset == 0 ? x : Float32List.sublistView(x, xOffset);
    final yView = yOffset == 0 ? y : Float32List.sublistView(y, yOffset);
    return _cblasSdot(n, xView.address, incX, yView.address, incY);
  }

  static double? dnrm2({
    required int n,
    required Float64List x,
    required int xOffset,
    required int incX,
  }) {
    if (!_hasDnrm2) return null;
    final xView = xOffset == 0 ? x : Float64List.sublistView(x, xOffset);
    return _cblasDnrm2(n, xView.address, incX);
  }

  static double? snrm2({
    required int n,
    required Float32List x,
    required int xOffset,
    required int incX,
  }) {
    if (!_hasSnrm2) return null;
    final xView = xOffset == 0 ? x : Float32List.sublistView(x, xOffset);
    return _cblasSnrm2(n, xView.address, incX);
  }

  static bool daxpy({
    required int n,
    required double alpha,
    required Float64List x,
    required int xOffset,
    required int incX,
    required Float64List y,
    required int yOffset,
    required int incY,
  }) {
    if (!_hasDaxpy) return false;
    final xView = xOffset == 0 ? x : Float64List.sublistView(x, xOffset);
    final yView = yOffset == 0 ? y : Float64List.sublistView(y, yOffset);
    _cblasDaxpy(n, alpha, xView.address, incX, yView.address, incY);
    return true;
  }

  static bool saxpy({
    required int n,
    required double alpha,
    required Float32List x,
    required int xOffset,
    required int incX,
    required Float32List y,
    required int yOffset,
    required int incY,
  }) {
    if (!_hasSaxpy) return false;
    final xView = xOffset == 0 ? x : Float32List.sublistView(x, xOffset);
    final yView = yOffset == 0 ? y : Float32List.sublistView(y, yOffset);
    _cblasSaxpy(n, alpha, xView.address, incX, yView.address, incY);
    return true;
  }

  static bool dscal({
    required int n,
    required double alpha,
    required Float64List x,
    required int xOffset,
    required int incX,
  }) {
    if (!_hasDscal) return false;
    final xView = xOffset == 0 ? x : Float64List.sublistView(x, xOffset);
    _cblasDscal(n, alpha, xView.address, incX);
    return true;
  }

  static bool sscal({
    required int n,
    required double alpha,
    required Float32List x,
    required int xOffset,
    required int incX,
  }) {
    if (!_hasSscal) return false;
    final xView = xOffset == 0 ? x : Float32List.sublistView(x, xOffset);
    _cblasSscal(n, alpha, xView.address, incX);
    return true;
  }

  // --- BLAS Level 2 ---

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
  }) {
    if (!_hasDgemv) return false;
    final aView = aOffset == 0 ? a : Float64List.sublistView(a, aOffset);
    final xView = xOffset == 0 ? x : Float64List.sublistView(x, xOffset);
    final yView = yOffset == 0 ? y : Float64List.sublistView(y, yOffset);
    _cblasDgemv(
      cblasRowMajor,
      transA,
      m,
      n,
      alpha,
      aView.address,
      lda,
      xView.address,
      incX,
      beta,
      yView.address,
      incY,
    );
    return true;
  }

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
  }) {
    if (!_hasSgemv) return false;
    final aView = aOffset == 0 ? a : Float32List.sublistView(a, aOffset);
    final xView = xOffset == 0 ? x : Float32List.sublistView(x, xOffset);
    final yView = yOffset == 0 ? y : Float32List.sublistView(y, yOffset);
    _cblasSgemv(
      cblasRowMajor,
      transA,
      m,
      n,
      alpha,
      aView.address,
      lda,
      xView.address,
      incX,
      beta,
      yView.address,
      incY,
    );
    return true;
  }

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
  }) {
    if (!_hasDsyr2) return false;
    final xView = xOffset == 0 ? x : Float64List.sublistView(x, xOffset);
    final yView = yOffset == 0 ? y : Float64List.sublistView(y, yOffset);
    final aView = aOffset == 0 ? a : Float64List.sublistView(a, aOffset);
    _cblasDsyr2(
      cblasRowMajor,
      uplo,
      n,
      alpha,
      xView.address,
      incX,
      yView.address,
      incY,
      aView.address,
      lda,
    );
    _mirrorSymmetricDouble(a, aOffset, n, lda, uplo);
    return true;
  }

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
  }) {
    if (!_hasSsyr2) return false;
    final xView = xOffset == 0 ? x : Float32List.sublistView(x, xOffset);
    final yView = yOffset == 0 ? y : Float32List.sublistView(y, yOffset);
    final aView = aOffset == 0 ? a : Float32List.sublistView(a, aOffset);
    _cblasSsyr2(
      cblasRowMajor,
      uplo,
      n,
      alpha,
      xView.address,
      incX,
      yView.address,
      incY,
      aView.address,
      lda,
    );
    _mirrorSymmetricFloat(a, aOffset, n, lda, uplo);
    return true;
  }

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
  }) {
    if (!_hasDtrmv) return false;
    final aView = aOffset == 0 ? a : Float64List.sublistView(a, aOffset);
    final xView = xOffset == 0 ? x : Float64List.sublistView(x, xOffset);
    _cblasDtrmv(
      cblasRowMajor,
      uplo,
      trans,
      diag,
      n,
      aView.address,
      lda,
      xView.address,
      incX,
    );
    return true;
  }

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
  }) {
    if (!_hasStrmv) return false;
    final aView = aOffset == 0 ? a : Float32List.sublistView(a, aOffset);
    final xView = xOffset == 0 ? x : Float32List.sublistView(x, xOffset);
    _cblasStrmv(
      cblasRowMajor,
      uplo,
      trans,
      diag,
      n,
      aView.address,
      lda,
      xView.address,
      incX,
    );
    return true;
  }

  // --- BLAS Level 3 ---

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
  }) {
    if (!_hasDgemm) return false;
    final aView = aOffset == 0 ? a : Float64List.sublistView(a, aOffset);
    final bView = bOffset == 0 ? b : Float64List.sublistView(b, bOffset);
    final cView = cOffset == 0 ? c : Float64List.sublistView(c, cOffset);
    _cblasDgemm(
      cblasRowMajor,
      transA,
      transB,
      m,
      n,
      k,
      alpha,
      aView.address,
      lda,
      bView.address,
      ldb,
      beta,
      cView.address,
      ldc,
    );
    return true;
  }

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
  }) {
    if (!_hasSgemm) return false;
    final aView = aOffset == 0 ? a : Float32List.sublistView(a, aOffset);
    final bView = bOffset == 0 ? b : Float32List.sublistView(b, bOffset);
    final cView = cOffset == 0 ? c : Float32List.sublistView(c, cOffset);
    _cblasSgemm(
      cblasRowMajor,
      transA,
      transB,
      m,
      n,
      k,
      alpha,
      aView.address,
      lda,
      bView.address,
      ldb,
      beta,
      cView.address,
      ldc,
    );
    return true;
  }

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
  }) {
    if (!_hasDsyrk) return false;
    final aView = aOffset == 0 ? a : Float64List.sublistView(a, aOffset);
    final cView = cOffset == 0 ? c : Float64List.sublistView(c, cOffset);
    _cblasDsyrk(
      cblasRowMajor,
      uplo,
      trans,
      n,
      k,
      alpha,
      aView.address,
      lda,
      beta,
      cView.address,
      ldc,
    );
    _mirrorSymmetricDouble(c, cOffset, n, ldc, uplo);
    return true;
  }

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
  }) {
    if (!_hasSsyrk) return false;
    final aView = aOffset == 0 ? a : Float32List.sublistView(a, aOffset);
    final cView = cOffset == 0 ? c : Float32List.sublistView(c, cOffset);
    _cblasSsyrk(
      cblasRowMajor,
      uplo,
      trans,
      n,
      k,
      alpha,
      aView.address,
      lda,
      beta,
      cView.address,
      ldc,
    );
    _mirrorSymmetricFloat(c, cOffset, n, ldc, uplo);
    return true;
  }

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
  }) {
    if (!_hasDsymm) return false;
    final aView = aOffset == 0 ? a : Float64List.sublistView(a, aOffset);
    final bView = bOffset == 0 ? b : Float64List.sublistView(b, bOffset);
    final cView = cOffset == 0 ? c : Float64List.sublistView(c, cOffset);
    _cblasDsymm(
      cblasRowMajor,
      side,
      uplo,
      m,
      n,
      alpha,
      aView.address,
      lda,
      bView.address,
      ldb,
      beta,
      cView.address,
      ldc,
    );
    return true;
  }

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
  }) {
    if (!_hasSsymm) return false;
    final aView = aOffset == 0 ? a : Float32List.sublistView(a, aOffset);
    final bView = bOffset == 0 ? b : Float32List.sublistView(b, bOffset);
    final cView = cOffset == 0 ? c : Float32List.sublistView(c, cOffset);
    _cblasSsymm(
      cblasRowMajor,
      side,
      uplo,
      m,
      n,
      alpha,
      aView.address,
      lda,
      bView.address,
      ldb,
      beta,
      cView.address,
      ldc,
    );
    return true;
  }

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
  }) {
    if (!_hasDtrmm) return false;
    final aView = aOffset == 0 ? a : Float64List.sublistView(a, aOffset);
    final bView = bOffset == 0 ? b : Float64List.sublistView(b, bOffset);
    _cblasDtrmm(
      cblasRowMajor,
      side,
      uplo,
      transA,
      diag,
      m,
      n,
      alpha,
      aView.address,
      lda,
      bView.address,
      ldb,
    );
    return true;
  }

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
  }) {
    if (!_hasStrmm) return false;
    final aView = aOffset == 0 ? a : Float32List.sublistView(a, aOffset);
    final bView = bOffset == 0 ? b : Float32List.sublistView(b, bOffset);
    _cblasStrmm(
      cblasRowMajor,
      side,
      uplo,
      transA,
      diag,
      m,
      n,
      alpha,
      aView.address,
      lda,
      bView.address,
      ldb,
    );
    return true;
  }

  static void _mirrorSymmetricDouble(
    Float64List c,
    int cOffset,
    int n,
    int ldc,
    int uplo,
  ) {
    if (uplo == cblasUpper) {
      for (var i = 0; i < n; i++) {
        for (var j = i + 1; j < n; j++) {
          c[cOffset + j * ldc + i] = c[cOffset + i * ldc + j];
        }
      }
    } else {
      for (var i = 0; i < n; i++) {
        for (var j = 0; j < i; j++) {
          c[cOffset + j * ldc + i] = c[cOffset + i * ldc + j];
        }
      }
    }
  }

  static void _mirrorSymmetricFloat(
    Float32List c,
    int cOffset,
    int n,
    int ldc,
    int uplo,
  ) {
    if (uplo == cblasUpper) {
      for (var i = 0; i < n; i++) {
        for (var j = i + 1; j < n; j++) {
          c[cOffset + j * ldc + i] = c[cOffset + i * ldc + j];
        }
      }
    } else {
      for (var i = 0; i < n; i++) {
        for (var j = 0; j < i; j++) {
          c[cOffset + j * ldc + i] = c[cOffset + i * ldc + j];
        }
      }
    }
  }
}

// --- CBLAS Native FFI Declarations ---

@ffi.Native<
  ffi.Double Function(
    ffi.Int32,
    ffi.Pointer<ffi.Double>,
    ffi.Int32,
    ffi.Pointer<ffi.Double>,
    ffi.Int32,
  )
>(symbol: 'cblas_ddot', isLeaf: true)
external double _cblasDdot(
  int n,
  ffi.Pointer<ffi.Double> x,
  int incX,
  ffi.Pointer<ffi.Double> y,
  int incY,
);

@ffi.Native<
  ffi.Float Function(
    ffi.Int32,
    ffi.Pointer<ffi.Float>,
    ffi.Int32,
    ffi.Pointer<ffi.Float>,
    ffi.Int32,
  )
>(symbol: 'cblas_sdot', isLeaf: true)
external double _cblasSdot(
  int n,
  ffi.Pointer<ffi.Float> x,
  int incX,
  ffi.Pointer<ffi.Float> y,
  int incY,
);

@ffi.Native<ffi.Double Function(ffi.Int32, ffi.Pointer<ffi.Double>, ffi.Int32)>(
  symbol: 'cblas_dnrm2',
  isLeaf: true,
)
external double _cblasDnrm2(int n, ffi.Pointer<ffi.Double> x, int incX);

@ffi.Native<ffi.Float Function(ffi.Int32, ffi.Pointer<ffi.Float>, ffi.Int32)>(
  symbol: 'cblas_snrm2',
  isLeaf: true,
)
external double _cblasSnrm2(int n, ffi.Pointer<ffi.Float> x, int incX);

@ffi.Native<
  ffi.Void Function(
    ffi.Int32,
    ffi.Double,
    ffi.Pointer<ffi.Double>,
    ffi.Int32,
    ffi.Pointer<ffi.Double>,
    ffi.Int32,
  )
>(symbol: 'cblas_daxpy', isLeaf: true)
external void _cblasDaxpy(
  int n,
  double alpha,
  ffi.Pointer<ffi.Double> x,
  int incX,
  ffi.Pointer<ffi.Double> y,
  int incY,
);

@ffi.Native<
  ffi.Void Function(
    ffi.Int32,
    ffi.Float,
    ffi.Pointer<ffi.Float>,
    ffi.Int32,
    ffi.Pointer<ffi.Float>,
    ffi.Int32,
  )
>(symbol: 'cblas_saxpy', isLeaf: true)
external void _cblasSaxpy(
  int n,
  double alpha,
  ffi.Pointer<ffi.Float> x,
  int incX,
  ffi.Pointer<ffi.Float> y,
  int incY,
);

@ffi.Native<
  ffi.Void Function(ffi.Int32, ffi.Double, ffi.Pointer<ffi.Double>, ffi.Int32)
>(symbol: 'cblas_dscal', isLeaf: true)
external void _cblasDscal(
  int n,
  double alpha,
  ffi.Pointer<ffi.Double> x,
  int incX,
);

@ffi.Native<
  ffi.Void Function(ffi.Int32, ffi.Float, ffi.Pointer<ffi.Float>, ffi.Int32)
>(symbol: 'cblas_sscal', isLeaf: true)
external void _cblasSscal(
  int n,
  double alpha,
  ffi.Pointer<ffi.Float> x,
  int incX,
);

@ffi.Native<
  ffi.Void Function(
    ffi.Int32,
    ffi.Int32,
    ffi.Int32,
    ffi.Int32,
    ffi.Double,
    ffi.Pointer<ffi.Double>,
    ffi.Int32,
    ffi.Pointer<ffi.Double>,
    ffi.Int32,
    ffi.Double,
    ffi.Pointer<ffi.Double>,
    ffi.Int32,
  )
>(symbol: 'cblas_dgemv', isLeaf: true)
external void _cblasDgemv(
  int layout,
  int transA,
  int m,
  int n,
  double alpha,
  ffi.Pointer<ffi.Double> a,
  int lda,
  ffi.Pointer<ffi.Double> x,
  int incX,
  double beta,
  ffi.Pointer<ffi.Double> y,
  int incY,
);

@ffi.Native<
  ffi.Void Function(
    ffi.Int32,
    ffi.Int32,
    ffi.Int32,
    ffi.Int32,
    ffi.Float,
    ffi.Pointer<ffi.Float>,
    ffi.Int32,
    ffi.Pointer<ffi.Float>,
    ffi.Int32,
    ffi.Float,
    ffi.Pointer<ffi.Float>,
    ffi.Int32,
  )
>(symbol: 'cblas_sgemv', isLeaf: true)
external void _cblasSgemv(
  int layout,
  int transA,
  int m,
  int n,
  double alpha,
  ffi.Pointer<ffi.Float> a,
  int lda,
  ffi.Pointer<ffi.Float> x,
  int incX,
  double beta,
  ffi.Pointer<ffi.Float> y,
  int incY,
);

@ffi.Native<
  ffi.Void Function(
    ffi.Int32,
    ffi.Int32,
    ffi.Int32,
    ffi.Double,
    ffi.Pointer<ffi.Double>,
    ffi.Int32,
    ffi.Pointer<ffi.Double>,
    ffi.Int32,
    ffi.Pointer<ffi.Double>,
    ffi.Int32,
  )
>(symbol: 'cblas_dsyr2', isLeaf: true)
external void _cblasDsyr2(
  int layout,
  int uplo,
  int n,
  double alpha,
  ffi.Pointer<ffi.Double> x,
  int incX,
  ffi.Pointer<ffi.Double> y,
  int incY,
  ffi.Pointer<ffi.Double> a,
  int lda,
);

@ffi.Native<
  ffi.Void Function(
    ffi.Int32,
    ffi.Int32,
    ffi.Int32,
    ffi.Float,
    ffi.Pointer<ffi.Float>,
    ffi.Int32,
    ffi.Pointer<ffi.Float>,
    ffi.Int32,
    ffi.Pointer<ffi.Float>,
    ffi.Int32,
  )
>(symbol: 'cblas_ssyr2', isLeaf: true)
external void _cblasSsyr2(
  int layout,
  int uplo,
  int n,
  double alpha,
  ffi.Pointer<ffi.Float> x,
  int incX,
  ffi.Pointer<ffi.Float> y,
  int incY,
  ffi.Pointer<ffi.Float> a,
  int lda,
);

@ffi.Native<
  ffi.Void Function(
    ffi.Int32,
    ffi.Int32,
    ffi.Int32,
    ffi.Int32,
    ffi.Int32,
    ffi.Pointer<ffi.Double>,
    ffi.Int32,
    ffi.Pointer<ffi.Double>,
    ffi.Int32,
  )
>(symbol: 'cblas_dtrmv', isLeaf: true)
external void _cblasDtrmv(
  int layout,
  int uplo,
  int trans,
  int diag,
  int n,
  ffi.Pointer<ffi.Double> a,
  int lda,
  ffi.Pointer<ffi.Double> x,
  int incX,
);

@ffi.Native<
  ffi.Void Function(
    ffi.Int32,
    ffi.Int32,
    ffi.Int32,
    ffi.Int32,
    ffi.Int32,
    ffi.Pointer<ffi.Float>,
    ffi.Int32,
    ffi.Pointer<ffi.Float>,
    ffi.Int32,
  )
>(symbol: 'cblas_strmv', isLeaf: true)
external void _cblasStrmv(
  int layout,
  int uplo,
  int trans,
  int diag,
  int n,
  ffi.Pointer<ffi.Float> a,
  int lda,
  ffi.Pointer<ffi.Float> x,
  int incX,
);

@ffi.Native<
  ffi.Void Function(
    ffi.Int32,
    ffi.Int32,
    ffi.Int32,
    ffi.Int32,
    ffi.Int32,
    ffi.Int32,
    ffi.Double,
    ffi.Pointer<ffi.Double>,
    ffi.Int32,
    ffi.Pointer<ffi.Double>,
    ffi.Int32,
    ffi.Double,
    ffi.Pointer<ffi.Double>,
    ffi.Int32,
  )
>(symbol: 'cblas_dgemm', isLeaf: true)
external void _cblasDgemm(
  int layout,
  int transA,
  int transB,
  int m,
  int n,
  int k,
  double alpha,
  ffi.Pointer<ffi.Double> a,
  int lda,
  ffi.Pointer<ffi.Double> b,
  int ldb,
  double beta,
  ffi.Pointer<ffi.Double> c,
  int ldc,
);

@ffi.Native<
  ffi.Void Function(
    ffi.Int32,
    ffi.Int32,
    ffi.Int32,
    ffi.Int32,
    ffi.Int32,
    ffi.Int32,
    ffi.Float,
    ffi.Pointer<ffi.Float>,
    ffi.Int32,
    ffi.Pointer<ffi.Float>,
    ffi.Int32,
    ffi.Float,
    ffi.Pointer<ffi.Float>,
    ffi.Int32,
  )
>(symbol: 'cblas_sgemm', isLeaf: true)
external void _cblasSgemm(
  int layout,
  int transA,
  int transB,
  int m,
  int n,
  int k,
  double alpha,
  ffi.Pointer<ffi.Float> a,
  int lda,
  ffi.Pointer<ffi.Float> b,
  int ldb,
  double beta,
  ffi.Pointer<ffi.Float> c,
  int ldc,
);

@ffi.Native<
  ffi.Void Function(
    ffi.Int32,
    ffi.Int32,
    ffi.Int32,
    ffi.Int32,
    ffi.Int32,
    ffi.Double,
    ffi.Pointer<ffi.Double>,
    ffi.Int32,
    ffi.Double,
    ffi.Pointer<ffi.Double>,
    ffi.Int32,
  )
>(symbol: 'cblas_dsyrk', isLeaf: true)
external void _cblasDsyrk(
  int layout,
  int uplo,
  int trans,
  int n,
  int k,
  double alpha,
  ffi.Pointer<ffi.Double> a,
  int lda,
  double beta,
  ffi.Pointer<ffi.Double> c,
  int ldc,
);

@ffi.Native<
  ffi.Void Function(
    ffi.Int32,
    ffi.Int32,
    ffi.Int32,
    ffi.Int32,
    ffi.Int32,
    ffi.Float,
    ffi.Pointer<ffi.Float>,
    ffi.Int32,
    ffi.Float,
    ffi.Pointer<ffi.Float>,
    ffi.Int32,
  )
>(symbol: 'cblas_ssyrk', isLeaf: true)
external void _cblasSsyrk(
  int layout,
  int uplo,
  int trans,
  int n,
  int k,
  double alpha,
  ffi.Pointer<ffi.Float> a,
  int lda,
  double beta,
  ffi.Pointer<ffi.Float> c,
  int ldc,
);

@ffi.Native<
  ffi.Void Function(
    ffi.Int32,
    ffi.Int32,
    ffi.Int32,
    ffi.Int32,
    ffi.Int32,
    ffi.Double,
    ffi.Pointer<ffi.Double>,
    ffi.Int32,
    ffi.Pointer<ffi.Double>,
    ffi.Int32,
    ffi.Double,
    ffi.Pointer<ffi.Double>,
    ffi.Int32,
  )
>(symbol: 'cblas_dsymm', isLeaf: true)
external void _cblasDsymm(
  int layout,
  int side,
  int uplo,
  int m,
  int n,
  double alpha,
  ffi.Pointer<ffi.Double> a,
  int lda,
  ffi.Pointer<ffi.Double> b,
  int ldb,
  double beta,
  ffi.Pointer<ffi.Double> c,
  int ldc,
);

@ffi.Native<
  ffi.Void Function(
    ffi.Int32,
    ffi.Int32,
    ffi.Int32,
    ffi.Int32,
    ffi.Int32,
    ffi.Float,
    ffi.Pointer<ffi.Float>,
    ffi.Int32,
    ffi.Pointer<ffi.Float>,
    ffi.Int32,
    ffi.Float,
    ffi.Pointer<ffi.Float>,
    ffi.Int32,
  )
>(symbol: 'cblas_ssymm', isLeaf: true)
external void _cblasSsymm(
  int layout,
  int side,
  int uplo,
  int m,
  int n,
  double alpha,
  ffi.Pointer<ffi.Float> a,
  int lda,
  ffi.Pointer<ffi.Float> b,
  int ldb,
  double beta,
  ffi.Pointer<ffi.Float> c,
  int ldc,
);

@ffi.Native<
  ffi.Void Function(
    ffi.Int32,
    ffi.Int32,
    ffi.Int32,
    ffi.Int32,
    ffi.Int32,
    ffi.Int32,
    ffi.Int32,
    ffi.Double,
    ffi.Pointer<ffi.Double>,
    ffi.Int32,
    ffi.Pointer<ffi.Double>,
    ffi.Int32,
  )
>(symbol: 'cblas_dtrmm', isLeaf: true)
external void _cblasDtrmm(
  int layout,
  int side,
  int uplo,
  int transA,
  int diag,
  int m,
  int n,
  double alpha,
  ffi.Pointer<ffi.Double> a,
  int lda,
  ffi.Pointer<ffi.Double> b,
  int ldb,
);

@ffi.Native<
  ffi.Void Function(
    ffi.Int32,
    ffi.Int32,
    ffi.Int32,
    ffi.Int32,
    ffi.Int32,
    ffi.Int32,
    ffi.Int32,
    ffi.Float,
    ffi.Pointer<ffi.Float>,
    ffi.Int32,
    ffi.Pointer<ffi.Float>,
    ffi.Int32,
  )
>(symbol: 'cblas_strmm', isLeaf: true)
external void _cblasStrmm(
  int layout,
  int side,
  int uplo,
  int transA,
  int diag,
  int m,
  int n,
  double alpha,
  ffi.Pointer<ffi.Float> a,
  int lda,
  ffi.Pointer<ffi.Float> b,
  int ldb,
);
