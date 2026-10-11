import 'dart:math' as math;

import 'package:more/number.dart' show Complex;

/// Computes the 1-dimensional Discrete Fourier Transform (FFT) of [input].
///
/// Conceptually, the Fast Fourier Transform acts like a prism:
/// it decomposes a signal measured over time into its constituent
/// sinusoidal frequencies and their corresponding amplitudes and phases.
/// Formally, it computes the discrete Fourier transform $X_k = \sum_{n=0}^{N-1} x_n e^{-2\pi i k n / N}$
/// using the Cooley-Tukey decimation-in-time radix-2 algorithm in $\mathcal{O}(N \log N)$ time.
/// Inputs are zero-padded to the next power of 2 if needed.
///
/// ```dart
/// final signal = [Complex(1.0, 0.0), Complex(1.0, 0.0), Complex(0.0, 0.0), Complex(0.0, 0.0)];
/// final spectrum = fft(signal);
/// ```
List<Complex> fft(Iterable<Complex> input) => _fft(input, inverse: false);

/// Computes the 1-dimensional Inverse Discrete Fourier Transform (IFFT) of [input].
///
/// Conceptually, this reverses the FFT, synthesizing the original time-domain
/// signal from its frequency spectrum.
/// Formally, it computes $x_n = \frac{1}{N} \sum_{k=0}^{N-1} X_k e^{2\pi i k n / N}$
/// satisfying $\text{ifft}(\text{fft}(x)) = x$.
///
/// ```dart
/// final signal = [Complex(1.0, 0.0), Complex(1.0, 0.0), Complex(0.0, 0.0), Complex(0.0, 0.0)];
/// final spectrum = fft(signal);
/// final reconstructed = ifft(spectrum);
/// ```
List<Complex> ifft(Iterable<Complex> input) => _fft(input, inverse: true);

List<Complex> _fft(Iterable<Complex> input, {required bool inverse}) {
  final list = input.toList();
  if (list.length <= 1) {
    return List<Complex>.of(list);
  }
  final length = _nextPowerOf2(list.length);
  final result = List<Complex>.filled(length, Complex.zero, growable: false);
  for (var i = 0; i < list.length; i++) {
    result[i] = list[i];
  }

  // Bit-reversal permutation
  for (var i = 1, j = 0; i < length; i++) {
    var bit = length >> 1;
    for (; j & bit != 0; bit >>= 1) {
      j ^= bit;
    }
    j ^= bit;
    if (i < j) {
      final temp = result[i];
      result[i] = result[j];
      result[j] = temp;
    }
  }

  // Cooley-Tukey decimation-in-time radix-2 FFT
  for (var len = 2; len <= length; len <<= 1) {
    final halfLen = len >> 1;
    final angle = (inverse ? 2.0 : -2.0) * math.pi / len;
    final wStep = Complex(math.cos(angle), math.sin(angle));
    for (var i = 0; i < length; i += len) {
      var omega = Complex.one;
      for (var j = 0; j < halfLen; j++) {
        final uVal = result[i + j];
        final vVal = result[i + j + halfLen] * omega;
        result[i + j] = uVal + vVal;
        result[i + j + halfLen] = uVal - vVal;
        omega *= wStep;
      }
    }
  }

  if (inverse) {
    final factor = 1.0 / length;
    for (var i = 0; i < length; i++) {
      result[i] = Complex(result[i].a * factor, result[i].b * factor);
    }
  }

  return result;
}

/// Computes the 1-dimensional Discrete Fourier Transform for real-valued [input].
///
/// For purely real-valued input signals (such as audio samples),
/// this computes the frequency spectrum without requiring prior conversion to complex numbers.
/// Formally, it exploits Hermitian conjugate symmetry $X_{N-k} = X_k^*$
/// for real sequences, returning only non-redundant frequencies of length $N/2 + 1$.
///
/// ```dart
/// final realSignal = [1.0, 2.0, 3.0, 4.0];
/// final spectrum = rfft(realSignal);
/// ```
List<Complex> rfft(Iterable<num> input) {
  if (input.isEmpty) return const [];
  final complexInput = [for (final x in input) Complex(x.toDouble(), 0.0)];
  final full = fft(complexInput);
  final fullLen = full.length;
  final half = (fullLen >> 1) + 1;
  return full.sublist(0, half);
}

/// Computes the Inverse Discrete Fourier Transform for real-valued signals from
/// positive frequency spectrum [input].
///
/// Conceptually, this reconstructs the original real-valued time-domain signal from its
/// one-sided frequency spectrum.
/// Formally, it synthesizes the full Hermitian symmetric spectrum and computes
/// the inverse DFT, discarding numerical imaginary roundoff artifacts.
///
/// If [n] is not provided, it defaults to $2 \times (\text{input.length} - 1)$.
///
/// ```dart
/// final realSignal = [1.0, 2.0, 3.0, 4.0];
/// final spectrum = rfft(realSignal);
/// final restored = irfft(spectrum, realSignal.length);
/// ```
List<double> irfft(List<Complex> input, [int? n]) {
  if (input.isEmpty) return const [];
  final targetLength = n ?? (2 * (input.length - 1));
  final fullLength = _nextPowerOf2(targetLength);
  final fullSpectrum = List<Complex>.filled(fullLength, Complex.zero);

  for (var i = 0; i < input.length && i < fullLength; i++) {
    fullSpectrum[i] = input[i];
  }
  // Hermite conjugate symmetry: X[fullLength - k] = X[k]^*
  for (var i = 1; i < input.length - 1 && i < (fullLength >> 1); i++) {
    final orig = input[i];
    fullSpectrum[fullLength - i] = Complex(orig.a, -orig.b);
  }

  final reconstructed = ifft(fullSpectrum);
  return [for (var i = 0; i < targetLength; i++) reconstructed[i].a.toDouble()];
}

/// Computes the 2-dimensional Discrete Fourier Transform of [matrix].
///
/// Conceptually, 2D FFT analyzes 2D grids (such as images or spatial fields) to identify
/// directional wave patterns, textures, and spatial frequencies.
/// Formally, it computes the separable 2D DFT by transforming rows then columns
/// in $\mathcal{O}(M N \log(M N))$ time.
///
/// ```dart
/// final image = [
///   [Complex(1.0, 0.0), Complex(2.0, 0.0)],
///   [Complex(3.0, 0.0), Complex(4.0, 0.0)],
/// ];
/// final spectrum2d = fft2(image);
/// ```
List<List<Complex>> fft2(List<List<Complex>> matrix) =>
    _fft2(matrix, inverse: false);

/// Computes the 2-dimensional Inverse Discrete Fourier Transform of [matrix].
///
/// Conceptually, this reconstructs a 2D spatial grid or image from its 2D frequency spectrum.
/// Formally, it applies the 2D inverse DFT satisfying $\text{ifft2}(\text{fft2}(A)) = A$.
///
/// ```dart
/// final image = [
///   [Complex(1.0, 0.0), Complex(2.0, 0.0)],
///   [Complex(3.0, 0.0), Complex(4.0, 0.0)],
/// ];
/// final restored = ifft2(fft2(image));
/// ```
List<List<Complex>> ifft2(List<List<Complex>> matrix) =>
    _fft2(matrix, inverse: true);

List<List<Complex>> _fft2(List<List<Complex>> matrix, {required bool inverse}) {
  if (matrix.isEmpty || matrix[0].isEmpty) return const [];
  final rowCount = matrix.length;
  final colCount = matrix[0].length;
  final targetRows = _nextPowerOf2(rowCount);
  final targetCols = _nextPowerOf2(colCount);

  // 1. Transform each row (with targetCols padding)
  final rowTransformed = <List<Complex>>[];
  for (var row = 0; row < rowCount; row++) {
    rowTransformed.add(_fft(matrix[row], inverse: inverse));
  }
  final zeroRow = List<Complex>.filled(targetCols, Complex.zero);
  while (rowTransformed.length < targetRows) {
    rowTransformed.add(List<Complex>.of(zeroRow));
  }

  // 2. Transform each column
  final result = List.generate(
    targetRows,
    (_) => List<Complex>.filled(targetCols, Complex.zero),
  );

  for (var col = 0; col < targetCols; col++) {
    final colVals = [
      for (var row = 0; row < targetRows; row++) rowTransformed[row][col],
    ];
    final colTransformed = _fft(colVals, inverse: inverse);
    for (var row = 0; row < targetRows; row++) {
      result[row][col] = colTransformed[row];
    }
  }

  return result;
}

int _nextPowerOf2(int value) {
  if (value <= 1) return 1;
  var power = value - 1;
  power |= power >> 1;
  power |= power >> 2;
  power |= power >> 4;
  power |= power >> 8;
  power |= power >> 16;
  power |= power >> 32;
  return power + 1;
}
