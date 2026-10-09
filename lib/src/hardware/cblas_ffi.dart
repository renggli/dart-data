import 'dart:ffi' as ffi;
import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

const int _cblasRowMajor = 101;
const int _cblasNoTrans = 111;

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

/// Native BLAS/LAPACK bindings via dart:ffi.
class BlasLibrary {
  new _(this._dylib) {
    if (_dylib != null) {
      try {
        _dgemm = _dylib.lookupFunction<_CblasDgemmNative, _CblasDgemm>(
          'cblas_dgemm',
        );
      } catch (_) {}
      try {
        _sgemm = _dylib.lookupFunction<_CblasSgemmNative, _CblasSgemm>(
          'cblas_sgemm',
        );
      } catch (_) {}
      try {
        _dgemv = _dylib.lookupFunction<_CblasDgemvNative, _CblasDgemv>(
          'cblas_dgemv',
        );
      } catch (_) {}
      try {
        _ddot = _dylib.lookupFunction<_CblasDdotNative, _CblasDdot>(
          'cblas_ddot',
        );
      } catch (_) {}
      try {
        _dnrm2 = _dylib.lookupFunction<_CblasDnrm2Native, _CblasDnrm2>(
          'cblas_dnrm2',
        );
      } catch (_) {}
      try {
        _daxpy = _dylib.lookupFunction<_CblasDaxpyNative, _CblasDaxpy>(
          'cblas_daxpy',
        );
      } catch (_) {}
      try {
        _dgesv = _dylib.lookupFunction<_LapackeDgesvNative, _LapackeDgesv>(
          'LAPACKE_dgesv',
        );
      } catch (_) {
        try {
          _dgesv = _dylib.lookupFunction<_LapackeDgesvNative, _LapackeDgesv>(
            'clapack_dgesv',
          );
        } catch (_) {}
      }
    }
  }

  final ffi.DynamicLibrary? _dylib;
  _CblasDgemm? _dgemm;
  _CblasSgemm? _sgemm;
  _CblasDgemv? _dgemv;
  _CblasDdot? _ddot;
  _CblasDnrm2? _dnrm2;
  _CblasDaxpy? _daxpy;
  _LapackeDgesv? _dgesv;

  bool get isAvailable => _dgemm != null;

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
  }) {
    final fn = _dgemm;
    if (fn == null) return false;

    using((arena) {
      final aPtr = arena<ffi.Double>(a.length);
      final bPtr = arena<ffi.Double>(b.length);
      final cPtr = arena<ffi.Double>(c.length);

      aPtr.asTypedList(a.length).setAll(0, a);
      bPtr.asTypedList(b.length).setAll(0, b);
      if (beta != 0.0) {
        cPtr.asTypedList(c.length).setAll(0, c);
      }

      fn(
        _cblasRowMajor,
        _cblasNoTrans,
        _cblasNoTrans,
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

      c.setAll(0, cPtr.asTypedList(c.length));
    });
    return true;
  }

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
  }) {
    final fn = _sgemm;
    if (fn == null) return false;

    using((arena) {
      final aPtr = arena<ffi.Float>(a.length);
      final bPtr = arena<ffi.Float>(b.length);
      final cPtr = arena<ffi.Float>(c.length);

      aPtr.asTypedList(a.length).setAll(0, a);
      bPtr.asTypedList(b.length).setAll(0, b);
      if (beta != 0.0) {
        cPtr.asTypedList(c.length).setAll(0, c);
      }

      fn(
        _cblasRowMajor,
        _cblasNoTrans,
        _cblasNoTrans,
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

      c.setAll(0, cPtr.asTypedList(c.length));
    });
    return true;
  }

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
  }) {
    final fn = _dgemv;
    if (fn == null) return false;

    using((arena) {
      final aPtr = arena<ffi.Double>(a.length);
      final xPtr = arena<ffi.Double>(x.length);
      final yPtr = arena<ffi.Double>(y.length);

      aPtr.asTypedList(a.length).setAll(0, a);
      xPtr.asTypedList(x.length).setAll(0, x);
      if (beta != 0.0) {
        yPtr.asTypedList(y.length).setAll(0, y);
      }

      fn(
        _cblasRowMajor,
        _cblasNoTrans,
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

      y.setAll(0, yPtr.asTypedList(y.length));
    });
    return true;
  }

  double? ddot({
    required int n,
    required Float64List x,
    required int incX,
    required Float64List y,
    required int incY,
  }) {
    final fn = _ddot;
    if (fn == null) return null;

    return using((arena) {
      final xPtr = arena<ffi.Double>(x.length);
      final yPtr = arena<ffi.Double>(y.length);
      xPtr.asTypedList(x.length).setAll(0, x);
      yPtr.asTypedList(y.length).setAll(0, y);
      return fn(n, xPtr, incX, yPtr, incY);
    });
  }

  double? dnrm2({required int n, required Float64List x, required int incX}) {
    final fn = _dnrm2;
    if (fn == null) return null;

    return using((arena) {
      final xPtr = arena<ffi.Double>(x.length);
      xPtr.asTypedList(x.length).setAll(0, x);
      return fn(n, xPtr, incX);
    });
  }

  bool daxpy({
    required int n,
    required double alpha,
    required Float64List x,
    required int incX,
    required Float64List y,
    required int incY,
  }) {
    final fn = _daxpy;
    if (fn == null) return false;

    using((arena) {
      final xPtr = arena<ffi.Double>(x.length);
      final yPtr = arena<ffi.Double>(y.length);
      xPtr.asTypedList(x.length).setAll(0, x);
      yPtr.asTypedList(y.length).setAll(0, y);
      fn(n, alpha, xPtr, incX, yPtr, incY);
      y.setAll(0, yPtr.asTypedList(y.length));
    });
    return true;
  }

  bool dgesv({
    required int n,
    required int nrhs,
    required Float64List a,
    required int lda,
    required Float64List b,
    required int ldb,
  }) {
    final fn = _dgesv;
    if (fn == null) return false;

    return using((arena) {
      final aPtr = arena<ffi.Double>(a.length);
      final bPtr = arena<ffi.Double>(b.length);
      final ipiv = arena<ffi.Int32>(n);

      aPtr.asTypedList(a.length).setAll(0, a);
      bPtr.asTypedList(b.length).setAll(0, b);

      final info = fn(_cblasRowMajor, n, nrhs, aPtr, lda, ipiv, bPtr, ldb);
      if (info == 0) {
        b.setAll(0, bPtr.asTypedList(b.length));
        return true;
      }
      return false;
    });
  }
}

ffi.DynamicLibrary? _loadPlatformLibrary() {
  try {
    if (Platform.isMacOS || Platform.isIOS) {
      for (final name in [
        '/System/Library/Frameworks/Accelerate.framework/Accelerate',
        'libBLAS.dylib',
      ]) {
        try {
          return ffi.DynamicLibrary.open(name);
        } catch (_) {}
      }
    } else if (Platform.isLinux || Platform.isAndroid) {
      for (final name in [
        'libopenblas.so.0',
        'libopenblas.so',
        'libblas.so.3',
      ]) {
        try {
          return ffi.DynamicLibrary.open(name);
        } catch (_) {}
      }
    } else if (Platform.isWindows) {
      for (final name in ['openblas.dll', 'libopenblas.dll']) {
        try {
          return ffi.DynamicLibrary.open(name);
        } catch (_) {}
      }
    }
  } catch (_) {}
  return null;
}

/// Loads the platform BLAS library.
BlasLibrary loadBlas() => BlasLibrary._(_loadPlatformLibrary());
