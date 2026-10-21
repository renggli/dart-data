// coverage:ignore-file
import 'dart:ffi' as ffi;
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import '../utils/library_loader_ffi.dart';

/// Native Apple vForce / vDSP bindings via dart:ffi.
abstract final class VforceNative {
  static final List<ffi.DynamicLibrary> _libs = platformVdspLibraries;

  static final bool _hasVvsin = hasSymbol('vvsin', _libs);
  static final bool _hasVvcos = hasSymbol('vvcos', _libs);
  static final bool _hasVvexp = hasSymbol('vvexp', _libs);
  static final bool _hasVvlog = hasSymbol('vvlog', _libs);
  static final bool _hasVvsqrt = hasSymbol('vvsqrt', _libs);
  static final bool _hasVvpow = hasSymbol('vvpow', _libs);

  static final bool _hasConvD = hasSymbol('vDSP_convD', _libs);
  static final bool _hasSveD = hasSymbol('vDSP_sveD', _libs);
  static final bool _hasMeanvD = hasSymbol('vDSP_meanvD', _libs);
  static final bool _hasVsaddD = hasSymbol('vDSP_vsaddD', _libs);
  static final bool _hasSvesqD = hasSymbol('vDSP_svesqD', _libs);

  /// Whether native vForce or vDSP vector acceleration is available.
  static bool get isAvailable => _libs.isNotEmpty && (_hasVvsin || _hasConvD);

  /// Whether native vForce transcendentals are available.
  static bool get hasVForce => _hasVvsin;

  /// Whether native vector reductions are available.
  static bool get hasReductions =>
      _hasSveD && _hasMeanvD && _hasVsaddD && _hasSvesqD;

  static bool vsin({
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

  static bool vcos({
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

  static bool vexp({
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

  static bool vlog({
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

  static bool vsqrt({
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

  static bool vpow({
    required Float64List base,
    required Float64List exponent,
    required Float64List output,
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

  static double? sum({required Float64List x, required int n}) {
    if (!_hasSveD || n <= 0 || x.length < n) return null;
    return using((arena) {
      final outPtr = arena<ffi.Double>();
      _vdspSveD(x.address, 1, outPtr, n);
      return outPtr.value;
    });
  }

  static double? mean({required Float64List x, required int n}) {
    if (!_hasMeanvD || n <= 0 || x.length < n) return null;
    return using((arena) {
      final outPtr = arena<ffi.Double>();
      _vdspMeanvD(x.address, 1, outPtr, n);
      return outPtr.value;
    });
  }

  static double? variance({
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

  static bool convolve({
    required Float64List signal,
    required Float64List filter,
    required Float64List output,
  }) {
    if (!_hasConvD) return false;

    final signalLen = signal.length;
    final filterLen = filter.length;
    final resultLen = signalLen - filterLen + 1;
    if (resultLen <= 0 || output.length < resultLen) return false;

    final filterEndView = Float64List.sublistView(filter, filterLen - 1);
    _vdspConvD(
      signal.address,
      1,
      filterEndView.address,
      -1,
      output.address,
      1,
      resultLen,
      filterLen,
    );
    return true;
  }

  static bool correlate({
    required Float64List signal,
    required Float64List filter,
    required Float64List output,
  }) {
    if (!_hasConvD) return false;

    final signalLen = signal.length;
    final filterLen = filter.length;
    final resultLen = signalLen - filterLen + 1;
    if (resultLen <= 0 || output.length < resultLen) return false;

    _vdspConvD(
      signal.address,
      1,
      filter.address,
      1,
      output.address,
      1,
      resultLen,
      filterLen,
    );
    return true;
  }
}

// --- Native vDSP FFI Declarations ---

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
