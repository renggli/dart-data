// coverage:ignore-file
import 'dart:ffi' as ffi;
import 'dart:typed_data';

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

  static final Int32List _nBuf = Int32List(1);
  static final Float64List _scalarBuf = Float64List(1);
  static final Float64List _outBuf = Float64List(1);

  /// Whether native vForce or vDSP vector acceleration is available.
  static bool get isAvailable =>
      _libs.isNotEmpty && (hasVForce || hasReductions || hasConvolution);

  /// Whether all native vForce transcendentals are available.
  static bool get hasVForce =>
      _hasVvsin &&
      _hasVvcos &&
      _hasVvexp &&
      _hasVvlog &&
      _hasVvsqrt &&
      _hasVvpow;

  /// Whether native vector reductions are available.
  static bool get hasReductions =>
      _hasSveD && _hasMeanvD && _hasVsaddD && _hasSvesqD;

  /// Whether native convolution / cross-correlation is available.
  static bool get hasConvolution => _hasConvD;

  static bool vsin({
    required Float64List input,
    required Float64List output,
    required int n,
  }) {
    if (!_hasVvsin || n <= 0 || input.length < n || output.length < n) {
      return false;
    }
    _nBuf[0] = n;
    _vvsin(output.address, input.address, _nBuf.address);
    return true;
  }

  static bool vcos({
    required Float64List input,
    required Float64List output,
    required int n,
  }) {
    if (!_hasVvcos || n <= 0 || input.length < n || output.length < n) {
      return false;
    }
    _nBuf[0] = n;
    _vvcos(output.address, input.address, _nBuf.address);
    return true;
  }

  static bool vexp({
    required Float64List input,
    required Float64List output,
    required int n,
  }) {
    if (!_hasVvexp || n <= 0 || input.length < n || output.length < n) {
      return false;
    }
    _nBuf[0] = n;
    _vvexp(output.address, input.address, _nBuf.address);
    return true;
  }

  static bool vlog({
    required Float64List input,
    required Float64List output,
    required int n,
  }) {
    if (!_hasVvlog || n <= 0 || input.length < n || output.length < n) {
      return false;
    }
    _nBuf[0] = n;
    _vvlog(output.address, input.address, _nBuf.address);
    return true;
  }

  static bool vsqrt({
    required Float64List input,
    required Float64List output,
    required int n,
  }) {
    if (!_hasVvsqrt || n <= 0 || input.length < n || output.length < n) {
      return false;
    }
    _nBuf[0] = n;
    _vvsqrt(output.address, input.address, _nBuf.address);
    return true;
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
    _nBuf[0] = n;
    _vvpow(output.address, exponent.address, base.address, _nBuf.address);
    return true;
  }

  static double? sum({required Float64List x, required int n}) {
    if (!_hasSveD || n <= 0 || x.length < n) return null;
    _vdspSveD(x.address, 1, _outBuf.address, n);
    return _outBuf[0];
  }

  static double? mean({required Float64List x, required int n}) {
    if (!_hasMeanvD || n <= 0 || x.length < n) return null;
    _vdspMeanvD(x.address, 1, _outBuf.address, n);
    final res = _outBuf[0];
    if (res.isFinite) return res;
    for (var i = 0; i < n; i++) {
      if (!x[i].isFinite) return res;
    }
    var welfordMean = 0.0;
    for (var i = 0; i < n; i++) {
      welfordMean += (x[i] - welfordMean) / (i + 1);
    }
    return welfordMean;
  }

  static double? variance({
    required Float64List x,
    required int n,
    required bool sample,
  }) {
    final minCount = sample ? 2 : 1;
    if (!hasReductions || n < minCount || x.length < n) {
      return null;
    }

    final avg = mean(x: x, n: n)!;
    if (!avg.isFinite) return double.nan;

    final diff = Float64List(n);
    _scalarBuf[0] = -avg;
    _vdspVsaddD(x.address, 1, _scalarBuf.address, diff.address, 1, n);
    _vdspSvesqD(diff.address, 1, _outBuf.address, n);

    final sumSq = _outBuf[0];
    final divisor = sample ? n - 1 : n;
    if (sumSq.isFinite) {
      return sumSq / divisor;
    }
    var maxDiff = 0.0;
    for (var i = 0; i < n; i++) {
      final ad = diff[i].abs();
      if (!ad.isFinite) return double.nan;
      if (ad > maxDiff) maxDiff = ad;
    }
    if (maxDiff == 0.0) return 0.0;
    var scaledSumSq = 0.0;
    for (var i = 0; i < n; i++) {
      final d = diff[i] / maxDiff;
      scaledSumSq += d * d;
    }
    return maxDiff * maxDiff * (scaledSumSq / divisor);
  }

  static bool convolve({
    required Float64List signal,
    required Float64List filter,
    required Float64List output,
  }) {
    if (!_hasConvD) return false;

    final signalLen = signal.length;
    final filterLen = filter.length;
    if (signalLen == 0 || filterLen == 0) return false;
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
    if (signalLen == 0 || filterLen == 0) return false;
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
