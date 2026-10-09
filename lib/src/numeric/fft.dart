import 'dart:math' as math;

import 'package:more/number.dart' show Complex;

/// Computes the 1-dimensional Discrete Fourier Transform (FFT) of [input].
///
/// This implementation is pure and non-mutating. If the length of [input] is
/// not a power of 2, it is zero-padded to the next power of 2.
List<Complex> fft(Iterable<Complex> input, {bool inverse = false}) {
  final list = input.toList();
  if (list.length <= 1) {
    return List<Complex>.of(list);
  }
  final n = _nextPowerOf2(list.length);
  final result = List<Complex>.filled(n, Complex.zero, growable: false);
  for (var i = 0; i < list.length; i++) {
    result[i] = list[i];
  }

  // Bit-reversal permutation
  for (var i = 1, j = 0; i < n; i++) {
    var bit = n >> 1;
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
  for (var len = 2; len <= n; len <<= 1) {
    final halfLen = len >> 1;
    final angle = (inverse ? 2.0 : -2.0) * math.pi / len;
    final wStep = Complex(math.cos(angle), math.sin(angle));
    for (var i = 0; i < n; i += len) {
      var w = Complex.one;
      for (var j = 0; j < halfLen; j++) {
        final u = result[i + j];
        final v = result[i + j + halfLen] * w;
        result[i + j] = u + v;
        result[i + j + halfLen] = u - v;
        w *= wStep;
      }
    }
  }

  if (inverse) {
    final factor = 1.0 / n;
    for (var i = 0; i < n; i++) {
      result[i] = Complex(result[i].a * factor, result[i].b * factor);
    }
  }

  return result;
}

/// Computes the 1-dimensional Inverse Discrete Fourier Transform (IFFT).
List<Complex> ifft(Iterable<Complex> input) => fft(input, inverse: true);

/// Computes the 1-dimensional Discrete Fourier Transform for real-valued [input].
///
/// Returns the non-redundant positive frequency components of length $N/2 + 1$.
List<Complex> rfft(Iterable<num> input) {
  if (input.isEmpty) return const [];
  final complexInput = [for (final x in input) Complex(x.toDouble(), 0.0)];
  final full = fft(complexInput);
  final n = full.length;
  final half = (n >> 1) + 1;
  return full.sublist(0, half);
}

/// Computes the Inverse Discrete Fourier Transform for real-valued signals from
/// positive frequency spectrum [input].
///
/// If [n] is not provided, it defaults to $2 \times (\text{input.length} - 1)$.
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
/// Transforms rows first, then columns. Non-mutating.
List<List<Complex>> fft2(List<List<Complex>> matrix, {bool inverse = false}) {
  if (matrix.isEmpty || matrix[0].isEmpty) return const [];
  final rowCount = matrix.length;
  final colCount = matrix[0].length;
  final targetRows = _nextPowerOf2(rowCount);
  final targetCols = _nextPowerOf2(colCount);

  // 1. Transform each row (with targetCols padding)
  final rowTransformed = <List<Complex>>[];
  for (var r = 0; r < rowCount; r++) {
    rowTransformed.add(fft(matrix[r], inverse: inverse));
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

  for (var c = 0; c < targetCols; c++) {
    final colVals = [for (var r = 0; r < targetRows; r++) rowTransformed[r][c]];
    final colTransformed = fft(colVals, inverse: inverse);
    for (var r = 0; r < targetRows; r++) {
      result[r][c] = colTransformed[r];
    }
  }

  return result;
}

/// Computes the 2-dimensional Inverse Discrete Fourier Transform of [matrix].
List<List<Complex>> ifft2(List<List<Complex>> matrix) =>
    fft2(matrix, inverse: true);

int _nextPowerOf2(int v) {
  if (v <= 1) return 1;
  var n = v - 1;
  n |= n >> 1;
  n |= n >> 2;
  n |= n >> 4;
  n |= n >> 8;
  n |= n >> 16;
  n |= n >> 32;
  return n + 1;
}
