import '../../type/types/complex.dart';
import '../utils/dispatcher.dart';
import 'fft_dart.dart';
import 'fft_stub.dart' if (dart.library.ffi) 'fft_native.dart';

/// Fast Fourier Transforms (FFT) for complex signals.
///
/// Automatically routes execution between native hardware libraries (Apple vDSP,
/// FFTW3 via FFI) and optimized pure Dart fallbacks according to acceleration
/// mode.
abstract final class Fft {
  /// Whether native FFT acceleration is available on the current platform.
  static bool get isAvailable => FftNative.isAvailable;

  /// Computes the discrete Fourier transform in-place on [buffer].
  static void fft({required Float64ComplexList buffer, bool inverse = false}) {
    final length = buffer.length;
    if (length <= 1) return;

    if ((length & (length - 1)) == 0) {
      final log2n = _log2(length);

      executeAcceleratedVoid(
        feature: 'FFT',
        operation: 'fft',
        isAvailable: isAvailable,
        accelerate: () =>
            FftNative.fft1d(buffer: buffer, log2n: log2n, inverse: inverse),
        fallback: () => FftDart.fft(buffer: buffer, inverse: inverse),
      );
    } else {
      executeAcceleratedVoid(
        feature: 'FFT',
        operation: 'fft',
        isAvailable: isAvailable,
        accelerate: () {
          FftDart.bluestein(
            buffer: buffer,
            inverse: inverse,
            innerFft: ({required buffer, bool inverse = false}) =>
                fft(buffer: buffer, inverse: inverse),
          );
          return true;
        },
        fallback: () => FftDart.fft(buffer: buffer, inverse: inverse),
      );
    }
  }

  /// Computes the 2D discrete Fourier transform in-place on flat row-major
  /// [buffer] of dimensions [rows] x [cols].
  static void fft2({
    required Float64ComplexList buffer,
    required int rows,
    required int cols,
    bool inverse = false,
  }) {
    if (rows <= 0 || cols <= 0) return;
    if (buffer.length != rows * cols) {
      throw ArgumentError.value(
        buffer.length,
        'buffer.length',
        'Buffer length must equal rows * cols ($rows * $cols = ${rows * cols})',
      );
    }

    if ((rows & (rows - 1)) == 0 && (cols & (cols - 1)) == 0) {
      final log2rows = _log2(rows);
      final log2cols = _log2(cols);

      executeAcceleratedVoid(
        feature: 'FFT',
        operation: 'fft2',
        isAvailable: isAvailable,
        accelerate: () => FftNative.fft2d(
          buffer: buffer,
          log2rows: log2rows,
          log2cols: log2cols,
          inverse: inverse,
        ),
        fallback: () => FftDart.fft2(
          buffer: buffer,
          rows: rows,
          cols: cols,
          inverse: inverse,
        ),
      );
      return;
    }

    final data = buffer.data;
    final rowStride = cols << 1;

    // 1. Row transforms using 1D Fft.fft
    final rowBuf = Float64ComplexList(cols);
    final rowData = rowBuf.data;
    for (var r = 0; r < rows; r++) {
      final rowOffset = r * rowStride;
      for (var c = 0; c < rowStride; c++) {
        rowData[c] = data[rowOffset + c];
      }
      fft(buffer: rowBuf, inverse: inverse);
      for (var c = 0; c < rowStride; c++) {
        data[rowOffset + c] = rowData[c];
      }
    }

    // 2. Column transforms using 1D Fft.fft
    final colBuf = Float64ComplexList(rows);
    final colData = colBuf.data;
    for (var c = 0; c < cols; c++) {
      var srcIdx = c << 1;
      var colIdx = 0;
      for (var r = 0; r < rows; r++) {
        colData[colIdx] = data[srcIdx];
        colData[colIdx + 1] = data[srcIdx + 1];
        colIdx += 2;
        srcIdx += rowStride;
      }
      fft(buffer: colBuf, inverse: inverse);
      var dstIdx = c << 1;
      colIdx = 0;
      for (var r = 0; r < rows; r++) {
        data[dstIdx] = colData[colIdx];
        data[dstIdx + 1] = colData[colIdx + 1];
        colIdx += 2;
        dstIdx += rowStride;
      }
    }
  }

  /// Returns the smallest power of 2 greater than or equal to [value].
  static int nextPowerOf2({required int value}) =>
      FftDart.nextPowerOf2(value: value);

  static int _log2(int value) {
    var v = value;
    var log = 0;
    while (v > 1) {
      v >>= 1;
      log++;
    }
    return log;
  }
}
