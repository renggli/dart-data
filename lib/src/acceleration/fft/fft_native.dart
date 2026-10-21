// coverage:ignore-file
import 'dart:ffi' as ffi;
import 'dart:typed_data';

import '../../type/types/complex.dart';
import '../utils/library_loader_ffi.dart';
import 'fft_dart.dart';

enum _FftBackend { none, vdsp, fftw }

const int _vDspDftForward = 1;
const int _vDspDftInverse = 2;
const int _vDspDftInterleavedComplextoComplex = 0;

const int _fftwForward = -1;
const int _fftwBackward = 1;
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
      hasSymbol('fftw_execute_dft', _libs);

  static final _FftBackend _backend = () {
    if (_hasVdsp) return _FftBackend.vdsp;
    if (_hasFftw) return _FftBackend.fftw;
    return _FftBackend.none;
  }();

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
    return cache.putIfAbsent(
      n,
      () => _vdspDftInterleavedCreateSetupD(
        ffi.nullptr,
        n,
        inverse ? _vDspDftInverse : _vDspDftForward,
        _vDspDftInterleavedComplextoComplex,
      ),
    );
  }

  static bool _fft1dVdsp({
    required Float64ComplexList buffer,
    required int log2n,
    required bool inverse,
  }) {
    final n = 1 << log2n;
    if (buffer.length < n) return false;
    if (n < 8) {
      FftDart.fft(buffer: buffer, inverse: inverse);
      return true;
    }

    final setup = _getVdspSetup(n, inverse);
    if (setup == null || setup == ffi.nullptr) {
      if (_hasFftw) {
        return _fft1dFftw(buffer: buffer, log2n: log2n, inverse: inverse);
      }
      FftDart.fft(buffer: buffer, inverse: inverse);
      return true;
    }

    final data = buffer.data;
    _vdspDftInterleavedExecuteD(setup, data.address, data.address);

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

    if (rows < 8 || cols < 8 || rows > 4096 || cols > 4096) {
      if (_hasFftw) {
        return _fft2dFftw(
          buffer: buffer,
          log2rows: log2rows,
          log2cols: log2cols,
          inverse: inverse,
        );
      }
      FftDart.fft2(buffer: buffer, rows: rows, cols: cols, inverse: inverse);
      return true;
    }

    final setupCols = _getVdspSetup(cols, inverse);
    final setupRows = _getVdspSetup(rows, inverse);
    if (setupCols == null ||
        setupCols == ffi.nullptr ||
        setupRows == null ||
        setupRows == ffi.nullptr) {
      if (_hasFftw) {
        return _fft2dFftw(
          buffer: buffer,
          log2rows: log2rows,
          log2cols: log2cols,
          inverse: inverse,
        );
      }
      FftDart.fft2(buffer: buffer, rows: rows, cols: cols, inverse: inverse);
      return true;
    }

    final data = buffer.data;

    final rowStride = cols << 1;

    // 1. In-place 1D row transforms directly on contiguous row slices
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

    // 2. In-place 1D column transforms with pointer stepping
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
      _vdspDftInterleavedExecuteD(
        setupRows,
        colBuffer.address,
        colBuffer.address,
      );
      var dstIdx = c << 1;
      colIdx = 0;
      for (var r = 0; r < rows; r++) {
        data[dstIdx] = colBuffer[colIdx];
        data[dstIdx + 1] = colBuffer[colIdx + 1];
        colIdx += 2;
        dstIdx += rowStride;
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
    return cache.putIfAbsent(
      n,
      () => _fftwPlanDft1d(
        n,
        ffi.nullptr,
        ffi.nullptr,
        inverse ? _fftwBackward : _fftwForward,
        _fftwEstimate,
      ),
    );
  }

  static ffi.Pointer<ffi.Void>? _getFftw2dPlan(
    int rows,
    int cols,
    bool inverse,
  ) {
    if (!_hasFftw) return null;
    final key = (rows << 32) | cols;
    final cache = inverse ? _fftw2dInvPlans : _fftw2dFwdPlans;
    return cache.putIfAbsent(
      key,
      () => _fftwPlanDft2d(
        rows,
        cols,
        ffi.nullptr,
        ffi.nullptr,
        inverse ? _fftwBackward : _fftwForward,
        _fftwEstimate,
      ),
    );
  }

  static bool _fft1dFftw({
    required Float64ComplexList buffer,
    required int log2n,
    required bool inverse,
  }) {
    if (!_hasFftw) return false;
    final n = 1 << log2n;
    if (buffer.length < n) return false;

    final plan = _getFftw1dPlan(n, inverse);
    if (plan == null || plan == ffi.nullptr) {
      FftDart.fft(buffer: buffer, inverse: inverse);
      return true;
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

    final plan = _getFftw2dPlan(rows, cols, inverse);
    if (plan == null || plan == ffi.nullptr) {
      FftDart.fft2(buffer: buffer, rows: rows, cols: cols, inverse: inverse);
      return true;
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

@ffi.Native<
  ffi.Pointer<ffi.Void> Function(
    ffi.Pointer<ffi.Void>,
    ffi.Uint64,
    ffi.Uint32,
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
