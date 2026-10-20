import 'dart:ffi' as ffi;
import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

/// Representation of Apple Accelerate `DSPDoubleSplitComplex` structure.
final class DSPDoubleSplitComplex extends ffi.Struct {
  external ffi.Pointer<ffi.Double> realp;
  external ffi.Pointer<ffi.Double> imagp;
}

/// Loads the platform vDSP / vForce library.
VdspLibrary loadVdsp() => VdspLibrary._(_loadPlatformLibraries());

/// Native vDSP and vForce acceleration bindings via `dart:ffi` using leaf native
/// calls and typed data direct addresses.
class VdspLibrary {
  new _(this.libraries)
    : _hasCreateFftSetupD = _hasSymbolIn('vDSP_create_fftsetupD', libraries),
      _hasDestroyFftSetupD = _hasSymbolIn('vDSP_destroy_fftsetupD', libraries),
      _hasFftZipD = _hasSymbolIn('vDSP_fft_zipD', libraries),
      _hasFft2dZipD = _hasSymbolIn('vDSP_fft2d_zipD', libraries),
      _hasConvD = _hasSymbolIn('vDSP_convD', libraries),
      _hasSveD = _hasSymbolIn('vDSP_sveD', libraries),
      _hasMeanvD = _hasSymbolIn('vDSP_meanvD', libraries),
      _hasMeasqvD = _hasSymbolIn('vDSP_measqvD', libraries),
      _hasVsaddD = _hasSymbolIn('vDSP_vsaddD', libraries),
      _hasSvesqD = _hasSymbolIn('vDSP_svesqD', libraries),
      _hasVvsin = _hasSymbolIn('vvsin', libraries),
      _hasVvcos = _hasSymbolIn('vvcos', libraries),
      _hasVvexp = _hasSymbolIn('vvexp', libraries),
      _hasVvlog = _hasSymbolIn('vvlog', libraries),
      _hasVvsqrt = _hasSymbolIn('vvsqrt', libraries),
      _hasVvpow = _hasSymbolIn('vvpow', libraries);

  /// The underlying platform dynamic libraries.
  final List<ffi.DynamicLibrary> libraries;

  final Map<int, ffi.Pointer<ffi.Void>> _fftSetups = {};

  final bool _hasCreateFftSetupD;
  final bool _hasDestroyFftSetupD;
  final bool _hasFftZipD;
  final bool _hasFft2dZipD;
  final bool _hasConvD;
  final bool _hasSveD;
  final bool _hasMeanvD;
  final bool _hasMeasqvD;
  final bool _hasVsaddD;
  final bool _hasSvesqD;
  final bool _hasVvsin;
  final bool _hasVvcos;
  final bool _hasVvexp;
  final bool _hasVvlog;
  final bool _hasVvsqrt;
  final bool _hasVvpow;

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

  /// Whether native acceleration (vDSP or vForce) is available.
  bool get isAvailable => _hasCreateFftSetupD || _hasVvsin;

  /// Whether native FFT is available.
  bool get hasFft => _hasCreateFftSetupD && _hasFftZipD;

  /// Whether native vForce transcendentals are available.
  bool get hasVForce => _hasVvsin;

  /// Whether native vector reductions are available.
  bool get hasReductions => _hasSveD && _hasMeanvD && _hasVsaddD && _hasSvesqD;

  ffi.Pointer<ffi.Void>? _getFftSetup(int log2n) {
    if (!_hasCreateFftSetupD) return null;
    return _fftSetups.putIfAbsent(log2n, () => _vdspCreateFftSetupD(log2n, 0));
  }

  /// Releases cached FFT setups.
  void dispose() {
    if (_hasDestroyFftSetupD) {
      for (final setup in _fftSetups.values) {
        if (setup != ffi.nullptr) {
          _vdspDestroyFftSetupD(setup);
        }
      }
    }
    _fftSetups.clear();
  }

  /// Computes 1D in-place complex FFT on [real] and [imag] buffers of size
  /// $2^{\text{log2n}}$.
  bool fft1d({
    required Float64List real,
    required Float64List imag,
    required int log2n,
    required bool inverse,
  }) {
    if (!_hasFftZipD) return false;

    final n = 1 << log2n;
    if (real.length < n || imag.length < n) return false;

    final setup = _getFftSetup(log2n);
    if (setup == null || setup == ffi.nullptr) return false;

    return using((arena) {
      final realPtr = arena<ffi.Double>(n);
      final imagPtr = arena<ffi.Double>(n);
      realPtr.asTypedList(n).setRange(0, n, real);
      imagPtr.asTypedList(n).setRange(0, n, imag);

      final splitComplex = arena<DSPDoubleSplitComplex>();
      splitComplex.ref.realp = realPtr;
      splitComplex.ref.imagp = imagPtr;

      final direction = inverse ? -1 : 1;
      _vdspFftZipD(setup, splitComplex, 1, log2n, direction);

      real.setRange(0, n, realPtr.asTypedList(n));
      imag.setRange(0, n, imagPtr.asTypedList(n));

      if (inverse) {
        final factor = 1.0 / n;
        for (var i = 0; i < n; i++) {
          real[i] *= factor;
          imag[i] *= factor;
        }
      }
      return true;
    });
  }

  /// Computes 2D in-place complex FFT on row-major [real] and [imag] buffers.
  bool fft2d({
    required Float64List real,
    required Float64List imag,
    required int log2rows,
    required int log2cols,
    required bool inverse,
  }) {
    if (!_hasFft2dZipD) return false;

    final rows = 1 << log2rows;
    final cols = 1 << log2cols;
    final total = rows * cols;
    if (real.length < total || imag.length < total) return false;

    final maxLog2 = log2rows > log2cols ? log2rows : log2cols;
    final setup = _getFftSetup(maxLog2);
    if (setup == null || setup == ffi.nullptr) return false;

    return using((arena) {
      final realPtr = arena<ffi.Double>(total);
      final imagPtr = arena<ffi.Double>(total);
      realPtr.asTypedList(total).setRange(0, total, real);
      imagPtr.asTypedList(total).setRange(0, total, imag);

      final splitComplex = arena<DSPDoubleSplitComplex>();
      splitComplex.ref.realp = realPtr;
      splitComplex.ref.imagp = imagPtr;

      final direction = inverse ? -1 : 1;
      _vdspFft2dZipD(setup, splitComplex, 1, 0, log2cols, log2rows, direction);

      real.setRange(0, total, realPtr.asTypedList(total));
      imag.setRange(0, total, imagPtr.asTypedList(total));

      if (inverse) {
        final factor = 1.0 / total;
        for (var i = 0; i < total; i++) {
          real[i] *= factor;
          imag[i] *= factor;
        }
      }
      return true;
    });
  }

  /// Computes 1D linear convolution of [signal] and [filter].
  bool conv1d({
    required Float64List signal,
    required Float64List filter,
    required Float64List result,
  }) {
    if (!_hasConvD) return false;

    final signalLen = signal.length;
    final filterLen = filter.length;
    final resultLen = signalLen - filterLen + 1;
    if (resultLen <= 0 || result.length < resultLen) return false;

    final filterEndView = Float64List.sublistView(filter, filterLen - 1);
    _vdspConvD(
      signal.address,
      1,
      filterEndView.address,
      -1,
      result.address,
      1,
      resultLen,
      filterLen,
    );
    return true;
  }

  /// Computes 1D cross-correlation of [signal] and [filter].
  bool xcorr1d({
    required Float64List signal,
    required Float64List filter,
    required Float64List result,
  }) {
    if (!_hasConvD) return false;

    final signalLen = signal.length;
    final filterLen = filter.length;
    final resultLen = signalLen - filterLen + 1;
    if (resultLen <= 0 || result.length < resultLen) return false;

    _vdspConvD(
      signal.address,
      1,
      filter.address,
      1,
      result.address,
      1,
      resultLen,
      filterLen,
    );
    return true;
  }

  // --- vForce Transcendentals ---

  /// Computes elementwise sine: `output[i] = sin(input[i])`.
  bool vvsin({
    required Float64List input,
    required Float64List output,
    required int n,
  }) {
    if (!_hasVvsin || n <= 0 || input.length < n || output.length < n) {
      return false;
    }
    return using((arena) {
      final nPtr = arena<ffi.Int32>()..value = n;
      _vvsin(output.address, input.address, nPtr);
      return true;
    });
  }

  /// Computes elementwise cosine: `output[i] = cos(input[i])`.
  bool vvcos({
    required Float64List input,
    required Float64List output,
    required int n,
  }) {
    if (!_hasVvcos || n <= 0 || input.length < n || output.length < n) {
      return false;
    }
    return using((arena) {
      final nPtr = arena<ffi.Int32>()..value = n;
      _vvcos(output.address, input.address, nPtr);
      return true;
    });
  }

  /// Computes elementwise exponential: `output[i] = exp(input[i])`.
  bool vvexp({
    required Float64List input,
    required Float64List output,
    required int n,
  }) {
    if (!_hasVvexp || n <= 0 || input.length < n || output.length < n) {
      return false;
    }
    return using((arena) {
      final nPtr = arena<ffi.Int32>()..value = n;
      _vvexp(output.address, input.address, nPtr);
      return true;
    });
  }

  /// Computes elementwise natural logarithm: `output[i] = ln(input[i])`.
  bool vvlog({
    required Float64List input,
    required Float64List output,
    required int n,
  }) {
    if (!_hasVvlog || n <= 0 || input.length < n || output.length < n) {
      return false;
    }
    return using((arena) {
      final nPtr = arena<ffi.Int32>()..value = n;
      _vvlog(output.address, input.address, nPtr);
      return true;
    });
  }

  /// Computes elementwise square root: `output[i] = sqrt(input[i])`.
  bool vvsqrt({
    required Float64List input,
    required Float64List output,
    required int n,
  }) {
    if (!_hasVvsqrt || n <= 0 || input.length < n || output.length < n) {
      return false;
    }
    return using((arena) {
      final nPtr = arena<ffi.Int32>()..value = n;
      _vvsqrt(output.address, input.address, nPtr);
      return true;
    });
  }

  /// Computes elementwise power: `output[i] = pow(base[i], exponent[i])`.
  bool vvpow({
    required Float64List output,
    required Float64List exponent,
    required Float64List base,
    required int n,
  }) {
    if (!_hasVvpow ||
        n <= 0 ||
        output.length < n ||
        exponent.length < n ||
        base.length < n) {
      return false;
    }
    return using((arena) {
      final nPtr = arena<ffi.Int32>()..value = n;
      _vvpow(output.address, exponent.address, base.address, nPtr);
      return true;
    });
  }

  // --- vDSP Vector Reductions ---

  /// Computes sum of elements in [x].
  double? sve({required Float64List x, required int n}) {
    if (!_hasSveD || n <= 0 || x.length < n) return null;
    return using((arena) {
      final outPtr = arena<ffi.Double>();
      _vdspSveD(x.address, 1, outPtr, n);
      return outPtr.value;
    });
  }

  /// Computes arithmetic mean of elements in [x].
  double? meanv({required Float64List x, required int n}) {
    if (!_hasMeanvD || n <= 0 || x.length < n) return null;
    return using((arena) {
      final outPtr = arena<ffi.Double>();
      _vdspMeanvD(x.address, 1, outPtr, n);
      return outPtr.value;
    });
  }

  /// Computes mean of squared elements in [x].
  double? measqv({required Float64List x, required int n}) {
    if (!_hasMeasqvD || n <= 0 || x.length < n) return null;
    return using((arena) {
      final outPtr = arena<ffi.Double>();
      _vdspMeasqvD(x.address, 1, outPtr, n);
      return outPtr.value;
    });
  }

  /// Computes sample or population variance of elements in [x] using two-pass
  /// deviation summation with vDSP vector instructions.
  double? variance({
    required Float64List x,
    required int n,
    required bool sample,
  }) {
    final minCount = sample ? 2 : 1;
    if (!_hasMeanvD ||
        !_hasVsaddD ||
        !_hasSvesqD ||
        n < minCount ||
        x.length < n) {
      return null;
    }

    return using((arena) {
      final meanPtr = arena<ffi.Double>();
      final diff = Float64List(n);
      final sumSqPtr = arena<ffi.Double>();

      _vdspMeanvD(x.address, 1, meanPtr, n);
      final negMean = arena<ffi.Double>()..value = -meanPtr.value;
      _vdspVsaddD(x.address, 1, negMean, diff.address, 1, n);
      _vdspSvesqD(diff.address, 1, sumSqPtr, n);

      final divisor = sample ? n - 1 : n;
      return sumSqPtr.value / divisor;
    });
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
      ]) {
        tryOpen(name);
      }
      // coverage:ignore-start
    } else if (Platform.isLinux || Platform.isAndroid) {
      for (final name in ['libopenblas.so.0', 'libopenblas.so']) {
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

@ffi.Native<ffi.Pointer<ffi.Void> Function(ffi.Int32, ffi.Int32)>(
  symbol: 'vDSP_create_fftsetupD',
  isLeaf: true,
)
external ffi.Pointer<ffi.Void> _vdspCreateFftSetupD(int log2n, int radix);

@ffi.Native<ffi.Void Function(ffi.Pointer<ffi.Void>)>(
  symbol: 'vDSP_destroy_fftsetupD',
  isLeaf: true,
)
external void _vdspDestroyFftSetupD(ffi.Pointer<ffi.Void> setup);

@ffi.Native<
  ffi.Void Function(
    ffi.Pointer<ffi.Void>,
    ffi.Pointer<DSPDoubleSplitComplex>,
    ffi.Int64,
    ffi.Int64,
    ffi.Int32,
  )
>(symbol: 'vDSP_fft_zipD', isLeaf: true)
external void _vdspFftZipD(
  ffi.Pointer<ffi.Void> setup,
  ffi.Pointer<DSPDoubleSplitComplex> c,
  int stride,
  int log2n,
  int direction,
);

@ffi.Native<
  ffi.Void Function(
    ffi.Pointer<ffi.Void>,
    ffi.Pointer<DSPDoubleSplitComplex>,
    ffi.Int64,
    ffi.Int64,
    ffi.Int64,
    ffi.Int64,
    ffi.Int32,
  )
>(symbol: 'vDSP_fft2d_zipD', isLeaf: true)
external void _vdspFft2dZipD(
  ffi.Pointer<ffi.Void> setup,
  ffi.Pointer<DSPDoubleSplitComplex> c,
  int rowStride,
  int colStride,
  int log2cols,
  int log2rows,
  int direction,
);

@ffi.Native<
  ffi.Void Function(
    ffi.Pointer<ffi.Double>,
    ffi.Int64,
    ffi.Pointer<ffi.Double>,
    ffi.Int64,
    ffi.Pointer<ffi.Double>,
    ffi.Int64,
    ffi.Uint64,
    ffi.Uint64,
  )
>(symbol: 'vDSP_convD', isLeaf: true)
external void _vdspConvD(
  ffi.Pointer<ffi.Double> signal,
  int strideSignal,
  ffi.Pointer<ffi.Double> filter,
  int strideFilter,
  ffi.Pointer<ffi.Double> result,
  int strideResult,
  int lenResult,
  int lenFilter,
);

@ffi.Native<
  ffi.Void Function(
    ffi.Pointer<ffi.Double>,
    ffi.Int64,
    ffi.Pointer<ffi.Double>,
    ffi.Uint64,
  )
>(symbol: 'vDSP_sveD', isLeaf: true)
external void _vdspSveD(
  ffi.Pointer<ffi.Double> x,
  int strideX,
  ffi.Pointer<ffi.Double> result,
  int n,
);

@ffi.Native<
  ffi.Void Function(
    ffi.Pointer<ffi.Double>,
    ffi.Int64,
    ffi.Pointer<ffi.Double>,
    ffi.Uint64,
  )
>(symbol: 'vDSP_meanvD', isLeaf: true)
external void _vdspMeanvD(
  ffi.Pointer<ffi.Double> x,
  int strideX,
  ffi.Pointer<ffi.Double> result,
  int n,
);

@ffi.Native<
  ffi.Void Function(
    ffi.Pointer<ffi.Double>,
    ffi.Int64,
    ffi.Pointer<ffi.Double>,
    ffi.Uint64,
  )
>(symbol: 'vDSP_measqvD', isLeaf: true)
external void _vdspMeasqvD(
  ffi.Pointer<ffi.Double> x,
  int strideX,
  ffi.Pointer<ffi.Double> result,
  int n,
);

@ffi.Native<
  ffi.Void Function(
    ffi.Pointer<ffi.Double>,
    ffi.Int64,
    ffi.Pointer<ffi.Double>,
    ffi.Pointer<ffi.Double>,
    ffi.Int64,
    ffi.Uint64,
  )
>(symbol: 'vDSP_vsaddD', isLeaf: true)
external void _vdspVsaddD(
  ffi.Pointer<ffi.Double> x,
  int strideX,
  ffi.Pointer<ffi.Double> scalar,
  ffi.Pointer<ffi.Double> result,
  int strideResult,
  int n,
);

@ffi.Native<
  ffi.Void Function(
    ffi.Pointer<ffi.Double>,
    ffi.Int64,
    ffi.Pointer<ffi.Double>,
    ffi.Uint64,
  )
>(symbol: 'vDSP_svesqD', isLeaf: true)
external void _vdspSvesqD(
  ffi.Pointer<ffi.Double> x,
  int strideX,
  ffi.Pointer<ffi.Double> result,
  int n,
);

@ffi.Native<
  ffi.Void Function(
    ffi.Pointer<ffi.Double>,
    ffi.Pointer<ffi.Double>,
    ffi.Pointer<ffi.Int32>,
  )
>(symbol: 'vvsin', isLeaf: true)
external void _vvsin(
  ffi.Pointer<ffi.Double> output,
  ffi.Pointer<ffi.Double> input,
  ffi.Pointer<ffi.Int32> n,
);

@ffi.Native<
  ffi.Void Function(
    ffi.Pointer<ffi.Double>,
    ffi.Pointer<ffi.Double>,
    ffi.Pointer<ffi.Int32>,
  )
>(symbol: 'vvcos', isLeaf: true)
external void _vvcos(
  ffi.Pointer<ffi.Double> output,
  ffi.Pointer<ffi.Double> input,
  ffi.Pointer<ffi.Int32> n,
);

@ffi.Native<
  ffi.Void Function(
    ffi.Pointer<ffi.Double>,
    ffi.Pointer<ffi.Double>,
    ffi.Pointer<ffi.Int32>,
  )
>(symbol: 'vvexp', isLeaf: true)
external void _vvexp(
  ffi.Pointer<ffi.Double> output,
  ffi.Pointer<ffi.Double> input,
  ffi.Pointer<ffi.Int32> n,
);

@ffi.Native<
  ffi.Void Function(
    ffi.Pointer<ffi.Double>,
    ffi.Pointer<ffi.Double>,
    ffi.Pointer<ffi.Int32>,
  )
>(symbol: 'vvlog', isLeaf: true)
external void _vvlog(
  ffi.Pointer<ffi.Double> output,
  ffi.Pointer<ffi.Double> input,
  ffi.Pointer<ffi.Int32> n,
);

@ffi.Native<
  ffi.Void Function(
    ffi.Pointer<ffi.Double>,
    ffi.Pointer<ffi.Double>,
    ffi.Pointer<ffi.Int32>,
  )
>(symbol: 'vvsqrt', isLeaf: true)
external void _vvsqrt(
  ffi.Pointer<ffi.Double> output,
  ffi.Pointer<ffi.Double> input,
  ffi.Pointer<ffi.Int32> n,
);

@ffi.Native<
  ffi.Void Function(
    ffi.Pointer<ffi.Double>,
    ffi.Pointer<ffi.Double>,
    ffi.Pointer<ffi.Double>,
    ffi.Pointer<ffi.Int32>,
  )
>(symbol: 'vvpow', isLeaf: true)
external void _vvpow(
  ffi.Pointer<ffi.Double> output,
  ffi.Pointer<ffi.Double> exponent,
  ffi.Pointer<ffi.Double> base,
  ffi.Pointer<ffi.Int32> n,
);
