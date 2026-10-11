import 'dart:ffi' as ffi;
import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import '../../type/buffers/native_buffer_ffi.dart';

/// Representation of Apple Accelerate `DSPDoubleSplitComplex` structure.
final class DSPDoubleSplitComplex extends ffi.Struct {
  external ffi.Pointer<ffi.Double> realp;
  external ffi.Pointer<ffi.Double> imagp;
}

/// Loads the platform vDSP / vForce library.
VdspLibrary loadVdsp() => VdspLibrary._(_loadPlatformLibraries());

/// Native vDSP and vForce acceleration bindings via `dart:ffi`.
class VdspLibrary {
  new _(this._libraries) {
    _createFftSetupD = _lookup(
      (lib) =>
          lib.lookupFunction<_VdspCreateFftSetupDNative, _VdspCreateFftSetupD>(
            'vDSP_create_fftsetupD',
          ),
    );
    _destroyFftSetupD = _lookup(
      (lib) => lib
          .lookupFunction<_VdspDestroyFftSetupDNative, _VdspDestroyFftSetupD>(
            'vDSP_destroy_fftsetupD',
          ),
    );
    _fftZipD = _lookup(
      (lib) =>
          lib.lookupFunction<_VdspFftZipDNative, _VdspFftZipD>('vDSP_fft_zipD'),
    );
    _fft2dZipD = _lookup(
      (lib) => lib.lookupFunction<_VdspFft2dZipDNative, _VdspFft2dZipD>(
        'vDSP_fft2d_zipD',
      ),
    );
    _convD = _lookup(
      (lib) => lib.lookupFunction<_VdspConvDNative, _VdspConvD>('vDSP_convD'),
    );
    _sveD = _lookup(
      (lib) => lib.lookupFunction<_VdspSveDNative, _VdspSveD>('vDSP_sveD'),
    );
    _meanvD = _lookup(
      (lib) =>
          lib.lookupFunction<_VdspMeanvDNative, _VdspMeanvD>('vDSP_meanvD'),
    );
    _measqvD = _lookup(
      (lib) =>
          lib.lookupFunction<_VdspMeasqvDNative, _VdspMeasqvD>('vDSP_measqvD'),
    );

    _vvsin = _lookup(
      (lib) => lib.lookupFunction<_VForceUnaryNative, _VForceUnary>('vvsin'),
    );
    _vvcos = _lookup(
      (lib) => lib.lookupFunction<_VForceUnaryNative, _VForceUnary>('vvcos'),
    );
    _vvexp = _lookup(
      (lib) => lib.lookupFunction<_VForceUnaryNative, _VForceUnary>('vvexp'),
    );
    _vvlog = _lookup(
      (lib) => lib.lookupFunction<_VForceUnaryNative, _VForceUnary>('vvlog'),
    );
    _vvsqrt = _lookup(
      (lib) => lib.lookupFunction<_VForceUnaryNative, _VForceUnary>('vvsqrt'),
    );
    _vvpow = _lookup(
      (lib) => lib.lookupFunction<_VForcePowNative, _VForcePow>('vvpow'),
    );
  }

  final List<ffi.DynamicLibrary> _libraries;

  _VdspCreateFftSetupD? _createFftSetupD;
  _VdspDestroyFftSetupD? _destroyFftSetupD;
  _VdspFftZipD? _fftZipD;
  _VdspFft2dZipD? _fft2dZipD;
  _VdspConvD? _convD;
  _VdspSveD? _sveD;
  _VdspMeanvD? _meanvD;
  _VdspMeasqvD? _measqvD;

  _VForceUnary? _vvsin;
  _VForceUnary? _vvcos;
  _VForceUnary? _vvexp;
  _VForceUnary? _vvlog;
  _VForceUnary? _vvsqrt;
  _VForcePow? _vvpow;

  /// Whether native acceleration (vDSP or vForce) is available.
  bool get isAvailable => _createFftSetupD != null || _vvsin != null;

  /// Whether native FFT is available.
  bool get hasFft => _createFftSetupD != null && _fftZipD != null;

  /// Whether native vForce transcendentals are available.
  bool get hasVForce => _vvsin != null;

  /// Whether native vector reductions are available.
  bool get hasReductions => _sveD != null && _meanvD != null;

  T? _lookup<T>(T Function(ffi.DynamicLibrary) lookup) {
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

  /// Computes 1D in-place complex FFT on [real] and [imag] buffers of size $2^{\text{log2n}}$.
  bool fft1d({
    required Float64List real,
    required Float64List imag,
    required int log2n,
    required bool inverse,
  }) {
    final createSetup = _createFftSetupD;
    final destroySetup = _destroyFftSetupD;
    final fftZip = _fftZipD;
    if (createSetup == null || destroySetup == null || fftZip == null) {
      return false;
    }

    final n = 1 << log2n;
    if (real.length < n || imag.length < n) return false;

    final setup = createSetup(log2n, 0);
    if (setup == ffi.nullptr) return false;

    try {
      final nativeReal = _pointerForDouble(real, 0);
      final nativeImag = _pointerForDouble(imag, 0);

      return using((arena) {
        final realPtr = nativeReal ?? arena<ffi.Double>(n);
        final imagPtr = nativeImag ?? arena<ffi.Double>(n);

        if (nativeReal == null) {
          realPtr.asTypedList(n).setRange(0, n, real);
        }
        if (nativeImag == null) {
          imagPtr.asTypedList(n).setRange(0, n, imag);
        }

        final splitComplex = arena<DSPDoubleSplitComplex>();
        splitComplex.ref.realp = realPtr;
        splitComplex.ref.imagp = imagPtr;

        // vDSP direction: 1 for forward, -1 for inverse
        final direction = inverse ? -1 : 1;
        fftZip(setup, splitComplex, 1, log2n, direction);

        if (nativeReal == null) {
          real.setRange(0, n, realPtr.asTypedList(n));
        }
        if (nativeImag == null) {
          imag.setRange(0, n, imagPtr.asTypedList(n));
        }

        // vDSP does not divide by N on inverse FFT
        if (inverse) {
          final factor = 1.0 / n;
          for (var i = 0; i < n; i++) {
            real[i] *= factor;
            imag[i] *= factor;
          }
        }
        return true;
      });
    } finally {
      destroySetup(setup);
    }
  }

  /// Computes 2D in-place complex FFT on row-major [real] and [imag] buffers.
  bool fft2d({
    required Float64List real,
    required Float64List imag,
    required int log2rows,
    required int log2cols,
    required bool inverse,
  }) {
    final createSetup = _createFftSetupD;
    final destroySetup = _destroyFftSetupD;
    final fft2dZip = _fft2dZipD;
    if (createSetup == null || destroySetup == null || fft2dZip == null) {
      return false;
    }

    final rows = 1 << log2rows;
    final cols = 1 << log2cols;
    final total = rows * cols;
    if (real.length < total || imag.length < total) return false;

    final maxLog2 = log2rows > log2cols ? log2rows : log2cols;
    final setup = createSetup(maxLog2, 0);
    if (setup == ffi.nullptr) return false;

    try {
      final nativeReal = _pointerForDouble(real, 0);
      final nativeImag = _pointerForDouble(imag, 0);

      return using((arena) {
        final realPtr = nativeReal ?? arena<ffi.Double>(total);
        final imagPtr = nativeImag ?? arena<ffi.Double>(total);

        if (nativeReal == null) {
          realPtr.asTypedList(total).setRange(0, total, real);
        }
        if (nativeImag == null) {
          imagPtr.asTypedList(total).setRange(0, total, imag);
        }

        final splitComplex = arena<DSPDoubleSplitComplex>();
        splitComplex.ref.realp = realPtr;
        splitComplex.ref.imagp = imagPtr;

        final direction = inverse ? -1 : 1;
        // rowStride = 1, colStride = 0 (2D format in vDSP)
        fft2dZip(setup, splitComplex, 1, 0, log2cols, log2rows, direction);

        if (nativeReal == null) {
          real.setRange(0, total, realPtr.asTypedList(total));
        }
        if (nativeImag == null) {
          imag.setRange(0, total, imagPtr.asTypedList(total));
        }

        if (inverse) {
          final factor = 1.0 / total;
          for (var i = 0; i < total; i++) {
            real[i] *= factor;
            imag[i] *= factor;
          }
        }
        return true;
      });
    } finally {
      destroySetup(setup);
    }
  }

  /// Computes 1D linear convolution of [signal] and [filter].
  bool conv1d({
    required Float64List signal,
    required Float64List filter,
    required Float64List result,
  }) {
    final conv = _convD;
    if (conv == null) return false;

    final signalLen = signal.length;
    final filterLen = filter.length;
    final resultLen = signalLen - filterLen + 1;
    if (resultLen <= 0 || result.length < resultLen) return false;

    final nativeSignal = _pointerForDouble(signal, 0);
    final nativeFilter = _pointerForDouble(filter, 0);
    final nativeResult = _pointerForDouble(result, 0);

    return using((arena) {
      final sigPtr = nativeSignal ?? arena<ffi.Double>(signalLen);
      final filtPtr = nativeFilter ?? arena<ffi.Double>(filterLen);
      final resPtr = nativeResult ?? arena<ffi.Double>(resultLen);

      if (nativeSignal == null) {
        sigPtr.asTypedList(signalLen).setRange(0, signalLen, signal);
      }
      if (nativeFilter == null) {
        filtPtr.asTypedList(filterLen).setRange(0, filterLen, filter);
      }

      conv(sigPtr, 1, filtPtr, 1, resPtr, 1, resultLen, filterLen);

      if (nativeResult == null) {
        result.setRange(0, resultLen, resPtr.asTypedList(resultLen));
      }
      return true;
    });
  }

  // --- vForce Transcendentals ---

  bool _applyUnary(
    _VForceUnary? fn,
    Float64List input,
    Float64List output,
    int n,
  ) {
    if (fn == null || n <= 0 || input.length < n || output.length < n) {
      return false;
    }
    final nativeIn = _pointerForDouble(input, 0);
    final nativeOut = _pointerForDouble(output, 0);

    return using((arena) {
      final inPtr = nativeIn ?? arena<ffi.Double>(n);
      final outPtr = nativeOut ?? arena<ffi.Double>(n);
      final nPtr = arena<ffi.Int32>()..value = n;

      if (nativeIn == null) {
        inPtr.asTypedList(n).setRange(0, n, input);
      }

      fn(outPtr, inPtr, nPtr);

      if (nativeOut == null) {
        output.setRange(0, n, outPtr.asTypedList(n));
      }
      return true;
    });
  }

  /// Computes elementwise sine: `output[i] = sin(input[i])`.
  bool vvsin({
    required Float64List input,
    required Float64List output,
    required int n,
  }) => _applyUnary(_vvsin, input, output, n);

  /// Computes elementwise cosine: `output[i] = cos(input[i])`.
  bool vvcos({
    required Float64List input,
    required Float64List output,
    required int n,
  }) => _applyUnary(_vvcos, input, output, n);

  /// Computes elementwise exponential: `output[i] = exp(input[i])`.
  bool vvexp({
    required Float64List input,
    required Float64List output,
    required int n,
  }) => _applyUnary(_vvexp, input, output, n);

  /// Computes elementwise natural logarithm: `output[i] = ln(input[i])`.
  bool vvlog({
    required Float64List input,
    required Float64List output,
    required int n,
  }) => _applyUnary(_vvlog, input, output, n);

  /// Computes elementwise square root: `output[i] = sqrt(input[i])`.
  bool vvsqrt({
    required Float64List input,
    required Float64List output,
    required int n,
  }) => _applyUnary(_vvsqrt, input, output, n);

  /// Computes elementwise power: `output[i] = pow(base[i], exponent[i])`.
  bool vvpow({
    required Float64List base,
    required Float64List exponent,
    required Float64List output,
    required int n,
  }) {
    final fn = _vvpow;
    if (fn == null ||
        n <= 0 ||
        base.length < n ||
        exponent.length < n ||
        output.length < n) {
      return false;
    }
    final nativeBase = _pointerForDouble(base, 0);
    final nativeExp = _pointerForDouble(exponent, 0);
    final nativeOut = _pointerForDouble(output, 0);

    return using((arena) {
      final basePtr = nativeBase ?? arena<ffi.Double>(n);
      final expPtr = nativeExp ?? arena<ffi.Double>(n);
      final outPtr = nativeOut ?? arena<ffi.Double>(n);
      final nPtr = arena<ffi.Int32>()..value = n;

      if (nativeBase == null) {
        basePtr.asTypedList(n).setRange(0, n, base);
      }
      if (nativeExp == null) {
        expPtr.asTypedList(n).setRange(0, n, exponent);
      }

      // vvpow(z, y, x, n): z = x^y, so y is exponent, x is base
      fn(outPtr, expPtr, basePtr, nPtr);

      if (nativeOut == null) {
        output.setRange(0, n, outPtr.asTypedList(n));
      }
      return true;
    });
  }

  // --- vDSP Vector Reductions ---

  /// Computes sum of elements in [x].
  double? sve({required Float64List x, required int n}) {
    final fn = _sveD;
    if (fn == null || n <= 0 || x.length < n) return null;

    final nativeX = _pointerForDouble(x, 0);
    return using((arena) {
      final xPtr = nativeX ?? arena<ffi.Double>(n);
      final outPtr = arena<ffi.Double>();

      if (nativeX == null) {
        xPtr.asTypedList(n).setRange(0, n, x);
      }

      fn(xPtr, 1, outPtr, n);
      return outPtr.value;
    });
  }

  /// Computes arithmetic mean of elements in [x].
  double? meanv({required Float64List x, required int n}) {
    final fn = _meanvD;
    if (fn == null || n <= 0 || x.length < n) return null;

    final nativeX = _pointerForDouble(x, 0);
    return using((arena) {
      final xPtr = nativeX ?? arena<ffi.Double>(n);
      final outPtr = arena<ffi.Double>();

      if (nativeX == null) {
        xPtr.asTypedList(n).setRange(0, n, x);
      }

      fn(xPtr, 1, outPtr, n);
      return outPtr.value;
    });
  }

  /// Computes mean of squared elements in [x].
  double? measqv({required Float64List x, required int n}) {
    final fn = _measqvD;
    if (fn == null || n <= 0 || x.length < n) return null;

    final nativeX = _pointerForDouble(x, 0);
    return using((arena) {
      final xPtr = nativeX ?? arena<ffi.Double>(n);
      final outPtr = arena<ffi.Double>();

      if (nativeX == null) {
        xPtr.asTypedList(n).setRange(0, n, x);
      }

      fn(xPtr, 1, outPtr, n);
      return outPtr.value;
    });
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
      tryOpen('/System/Library/Frameworks/Accelerate.framework/Accelerate');
    } else if (Platform.isLinux || Platform.isAndroid) {
      for (final name in ['libfftw3.so.3', 'libfftw3.so']) {
        tryOpen(name);
      }
    } else if (Platform.isWindows) {
      for (final name in ['fftw3.dll', 'libfftw3-3.dll']) {
        tryOpen(name);
      }
    }
  } catch (_) {}
  return libs;
}

// Native function typedefs
typedef _VdspCreateFftSetupDNative = ffi.Pointer<ffi.Void> Function(
  ffi.Uint64 log2n,
  ffi.Int32 radix,
);
typedef _VdspCreateFftSetupD = ffi.Pointer<ffi.Void> Function(
  int log2n,
  int radix,
);

typedef _VdspDestroyFftSetupDNative = ffi.Void Function(
  ffi.Pointer<ffi.Void> setup,
);
typedef _VdspDestroyFftSetupD = void Function(ffi.Pointer<ffi.Void> setup);

typedef _VdspFftZipDNative = ffi.Void Function(
  ffi.Pointer<ffi.Void> setup,
  ffi.Pointer<DSPDoubleSplitComplex> c,
  ffi.Int64 stride,
  ffi.Uint64 log2n,
  ffi.Int32 direction,
);
typedef _VdspFftZipD = void Function(
  ffi.Pointer<ffi.Void> setup,
  ffi.Pointer<DSPDoubleSplitComplex> c,
  int stride,
  int log2n,
  int direction,
);

typedef _VdspFft2dZipDNative = ffi.Void Function(
  ffi.Pointer<ffi.Void> setup,
  ffi.Pointer<DSPDoubleSplitComplex> c,
  ffi.Int64 rowStride,
  ffi.Int64 colStride,
  ffi.Uint64 log2cols,
  ffi.Uint64 log2rows,
  ffi.Int32 direction,
);
typedef _VdspFft2dZipD = void Function(
  ffi.Pointer<ffi.Void> setup,
  ffi.Pointer<DSPDoubleSplitComplex> c,
  int rowStride,
  int colStride,
  int log2cols,
  int log2rows,
  int direction,
);

typedef _VdspConvDNative = ffi.Void Function(
  ffi.Pointer<ffi.Double> signal,
  ffi.Int64 signalStride,
  ffi.Pointer<ffi.Double> filter,
  ffi.Int64 filterStride,
  ffi.Pointer<ffi.Double> result,
  ffi.Int64 resultStride,
  ffi.Uint64 resultLen,
  ffi.Uint64 filterLen,
);
typedef _VdspConvD = void Function(
  ffi.Pointer<ffi.Double> signal,
  int signalStride,
  ffi.Pointer<ffi.Double> filter,
  int filterStride,
  ffi.Pointer<ffi.Double> result,
  int resultStride,
  int resultLen,
  int filterLen,
);

typedef _VdspSveDNative = ffi.Void Function(
  ffi.Pointer<ffi.Double> a,
  ffi.Int64 stride,
  ffi.Pointer<ffi.Double> c,
  ffi.Uint64 n,
);
typedef _VdspSveD = void Function(
  ffi.Pointer<ffi.Double> a,
  int stride,
  ffi.Pointer<ffi.Double> c,
  int n,
);

typedef _VdspMeanvDNative = ffi.Void Function(
  ffi.Pointer<ffi.Double> a,
  ffi.Int64 stride,
  ffi.Pointer<ffi.Double> c,
  ffi.Uint64 n,
);
typedef _VdspMeanvD = void Function(
  ffi.Pointer<ffi.Double> a,
  int stride,
  ffi.Pointer<ffi.Double> c,
  int n,
);

typedef _VdspMeasqvDNative = ffi.Void Function(
  ffi.Pointer<ffi.Double> a,
  ffi.Int64 stride,
  ffi.Pointer<ffi.Double> c,
  ffi.Uint64 n,
);
typedef _VdspMeasqvD = void Function(
  ffi.Pointer<ffi.Double> a,
  int stride,
  ffi.Pointer<ffi.Double> c,
  int n,
);

typedef _VForceUnaryNative = ffi.Void Function(
  ffi.Pointer<ffi.Double> y,
  ffi.Pointer<ffi.Double> x,
  ffi.Pointer<ffi.Int32> n,
);
typedef _VForceUnary = void Function(
  ffi.Pointer<ffi.Double> y,
  ffi.Pointer<ffi.Double> x,
  ffi.Pointer<ffi.Int32> n,
);

typedef _VForcePowNative = ffi.Void Function(
  ffi.Pointer<ffi.Double> z,
  ffi.Pointer<ffi.Double> y,
  ffi.Pointer<ffi.Double> x,
  ffi.Pointer<ffi.Int32> n,
);
typedef _VForcePow = void Function(
  ffi.Pointer<ffi.Double> z,
  ffi.Pointer<ffi.Double> y,
  ffi.Pointer<ffi.Double> x,
  ffi.Pointer<ffi.Int32> n,
);
