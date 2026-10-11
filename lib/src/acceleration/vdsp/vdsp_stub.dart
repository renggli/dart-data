import 'dart:typed_data';

/// Loads the platform vDSP / vForce library stub for platforms without FFI.
VdspLibrary loadVdsp() => const VdspLibrary._();

/// Stub implementation of vDSP / vForce library when FFI is unavailable (e.g.
/// Web).
class VdspLibrary {
  const new _();

  /// Whether native vDSP / vForce acceleration is available.
  bool get isAvailable => false;

  /// Whether native FFT is available.
  bool get hasFft => false;

  /// Whether native vForce transcendentals are available.
  bool get hasVForce => false;

  /// Whether native vector reductions are available.
  bool get hasReductions => false;

  /// Computes 1D in-place complex FFT on [real] and [imag] buffers of size
  /// $2^{\text{log2n}}$.
  bool fft1d({
    required Float64List real,
    required Float64List imag,
    required int log2n,
    required bool inverse,
  }) => false;

  /// Computes 2D in-place complex FFT on row-major [real] and [imag] buffers.
  bool fft2d({
    required Float64List real,
    required Float64List imag,
    required int log2rows,
    required int log2cols,
    required bool inverse,
  }) => false;

  /// Computes 1D linear convolution of [signal] and [filter].
  bool conv1d({
    required Float64List signal,
    required Float64List filter,
    required Float64List result,
  }) => false;

  /// Computes elementwise sine: `output[i] = sin(input[i])`.
  bool vvsin({
    required Float64List input,
    required Float64List output,
    required int n,
  }) => false;

  /// Computes elementwise cosine: `output[i] = cos(input[i])`.
  bool vvcos({
    required Float64List input,
    required Float64List output,
    required int n,
  }) => false;

  /// Computes elementwise exponential: `output[i] = exp(input[i])`.
  bool vvexp({
    required Float64List input,
    required Float64List output,
    required int n,
  }) => false;

  /// Computes elementwise natural logarithm: `output[i] = ln(input[i])`.
  bool vvlog({
    required Float64List input,
    required Float64List output,
    required int n,
  }) => false;

  /// Computes elementwise square root: `output[i] = sqrt(input[i])`.
  bool vvsqrt({
    required Float64List input,
    required Float64List output,
    required int n,
  }) => false;

  /// Computes elementwise power: `output[i] = pow(base[i], exponent[i])`.
  bool vvpow({
    required Float64List base,
    required Float64List exponent,
    required Float64List output,
    required int n,
  }) => false;

  /// Computes sum of elements in [x].
  double? sve({required Float64List x, required int n}) => null;

  /// Computes arithmetic mean of elements in [x].
  double? meanv({required Float64List x, required int n}) => null;

  /// Computes mean of squared elements in [x].
  double? measqv({required Float64List x, required int n}) => null;
}
