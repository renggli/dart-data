// coverage:ignore-file
// ignore_for_file: constant_identifier_names

import 'dart:ffi' as ffi;
import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

/// CBLAS Matrix Layout Order.
const int cblasRowMajor = 101;
const int cblasColMajor = 102;

/// CBLAS Transposition options.
const int cblasNoTrans = 111;
const int cblasTrans = 112;
const int cblasConjTrans = 113;

/// CBLAS Upper/Lower triangular matrix options.
const int cblasUpper = 121;
const int cblasLower = 122;

/// CBLAS Unit/Non-unit diagonal options.
const int cblasNonUnit = 131;
const int cblasUnit = 132;

/// CBLAS Side options (left/right).
const int cblasLeft = 141;
const int cblasRight = 142;

/// Loads the platform BLAS library.
BlasLibrary loadBlas() => BlasLibrary._(_loadPlatformLibraries());

/// Native BLAS/LAPACK bindings via dart:ffi using leaf native calls and
/// typed data direct addresses.
class BlasLibrary {
  new _(this.libraries)
    : _hasDgemm = _hasSymbolIn('cblas_dgemm', libraries),
      _hasSgemm = _hasSymbolIn('cblas_sgemm', libraries),
      _hasDgemv = _hasSymbolIn('cblas_dgemv', libraries),
      _hasSgemv = _hasSymbolIn('cblas_sgemv', libraries),
      _hasDtrmv = _hasSymbolIn('cblas_dtrmv', libraries),
      _hasStrmv = _hasSymbolIn('cblas_strmv', libraries),
      _hasDdot = _hasSymbolIn('cblas_ddot', libraries),
      _hasSdot = _hasSymbolIn('cblas_sdot', libraries),
      _hasDnrm2 = _hasSymbolIn('cblas_dnrm2', libraries),
      _hasSnrm2 = _hasSymbolIn('cblas_snrm2', libraries),
      _hasDaxpy = _hasSymbolIn('cblas_daxpy', libraries),
      _hasSaxpy = _hasSymbolIn('cblas_saxpy', libraries),
      _hasDscal = _hasSymbolIn('cblas_dscal', libraries),
      _hasSscal = _hasSymbolIn('cblas_sscal', libraries),
      _hasDsyrk = _hasSymbolIn('cblas_dsyrk', libraries),
      _hasSsyrk = _hasSymbolIn('cblas_ssyrk', libraries),
      _hasDsyr2 = _hasSymbolIn('cblas_dsyr2', libraries),
      _hasSsyr2 = _hasSymbolIn('cblas_ssyr2', libraries),
      _hasDsymm = _hasSymbolIn('cblas_dsymm', libraries),
      _hasSsymm = _hasSymbolIn('cblas_ssymm', libraries),
      _hasDtrmm = _hasSymbolIn('cblas_dtrmm', libraries),
      _hasStrmm = _hasSymbolIn('cblas_strmm', libraries),
      _hasLapackeDgesv = _hasSymbolIn('LAPACKE_dgesv', libraries),
      _hasClapackDgesv = _hasSymbolIn('clapack_dgesv', libraries),
      _hasDgetrf = _hasSymbolIn('dgetrf_', libraries),
      _hasDgetrs = _hasSymbolIn('dgetrs_', libraries),
      _hasDgesv = _hasSymbolIn('dgesv_', libraries),
      _hasLapackeDgels = _hasSymbolIn('LAPACKE_dgels', libraries),
      _hasDgels = _hasSymbolIn('dgels_', libraries),
      _hasDpotrf = _hasSymbolIn('dpotrf_', libraries),
      _hasDgeqrf = _hasSymbolIn('dgeqrf_', libraries),
      _hasDgesvd =
          _hasSymbolIn('dgesvd_', libraries) ||
          _hasSymbolIn('dgesdd_', libraries),
      _hasLapackeDsyev = _hasSymbolIn('LAPACKE_dsyev', libraries),
      _hasLapackeSsyev = _hasSymbolIn('LAPACKE_ssyev', libraries),
      _hasDsyev = _hasSymbolIn('dsyev_', libraries),
      _hasSsyev = _hasSymbolIn('ssyev_', libraries);

  /// The underlying platform dynamic libraries.
  final List<ffi.DynamicLibrary> libraries;

  final bool _hasDgemm;
  final bool _hasSgemm;
  final bool _hasDgemv;
  final bool _hasSgemv;
  final bool _hasDtrmv;
  final bool _hasStrmv;
  final bool _hasDdot;
  final bool _hasSdot;
  final bool _hasDnrm2;
  final bool _hasSnrm2;
  final bool _hasDaxpy;
  final bool _hasSaxpy;
  final bool _hasDscal;
  final bool _hasSscal;
  final bool _hasDsyrk;
  final bool _hasSsyrk;
  final bool _hasDsyr2;
  final bool _hasSsyr2;
  final bool _hasDsymm;
  final bool _hasSsymm;
  final bool _hasDtrmm;
  final bool _hasStrmm;
  final bool _hasLapackeDgesv;
  final bool _hasClapackDgesv;
  final bool _hasDgetrf;
  final bool _hasDgetrs;
  final bool _hasDgesv;
  final bool _hasLapackeDgels;
  final bool _hasDgels;
  final bool _hasDpotrf;
  final bool _hasDgeqrf;
  final bool _hasDgesvd;
  final bool _hasLapackeDsyev;
  final bool _hasLapackeSsyev;
  final bool _hasDsyev;
  final bool _hasSsyev;

  static bool _hasSymbolIn(String name, List<ffi.DynamicLibrary> libraries) {
    try {
      if (ffi.DynamicLibrary.process().providesSymbol(name)) return true;
    } catch (_) {}
    for (final lib in libraries) {
      try {
        if (lib.providesSymbol(name)) return true;
      } catch (_) {}
    }
    return false;
  }

  bool get isAvailable => _hasDgemm;

  /// Whether native QR factorization (_dgeqrf) is bound.
  bool get hasDgeqrf => _hasDgeqrf;

  /// Whether native SVD factorization (_dgesvd or _dgesdd) is bound.
  bool get hasDgesvd => _hasDgesvd;

  /// Whether native symmetric eigenvalue solver (_dsyev or _lapackeDsyev) is
  /// bound.
  bool get hasDsyev => _hasDsyev || _hasLapackeDsyev;

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

  bool dtrmv({
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
    if (!_hasDtrmv) return false;
    if (n == 0) return true;
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

  bool strmv({
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
    if (!_hasStrmv) return false;
    if (n == 0) return true;
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

  double? ddot({
    required int n,
    required Float64List x,
    int xOffset = 0,
    required int incX,
    required Float64List y,
    int yOffset = 0,
    required int incY,
  }) {
    if (!_hasDdot) return null;
    final xView = xOffset == 0 ? x : Float64List.sublistView(x, xOffset);
    final yView = yOffset == 0 ? y : Float64List.sublistView(y, yOffset);
    return _cblasDdot(n, xView.address, incX, yView.address, incY);
  }

  double? sdot({
    required int n,
    required Float32List x,
    int xOffset = 0,
    required int incX,
    required Float32List y,
    int yOffset = 0,
    required int incY,
  }) {
    if (!_hasSdot) return null;
    final xView = xOffset == 0 ? x : Float32List.sublistView(x, xOffset);
    final yView = yOffset == 0 ? y : Float32List.sublistView(y, yOffset);
    return _cblasSdot(n, xView.address, incX, yView.address, incY);
  }

  double? dnrm2({
    required int n,
    required Float64List x,
    int xOffset = 0,
    required int incX,
  }) {
    if (!_hasDnrm2) return null;
    final xView = xOffset == 0 ? x : Float64List.sublistView(x, xOffset);
    return _cblasDnrm2(n, xView.address, incX);
  }

  double? snrm2({
    required int n,
    required Float32List x,
    int xOffset = 0,
    required int incX,
  }) {
    if (!_hasSnrm2) return null;
    final xView = xOffset == 0 ? x : Float32List.sublistView(x, xOffset);
    return _cblasSnrm2(n, xView.address, incX);
  }

  bool daxpy({
    required int n,
    required double alpha,
    required Float64List x,
    int xOffset = 0,
    required int incX,
    required Float64List y,
    int yOffset = 0,
    required int incY,
  }) {
    if (!_hasDaxpy) return false;
    final xView = xOffset == 0 ? x : Float64List.sublistView(x, xOffset);
    final yView = yOffset == 0 ? y : Float64List.sublistView(y, yOffset);
    _cblasDaxpy(n, alpha, xView.address, incX, yView.address, incY);
    return true;
  }

  bool saxpy({
    required int n,
    required double alpha,
    required Float32List x,
    int xOffset = 0,
    required int incX,
    required Float32List y,
    int yOffset = 0,
    required int incY,
  }) {
    if (!_hasSaxpy) return false;
    final xView = xOffset == 0 ? x : Float32List.sublistView(x, xOffset);
    final yView = yOffset == 0 ? y : Float32List.sublistView(y, yOffset);
    _cblasSaxpy(n, alpha, xView.address, incX, yView.address, incY);
    return true;
  }

  bool dscal({
    required int n,
    required double alpha,
    required Float64List x,
    int xOffset = 0,
    required int incX,
  }) {
    if (!_hasDscal) return false;
    final xView = xOffset == 0 ? x : Float64List.sublistView(x, xOffset);
    _cblasDscal(n, alpha, xView.address, incX);
    return true;
  }

  bool sscal({
    required int n,
    required double alpha,
    required Float32List x,
    int xOffset = 0,
    required int incX,
  }) {
    if (!_hasSscal) return false;
    final xView = xOffset == 0 ? x : Float32List.sublistView(x, xOffset);
    _cblasSscal(n, alpha, xView.address, incX);
    return true;
  }

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

  bool dsymm({
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

  bool ssymm({
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

  bool dtrmm({
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
  }) {
    if (!_hasDtrmm) return false;
    if (m == 0 || n == 0) return true;
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

  bool strmm({
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
  }) {
    if (!_hasStrmm) return false;
    if (m == 0 || n == 0) return true;
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

  bool dpotrf({
    int uplo = cblasUpper,
    required int n,
    required Float64List a,
    int aOffset = 0,
    required int lda,
  }) {
    if (!_hasDpotrf) return false;
    return using((arena) {
      final fortranUplo = uplo == cblasUpper ? 76 : 85;
      final uploPtr = arena<ffi.Uint8>()..value = fortranUplo;
      final nPtr = arena<ffi.Int32>()..value = n;
      final ldaPtr = arena<ffi.Int32>()..value = lda >= n ? lda : n;
      final info = arena<ffi.Int32>();
      final aView = aOffset == 0 ? a : Float64List.sublistView(a, aOffset);

      _fortranDpotrf(uploPtr, nPtr, aView.address, ldaPtr, info);
      return info.value == 0;
    });
  }

  /// Solves the general linear system $A X = B$ for $X$.
  bool dgesv({
    required int n,
    required int nrhs,
    required Float64List a,
    int aOffset = 0,
    required int lda,
    required Float64List b,
    int bOffset = 0,
    required int ldb,
  }) {
    if (n < 0 || nrhs < 0 || lda < n || (nrhs > 0 && ldb < nrhs)) return false;
    if (n == 0 || nrhs == 0) return true;
    final aRequired = aOffset + (n - 1) * lda + n;
    final bRequired = bOffset + (n - 1) * ldb + nrhs;
    if (a.length < aRequired || b.length < bRequired) return false;

    // coverage:ignore-start
    if (_hasLapackeDgesv || _hasClapackDgesv) {
      return using((arena) {
        final aLen = n * lda;
        final aPtr = arena<ffi.Double>(aLen);
        if (lda == n) {
          aPtr.asTypedList(n * n).setRange(0, n * n, a, aOffset);
        } else {
          for (var i = 0; i < n; i++) {
            for (var j = 0; j < n; j++) {
              aPtr[i * lda + j] = a[aOffset + i * lda + j];
            }
          }
        }

        final isContiguous1D = nrhs == 1 && ldb == 1;
        final ipiv = arena<ffi.Int32>(n);

        if (isContiguous1D) {
          final bView = bOffset == 0 ? b : Float64List.sublistView(b, bOffset);
          final info = _hasLapackeDgesv
              ? _lapackeDgesv(
                  cblasRowMajor,
                  n,
                  nrhs,
                  aPtr,
                  lda,
                  ipiv,
                  bView.address,
                  ldb,
                )
              : _clapackDgesv(
                  cblasRowMajor,
                  n,
                  nrhs,
                  aPtr,
                  lda,
                  ipiv,
                  bView.address,
                  ldb,
                );
          return info == 0;
        } else {
          final bLen = n * ldb;
          final bPtr = arena<ffi.Double>(bLen);
          for (var i = 0; i < n; i++) {
            for (var j = 0; j < nrhs; j++) {
              bPtr[i * ldb + j] = b[bOffset + i * ldb + j];
            }
          }
          final info = _hasLapackeDgesv
              ? _lapackeDgesv(
                  cblasRowMajor,
                  n,
                  nrhs,
                  aPtr,
                  lda,
                  ipiv,
                  bPtr,
                  ldb,
                )
              : _clapackDgesv(
                  cblasRowMajor,
                  n,
                  nrhs,
                  aPtr,
                  lda,
                  ipiv,
                  bPtr,
                  ldb,
                );
          if (info == 0) {
            for (var i = 0; i < n; i++) {
              for (var j = 0; j < nrhs; j++) {
                b[bOffset + i * ldb + j] = bPtr[i * ldb + j];
              }
            }
            return true;
          }
          return false;
        }
      });
    }
    // coverage:ignore-end

    if (_hasDgetrf && _hasDgetrs) {
      return using((arena) {
        final aLen = n * lda;
        final aPtr = arena<ffi.Double>(aLen);
        if (lda == n) {
          aPtr.asTypedList(n * n).setRange(0, n * n, a, aOffset);
        } else {
          for (var i = 0; i < n; i++) {
            for (var j = 0; j < n; j++) {
              aPtr[i * lda + j] = a[aOffset + i * lda + j];
            }
          }
        }

        final isContiguous1D = nrhs == 1 && ldb == 1;
        final nPtr = arena<ffi.Int32>()..value = n;
        final nrhsPtr = arena<ffi.Int32>()..value = nrhs;
        final ldaPtr = arena<ffi.Int32>()..value = lda >= n ? lda : n;
        final ldbPtr = arena<ffi.Int32>()..value = n;
        final ipiv = arena<ffi.Int32>(n);
        final info = arena<ffi.Int32>();
        final trans = arena<ffi.Uint8>()..value = 84; // 'T'

        _fortranDgetrf(nPtr, nPtr, aPtr, ldaPtr, ipiv, info);
        if (info.value != 0) return false;

        if (isContiguous1D) {
          final bView = bOffset == 0 ? b : Float64List.sublistView(b, bOffset);
          _fortranDgetrs(
            trans,
            nPtr,
            nrhsPtr,
            aPtr,
            ldaPtr,
            ipiv,
            bView.address,
            ldbPtr,
            info,
          );
          return info.value == 0;
        } else {
          final bPtr = arena<ffi.Double>(n * nrhs);
          for (var j = 0; j < nrhs; j++) {
            for (var i = 0; i < n; i++) {
              bPtr[j * n + i] = b[bOffset + i * ldb + j];
            }
          }
          _fortranDgetrs(
            trans,
            nPtr,
            nrhsPtr,
            aPtr,
            ldaPtr,
            ipiv,
            bPtr,
            ldbPtr,
            info,
          );
          if (info.value != 0) return false;
          for (var i = 0; i < n; i++) {
            for (var j = 0; j < nrhs; j++) {
              b[bOffset + i * ldb + j] = bPtr[j * n + i];
            }
          }
          return true;
        }
      });
    }

    // coverage:ignore-start
    if (_hasDgesv) {
      return using((arena) {
        final aTrans = arena<ffi.Double>(n * n);
        for (var i = 0; i < n; i++) {
          for (var j = 0; j < n; j++) {
            aTrans[j * n + i] = a[aOffset + i * lda + j];
          }
        }

        final isContiguous1D = nrhs == 1 && ldb == 1;
        final nPtr = arena<ffi.Int32>()..value = n;
        final nrhsPtr = arena<ffi.Int32>()..value = nrhs;
        final ldaPtr = arena<ffi.Int32>()..value = n;
        final ldbPtr = arena<ffi.Int32>()..value = n;
        final ipiv = arena<ffi.Int32>(n);
        final info = arena<ffi.Int32>();

        if (isContiguous1D) {
          final bView = bOffset == 0 ? b : Float64List.sublistView(b, bOffset);
          _fortranDgesv(
            nPtr,
            nrhsPtr,
            aTrans,
            ldaPtr,
            ipiv,
            bView.address,
            ldbPtr,
            info,
          );
          return info.value == 0;
        } else {
          final bPtr = arena<ffi.Double>(n * nrhs);
          for (var j = 0; j < nrhs; j++) {
            for (var i = 0; i < n; i++) {
              bPtr[j * n + i] = b[bOffset + i * ldb + j];
            }
          }
          _fortranDgesv(
            nPtr,
            nrhsPtr,
            aTrans,
            ldaPtr,
            ipiv,
            bPtr,
            ldbPtr,
            info,
          );
          if (info.value != 0) return false;
          for (var i = 0; i < n; i++) {
            for (var j = 0; j < nrhs; j++) {
              b[bOffset + i * ldb + j] = bPtr[j * n + i];
            }
          }
          return true;
        }
      });
    }
    // coverage:ignore-end

    return false;
  }

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
  }) {
    final aView = aOffset == 0 ? a : Float64List.sublistView(a, aOffset);
    final bView = bOffset == 0 ? b : Float64List.sublistView(b, bOffset);

    // coverage:ignore-start
    if (_hasLapackeDgels) {
      final info = _lapackeDgels(
        cblasRowMajor,
        78, // 'N'
        m,
        n,
        nrhs,
        aView.address,
        lda,
        bView.address,
        ldb,
      );
      return info == 0;
    }
    // coverage:ignore-end

    if (_hasDgels) {
      return using((arena) {
        final maxMN = m > n ? m : n;
        final trans = arena<ffi.Uint8>()..value = 84; // 'T'
        final fRows = arena<ffi.Int32>()..value = n;
        final fCols = arena<ffi.Int32>()..value = m;
        final nrhsPtr = arena<ffi.Int32>()..value = nrhs;
        final ldaPtr = arena<ffi.Int32>()..value = n;
        final ldbPtr = arena<ffi.Int32>()..value = maxMN;
        final info = arena<ffi.Int32>();

        final lworkQuery = arena<ffi.Int32>()..value = -1;
        final workQuery = arena<ffi.Double>(1);
        _fortranDgels(
          trans,
          fRows,
          fCols,
          nrhsPtr,
          aView.address,
          ldaPtr,
          bView.address,
          ldbPtr,
          workQuery,
          lworkQuery,
          info,
        );
        if (info.value != 0) return false;

        final optLwork = workQuery[0].toInt();
        final work = arena<ffi.Double>(optLwork);
        final lwork = arena<ffi.Int32>()..value = optLwork;

        _fortranDgels(
          trans,
          fRows,
          fCols,
          nrhsPtr,
          aView.address,
          ldaPtr,
          bView.address,
          ldbPtr,
          work,
          lwork,
          info,
        );
        return info.value == 0;
      });
    }

    return false;
  }

  bool dsyev({
    String jobz = 'V',
    int uplo = cblasUpper,
    required int n,
    required Float64List a,
    int aOffset = 0,
    required int lda,
    required Float64List w,
    int wOffset = 0,
  }) {
    if (n < 0 || lda < n) return false;
    if (n == 0) return true;
    final normJobz = jobz.toUpperCase();
    if (normJobz != 'V' && normJobz != 'N') return false;
    if (uplo != cblasUpper && uplo != cblasLower) return false;
    final aRequired = aOffset + (n - 1) * lda + n;
    final wRequired = wOffset + n;
    if (a.length < aRequired || w.length < wRequired) return false;

    final aView = aOffset == 0 ? a : Float64List.sublistView(a, aOffset);
    final wView = wOffset == 0 ? w : Float64List.sublistView(w, wOffset);

    // coverage:ignore-start
    if (_hasLapackeDsyev) {
      final info = _lapackeDsyev(
        cblasRowMajor,
        normJobz.codeUnitAt(0),
        uplo == cblasUpper ? 85 : 76,
        n,
        aView.address,
        lda,
        wView.address,
      );
      if (info == 0) {
        if (normJobz == 'V') {
          for (var i = 0; i < n; i++) {
            for (var j = i + 1; j < n; j++) {
              final tmp = a[aOffset + i * lda + j];
              a[aOffset + i * lda + j] = a[aOffset + j * lda + i];
              a[aOffset + j * lda + i] = tmp;
            }
          }
        }
        return true;
      }
      return false;
    }
    // coverage:ignore-end

    if (_hasDsyev) {
      return using((arena) {
        final fA = arena<ffi.Double>(n * n);
        for (var i = 0; i < n; i++) {
          for (var j = 0; j < n; j++) {
            fA[j * n + i] = a[aOffset + i * lda + j];
          }
        }
        final jobzPtr = arena<ffi.Uint8>()..value = normJobz.codeUnitAt(0);
        final uploPtr = arena<ffi.Uint8>()
          ..value = uplo == cblasUpper ? 85 : 76;
        final nPtr = arena<ffi.Int32>()..value = n;
        final ldaPtr = arena<ffi.Int32>()..value = n;
        final info = arena<ffi.Int32>();

        final lworkQuery = arena<ffi.Int32>()..value = -1;
        final workQuery = arena<ffi.Double>(1);
        _fortranDsyev(
          jobzPtr,
          uploPtr,
          nPtr,
          fA,
          ldaPtr,
          wView.address,
          workQuery,
          lworkQuery,
          info,
        );
        if (info.value != 0) return false;

        final optLwork = workQuery[0].toInt();
        final lworkVal = optLwork > 0
            ? optLwork
            : (3 * n - 1 > 0 ? 3 * n - 1 : 1);
        final work = arena<ffi.Double>(lworkVal);
        final lwork = arena<ffi.Int32>()..value = lworkVal;

        _fortranDsyev(
          jobzPtr,
          uploPtr,
          nPtr,
          fA,
          ldaPtr,
          wView.address,
          work,
          lwork,
          info,
        );
        if (info.value == 0) {
          if (normJobz == 'V') {
            for (var i = 0; i < n; i++) {
              for (var j = 0; j < n; j++) {
                a[aOffset + i * lda + j] = fA[j * n + i];
              }
            }
          }
          return true;
        }
        return false;
      });
    }

    return false;
  }

  bool ssyev({
    String jobz = 'V',
    int uplo = cblasUpper,
    required int n,
    required Float32List a,
    int aOffset = 0,
    required int lda,
    required Float32List w,
    int wOffset = 0,
  }) {
    if (n < 0 || lda < n) return false;
    if (n == 0) return true;
    final normJobz = jobz.toUpperCase();
    if (normJobz != 'V' && normJobz != 'N') return false;
    if (uplo != cblasUpper && uplo != cblasLower) return false;
    final aRequired = aOffset + (n - 1) * lda + n;
    final wRequired = wOffset + n;
    if (a.length < aRequired || w.length < wRequired) return false;

    final aView = aOffset == 0 ? a : Float32List.sublistView(a, aOffset);
    final wView = wOffset == 0 ? w : Float32List.sublistView(w, wOffset);

    // coverage:ignore-start
    if (_hasLapackeSsyev) {
      final info = _lapackeSsyev(
        cblasRowMajor,
        normJobz.codeUnitAt(0),
        uplo == cblasUpper ? 85 : 76,
        n,
        aView.address,
        lda,
        wView.address,
      );
      if (info == 0) {
        if (normJobz == 'V') {
          for (var i = 0; i < n; i++) {
            for (var j = i + 1; j < n; j++) {
              final tmp = a[aOffset + i * lda + j];
              a[aOffset + i * lda + j] = a[aOffset + j * lda + i];
              a[aOffset + j * lda + i] = tmp;
            }
          }
        }
        return true;
      }
      return false;
    }
    // coverage:ignore-end

    if (_hasSsyev) {
      return using((arena) {
        final fA = arena<ffi.Float>(n * n);
        for (var i = 0; i < n; i++) {
          for (var j = 0; j < n; j++) {
            fA[j * n + i] = a[aOffset + i * lda + j];
          }
        }
        final jobzPtr = arena<ffi.Uint8>()..value = normJobz.codeUnitAt(0);
        final uploPtr = arena<ffi.Uint8>()
          ..value = uplo == cblasUpper ? 85 : 76;
        final nPtr = arena<ffi.Int32>()..value = n;
        final ldaPtr = arena<ffi.Int32>()..value = n;
        final info = arena<ffi.Int32>();

        final lworkQuery = arena<ffi.Int32>()..value = -1;
        final workQuery = arena<ffi.Float>(1);
        _fortranSsyev(
          jobzPtr,
          uploPtr,
          nPtr,
          fA,
          ldaPtr,
          wView.address,
          workQuery,
          lworkQuery,
          info,
        );
        if (info.value != 0) return false;

        final optLwork = workQuery[0].toInt();
        final lworkVal = optLwork > 0
            ? optLwork
            : (3 * n - 1 > 0 ? 3 * n - 1 : 1);
        final work = arena<ffi.Float>(lworkVal);
        final lwork = arena<ffi.Int32>()..value = lworkVal;

        _fortranSsyev(
          jobzPtr,
          uploPtr,
          nPtr,
          fA,
          ldaPtr,
          wView.address,
          work,
          lwork,
          info,
        );
        if (info.value == 0) {
          if (normJobz == 'V') {
            for (var i = 0; i < n; i++) {
              for (var j = 0; j < n; j++) {
                a[aOffset + i * lda + j] = fA[j * n + i];
              }
            }
          }
          return true;
        }
        return false;
      });
    }

    return false;
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

List<ffi.DynamicLibrary> _loadPlatformLibraries() {
  final libs = <ffi.DynamicLibrary>[];
  void tryOpen(String name) {
    try {
      libs.add(ffi.DynamicLibrary.open(name));
      if (!Platform.isWindows) {
        using((arena) {
          final str = name.toNativeUtf8(allocator: arena);
          _posixDlopen(str.cast(), 1 | 0x100);
        });
      }
    } catch (_) {}
  }

  try {
    if (Platform.isMacOS || Platform.isIOS) {
      for (final name in [
        '/System/Library/Frameworks/Accelerate.framework/Accelerate',
        'libBLAS.dylib',
        'liblapack.dylib',
      ]) {
        tryOpen(name);
      }
      // coverage:ignore-start
    } else if (Platform.isLinux || Platform.isAndroid) {
      for (final name in [
        'libopenblas.so.0',
        'libopenblas.so',
        'liblapacke.so.3',
        'liblapacke.so',
        'libblas.so.3',
        'liblapack.so.3',
      ]) {
        tryOpen(name);
      }
    } else if (Platform.isWindows) {
      for (final name in [
        'openblas.dll',
        'libopenblas.dll',
        'liblapacke.dll',
        'lapack.dll',
      ]) {
        tryOpen(name);
      }
    }
    // coverage:ignore-end
  } catch (_) {}
  return libs;
}

@ffi.Native<ffi.Pointer<ffi.Void> Function(ffi.Pointer<ffi.Char>, ffi.Int32)>(
  symbol: 'dlopen',
  isLeaf: true,
)
external ffi.Pointer<ffi.Void> _posixDlopen(
  ffi.Pointer<ffi.Char> file,
  int mode,
);

// --- Native bindings ---

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
  int order,
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
  int order,
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
    ffi.Int32,
    ffi.Int32,
    ffi.Pointer<ffi.Double>,
    ffi.Int32,
    ffi.Pointer<ffi.Double>,
    ffi.Int32,
  )
>(symbol: 'cblas_dtrmv', isLeaf: true)
external void _cblasDtrmv(
  int order,
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
  int order,
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
  int order,
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
  int order,
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
  int order,
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
  int order,
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
  int order,
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
  int order,
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
  int order,
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
  int order,
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
  int order,
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
  int order,
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

@ffi.Native<
  ffi.Int32 Function(
    ffi.Int32,
    ffi.Int32,
    ffi.Int32,
    ffi.Pointer<ffi.Double>,
    ffi.Int32,
    ffi.Pointer<ffi.Int32>,
    ffi.Pointer<ffi.Double>,
    ffi.Int32,
  )
>(symbol: 'LAPACKE_dgesv', isLeaf: true)
external int _lapackeDgesv(
  int matrixLayout,
  int n,
  int nrhs,
  ffi.Pointer<ffi.Double> a,
  int lda,
  ffi.Pointer<ffi.Int32> ipiv,
  ffi.Pointer<ffi.Double> b,
  int ldb,
);

@ffi.Native<
  ffi.Int32 Function(
    ffi.Int32,
    ffi.Int32,
    ffi.Int32,
    ffi.Pointer<ffi.Double>,
    ffi.Int32,
    ffi.Pointer<ffi.Int32>,
    ffi.Pointer<ffi.Double>,
    ffi.Int32,
  )
>(symbol: 'clapack_dgesv', isLeaf: true)
external int _clapackDgesv(
  int matrixLayout,
  int n,
  int nrhs,
  ffi.Pointer<ffi.Double> a,
  int lda,
  ffi.Pointer<ffi.Int32> ipiv,
  ffi.Pointer<ffi.Double> b,
  int ldb,
);

@ffi.Native<
  ffi.Void Function(
    ffi.Pointer<ffi.Int32>,
    ffi.Pointer<ffi.Int32>,
    ffi.Pointer<ffi.Double>,
    ffi.Pointer<ffi.Int32>,
    ffi.Pointer<ffi.Int32>,
    ffi.Pointer<ffi.Int32>,
  )
>(symbol: 'dgetrf_', isLeaf: true)
external void _fortranDgetrf(
  ffi.Pointer<ffi.Int32> m,
  ffi.Pointer<ffi.Int32> n,
  ffi.Pointer<ffi.Double> a,
  ffi.Pointer<ffi.Int32> lda,
  ffi.Pointer<ffi.Int32> ipiv,
  ffi.Pointer<ffi.Int32> info,
);

@ffi.Native<
  ffi.Void Function(
    ffi.Pointer<ffi.Uint8>,
    ffi.Pointer<ffi.Int32>,
    ffi.Pointer<ffi.Int32>,
    ffi.Pointer<ffi.Double>,
    ffi.Pointer<ffi.Int32>,
    ffi.Pointer<ffi.Int32>,
    ffi.Pointer<ffi.Double>,
    ffi.Pointer<ffi.Int32>,
    ffi.Pointer<ffi.Int32>,
  )
>(symbol: 'dgetrs_', isLeaf: true)
external void _fortranDgetrs(
  ffi.Pointer<ffi.Uint8> trans,
  ffi.Pointer<ffi.Int32> n,
  ffi.Pointer<ffi.Int32> nrhs,
  ffi.Pointer<ffi.Double> a,
  ffi.Pointer<ffi.Int32> lda,
  ffi.Pointer<ffi.Int32> ipiv,
  ffi.Pointer<ffi.Double> b,
  ffi.Pointer<ffi.Int32> ldb,
  ffi.Pointer<ffi.Int32> info,
);

@ffi.Native<
  ffi.Void Function(
    ffi.Pointer<ffi.Int32>,
    ffi.Pointer<ffi.Int32>,
    ffi.Pointer<ffi.Double>,
    ffi.Pointer<ffi.Int32>,
    ffi.Pointer<ffi.Int32>,
    ffi.Pointer<ffi.Double>,
    ffi.Pointer<ffi.Int32>,
    ffi.Pointer<ffi.Int32>,
  )
>(symbol: 'dgesv_', isLeaf: true)
external void _fortranDgesv(
  ffi.Pointer<ffi.Int32> n,
  ffi.Pointer<ffi.Int32> nrhs,
  ffi.Pointer<ffi.Double> a,
  ffi.Pointer<ffi.Int32> lda,
  ffi.Pointer<ffi.Int32> ipiv,
  ffi.Pointer<ffi.Double> b,
  ffi.Pointer<ffi.Int32> ldb,
  ffi.Pointer<ffi.Int32> info,
);

@ffi.Native<
  ffi.Int32 Function(
    ffi.Int32,
    ffi.Uint8,
    ffi.Int32,
    ffi.Int32,
    ffi.Int32,
    ffi.Pointer<ffi.Double>,
    ffi.Int32,
    ffi.Pointer<ffi.Double>,
    ffi.Int32,
  )
>(symbol: 'LAPACKE_dgels', isLeaf: true)
external int _lapackeDgels(
  int matrixLayout,
  int trans,
  int m,
  int n,
  int nrhs,
  ffi.Pointer<ffi.Double> a,
  int lda,
  ffi.Pointer<ffi.Double> b,
  int ldb,
);

@ffi.Native<
  ffi.Void Function(
    ffi.Pointer<ffi.Uint8>,
    ffi.Pointer<ffi.Int32>,
    ffi.Pointer<ffi.Int32>,
    ffi.Pointer<ffi.Int32>,
    ffi.Pointer<ffi.Double>,
    ffi.Pointer<ffi.Int32>,
    ffi.Pointer<ffi.Double>,
    ffi.Pointer<ffi.Int32>,
    ffi.Pointer<ffi.Double>,
    ffi.Pointer<ffi.Int32>,
    ffi.Pointer<ffi.Int32>,
  )
>(symbol: 'dgels_', isLeaf: true)
external void _fortranDgels(
  ffi.Pointer<ffi.Uint8> trans,
  ffi.Pointer<ffi.Int32> m,
  ffi.Pointer<ffi.Int32> n,
  ffi.Pointer<ffi.Int32> nrhs,
  ffi.Pointer<ffi.Double> a,
  ffi.Pointer<ffi.Int32> lda,
  ffi.Pointer<ffi.Double> b,
  ffi.Pointer<ffi.Int32> ldb,
  ffi.Pointer<ffi.Double> work,
  ffi.Pointer<ffi.Int32> lwork,
  ffi.Pointer<ffi.Int32> info,
);

@ffi.Native<
  ffi.Void Function(
    ffi.Pointer<ffi.Uint8>,
    ffi.Pointer<ffi.Int32>,
    ffi.Pointer<ffi.Double>,
    ffi.Pointer<ffi.Int32>,
    ffi.Pointer<ffi.Int32>,
  )
>(symbol: 'dpotrf_', isLeaf: true)
external void _fortranDpotrf(
  ffi.Pointer<ffi.Uint8> uplo,
  ffi.Pointer<ffi.Int32> n,
  ffi.Pointer<ffi.Double> a,
  ffi.Pointer<ffi.Int32> lda,
  ffi.Pointer<ffi.Int32> info,
);

@ffi.Native<
  ffi.Int32 Function(
    ffi.Int32,
    ffi.Uint8,
    ffi.Uint8,
    ffi.Int32,
    ffi.Pointer<ffi.Double>,
    ffi.Int32,
    ffi.Pointer<ffi.Double>,
  )
>(symbol: 'LAPACKE_dsyev', isLeaf: true)
external int _lapackeDsyev(
  int matrixLayout,
  int jobz,
  int uplo,
  int n,
  ffi.Pointer<ffi.Double> a,
  int lda,
  ffi.Pointer<ffi.Double> w,
);

@ffi.Native<
  ffi.Int32 Function(
    ffi.Int32,
    ffi.Uint8,
    ffi.Uint8,
    ffi.Int32,
    ffi.Pointer<ffi.Float>,
    ffi.Int32,
    ffi.Pointer<ffi.Float>,
  )
>(symbol: 'LAPACKE_ssyev', isLeaf: true)
external int _lapackeSsyev(
  int matrixLayout,
  int jobz,
  int uplo,
  int n,
  ffi.Pointer<ffi.Float> a,
  int lda,
  ffi.Pointer<ffi.Float> w,
);

@ffi.Native<
  ffi.Void Function(
    ffi.Pointer<ffi.Uint8>,
    ffi.Pointer<ffi.Uint8>,
    ffi.Pointer<ffi.Int32>,
    ffi.Pointer<ffi.Double>,
    ffi.Pointer<ffi.Int32>,
    ffi.Pointer<ffi.Double>,
    ffi.Pointer<ffi.Double>,
    ffi.Pointer<ffi.Int32>,
    ffi.Pointer<ffi.Int32>,
  )
>(symbol: 'dsyev_', isLeaf: true)
external void _fortranDsyev(
  ffi.Pointer<ffi.Uint8> jobz,
  ffi.Pointer<ffi.Uint8> uplo,
  ffi.Pointer<ffi.Int32> n,
  ffi.Pointer<ffi.Double> a,
  ffi.Pointer<ffi.Int32> lda,
  ffi.Pointer<ffi.Double> w,
  ffi.Pointer<ffi.Double> work,
  ffi.Pointer<ffi.Int32> lwork,
  ffi.Pointer<ffi.Int32> info,
);

@ffi.Native<
  ffi.Void Function(
    ffi.Pointer<ffi.Uint8>,
    ffi.Pointer<ffi.Uint8>,
    ffi.Pointer<ffi.Int32>,
    ffi.Pointer<ffi.Float>,
    ffi.Pointer<ffi.Int32>,
    ffi.Pointer<ffi.Float>,
    ffi.Pointer<ffi.Float>,
    ffi.Pointer<ffi.Int32>,
    ffi.Pointer<ffi.Int32>,
  )
>(symbol: 'ssyev_', isLeaf: true)
external void _fortranSsyev(
  ffi.Pointer<ffi.Uint8> jobz,
  ffi.Pointer<ffi.Uint8> uplo,
  ffi.Pointer<ffi.Int32> n,
  ffi.Pointer<ffi.Float> a,
  ffi.Pointer<ffi.Int32> lda,
  ffi.Pointer<ffi.Float> w,
  ffi.Pointer<ffi.Float> work,
  ffi.Pointer<ffi.Int32> lwork,
  ffi.Pointer<ffi.Int32> info,
);
