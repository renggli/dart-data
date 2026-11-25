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

    executeAcceleratedVoid(
      feature: 'FFT',
      operation: 'fft',
      isAvailable: isAvailable,
      accelerate: () {
        if (FftNative.fft1d(buffer: buffer, length: length, inverse: inverse)) {
          return true;
        }
        if ((length & (length - 1)) != 0) {
          FftDart.bluestein(buffer: buffer, inverse: inverse, innerFft: fft);
          return true;
        }
        return false;
      },
      fallback: () => FftDart.fft(buffer: buffer, inverse: inverse),
    );
  }

  /// Computes the 2D discrete Fourier transform in-place on flat row-major
  /// [buffer] of dimensions [rows] x [cols].
  ///
  /// Throws [ArgumentError] if [rows] or [cols] is negative, or if
  /// `buffer.length != rows * cols`.
  static void fft2({
    required Float64ComplexList buffer,
    required int rows,
    required int cols,
    bool inverse = false,
  }) {
    if (rows < 0) {
      throw ArgumentError.value(rows, 'rows', 'Rows must be non-negative');
    }
    if (cols < 0) {
      throw ArgumentError.value(cols, 'cols', 'Cols must be non-negative');
    }
    if (buffer.length != rows * cols) {
      throw ArgumentError.value(
        buffer.length,
        'buffer.length',
        'Buffer length must equal rows * cols ($rows * $cols = ${rows * cols})',
      );
    }
    if (rows == 0 || cols == 0) return;

    executeAcceleratedVoid(
      feature: 'FFT',
      operation: 'fft2',
      isAvailable: isAvailable,
      accelerate: () {
        if (FftNative.fft2d(
          buffer: buffer,
          rows: rows,
          cols: cols,
          inverse: inverse,
        )) {
          return true;
        }
        FftDart.fft2Separable(
          buffer: buffer,
          rows: rows,
          cols: cols,
          inverse: inverse,
          innerFft: fft,
        );
        return true;
      },
      fallback: () => FftDart.fft2(
        buffer: buffer,
        rows: rows,
        cols: cols,
        inverse: inverse,
      ),
    );
  }

  /// Returns the smallest power of 2 greater than or equal to [value].
  static int nextPowerOf2({required int value}) =>
      FftDart.nextPowerOf2(value: value);
}
