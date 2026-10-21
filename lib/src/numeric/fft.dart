import 'dart:typed_data';

import 'package:more/number.dart' show Complex;

import '../acceleration/fft/fft.dart' as acc;
import '../acceleration/vforce/vforce.dart';
import '../type/types/complex.dart';

/// Computes the 1-dimensional Discrete Fourier Transform (FFT) in-place on
/// [buffer].
///
/// Conceptually, the Fast Fourier Transform acts like a prism: it decomposes a
/// signal measured over time into its constituent sinusoidal frequencies and
/// their corresponding amplitudes and phases. Formally, it computes the
/// discrete Fourier transform $X_k = \sum_{n=0}^{N-1} x_n e^{-2\pi i k n / N}$
/// using the Cooley-Tukey decimation-in-time radix-2 algorithm in
/// $\mathcal{O}(N \log N)$ time, with native hardware acceleration when
/// available.
///
/// If [buffer] is a [Float64ComplexList], the transform executes directly
/// in-place on its internal interleaved storage array with zero memory
/// allocations or copies.
///
/// If [buffer] is a `List<Complex>`, the transform operates in-place,
/// replacing elements with their transformed complex values.
///
/// The length of [buffer] must be a power of 2.
///
/// ```dart
/// final buffer = Float64ComplexList.fromList([
///   const Complex(1.0, 0.0),
///   const Complex(1.0, 0.0),
///   const Complex(0.0, 0.0),
///   const Complex(0.0, 0.0),
/// ]);
/// fft(buffer);
/// fft(buffer, inverse: true);
/// ```
void fft(List<Complex> buffer, {bool inverse = false}) {
  if (buffer is Float64ComplexList) {
    acc.Fft.fft(buffer: buffer, inverse: inverse);
    return;
  }

  final length = buffer.length;
  if (length <= 1) return;
  if ((length & (length - 1)) != 0) {
    throw ArgumentError.value(
      length,
      'buffer.length',
      'Length must be a power of 2',
    );
  }

  final temp = Float64ComplexList(length);
  final data = temp.data;
  for (var i = 0; i < length; i++) {
    final c = buffer[i];
    data[2 * i] = c.a.toDouble();
    data[2 * i + 1] = c.b.toDouble();
  }
  acc.Fft.fft(buffer: temp, inverse: inverse);
  for (var i = 0; i < length; i++) {
    buffer[i] = Complex(data[2 * i], data[2 * i + 1]);
  }
}

/// Computes the 2-dimensional Discrete Fourier Transform in-place on flat
/// row-major [flat] buffer of dimensions [rows] x [cols].
///
/// Conceptually, 2D FFT analyzes 2D grids (such as images or spatial fields) to
/// identify directional wave patterns, textures, and spatial frequencies.
/// Formally, it computes the separable 2D DFT by transforming rows then columns
/// in $\mathcal{O}(M N \log(M N))$ time with hardware acceleration when
/// available.
///
/// If [flat] is a [Float64ComplexList], the transform executes directly
/// in-place on its internal interleaved storage array with zero memory
/// allocations or copies.
///
/// The dimensions [rows] and [cols] must each be a power of 2, and the length
/// of [flat] must equal `rows * cols`.
///
/// ```dart
/// final image = Float64ComplexList.fromList([
///   const Complex(1.0, 0.0), const Complex(2.0, 0.0),
///   const Complex(3.0, 0.0), const Complex(4.0, 0.0),
/// ]);
/// fft2(image, rows: 2, cols: 2);
/// fft2(image, rows: 2, cols: 2, inverse: true);
/// ```
void fft2(
  List<Complex> flat, {
  required int rows,
  required int cols,
  bool inverse = false,
}) {
  if (flat is Float64ComplexList) {
    acc.Fft.fft2(buffer: flat, rows: rows, cols: cols, inverse: inverse);
    return;
  }

  if (rows <= 0 || cols <= 0) return;
  if ((rows & (rows - 1)) != 0) {
    throw ArgumentError.value(rows, 'rows', 'Rows must be a power of 2');
  }
  if ((cols & (cols - 1)) != 0) {
    throw ArgumentError.value(cols, 'cols', 'Cols must be a power of 2');
  }
  final total = rows * cols;
  if (flat.length != total) {
    throw ArgumentError.value(
      flat.length,
      'flat.length',
      'Buffer length must equal rows * cols ($rows * $cols = $total)',
    );
  }

  final temp = Float64ComplexList(total);
  final data = temp.data;
  for (var i = 0; i < total; i++) {
    final c = flat[i];
    data[2 * i] = c.a.toDouble();
    data[2 * i + 1] = c.b.toDouble();
  }
  acc.Fft.fft2(buffer: temp, rows: rows, cols: cols, inverse: inverse);
  for (var i = 0; i < total; i++) {
    flat[i] = Complex(data[2 * i], data[2 * i + 1]);
  }
}

/// Computes the 1-dimensional discrete linear convolution of [signal] and
/// [filter].
///
/// Conceptually, convolution filters or transforms an input signal by sliding
/// a filter kernel across it and computing weighted sums. Formally, it computes
/// $c_n = \sum_{p=0}^{P-1} s_{n+p} f_{P-1-p}$ for valid overlap length
/// $N = \text{signal.length} - \text{filter.length} + 1$.
///
/// ```dart
/// final signal = [1.0, 2.0, 3.0, 4.0];
/// final filter = [0.5, 0.5];
/// final smoothed = convolve(signal, filter);
/// ```
List<double> convolve(Iterable<num> signal, Iterable<num> filter) {
  final s = Float64List.fromList([for (final x in signal) x.toDouble()]);
  final f = Float64List.fromList([for (final x in filter) x.toDouble()]);
  return Vforce.convolve(signal: s, filter: f);
}

/// Computes the 1-dimensional discrete cross-correlation of [signal] and
/// [filter].
///
/// Conceptually, cross-correlation measures the similarity of two waveforms as
/// a function of the displacement of one relative to the other. Formally, it
/// computes $r_n = \sum_{p=0}^{P-1} s_{n+p} f_p$ for valid overlap length
/// $N = \text{signal.length} - \text{filter.length} + 1$.
///
/// ```dart
/// final signal = [1.0, 2.0, 3.0, 4.0];
/// final pattern = [2.0, 3.0];
/// final match = correlate(signal, pattern);
/// ```
List<double> correlate(Iterable<num> signal, Iterable<num> filter) {
  final s = Float64List.fromList([for (final x in signal) x.toDouble()]);
  final f = Float64List.fromList([for (final x in filter) x.toDouble()]);
  return Vforce.correlate(signal: s, filter: f);
}
