// ignore_for_file: constant_identifier_names

import 'dart:ffi' as ffi;
import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import '../type/native_buffer_ffi.dart';

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

/// Loads the platform BLAS library.
BlasLibrary loadBlas() => BlasLibrary._(_loadPlatformLibraries());

/// Native BLAS/LAPACK bindings via dart:ffi.
class BlasLibrary {
  new _(this._libraries) {
    _dgemm = _lookup(
      (lib) =>
          lib.lookupFunction<_CblasDgemmNative, _CblasDgemm>('cblas_dgemm'),
    );
    _sgemm = _lookup(
      (lib) =>
          lib.lookupFunction<_CblasSgemmNative, _CblasSgemm>('cblas_sgemm'),
    );
    _dgemv = _lookup(
      (lib) =>
          lib.lookupFunction<_CblasDgemvNative, _CblasDgemv>('cblas_dgemv'),
    );
    _sgemv = _lookup(
      (lib) =>
          lib.lookupFunction<_CblasSgemvNative, _CblasSgemv>('cblas_sgemv'),
    );
    _ddot = _lookup(
      (lib) => lib.lookupFunction<_CblasDdotNative, _CblasDdot>('cblas_ddot'),
    );
    _sdot = _lookup(
      (lib) => lib.lookupFunction<_CblasSdotNative, _CblasSdot>('cblas_sdot'),
    );
    _dnrm2 = _lookup(
      (lib) =>
          lib.lookupFunction<_CblasDnrm2Native, _CblasDnrm2>('cblas_dnrm2'),
    );
    _snrm2 = _lookup(
      (lib) =>
          lib.lookupFunction<_CblasSnrm2Native, _CblasSnrm2>('cblas_snrm2'),
    );
    _daxpy = _lookup(
      (lib) =>
          lib.lookupFunction<_CblasDaxpyNative, _CblasDaxpy>('cblas_daxpy'),
    );
    _saxpy = _lookup(
      (lib) =>
          lib.lookupFunction<_CblasSaxpyNative, _CblasSaxpy>('cblas_saxpy'),
    );
    _dscal = _lookup(
      (lib) =>
          lib.lookupFunction<_CblasDscalNative, _CblasDscal>('cblas_dscal'),
    );
    _sscal = _lookup(
      (lib) =>
          lib.lookupFunction<_CblasSscalNative, _CblasSscal>('cblas_sscal'),
    );
    _dsyrk = _lookup(
      (lib) =>
          lib.lookupFunction<_CblasDsyrkNative, _CblasDsyrk>('cblas_dsyrk'),
    );
    _ssyrk = _lookup(
      (lib) =>
          lib.lookupFunction<_CblasSsyrkNative, _CblasSsyrk>('cblas_ssyrk'),
    );
    _dsyr2 = _lookup(
      (lib) =>
          lib.lookupFunction<_CblasDsyr2Native, _CblasDsyr2>('cblas_dsyr2'),
    );
    _ssyr2 = _lookup(
      (lib) =>
          lib.lookupFunction<_CblasSsyr2Native, _CblasSsyr2>('cblas_ssyr2'),
    );

    _lapackeDgesv =
        _lookup(
          (lib) => lib.lookupFunction<_LapackeDgesvNative, _LapackeDgesv>(
            'LAPACKE_dgesv',
          ),
        ) ??
        _lookup(
          (lib) => lib.lookupFunction<_LapackeDgesvNative, _LapackeDgesv>(
            'clapack_dgesv',
          ),
        );
    _dgetrf = _lookup(
      (lib) =>
          lib.lookupFunction<_FortranDgetrfNative, _FortranDgetrf>('dgetrf_'),
    );
    _dgetrs = _lookup(
      (lib) =>
          lib.lookupFunction<_FortranDgetrsNative, _FortranDgetrs>('dgetrs_'),
    );
    _dgesv = _lookup(
      (lib) => lib.lookupFunction<_FortranDgesvNative, _FortranDgesv>('dgesv_'),
    );

    _lapackeDgels = _lookup(
      (lib) => lib.lookupFunction<_LapackeDgelsNative, _LapackeDgels>(
        'LAPACKE_dgels',
      ),
    );
    _dgels = _lookup(
      (lib) => lib.lookupFunction<_FortranDgelsNative, _FortranDgels>('dgels_'),
    );

    _dpotrf = _lookup(
      (lib) =>
          lib.lookupFunction<_FortranDpotrfNative, _FortranDpotrf>('dpotrf_'),
    );
    _dgeqrf = _lookup(
      (lib) =>
          lib.lookupFunction<_FortranDgeqrfNative, _FortranDgeqrf>('dgeqrf_'),
    );
    _dgesvd = _lookup(
      (lib) =>
          lib.lookupFunction<_FortranDgesvdNative, _FortranDgesvd>('dgesvd_'),
    );
    _dgesdd = _lookup(
      (lib) =>
          lib.lookupFunction<_FortranDgesddNative, _FortranDgesdd>('dgesdd_'),
    );
  }

  final List<ffi.DynamicLibrary> _libraries;

  _CblasDgemm? _dgemm;
  _CblasSgemm? _sgemm;
  _CblasDgemv? _dgemv;
  _CblasSgemv? _sgemv;
  _CblasDdot? _ddot;
  _CblasSdot? _sdot;
  _CblasDnrm2? _dnrm2;
  _CblasSnrm2? _snrm2;
  _CblasDaxpy? _daxpy;
  _CblasSaxpy? _saxpy;
  _CblasDscal? _dscal;
  _CblasSscal? _sscal;
  _CblasDsyrk? _dsyrk;
  _CblasSsyrk? _ssyrk;
  _CblasDsyr2? _dsyr2;
  _CblasSsyr2? _ssyr2;
  _LapackeDgesv? _lapackeDgesv;
  _FortranDgetrf? _dgetrf;
  _FortranDgetrs? _dgetrs;
  _FortranDgesv? _dgesv;
  _LapackeDgels? _lapackeDgels;
  _FortranDgels? _dgels;
  _FortranDpotrf? _dpotrf;
  _FortranDgeqrf? _dgeqrf;
  _FortranDgesvd? _dgesvd;
  _FortranDgesdd? _dgesdd;

  bool get isAvailable => _dgemm != null;

  /// Whether native QR factorization (_dgeqrf) is bound.
  bool get hasDgeqrf => _dgeqrf != null;

  /// Whether native SVD factorization (_dgesvd or _dgesdd) is bound.
  bool get hasDgesvd => _dgesvd != null || _dgesdd != null;

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
    final fn = _dgemm;
    if (fn == null) return false;

    final nativeA = _pointerForDouble(a, aOffset);
    final nativeB = _pointerForDouble(b, bOffset);
    final nativeC = _pointerForDouble(c, cOffset);

    if (nativeA != null && nativeB != null && nativeC != null) {
      fn(
        cblasRowMajor,
        transA,
        transB,
        m,
        n,
        k,
        alpha,
        nativeA,
        lda,
        nativeB,
        ldb,
        beta,
        nativeC,
        ldc,
      );
      return true;
    }

    return using((arena) {
      final aLen = transA == cblasTrans ? k * lda : m * lda;
      final bLen = transB == cblasTrans ? n * ldb : k * ldb;
      final cLen = m * ldc;

      final aPtr = nativeA ?? arena<ffi.Double>(aLen);
      if (nativeA == null) {
        aPtr.asTypedList(aLen).setRange(0, aLen, a, aOffset);
      }

      final bPtr = nativeB ?? arena<ffi.Double>(bLen);
      if (nativeB == null) {
        bPtr.asTypedList(bLen).setRange(0, bLen, b, bOffset);
      }

      final cPtr = nativeC ?? arena<ffi.Double>(cLen);
      if (nativeC == null && beta != 0.0) {
        cPtr.asTypedList(cLen).setRange(0, cLen, c, cOffset);
      }

      fn(
        cblasRowMajor,
        transA,
        transB,
        m,
        n,
        k,
        alpha,
        aPtr,
        lda,
        bPtr,
        ldb,
        beta,
        cPtr,
        ldc,
      );

      if (nativeC == null) {
        c.setRange(cOffset, cOffset + cLen, cPtr.asTypedList(cLen));
      }
      return true;
    });
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
    final fn = _sgemm;
    if (fn == null) return false;

    final nativeA = _pointerForFloat(a, aOffset);
    final nativeB = _pointerForFloat(b, bOffset);
    final nativeC = _pointerForFloat(c, cOffset);

    if (nativeA != null && nativeB != null && nativeC != null) {
      fn(
        cblasRowMajor,
        transA,
        transB,
        m,
        n,
        k,
        alpha,
        nativeA,
        lda,
        nativeB,
        ldb,
        beta,
        nativeC,
        ldc,
      );
      return true;
    }

    return using((arena) {
      final aLen = transA == cblasTrans ? k * lda : m * lda;
      final bLen = transB == cblasTrans ? n * ldb : k * ldb;
      final cLen = m * ldc;

      final aPtr = nativeA ?? arena<ffi.Float>(aLen);
      if (nativeA == null) {
        aPtr.asTypedList(aLen).setRange(0, aLen, a, aOffset);
      }

      final bPtr = nativeB ?? arena<ffi.Float>(bLen);
      if (nativeB == null) {
        bPtr.asTypedList(bLen).setRange(0, bLen, b, bOffset);
      }

      final cPtr = nativeC ?? arena<ffi.Float>(cLen);
      if (nativeC == null && beta != 0.0) {
        cPtr.asTypedList(cLen).setRange(0, cLen, c, cOffset);
      }

      fn(
        cblasRowMajor,
        transA,
        transB,
        m,
        n,
        k,
        alpha,
        aPtr,
        lda,
        bPtr,
        ldb,
        beta,
        cPtr,
        ldc,
      );

      if (nativeC == null) {
        c.setRange(cOffset, cOffset + cLen, cPtr.asTypedList(cLen));
      }
      return true;
    });
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
    final fn = _dgemv;
    if (fn == null) return false;

    final nativeA = _pointerForDouble(a, aOffset);
    final nativeX = _pointerForDouble(x, xOffset);
    final nativeY = _pointerForDouble(y, yOffset);

    if (nativeA != null && nativeX != null && nativeY != null) {
      fn(
        cblasRowMajor,
        transA,
        m,
        n,
        alpha,
        nativeA,
        lda,
        nativeX,
        incX,
        beta,
        nativeY,
        incY,
      );
      return true;
    }

    return using((arena) {
      final lenX = transA == cblasTrans ? m : n;
      final lenY = transA == cblasTrans ? n : m;
      final aLen = m <= 0 || n <= 0 ? 0 : (m - 1) * lda + n;
      final xLen = lenX <= 0 ? 0 : 1 + (lenX - 1) * incX.abs();
      final yLen = lenY <= 0 ? 0 : 1 + (lenY - 1) * incY.abs();

      final aPtr = nativeA ?? arena<ffi.Double>(aLen);
      if (nativeA == null) {
        aPtr.asTypedList(aLen).setRange(0, aLen, a, aOffset);
      }

      final xPtr = nativeX ?? arena<ffi.Double>(xLen);
      if (nativeX == null) {
        xPtr.asTypedList(xLen).setRange(0, xLen, x, xOffset);
      }

      final yPtr = nativeY ?? arena<ffi.Double>(yLen);
      if (nativeY == null && beta != 0.0) {
        yPtr.asTypedList(yLen).setRange(0, yLen, y, yOffset);
      }

      fn(
        cblasRowMajor,
        transA,
        m,
        n,
        alpha,
        aPtr,
        lda,
        xPtr,
        incX,
        beta,
        yPtr,
        incY,
      );

      if (nativeY == null) {
        y.setRange(yOffset, yOffset + yLen, yPtr.asTypedList(yLen));
      }
      return true;
    });
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
    final fn = _sgemv;
    if (fn == null) return false;

    final nativeA = _pointerForFloat(a, aOffset);
    final nativeX = _pointerForFloat(x, xOffset);
    final nativeY = _pointerForFloat(y, yOffset);

    if (nativeA != null && nativeX != null && nativeY != null) {
      fn(
        cblasRowMajor,
        transA,
        m,
        n,
        alpha,
        nativeA,
        lda,
        nativeX,
        incX,
        beta,
        nativeY,
        incY,
      );
      return true;
    }

    return using((arena) {
      final lenX = transA == cblasTrans ? m : n;
      final lenY = transA == cblasTrans ? n : m;
      final aLen = m <= 0 || n <= 0 ? 0 : (m - 1) * lda + n;
      final xLen = lenX <= 0 ? 0 : 1 + (lenX - 1) * incX.abs();
      final yLen = lenY <= 0 ? 0 : 1 + (lenY - 1) * incY.abs();

      final aPtr = nativeA ?? arena<ffi.Float>(aLen);
      if (nativeA == null) {
        aPtr.asTypedList(aLen).setRange(0, aLen, a, aOffset);
      }

      final xPtr = nativeX ?? arena<ffi.Float>(xLen);
      if (nativeX == null) {
        xPtr.asTypedList(xLen).setRange(0, xLen, x, xOffset);
      }

      final yPtr = nativeY ?? arena<ffi.Float>(yLen);
      if (nativeY == null && beta != 0.0) {
        yPtr.asTypedList(yLen).setRange(0, yLen, y, yOffset);
      }

      fn(
        cblasRowMajor,
        transA,
        m,
        n,
        alpha,
        aPtr,
        lda,
        xPtr,
        incX,
        beta,
        yPtr,
        incY,
      );

      if (nativeY == null) {
        y.setRange(yOffset, yOffset + yLen, yPtr.asTypedList(yLen));
      }
      return true;
    });
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
    final fn = _ddot;
    if (fn == null) return null;

    final nativeX = _pointerForDouble(x, xOffset);
    final nativeY = _pointerForDouble(y, yOffset);

    if (nativeX != null && nativeY != null) {
      return fn(n, nativeX, incX, nativeY, incY);
    }

    return using((arena) {
      final xLen = n <= 0 ? 0 : 1 + (n - 1) * incX.abs();
      final yLen = n <= 0 ? 0 : 1 + (n - 1) * incY.abs();

      final xPtr = nativeX ?? arena<ffi.Double>(xLen);
      if (nativeX == null) {
        xPtr.asTypedList(xLen).setRange(0, xLen, x, xOffset);
      }

      final yPtr = nativeY ?? arena<ffi.Double>(yLen);
      if (nativeY == null) {
        yPtr.asTypedList(yLen).setRange(0, yLen, y, yOffset);
      }

      return fn(n, xPtr, incX, yPtr, incY);
    });
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
    final fn = _sdot;
    if (fn == null) return null;

    final nativeX = _pointerForFloat(x, xOffset);
    final nativeY = _pointerForFloat(y, yOffset);

    if (nativeX != null && nativeY != null) {
      return fn(n, nativeX, incX, nativeY, incY);
    }

    return using((arena) {
      final xLen = n <= 0 ? 0 : 1 + (n - 1) * incX.abs();
      final yLen = n <= 0 ? 0 : 1 + (n - 1) * incY.abs();

      final xPtr = nativeX ?? arena<ffi.Float>(xLen);
      if (nativeX == null) {
        xPtr.asTypedList(xLen).setRange(0, xLen, x, xOffset);
      }

      final yPtr = nativeY ?? arena<ffi.Float>(yLen);
      if (nativeY == null) {
        yPtr.asTypedList(yLen).setRange(0, yLen, y, yOffset);
      }

      return fn(n, xPtr, incX, yPtr, incY);
    });
  }

  double? dnrm2({
    required int n,
    required Float64List x,
    int xOffset = 0,
    required int incX,
  }) {
    final fn = _dnrm2;
    if (fn == null) return null;

    final nativeX = _pointerForDouble(x, xOffset);
    if (nativeX != null) {
      return fn(n, nativeX, incX);
    }

    return using((arena) {
      final xLen = n <= 0 ? 0 : 1 + (n - 1) * incX.abs();
      final xPtr = arena<ffi.Double>(xLen);
      xPtr.asTypedList(xLen).setRange(0, xLen, x, xOffset);
      return fn(n, xPtr, incX);
    });
  }

  double? snrm2({
    required int n,
    required Float32List x,
    int xOffset = 0,
    required int incX,
  }) {
    final fn = _snrm2;
    if (fn == null) return null;

    final nativeX = _pointerForFloat(x, xOffset);
    if (nativeX != null) {
      return fn(n, nativeX, incX);
    }

    return using((arena) {
      final xLen = n <= 0 ? 0 : 1 + (n - 1) * incX.abs();
      final xPtr = arena<ffi.Float>(xLen);
      xPtr.asTypedList(xLen).setRange(0, xLen, x, xOffset);
      return fn(n, xPtr, incX);
    });
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
    final fn = _daxpy;
    if (fn == null) return false;

    final nativeX = _pointerForDouble(x, xOffset);
    final nativeY = _pointerForDouble(y, yOffset);

    if (nativeX != null && nativeY != null) {
      fn(n, alpha, nativeX, incX, nativeY, incY);
      return true;
    }

    return using((arena) {
      final xLen = n <= 0 ? 0 : 1 + (n - 1) * incX.abs();
      final yLen = n <= 0 ? 0 : 1 + (n - 1) * incY.abs();

      final xPtr = nativeX ?? arena<ffi.Double>(xLen);
      if (nativeX == null) {
        xPtr.asTypedList(xLen).setRange(0, xLen, x, xOffset);
      }

      final yPtr = nativeY ?? arena<ffi.Double>(yLen);
      if (nativeY == null) {
        yPtr.asTypedList(yLen).setRange(0, yLen, y, yOffset);
      }

      fn(n, alpha, xPtr, incX, yPtr, incY);

      if (nativeY == null) {
        y.setRange(yOffset, yOffset + yLen, yPtr.asTypedList(yLen));
      }
      return true;
    });
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
    final fn = _saxpy;
    if (fn == null) return false;

    final nativeX = _pointerForFloat(x, xOffset);
    final nativeY = _pointerForFloat(y, yOffset);

    if (nativeX != null && nativeY != null) {
      fn(n, alpha, nativeX, incX, nativeY, incY);
      return true;
    }

    return using((arena) {
      final xLen = n <= 0 ? 0 : 1 + (n - 1) * incX.abs();
      final yLen = n <= 0 ? 0 : 1 + (n - 1) * incY.abs();

      final xPtr = nativeX ?? arena<ffi.Float>(xLen);
      if (nativeX == null) {
        xPtr.asTypedList(xLen).setRange(0, xLen, x, xOffset);
      }

      final yPtr = nativeY ?? arena<ffi.Float>(yLen);
      if (nativeY == null) {
        yPtr.asTypedList(yLen).setRange(0, yLen, y, yOffset);
      }

      fn(n, alpha, xPtr, incX, yPtr, incY);

      if (nativeY == null) {
        y.setRange(yOffset, yOffset + yLen, yPtr.asTypedList(yLen));
      }
      return true;
    });
  }

  bool dscal({
    required int n,
    required double alpha,
    required Float64List x,
    int xOffset = 0,
    required int incX,
  }) {
    final fn = _dscal;
    if (fn == null) return false;

    final nativeX = _pointerForDouble(x, xOffset);
    if (nativeX != null) {
      fn(n, alpha, nativeX, incX);
      return true;
    }

    return using((arena) {
      final xLen = n <= 0 ? 0 : 1 + (n - 1) * incX.abs();
      final xPtr = arena<ffi.Double>(xLen);
      xPtr.asTypedList(xLen).setRange(0, xLen, x, xOffset);
      fn(n, alpha, xPtr, incX);
      x.setRange(xOffset, xOffset + xLen, xPtr.asTypedList(xLen));
      return true;
    });
  }

  bool sscal({
    required int n,
    required double alpha,
    required Float32List x,
    int xOffset = 0,
    required int incX,
  }) {
    final fn = _sscal;
    if (fn == null) return false;

    final nativeX = _pointerForFloat(x, xOffset);
    if (nativeX != null) {
      fn(n, alpha, nativeX, incX);
      return true;
    }

    return using((arena) {
      final xLen = n <= 0 ? 0 : 1 + (n - 1) * incX.abs();
      final xPtr = arena<ffi.Float>(xLen);
      xPtr.asTypedList(xLen).setRange(0, xLen, x, xOffset);
      fn(n, alpha, xPtr, incX);
      x.setRange(xOffset, xOffset + xLen, xPtr.asTypedList(xLen));
      return true;
    });
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
    final fn = _dsyrk;
    if (fn == null) return false;

    final nativeA = _pointerForDouble(a, aOffset);
    final nativeC = _pointerForDouble(c, cOffset);

    if (nativeA != null && nativeC != null) {
      fn(
        cblasRowMajor,
        uplo,
        trans,
        n,
        k,
        alpha,
        nativeA,
        lda,
        beta,
        nativeC,
        ldc,
      );
      _mirrorSymmetricDouble(c, cOffset, n, ldc, uplo);
      return true;
    }

    return using((arena) {
      final aLen = trans == cblasTrans ? k * lda : n * lda;
      final cLen = n * ldc;

      final aPtr = nativeA ?? arena<ffi.Double>(aLen);
      if (nativeA == null) {
        aPtr.asTypedList(aLen).setRange(0, aLen, a, aOffset);
      }

      final cPtr = nativeC ?? arena<ffi.Double>(cLen);
      if (nativeC == null && beta != 0.0) {
        cPtr.asTypedList(cLen).setRange(0, cLen, c, cOffset);
      }

      fn(cblasRowMajor, uplo, trans, n, k, alpha, aPtr, lda, beta, cPtr, ldc);

      if (nativeC == null) {
        c.setRange(cOffset, cOffset + cLen, cPtr.asTypedList(cLen));
      }
      _mirrorSymmetricDouble(c, cOffset, n, ldc, uplo);
      return true;
    });
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
    final fn = _ssyrk;
    if (fn == null) return false;

    final nativeA = _pointerForFloat(a, aOffset);
    final nativeC = _pointerForFloat(c, cOffset);

    if (nativeA != null && nativeC != null) {
      fn(
        cblasRowMajor,
        uplo,
        trans,
        n,
        k,
        alpha,
        nativeA,
        lda,
        beta,
        nativeC,
        ldc,
      );
      _mirrorSymmetricFloat(c, cOffset, n, ldc, uplo);
      return true;
    }

    return using((arena) {
      final aLen = trans == cblasTrans ? k * lda : n * lda;
      final cLen = n * ldc;

      final aPtr = nativeA ?? arena<ffi.Float>(aLen);
      if (nativeA == null) {
        aPtr.asTypedList(aLen).setRange(0, aLen, a, aOffset);
      }

      final cPtr = nativeC ?? arena<ffi.Float>(cLen);
      if (nativeC == null && beta != 0.0) {
        cPtr.asTypedList(cLen).setRange(0, cLen, c, cOffset);
      }

      fn(cblasRowMajor, uplo, trans, n, k, alpha, aPtr, lda, beta, cPtr, ldc);

      if (nativeC == null) {
        c.setRange(cOffset, cOffset + cLen, cPtr.asTypedList(cLen));
      }
      _mirrorSymmetricFloat(c, cOffset, n, ldc, uplo);
      return true;
    });
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
    final fn = _dsyr2;
    if (fn == null) return false;

    final nativeX = _pointerForDouble(x, xOffset);
    final nativeY = _pointerForDouble(y, yOffset);
    final nativeA = _pointerForDouble(a, aOffset);

    if (nativeX != null && nativeY != null && nativeA != null) {
      fn(
        cblasRowMajor,
        uplo,
        n,
        alpha,
        nativeX,
        incX,
        nativeY,
        incY,
        nativeA,
        lda,
      );
      _mirrorSymmetricDouble(a, aOffset, n, lda, uplo);
      return true;
    }

    return using((arena) {
      final xLen = n <= 0 ? 0 : 1 + (n - 1) * incX.abs();
      final yLen = n <= 0 ? 0 : 1 + (n - 1) * incY.abs();
      final aLen = n * lda;

      final xPtr = nativeX ?? arena<ffi.Double>(xLen);
      if (nativeX == null) {
        xPtr.asTypedList(xLen).setRange(0, xLen, x, xOffset);
      }
      final yPtr = nativeY ?? arena<ffi.Double>(yLen);
      if (nativeY == null) {
        yPtr.asTypedList(yLen).setRange(0, yLen, y, yOffset);
      }
      final aPtr = nativeA ?? arena<ffi.Double>(aLen);
      if (nativeA == null) {
        aPtr.asTypedList(aLen).setRange(0, aLen, a, aOffset);
      }

      fn(cblasRowMajor, uplo, n, alpha, xPtr, incX, yPtr, incY, aPtr, lda);

      if (nativeA == null) {
        a.setRange(aOffset, aOffset + aLen, aPtr.asTypedList(aLen));
      }
      _mirrorSymmetricDouble(a, aOffset, n, lda, uplo);
      return true;
    });
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
    final fn = _ssyr2;
    if (fn == null) return false;

    final nativeX = _pointerForFloat(x, xOffset);
    final nativeY = _pointerForFloat(y, yOffset);
    final nativeA = _pointerForFloat(a, aOffset);

    if (nativeX != null && nativeY != null && nativeA != null) {
      fn(
        cblasRowMajor,
        uplo,
        n,
        alpha,
        nativeX,
        incX,
        nativeY,
        incY,
        nativeA,
        lda,
      );
      _mirrorSymmetricFloat(a, aOffset, n, lda, uplo);
      return true;
    }

    return using((arena) {
      final xLen = n <= 0 ? 0 : 1 + (n - 1) * incX.abs();
      final yLen = n <= 0 ? 0 : 1 + (n - 1) * incY.abs();
      final aLen = n * lda;

      final xPtr = nativeX ?? arena<ffi.Float>(xLen);
      if (nativeX == null) {
        xPtr.asTypedList(xLen).setRange(0, xLen, x, xOffset);
      }
      final yPtr = nativeY ?? arena<ffi.Float>(yLen);
      if (nativeY == null) {
        yPtr.asTypedList(yLen).setRange(0, yLen, y, yOffset);
      }
      final aPtr = nativeA ?? arena<ffi.Float>(aLen);
      if (nativeA == null) {
        aPtr.asTypedList(aLen).setRange(0, aLen, a, aOffset);
      }

      fn(cblasRowMajor, uplo, n, alpha, xPtr, incX, yPtr, incY, aPtr, lda);

      if (nativeA == null) {
        a.setRange(aOffset, aOffset + aLen, aPtr.asTypedList(aLen));
      }
      _mirrorSymmetricFloat(a, aOffset, n, lda, uplo);
      return true;
    });
  }

  bool dpotrf({
    int uplo = cblasUpper,
    required int n,
    required Float64List a,
    int aOffset = 0,
    required int lda,
  }) {
    final fn = _dpotrf;
    if (fn == null) return false;

    return using((arena) {
      final aLen = n * lda;
      final nativeA = _pointerForDouble(a, aOffset);
      final aPtr = nativeA ?? arena<ffi.Double>(aLen);
      if (nativeA == null) {
        aPtr.asTypedList(aLen).setRange(0, aLen, a, aOffset);
      }

      // For row-major: upper triangle in row-major is lower triangle in Fortran column-major ('L'=76, 'U'=85)
      final fortranUplo = uplo == cblasUpper ? 76 : 85;
      final uploPtr = arena<ffi.Uint8>()..value = fortranUplo;
      final nPtr = arena<ffi.Int32>()..value = n;
      final ldaPtr = arena<ffi.Int32>()..value = lda >= n ? lda : n;
      final info = arena<ffi.Int32>();

      fn(uploPtr, nPtr, aPtr, ldaPtr, info);
      if (info.value == 0) {
        if (nativeA == null) {
          a.setRange(aOffset, aOffset + aLen, aPtr.asTypedList(aLen));
        }
        return true;
      }
      return false;
    });
  }

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
    if (_lapackeDgesv != null) {
      return using((arena) {
        final aLen = n * lda;
        final bLen = n * ldb;
        final aPtr = _pointerForDouble(a, aOffset) ?? arena<ffi.Double>(aLen);
        if (_pointerForDouble(a, aOffset) == null) {
          aPtr.asTypedList(aLen).setRange(0, aLen, a, aOffset);
        }
        final bPtr = _pointerForDouble(b, bOffset) ?? arena<ffi.Double>(bLen);
        if (_pointerForDouble(b, bOffset) == null) {
          bPtr.asTypedList(bLen).setRange(0, bLen, b, bOffset);
        }
        final ipiv = arena<ffi.Int32>(n);

        final info = _lapackeDgesv!(
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
          if (_pointerForDouble(b, bOffset) == null) {
            b.setRange(bOffset, bOffset + bLen, bPtr.asTypedList(bLen));
          }
          return true;
        }
        return false;
      });
    }

    if (_dgetrf != null && _dgetrs != null) {
      return using((arena) {
        final aLen = n * lda;
        final bLen = n * ldb;

        final aPtr = arena<ffi.Double>(aLen);
        aPtr.asTypedList(aLen).setRange(0, aLen, a, aOffset);

        final bPtr = _pointerForDouble(b, bOffset) ?? arena<ffi.Double>(bLen);
        if (_pointerForDouble(b, bOffset) == null) {
          bPtr.asTypedList(bLen).setRange(0, bLen, b, bOffset);
        }

        final nPtr = arena<ffi.Int32>()..value = n;
        final nrhsPtr = arena<ffi.Int32>()..value = nrhs;
        final ldaPtr = arena<ffi.Int32>()..value = lda >= n ? lda : n;
        final fortranLdb = nrhs == 1 ? n : (ldb >= n ? ldb : n);
        final ldbPtr = arena<ffi.Int32>()..value = fortranLdb;
        final ipiv = arena<ffi.Int32>(n);
        final info = arena<ffi.Int32>();
        final trans = arena<ffi.Uint8>()..value = 84; // 'T'

        _dgetrf!(nPtr, nPtr, aPtr, ldaPtr, ipiv, info);
        if (info.value != 0) return false;

        _dgetrs!(trans, nPtr, nrhsPtr, aPtr, ldaPtr, ipiv, bPtr, ldbPtr, info);
        if (info.value != 0) return false;

        if (_pointerForDouble(b, bOffset) == null) {
          b.setRange(bOffset, bOffset + bLen, bPtr.asTypedList(bLen));
        }
        return true;
      });
    }

    if (_dgesv != null) {
      return using((arena) {
        final aLen = n * lda;
        final bLen = n * ldb;

        final aTrans = arena<ffi.Double>(aLen);
        for (var i = 0; i < n; i++) {
          for (var j = 0; j < n; j++) {
            aTrans[j * n + i] = a[aOffset + i * lda + j];
          }
        }

        final bPtr = arena<ffi.Double>(bLen);
        bPtr.asTypedList(bLen).setRange(0, bLen, b, bOffset);

        final nPtr = arena<ffi.Int32>()..value = n;
        final nrhsPtr = arena<ffi.Int32>()..value = nrhs;
        final ldaPtr = arena<ffi.Int32>()..value = n;
        final ldbPtr = arena<ffi.Int32>()..value = n;
        final ipiv = arena<ffi.Int32>(n);
        final info = arena<ffi.Int32>();

        _dgesv!(nPtr, nrhsPtr, aTrans, ldaPtr, ipiv, bPtr, ldbPtr, info);
        if (info.value == 0) {
          b.setRange(bOffset, bOffset + bLen, bPtr.asTypedList(bLen));
          return true;
        }
        return false;
      });
    }

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
    if (_lapackeDgels != null) {
      return using((arena) {
        final aLen = m * lda;
        final bLen = (m > n ? m : n) * ldb;

        final nativeA = _pointerForDouble(a, aOffset);
        final nativeB = _pointerForDouble(b, bOffset);

        final aPtr = nativeA ?? arena<ffi.Double>(aLen);
        if (nativeA == null) {
          aPtr.asTypedList(aLen).setRange(0, aLen, a, aOffset);
        }

        final bPtr = nativeB ?? arena<ffi.Double>(bLen);
        if (nativeB == null) {
          bPtr.asTypedList(bLen).setRange(0, m, b, bOffset);
        }

        final info = _lapackeDgels!(
          cblasRowMajor,
          78, // 'N'
          m,
          n,
          nrhs,
          aPtr,
          lda,
          bPtr,
          ldb,
        );
        if (info == 0) {
          if (nativeB == null) {
            b.setRange(bOffset, bOffset + n * ldb, bPtr.asTypedList(bLen));
          }
          return true;
        }
        return false;
      });
    }

    if (_dgels != null) {
      return using((arena) {
        final aLen = m * lda;
        final maxMN = m > n ? m : n;
        final bLen = maxMN * nrhs;

        final nativeA = _pointerForDouble(a, aOffset);
        final nativeB = _pointerForDouble(b, bOffset);

        final aPtr = nativeA ?? arena<ffi.Double>(aLen);
        if (nativeA == null) {
          aPtr.asTypedList(aLen).setRange(0, aLen, a, aOffset);
        }

        final bPtr = nativeB ?? arena<ffi.Double>(bLen);
        if (nativeB == null) {
          bPtr.asTypedList(bLen).setRange(0, m, b, bOffset);
        }

        final trans = arena<ffi.Uint8>()..value = 84; // 'T'
        final fRows = arena<ffi.Int32>()..value = n;
        final fCols = arena<ffi.Int32>()..value = m;
        final nrhsPtr = arena<ffi.Int32>()..value = nrhs;
        final ldaPtr = arena<ffi.Int32>()..value = n;
        final ldbPtr = arena<ffi.Int32>()..value = maxMN;
        final info = arena<ffi.Int32>();

        final lworkQuery = arena<ffi.Int32>()..value = -1;
        final workQuery = arena<ffi.Double>(1);
        _dgels!(
          trans,
          fRows,
          fCols,
          nrhsPtr,
          aPtr,
          ldaPtr,
          bPtr,
          ldbPtr,
          workQuery,
          lworkQuery,
          info,
        );
        if (info.value != 0) return false;

        final optLwork = workQuery[0].toInt();
        final work = arena<ffi.Double>(optLwork);
        final lwork = arena<ffi.Int32>()..value = optLwork;

        _dgels!(
          trans,
          fRows,
          fCols,
          nrhsPtr,
          aPtr,
          ldaPtr,
          bPtr,
          ldbPtr,
          work,
          lwork,
          info,
        );
        if (info.value == 0) {
          if (nativeB == null) {
            b.setRange(bOffset, bOffset + n, bPtr.asTypedList(bLen));
          }
          return true;
        }
        return false;
      });
    }

    return false;
  }

  T? _lookup<T extends Function>(T Function(ffi.DynamicLibrary lib) lookup) {
    for (final lib in _libraries) {
      try {
        return lookup(lib);
      } catch (_) {}
    }
    return null;
  }

  static ffi.Pointer<ffi.Double>? _pointerForDouble(
    Float64List list,
    int offset,
  ) {
    final nb = NativeBuffer.find(list);
    if (nb != null && !nb.isDisposed) {
      final ptr = nb.asDoublePointer;
      if (ptr != null) {
        final elemOffset = list.offsetInBytes ~/ 8;
        return ptr + elemOffset + offset;
      }
    }
    return null;
  }

  static ffi.Pointer<ffi.Float>? _pointerForFloat(
    Float32List list,
    int offset,
  ) {
    final nb = NativeBuffer.find(list);
    if (nb != null && !nb.isDisposed) {
      final ptr = nb.asFloatPointer;
      if (ptr != null) {
        final elemOffset = list.offsetInBytes ~/ 4;
        return ptr + elemOffset + offset;
      }
    }
    return null;
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
        for (var j = i + 1; j < n; j++) {
          c[cOffset + i * ldc + j] = c[cOffset + j * ldc + i];
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
        for (var j = i + 1; j < n; j++) {
          c[cOffset + i * ldc + j] = c[cOffset + j * ldc + i];
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
  } catch (_) {}
  return libs;
}

typedef _CblasDgemmNative = ffi.Void Function(
  ffi.Int32 order,
  ffi.Int32 transA,
  ffi.Int32 transB,
  ffi.Int32 m,
  ffi.Int32 n,
  ffi.Int32 k,
  ffi.Double alpha,
  ffi.Pointer<ffi.Double> a,
  ffi.Int32 lda,
  ffi.Pointer<ffi.Double> b,
  ffi.Int32 ldb,
  ffi.Double beta,
  ffi.Pointer<ffi.Double> c,
  ffi.Int32 ldc,
);
typedef _CblasDgemm = void Function(
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

typedef _CblasSgemmNative = ffi.Void Function(
  ffi.Int32 order,
  ffi.Int32 transA,
  ffi.Int32 transB,
  ffi.Int32 m,
  ffi.Int32 n,
  ffi.Int32 k,
  ffi.Float alpha,
  ffi.Pointer<ffi.Float> a,
  ffi.Int32 lda,
  ffi.Pointer<ffi.Float> b,
  ffi.Int32 ldb,
  ffi.Float beta,
  ffi.Pointer<ffi.Float> c,
  ffi.Int32 ldc,
);
typedef _CblasSgemm = void Function(
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

typedef _CblasDgemvNative = ffi.Void Function(
  ffi.Int32 order,
  ffi.Int32 transA,
  ffi.Int32 m,
  ffi.Int32 n,
  ffi.Double alpha,
  ffi.Pointer<ffi.Double> a,
  ffi.Int32 lda,
  ffi.Pointer<ffi.Double> x,
  ffi.Int32 incX,
  ffi.Double beta,
  ffi.Pointer<ffi.Double> y,
  ffi.Int32 incY,
);
typedef _CblasDgemv = void Function(
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

typedef _CblasSgemvNative = ffi.Void Function(
  ffi.Int32 order,
  ffi.Int32 transA,
  ffi.Int32 m,
  ffi.Int32 n,
  ffi.Float alpha,
  ffi.Pointer<ffi.Float> a,
  ffi.Int32 lda,
  ffi.Pointer<ffi.Float> x,
  ffi.Int32 incX,
  ffi.Float beta,
  ffi.Pointer<ffi.Float> y,
  ffi.Int32 incY,
);
typedef _CblasSgemv = void Function(
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

typedef _CblasDdotNative = ffi.Double Function(
  ffi.Int32 n,
  ffi.Pointer<ffi.Double> x,
  ffi.Int32 incX,
  ffi.Pointer<ffi.Double> y,
  ffi.Int32 incY,
);
typedef _CblasDdot = double Function(
  int n,
  ffi.Pointer<ffi.Double> x,
  int incX,
  ffi.Pointer<ffi.Double> y,
  int incY,
);

typedef _CblasSdotNative = ffi.Float Function(
  ffi.Int32 n,
  ffi.Pointer<ffi.Float> x,
  ffi.Int32 incX,
  ffi.Pointer<ffi.Float> y,
  ffi.Int32 incY,
);
typedef _CblasSdot = double Function(
  int n,
  ffi.Pointer<ffi.Float> x,
  int incX,
  ffi.Pointer<ffi.Float> y,
  int incY,
);

typedef _CblasDnrm2Native = ffi.Double Function(
  ffi.Int32 n,
  ffi.Pointer<ffi.Double> x,
  ffi.Int32 incX,
);
typedef _CblasDnrm2 = double Function(
  int n,
  ffi.Pointer<ffi.Double> x,
  int incX,
);

typedef _CblasSnrm2Native = ffi.Float Function(
  ffi.Int32 n,
  ffi.Pointer<ffi.Float> x,
  ffi.Int32 incX,
);
typedef _CblasSnrm2 = double Function(
  int n,
  ffi.Pointer<ffi.Float> x,
  int incX,
);

typedef _CblasDaxpyNative = ffi.Void Function(
  ffi.Int32 n,
  ffi.Double alpha,
  ffi.Pointer<ffi.Double> x,
  ffi.Int32 incX,
  ffi.Pointer<ffi.Double> y,
  ffi.Int32 incY,
);
typedef _CblasDaxpy = void Function(
  int n,
  double alpha,
  ffi.Pointer<ffi.Double> x,
  int incX,
  ffi.Pointer<ffi.Double> y,
  int incY,
);

typedef _CblasSaxpyNative = ffi.Void Function(
  ffi.Int32 n,
  ffi.Float alpha,
  ffi.Pointer<ffi.Float> x,
  ffi.Int32 incX,
  ffi.Pointer<ffi.Float> y,
  ffi.Int32 incY,
);
typedef _CblasSaxpy = void Function(
  int n,
  double alpha,
  ffi.Pointer<ffi.Float> x,
  int incX,
  ffi.Pointer<ffi.Float> y,
  int incY,
);

typedef _CblasDscalNative = ffi.Void Function(
  ffi.Int32 n,
  ffi.Double alpha,
  ffi.Pointer<ffi.Double> x,
  ffi.Int32 incX,
);
typedef _CblasDscal = void Function(
  int n,
  double alpha,
  ffi.Pointer<ffi.Double> x,
  int incX,
);

typedef _CblasSscalNative = ffi.Void Function(
  ffi.Int32 n,
  ffi.Float alpha,
  ffi.Pointer<ffi.Float> x,
  ffi.Int32 incX,
);
typedef _CblasSscal = void Function(
  int n,
  double alpha,
  ffi.Pointer<ffi.Float> x,
  int incX,
);

typedef _CblasDsyrkNative = ffi.Void Function(
  ffi.Int32 order,
  ffi.Int32 uplo,
  ffi.Int32 trans,
  ffi.Int32 n,
  ffi.Int32 k,
  ffi.Double alpha,
  ffi.Pointer<ffi.Double> a,
  ffi.Int32 lda,
  ffi.Double beta,
  ffi.Pointer<ffi.Double> c,
  ffi.Int32 ldc,
);
typedef _CblasDsyrk = void Function(
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

typedef _CblasSsyrkNative = ffi.Void Function(
  ffi.Int32 order,
  ffi.Int32 uplo,
  ffi.Int32 trans,
  ffi.Int32 n,
  ffi.Int32 k,
  ffi.Float alpha,
  ffi.Pointer<ffi.Float> a,
  ffi.Int32 lda,
  ffi.Float beta,
  ffi.Pointer<ffi.Float> c,
  ffi.Int32 ldc,
);
typedef _CblasSsyrk = void Function(
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
typedef _CblasDsyr2Native = ffi.Void Function(
  ffi.Int32 order,
  ffi.Int32 uplo,
  ffi.Int32 n,
  ffi.Double alpha,
  ffi.Pointer<ffi.Double> x,
  ffi.Int32 incX,
  ffi.Pointer<ffi.Double> y,
  ffi.Int32 incY,
  ffi.Pointer<ffi.Double> a,
  ffi.Int32 lda,
);
typedef _CblasDsyr2 = void Function(
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

typedef _CblasSsyr2Native = ffi.Void Function(
  ffi.Int32 order,
  ffi.Int32 uplo,
  ffi.Int32 n,
  ffi.Float alpha,
  ffi.Pointer<ffi.Float> x,
  ffi.Int32 incX,
  ffi.Pointer<ffi.Float> y,
  ffi.Int32 incY,
  ffi.Pointer<ffi.Float> a,
  ffi.Int32 lda,
);
typedef _CblasSsyr2 = void Function(
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

typedef _FortranDgesvNative = ffi.Void Function(
  ffi.Pointer<ffi.Int32> n,
  ffi.Pointer<ffi.Int32> nrhs,
  ffi.Pointer<ffi.Double> a,
  ffi.Pointer<ffi.Int32> lda,
  ffi.Pointer<ffi.Int32> ipiv,
  ffi.Pointer<ffi.Double> b,
  ffi.Pointer<ffi.Int32> ldb,
  ffi.Pointer<ffi.Int32> info,
);
typedef _FortranDgesv = void Function(
  ffi.Pointer<ffi.Int32> n,
  ffi.Pointer<ffi.Int32> nrhs,
  ffi.Pointer<ffi.Double> a,
  ffi.Pointer<ffi.Int32> lda,
  ffi.Pointer<ffi.Int32> ipiv,
  ffi.Pointer<ffi.Double> b,
  ffi.Pointer<ffi.Int32> ldb,
  ffi.Pointer<ffi.Int32> info,
);

typedef _FortranDpotrfNative = ffi.Void Function(
  ffi.Pointer<ffi.Uint8> uplo,
  ffi.Pointer<ffi.Int32> n,
  ffi.Pointer<ffi.Double> a,
  ffi.Pointer<ffi.Int32> lda,
  ffi.Pointer<ffi.Int32> info,
);
typedef _FortranDpotrf = void Function(
  ffi.Pointer<ffi.Uint8> uplo,
  ffi.Pointer<ffi.Int32> n,
  ffi.Pointer<ffi.Double> a,
  ffi.Pointer<ffi.Int32> lda,
  ffi.Pointer<ffi.Int32> info,
);

typedef _FortranDgeqrfNative = ffi.Void Function(
  ffi.Pointer<ffi.Int32> m,
  ffi.Pointer<ffi.Int32> n,
  ffi.Pointer<ffi.Double> a,
  ffi.Pointer<ffi.Int32> lda,
  ffi.Pointer<ffi.Double> tau,
  ffi.Pointer<ffi.Double> work,
  ffi.Pointer<ffi.Int32> lwork,
  ffi.Pointer<ffi.Int32> info,
);
typedef _FortranDgeqrf = void Function(
  ffi.Pointer<ffi.Int32> m,
  ffi.Pointer<ffi.Int32> n,
  ffi.Pointer<ffi.Double> a,
  ffi.Pointer<ffi.Int32> lda,
  ffi.Pointer<ffi.Double> tau,
  ffi.Pointer<ffi.Double> work,
  ffi.Pointer<ffi.Int32> lwork,
  ffi.Pointer<ffi.Int32> info,
);

typedef _FortranDgesvdNative = ffi.Void Function(
  ffi.Pointer<ffi.Uint8> jobu,
  ffi.Pointer<ffi.Uint8> jobvt,
  ffi.Pointer<ffi.Int32> m,
  ffi.Pointer<ffi.Int32> n,
  ffi.Pointer<ffi.Double> a,
  ffi.Pointer<ffi.Int32> lda,
  ffi.Pointer<ffi.Double> s,
  ffi.Pointer<ffi.Double> u,
  ffi.Pointer<ffi.Int32> ldu,
  ffi.Pointer<ffi.Double> vt,
  ffi.Pointer<ffi.Int32> ldvt,
  ffi.Pointer<ffi.Double> work,
  ffi.Pointer<ffi.Int32> lwork,
  ffi.Pointer<ffi.Int32> info,
);
typedef _FortranDgesvd = void Function(
  ffi.Pointer<ffi.Uint8> jobu,
  ffi.Pointer<ffi.Uint8> jobvt,
  ffi.Pointer<ffi.Int32> m,
  ffi.Pointer<ffi.Int32> n,
  ffi.Pointer<ffi.Double> a,
  ffi.Pointer<ffi.Int32> lda,
  ffi.Pointer<ffi.Double> s,
  ffi.Pointer<ffi.Double> u,
  ffi.Pointer<ffi.Int32> ldu,
  ffi.Pointer<ffi.Double> vt,
  ffi.Pointer<ffi.Int32> ldvt,
  ffi.Pointer<ffi.Double> work,
  ffi.Pointer<ffi.Int32> lwork,
  ffi.Pointer<ffi.Int32> info,
);

typedef _FortranDgesddNative = ffi.Void Function(
  ffi.Pointer<ffi.Uint8> jobz,
  ffi.Pointer<ffi.Int32> m,
  ffi.Pointer<ffi.Int32> n,
  ffi.Pointer<ffi.Double> a,
  ffi.Pointer<ffi.Int32> lda,
  ffi.Pointer<ffi.Double> s,
  ffi.Pointer<ffi.Double> u,
  ffi.Pointer<ffi.Int32> ldu,
  ffi.Pointer<ffi.Double> vt,
  ffi.Pointer<ffi.Int32> ldvt,
  ffi.Pointer<ffi.Double> work,
  ffi.Pointer<ffi.Int32> lwork,
  ffi.Pointer<ffi.Int32> iwork,
  ffi.Pointer<ffi.Int32> info,
);
typedef _FortranDgesdd = void Function(
  ffi.Pointer<ffi.Uint8> jobz,
  ffi.Pointer<ffi.Int32> m,
  ffi.Pointer<ffi.Int32> n,
  ffi.Pointer<ffi.Double> a,
  ffi.Pointer<ffi.Int32> lda,
  ffi.Pointer<ffi.Double> s,
  ffi.Pointer<ffi.Double> u,
  ffi.Pointer<ffi.Int32> ldu,
  ffi.Pointer<ffi.Double> vt,
  ffi.Pointer<ffi.Int32> ldvt,
  ffi.Pointer<ffi.Double> work,
  ffi.Pointer<ffi.Int32> lwork,
  ffi.Pointer<ffi.Int32> iwork,
  ffi.Pointer<ffi.Int32> info,
);

typedef _LapackeDgesvNative = ffi.Int32 Function(
  ffi.Int32 matrixLayout,
  ffi.Int32 n,
  ffi.Int32 nrhs,
  ffi.Pointer<ffi.Double> a,
  ffi.Int32 lda,
  ffi.Pointer<ffi.Int32> ipiv,
  ffi.Pointer<ffi.Double> b,
  ffi.Int32 ldb,
);
typedef _LapackeDgesv = int Function(
  int matrixLayout,
  int n,
  int nrhs,
  ffi.Pointer<ffi.Double> a,
  int lda,
  ffi.Pointer<ffi.Int32> ipiv,
  ffi.Pointer<ffi.Double> b,
  int ldb,
);

typedef _FortranDgetrfNative = ffi.Void Function(
  ffi.Pointer<ffi.Int32> m,
  ffi.Pointer<ffi.Int32> n,
  ffi.Pointer<ffi.Double> a,
  ffi.Pointer<ffi.Int32> lda,
  ffi.Pointer<ffi.Int32> ipiv,
  ffi.Pointer<ffi.Int32> info,
);
typedef _FortranDgetrf = void Function(
  ffi.Pointer<ffi.Int32> m,
  ffi.Pointer<ffi.Int32> n,
  ffi.Pointer<ffi.Double> a,
  ffi.Pointer<ffi.Int32> lda,
  ffi.Pointer<ffi.Int32> ipiv,
  ffi.Pointer<ffi.Int32> info,
);

typedef _FortranDgetrsNative = ffi.Void Function(
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
typedef _FortranDgetrs = void Function(
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

typedef _LapackeDgelsNative = ffi.Int32 Function(
  ffi.Int32 matrixLayout,
  ffi.Uint8 trans,
  ffi.Int32 m,
  ffi.Int32 n,
  ffi.Int32 nrhs,
  ffi.Pointer<ffi.Double> a,
  ffi.Int32 lda,
  ffi.Pointer<ffi.Double> b,
  ffi.Int32 ldb,
);
typedef _LapackeDgels = int Function(
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

typedef _FortranDgelsNative = ffi.Void Function(
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
typedef _FortranDgels = void Function(
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
