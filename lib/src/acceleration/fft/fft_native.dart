// coverage:ignore-file
import 'dart:ffi' as ffi;
import 'dart:typed_data';

import '../../type/types/complex.dart';
import '../utils/library_loader_ffi.dart';

enum _FftBackend { none, vdsp, fftw }

const int _vDspDftForward = 1;
const int _vDspDftInverse = -1;
const int _vDspDftInterleavedComplextoComplex = 0;

const int _fftwForward = -1;
const int _fftwBackward = 1;
const int _fftwUnaligned = 1 << 1;
const int _fftwEstimate = 1 << 6;

/// Native FFT bindings via dart:ffi supporting Apple vDSP (macOS/iOS) and
/// FFTW3 (Linux/Android/Windows) using direct leaf typed data addresses.
abstract final class FftNative {
  static final List<ffi.DynamicLibrary> _libs = platformFftLibraries;

  static final bool _hasVdsp =
      hasSymbol('vDSP_DFT_Interleaved_CreateSetupD', _libs) &&
      hasSymbol('vDSP_DFT_Interleaved_ExecuteD', _libs);

  static final bool _hasFftw =
      hasSymbol('fftw_plan_dft_1d', _libs) &&
      hasSymbol('fftw_execute_dft', _libs) &&
      hasSymbol('fftw_destroy_plan', _libs);

  static final _FftBackend _backend = () {
    if (_hasVdsp) return _FftBackend.vdsp;
    if (_hasFftw) return _FftBackend.fftw;
    return _FftBackend.none;
  }();

  static const int _maxCacheSize = 64;

  static final Map<int, ffi.Pointer<ffi.Void>> _vdspFwdSetups = {};
  static final Map<int, ffi.Pointer<ffi.Void>> _vdspInvSetups = {};

  static final Map<int, ffi.Pointer<ffi.Void>> _fftw1dFwdPlans = {};
  static final Map<int, ffi.Pointer<ffi.Void>> _fftw1dInvPlans = {};
  static final Map<int, ffi.Pointer<ffi.Void>> _fftw2dFwdPlans = {};
  static final Map<int, ffi.Pointer<ffi.Void>> _fftw2dInvPlans = {};

  /// Whether native FFT is available.
  static bool get isAvailable => _backend != _FftBackend.none;

  /// Computes 1D in-place complex FFT on [buffer] with zero heap copying.
  static bool fft1d({
    required Float64ComplexList buffer,
    required int log2n,
    required bool inverse,
  }) => switch (_backend) {
    _FftBackend.vdsp => _fft1dVdsp(
      buffer: buffer,
      log2n: log2n,
      inverse: inverse,
    ),
    _FftBackend.fftw => _fft1dFftw(
      buffer: buffer,
      log2n: log2n,
      inverse: inverse,
    ),
    _FftBackend.none => false,
  };

  /// Computes 2D in-place complex FFT on flat row-major [buffer] with zero
  /// heap copying.
  static bool fft2d({
    required Float64ComplexList buffer,
    required int log2rows,
    required int log2cols,
    required bool inverse,
  }) => switch (_backend) {
    _FftBackend.vdsp => _fft2dVdsp(
      buffer: buffer,
      log2rows: log2rows,
      log2cols: log2cols,
      inverse: inverse,
    ),
    _FftBackend.fftw => _fft2dFftw(
      buffer: buffer,
      log2rows: log2rows,
      log2cols: log2cols,
      inverse: inverse,
    ),
    _FftBackend.none => false,
  };

  // --- vDSP Implementation (macOS / iOS) ---

  static ffi.Pointer<ffi.Void>? _getVdspSetup(int n, bool inverse) {
    if (!_hasVdsp) return null;
    final cache = inverse ? _vdspInvSetups : _vdspFwdSetups;
    final existing = cache[n];
    if (existing != null) return existing;
    if (cache.length >= _maxCacheSize) {
      final oldestKey = cache.keys.first;
      final evicted = cache.remove(oldestKey);
      if (evicted != null && evicted != ffi.nullptr) {
        _vdspDftDestroySetupD(evicted);
      }
    }
    final created = _vdspDftInterleavedCreateSetupD(
      ffi.nullptr,
      n,
      inverse ? _vDspDftInverse : _vDspDftForward,
      _vDspDftInterleavedComplextoComplex,
    );
    if (created != ffi.nullptr) {
      cache[n] = created;
    }
    return created;
  }

  static void _butterfly2or4(
    Float64List data,
    int offset,
    int n,
    bool inverse,
  ) {
    if (n == 2) {
      final r0 = data[offset];
      final i0 = data[offset + 1];
      final r1 = data[offset + 2];
      final i1 = data[offset + 3];
      data[offset] = r0 + r1;
      data[offset + 1] = i0 + i1;
      data[offset + 2] = r0 - r1;
      data[offset + 3] = i0 - i1;
    } else if (n == 4) {
      final r0 = data[offset];
      final i0 = data[offset + 1];
      final r1 = data[offset + 2];
      final i1 = data[offset + 3];
      final r2 = data[offset + 4];
      final i2 = data[offset + 5];
      final r3 = data[offset + 6];
      final i3 = data[offset + 7];
      final er0 = r0 + r2;
      final ei0 = i0 + i2;
      final er1 = r0 - r2;
      final ei1 = i0 - i2;
      final or0 = r1 + r3;
      final oi0 = i1 + i3;
      final or1 = r1 - r3;
      final oi1 = i1 - i3;
      final tr = inverse ? -oi1 : oi1;
      final ti = inverse ? or1 : -or1;
      data[offset] = er0 + or0;
      data[offset + 1] = ei0 + oi0;
      data[offset + 2] = er1 + tr;
      data[offset + 3] = ei1 + ti;
      data[offset + 4] = er0 - or0;
      data[offset + 5] = ei0 - oi0;
      data[offset + 6] = er1 - tr;
      data[offset + 7] = ei1 - ti;
    }
  }

  static bool _fft1dVdsp({
    required Float64ComplexList buffer,
    required int log2n,
    required bool inverse,
  }) {
    final n = 1 << log2n;
    if (buffer.length < n) return false;
    if (n <= 1) return true;

    final data = buffer.data;
    if (n == 2 || n == 4) {
      _butterfly2or4(data, 0, n, inverse);
    } else {
      final setup = _getVdspSetup(n, inverse);
      if (setup == null || setup == ffi.nullptr) {
        if (_hasFftw) {
          return _fft1dFftw(buffer: buffer, log2n: log2n, inverse: inverse);
        }
        return false;
      }

      if (data.offsetInBytes % 16 == 0) {
        _vdspDftInterleavedExecuteD(setup, data.address, data.address);
      } else {
        final totalFloats = 2 * n;
        final aligned = Float64List(totalFloats)
          ..setRange(0, totalFloats, data);
        _vdspDftInterleavedExecuteD(setup, aligned.address, aligned.address);
        data.setRange(0, totalFloats, aligned);
      }
    }

    if (inverse) {
      final factor = 1.0 / n;
      final totalFloats = 2 * n;
      for (var i = 0; i < totalFloats; i++) {
        data[i] *= factor;
      }
    }
    return true;
  }

  static bool _fft2dVdsp({
    required Float64ComplexList buffer,
    required int log2rows,
    required int log2cols,
    required bool inverse,
  }) {
    final rows = 1 << log2rows;
    final cols = 1 << log2cols;
    final total = rows * cols;
    if (buffer.length < total) return false;

    final setupCols = cols >= 8 ? _getVdspSetup(cols, inverse) : null;
    final setupRows = rows >= 8 ? _getVdspSetup(rows, inverse) : null;
    if ((cols >= 8 && (setupCols == null || setupCols == ffi.nullptr)) ||
        (rows >= 8 && (setupRows == null || setupRows == ffi.nullptr))) {
      if (_hasFftw) {
        return _fft2dFftw(
          buffer: buffer,
          log2rows: log2rows,
          log2cols: log2cols,
          inverse: inverse,
        );
      }
      return false;
    }

    final data = buffer.data;
    final rowStride = cols << 1;

    // 1. In-place 1D row transforms directly on contiguous row slices
    if (cols == 2 || cols == 4) {
      var rowOffset = 0;
      for (var r = 0; r < rows; r++, rowOffset += rowStride) {
        _butterfly2or4(data, rowOffset, cols, inverse);
      }
    } else if (cols >= 8 && setupCols != null) {
      if (data.offsetInBytes % 16 == 0) {
        var rowOffset = 0;
        for (var r = 0; r < rows; r++, rowOffset += rowStride) {
          final rowSlice = Float64List.sublistView(
            data,
            rowOffset,
            rowOffset + rowStride,
          );
          _vdspDftInterleavedExecuteD(
            setupCols,
            rowSlice.address,
            rowSlice.address,
          );
        }
      } else {
        final rowBuffer = Float64List(rowStride);
        var rowOffset = 0;
        for (var r = 0; r < rows; r++, rowOffset += rowStride) {
          rowBuffer.setRange(0, rowStride, data, rowOffset);
          _vdspDftInterleavedExecuteD(
            setupCols,
            rowBuffer.address,
            rowBuffer.address,
          );
          data.setRange(rowOffset, rowOffset + rowStride, rowBuffer);
        }
      }
    }

    // 2. In-place 1D column transforms with pointer stepping
    if (rows > 1) {
      final colBuffer = Float64List(rows << 1);
      for (var c = 0; c < cols; c++) {
        var srcIdx = c << 1;
        var colIdx = 0;
        for (var r = 0; r < rows; r++) {
          colBuffer[colIdx] = data[srcIdx];
          colBuffer[colIdx + 1] = data[srcIdx + 1];
          colIdx += 2;
          srcIdx += rowStride;
        }
        if (rows == 2 || rows == 4) {
          _butterfly2or4(colBuffer, 0, rows, inverse);
        } else if (setupRows != null) {
          _vdspDftInterleavedExecuteD(
            setupRows,
            colBuffer.address,
            colBuffer.address,
          );
        }
        var dstIdx = c << 1;
        colIdx = 0;
        for (var r = 0; r < rows; r++) {
          data[dstIdx] = colBuffer[colIdx];
          data[dstIdx + 1] = colBuffer[colIdx + 1];
          colIdx += 2;
          dstIdx += rowStride;
        }
      }
    }

    if (inverse) {
      final factor = 1.0 / total;
      final totalFloats = 2 * total;
      for (var i = 0; i < totalFloats; i++) {
        data[i] *= factor;
      }
    }
    return true;
  }

  // --- FFTW3 Implementation (Linux / Android / Windows) ---

  static ffi.Pointer<ffi.Void>? _getFftw1dPlan(int n, bool inverse) {
    if (!_hasFftw) return null;
    final cache = inverse ? _fftw1dInvPlans : _fftw1dFwdPlans;
    final existing = cache[n];
    if (existing != null) return existing;
    if (cache.length >= _maxCacheSize) {
      final oldestKey = cache.keys.first;
      final evicted = cache.remove(oldestKey);
      if (evicted != null && evicted != ffi.nullptr) {
        _fftwDestroyPlan(evicted);
      }
    }
    final created = _fftwPlanDft1d(
      n,
      ffi.nullptr,
      ffi.nullptr,
      inverse ? _fftwBackward : _fftwForward,
      _fftwEstimate | _fftwUnaligned,
    );
    if (created != ffi.nullptr) {
      cache[n] = created;
    }
    return created;
  }

  static ffi.Pointer<ffi.Void>? _getFftw2dPlan(
    int rows,
    int cols,
    bool inverse,
  ) {
    if (!_hasFftw) return null;
    final key = (rows << 32) | cols;
    final cache = inverse ? _fftw2dInvPlans : _fftw2dFwdPlans;
    final existing = cache[key];
    if (existing != null) return existing;
    if (cache.length >= _maxCacheSize) {
      final oldestKey = cache.keys.first;
      final evicted = cache.remove(oldestKey);
      if (evicted != null && evicted != ffi.nullptr) {
        _fftwDestroyPlan(evicted);
      }
    }
    final created = _fftwPlanDft2d(
      rows,
      cols,
      ffi.nullptr,
      ffi.nullptr,
      inverse ? _fftwBackward : _fftwForward,
      _fftwEstimate | _fftwUnaligned,
    );
    if (created != ffi.nullptr) {
      cache[key] = created;
    }
    return created;
  }

  static bool _fft1dFftw({
    required Float64ComplexList buffer,
    required int log2n,
    required bool inverse,
  }) {
    if (!_hasFftw) return false;
    final n = 1 << log2n;
    if (buffer.length < n) return false;
    if (n <= 1) return true;

    final plan = _getFftw1dPlan(n, inverse);
    if (plan == null || plan == ffi.nullptr) {
      return false;
    }

    final data = buffer.data;
    _fftwExecuteDft(plan, data.address, data.address);

    if (inverse) {
      final factor = 1.0 / n;
      final totalFloats = 2 * n;
      for (var i = 0; i < totalFloats; i++) {
        data[i] *= factor;
      }
    }
    return true;
  }

  static bool _fft2dFftw({
    required Float64ComplexList buffer,
    required int log2rows,
    required int log2cols,
    required bool inverse,
  }) {
    if (!_hasFftw) return false;
    final rows = 1 << log2rows;
    final cols = 1 << log2cols;
    final total = rows * cols;
    if (buffer.length < total) return false;
    if (total <= 1) return true;

    final plan = _getFftw2dPlan(rows, cols, inverse);
    if (plan == null || plan == ffi.nullptr) {
      return false;
    }

    final data = buffer.data;
    _fftwExecuteDft(plan, data.address, data.address);

    if (inverse) {
      final factor = 1.0 / total;
      final totalFloats = 2 * total;
      for (var i = 0; i < totalFloats; i++) {
        data[i] *= factor;
      }
    }
    return true;
  }
}

// --- FFI Function Bindings ---

@ffi.Native<ffi.Void Function(ffi.Pointer<ffi.Void>)>(
  symbol: 'vDSP_DFT_DestroySetupD',
  isLeaf: true,
)
external void _vdspDftDestroySetupD(ffi.Pointer<ffi.Void> setup);

@ffi.Native<
  ffi.Pointer<ffi.Void> Function(
    ffi.Pointer<ffi.Void>,
    ffi.Uint64,
    ffi.Int32,
    ffi.Uint32,
  )
>(symbol: 'vDSP_DFT_Interleaved_CreateSetupD', isLeaf: true)
external ffi.Pointer<ffi.Void> _vdspDftInterleavedCreateSetupD(
  ffi.Pointer<ffi.Void> previous,
  int length,
  int direction,
  int dataType,
);

@ffi.Native<
  ffi.Void Function(
    ffi.Pointer<ffi.Void>,
    ffi.Pointer<ffi.Double>,
    ffi.Pointer<ffi.Double>,
  )
>(symbol: 'vDSP_DFT_Interleaved_ExecuteD', isLeaf: true)
external void _vdspDftInterleavedExecuteD(
  ffi.Pointer<ffi.Void> setup,
  ffi.Pointer<ffi.Double> inReal,
  ffi.Pointer<ffi.Double> outReal,
);

@ffi.Native<
  ffi.Pointer<ffi.Void> Function(
    ffi.Int32,
    ffi.Pointer<ffi.Double>,
    ffi.Pointer<ffi.Double>,
    ffi.Int32,
    ffi.Uint32,
  )
>(symbol: 'fftw_plan_dft_1d', isLeaf: true)
external ffi.Pointer<ffi.Void> _fftwPlanDft1d(
  int n,
  ffi.Pointer<ffi.Double> inBuf,
  ffi.Pointer<ffi.Double> outBuf,
  int sign,
  int flags,
);

@ffi.Native<
  ffi.Pointer<ffi.Void> Function(
    ffi.Int32,
    ffi.Int32,
    ffi.Pointer<ffi.Double>,
    ffi.Pointer<ffi.Double>,
    ffi.Int32,
    ffi.Uint32,
  )
>(symbol: 'fftw_plan_dft_2d', isLeaf: true)
external ffi.Pointer<ffi.Void> _fftwPlanDft2d(
  int n0,
  int n1,
  ffi.Pointer<ffi.Double> inBuf,
  ffi.Pointer<ffi.Double> outBuf,
  int sign,
  int flags,
);

@ffi.Native<ffi.Void Function(ffi.Pointer<ffi.Void>)>(
  symbol: 'fftw_destroy_plan',
  isLeaf: true,
)
external void _fftwDestroyPlan(ffi.Pointer<ffi.Void> plan);

@ffi.Native<
  ffi.Void Function(
    ffi.Pointer<ffi.Void>,
    ffi.Pointer<ffi.Double>,
    ffi.Pointer<ffi.Double>,
  )
>(symbol: 'fftw_execute_dft', isLeaf: true)
external void _fftwExecuteDft(
  ffi.Pointer<ffi.Void> plan,
  ffi.Pointer<ffi.Double> inBuf,
  ffi.Pointer<ffi.Double> outBuf,
);
