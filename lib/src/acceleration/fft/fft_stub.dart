// coverage:ignore-file
import '../../type/types/complex.dart';

/// Platform FFT library stub when FFI is unavailable.
abstract final class FftNative {
  /// Whether native FFT is available.
  static bool get isAvailable => false;

  /// Computes 1D in-place complex FFT on [buffer] of size $2^{\text{log2n}}$.
  static bool fft1d({
    required Float64ComplexList buffer,
    required int log2n,
    required bool inverse,
  }) => false;

  /// Computes 2D in-place complex FFT on flat row-major [buffer].
  static bool fft2d({
    required Float64ComplexList buffer,
    required int log2rows,
    required int log2cols,
    required bool inverse,
  }) => false;
}
