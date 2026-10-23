// coverage:ignore-file
import 'dart:ffi' as ffi;
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import '../blas/cblas_constants.dart';
import '../utils/library_loader_ffi.dart';

/// Native LAPACK bindings via dart:ffi.
abstract final class LapackNative {
  static final List<ffi.DynamicLibrary> _libs = platformBlasLibraries;

  static final bool _hasDpotrf =
      hasSymbol('dpotrf_', _libs) || hasSymbol('LAPACKE_dpotrf', _libs);
  static final bool _hasLapackeDgesv = hasSymbol('LAPACKE_dgesv', _libs);
  static final bool _hasClapackDgesv = hasSymbol('clapack_dgesv', _libs);
  static final bool _hasDgesv = hasSymbol('dgesv_', _libs);
  static final bool _hasLapackeDgels = hasSymbol('LAPACKE_dgels', _libs);
  static final bool _hasDgels = hasSymbol('dgels_', _libs);
  static final bool _hasLapackeDsyev = hasSymbol('LAPACKE_dsyev', _libs);
  static final bool _hasDsyev = hasSymbol('dsyev_', _libs);
  static final bool _hasLapackeSsyev = hasSymbol('LAPACKE_ssyev', _libs);
  static final bool _hasSsyev = hasSymbol('ssyev_', _libs);

  /// Whether native LAPACK is available.
  static bool get isAvailable =>
      _libs.isNotEmpty &&
      (_hasDpotrf || _hasDgesv || _hasLapackeDgesv || _hasClapackDgesv);

  static bool get hasDpotrf => _hasDpotrf;
  static bool get hasDgesv => _hasLapackeDgesv || _hasClapackDgesv || _hasDgesv;
  static bool get hasDgels => _hasLapackeDgels || _hasDgels;
  static bool get hasDsyev => _hasLapackeDsyev || _hasDsyev;
  static bool get hasSsyev => _hasLapackeSsyev || _hasSsyev;

  static bool? dpotrf({
    required int uplo,
    required int n,
    required Float64List a,
    required int aOffset,
    required int lda,
  }) {
    if (!_hasDpotrf) return null;
    if (n == 0) return true;
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

  static bool? dgesv({
    required int n,
    required int nrhs,
    required Float64List a,
    required int aOffset,
    required int lda,
    required Float64List b,
    required int bOffset,
    required int ldb,
  }) {
    if (!hasDgesv) return null;
    if (n < 0 || nrhs < 0 || lda < n || (nrhs > 0 && ldb < nrhs)) return false;
    if (n == 0 || nrhs == 0) return true;
    final aRequired = aOffset + (n - 1) * lda + n;
    final bRequired = bOffset + (n - 1) * ldb + nrhs;
    if (a.length < aRequired || b.length < bRequired) return false;

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

    if (_hasDgesv) {
      return using((arena) {
        final aFortran = arena<ffi.Double>(n * n);
        for (var i = 0; i < n; i++) {
          for (var j = 0; j < n; j++) {
            aFortran[j * n + i] = a[aOffset + i * lda + j];
          }
        }

        final bFortran = arena<ffi.Double>(n * nrhs);
        for (var i = 0; i < n; i++) {
          for (var j = 0; j < nrhs; j++) {
            bFortran[j * n + i] = b[bOffset + i * ldb + j];
          }
        }

        final nPtr = arena<ffi.Int32>()..value = n;
        final nrhsPtr = arena<ffi.Int32>()..value = nrhs;
        final ldaPtr = arena<ffi.Int32>()..value = n;
        final ldbPtr = arena<ffi.Int32>()..value = n;
        final ipiv = arena<ffi.Int32>(n);
        final info = arena<ffi.Int32>();

        _fortranDgesv(
          nPtr,
          nrhsPtr,
          aFortran,
          ldaPtr,
          ipiv,
          bFortran,
          ldbPtr,
          info,
        );

        if (info.value == 0) {
          for (var i = 0; i < n; i++) {
            for (var j = 0; j < nrhs; j++) {
              b[bOffset + i * ldb + j] = bFortran[j * n + i];
            }
          }
          return true;
        }
        return false;
      });
    }

    return false;
  }

  static bool? dgels({
    required int m,
    required int n,
    required int nrhs,
    required Float64List a,
    required int aOffset,
    required int lda,
    required Float64List b,
    required int bOffset,
    required int ldb,
  }) {
    if (!hasDgels) return null;
    if (m == 0 || n == 0 || nrhs == 0) return true;
    final aView = aOffset == 0 ? a : Float64List.sublistView(a, aOffset);
    final bView = bOffset == 0 ? b : Float64List.sublistView(b, bOffset);

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

    if (_hasDgels) {
      return using((arena) {
        final maxMN = m > n ? m : n;
        final fA = arena<ffi.Double>(m * n);
        for (var i = 0; i < m; i++) {
          for (var j = 0; j < n; j++) {
            fA[j * m + i] = a[aOffset + i * lda + j];
          }
        }

        final fB = arena<ffi.Double>(maxMN * nrhs);
        for (var i = 0; i < maxMN; i++) {
          for (var j = 0; j < nrhs; j++) {
            fB[j * maxMN + i] = (i < m || i < n)
                ? b[bOffset + i * ldb + j]
                : 0.0;
          }
        }

        final trans = arena<ffi.Uint8>()..value = 78; // 'N'
        final mPtr = arena<ffi.Int32>()..value = m;
        final nPtr = arena<ffi.Int32>()..value = n;
        final nrhsPtr = arena<ffi.Int32>()..value = nrhs;
        final ldaPtr = arena<ffi.Int32>()..value = m;
        final ldbPtr = arena<ffi.Int32>()..value = maxMN;
        final info = arena<ffi.Int32>();

        final lworkQuery = arena<ffi.Int32>()..value = -1;
        final workQuery = arena<ffi.Double>(1);
        _fortranDgels(
          trans,
          mPtr,
          nPtr,
          nrhsPtr,
          fA,
          ldaPtr,
          fB,
          ldbPtr,
          workQuery,
          lworkQuery,
          info,
        );
        if (info.value != 0) return false;

        final optLwork = workQuery[0].toInt();
        final lworkVal = optLwork > 0 ? optLwork : 1;
        final work = arena<ffi.Double>(lworkVal);
        final lwork = arena<ffi.Int32>()..value = lworkVal;

        _fortranDgels(
          trans,
          mPtr,
          nPtr,
          nrhsPtr,
          fA,
          ldaPtr,
          fB,
          ldbPtr,
          work,
          lwork,
          info,
        );
        if (info.value == 0) {
          for (var i = 0; i < maxMN; i++) {
            for (var j = 0; j < nrhs; j++) {
              b[bOffset + i * ldb + j] = fB[j * maxMN + i];
            }
          }
          return true;
        }
        return false;
      });
    }

    return false;
  }

  static bool? dsyev({
    required String jobz,
    required int uplo,
    required int n,
    required Float64List a,
    required int aOffset,
    required int lda,
    required Float64List w,
    required int wOffset,
  }) {
    if (!hasDsyev) return null;
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
        return true;
      }
      return false;
    }

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

  static bool? ssyev({
    required String jobz,
    required int uplo,
    required int n,
    required Float32List a,
    required int aOffset,
    required int lda,
    required Float32List w,
    required int wOffset,
  }) {
    if (!hasSsyev) return null;
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
        return true;
      }
      return false;
    }

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
}

// --- LAPACK Native FFI Declarations ---

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
