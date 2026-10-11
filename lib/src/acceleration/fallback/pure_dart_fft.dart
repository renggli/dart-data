import 'dart:math' as math;
import 'dart:typed_data';

import 'package:more/number.dart' show Complex;

/// Pure Dart reference implementations of Fast Fourier Transforms and
/// vectorized math.
abstract final class PureDartFft {
  /// Computes the 1D discrete Fourier transform or inverse transform.
  static List<Complex> fft(Iterable<Complex> input, {required bool inverse}) {
    final list = input.toList();
    if (list.length <= 1) {
      return List<Complex>.of(list);
    }
    final length = nextPowerOf2(list.length);
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

  /// Computes 1D real FFT.
  static List<Complex> rfft(Iterable<num> input) {
    if (input.isEmpty) return const [];
    final complexInput = [for (final x in input) Complex(x.toDouble(), 0.0)];
    final full = fft(complexInput, inverse: false);
    final fullLen = full.length;
    final half = (fullLen >> 1) + 1;
    return full.sublist(0, half);
  }

  /// Computes inverse 1D real FFT.
  static List<double> irfft(List<Complex> input, [int? n]) {
    if (input.isEmpty) return const [];
    final targetLength = n ?? (2 * (input.length - 1));
    final fullLength = nextPowerOf2(targetLength);
    final fullSpectrum = List<Complex>.filled(fullLength, Complex.zero);

    for (var i = 0; i < input.length && i < fullLength; i++) {
      fullSpectrum[i] = input[i];
    }
    // Hermite conjugate symmetry: X[fullLength - k] = X[k]^*
    for (var i = 1; i < input.length - 1 && i < (fullLength >> 1); i++) {
      final orig = input[i];
      fullSpectrum[fullLength - i] = Complex(orig.a, -orig.b);
    }

    final reconstructed = fft(fullSpectrum, inverse: true);
    return [
      for (var i = 0; i < targetLength; i++) reconstructed[i].a.toDouble(),
    ];
  }

  /// Computes 2D FFT.
  static List<List<Complex>> fft2(
    List<List<Complex>> matrix, {
    required bool inverse,
  }) {
    if (matrix.isEmpty || matrix[0].isEmpty) return const [];
    final rowCount = matrix.length;
    final colCount = matrix[0].length;
    final targetRows = nextPowerOf2(rowCount);
    final targetCols = nextPowerOf2(colCount);

    final rowTransformed = <List<Complex>>[];
    for (var row = 0; row < rowCount; row++) {
      rowTransformed.add(fft(matrix[row], inverse: inverse));
    }
    final zeroRow = List<Complex>.filled(targetCols, Complex.zero);
    while (rowTransformed.length < targetRows) {
      rowTransformed.add(List<Complex>.of(zeroRow));
    }

    final result = List.generate(
      targetRows,
      (_) => List<Complex>.filled(targetCols, Complex.zero),
    );

    for (var col = 0; col < targetCols; col++) {
      final colVals = [
        for (var row = 0; row < targetRows; row++) rowTransformed[row][col],
      ];
      final colTransformed = fft(colVals, inverse: inverse);
      for (var row = 0; row < targetRows; row++) {
        result[row][col] = colTransformed[row];
      }
    }

    return result;
  }

  /// Computes next power of 2 for [value].
  static int nextPowerOf2(int value) {
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

  // --- Transcendental Vector Math ---

  /// Elementwise sine.
  static Float64List vsin(Float64List input) {
    final len = input.length;
    final out = Float64List(len);
    for (var i = 0; i < len; i++) {
      out[i] = math.sin(input[i]);
    }
    return out;
  }

  /// Elementwise cosine.
  static Float64List vcos(Float64List input) {
    final len = input.length;
    final out = Float64List(len);
    for (var i = 0; i < len; i++) {
      out[i] = math.cos(input[i]);
    }
    return out;
  }

  /// Elementwise exp.
  static Float64List vexp(Float64List input) {
    final len = input.length;
    final out = Float64List(len);
    for (var i = 0; i < len; i++) {
      out[i] = math.exp(input[i]);
    }
    return out;
  }

  /// Elementwise ln.
  static Float64List vlog(Float64List input) {
    final len = input.length;
    final out = Float64List(len);
    for (var i = 0; i < len; i++) {
      out[i] = math.log(input[i]);
    }
    return out;
  }

  /// Elementwise sqrt.
  static Float64List vsqrt(Float64List input) {
    final len = input.length;
    final out = Float64List(len);
    for (var i = 0; i < len; i++) {
      out[i] = math.sqrt(input[i]);
    }
    return out;
  }

  /// Elementwise pow: `base[i] ^ exponent[i]`.
  static Float64List vpow(Float64List base, Float64List exponent) {
    final len = math.min(base.length, exponent.length);
    final out = Float64List(len);
    for (var i = 0; i < len; i++) {
      out[i] = math.pow(base[i], exponent[i]).toDouble();
    }
    return out;
  }

  // --- Vector Reductions ---

  /// Sum of vector elements.
  static double sum(Float64List x) {
    var total = 0.0;
    for (var i = 0; i < x.length; i++) {
      total += x[i];
    }
    return total;
  }

  /// Arithmetic mean of vector elements.
  static double mean(Float64List x) {
    if (x.isEmpty) return double.nan;
    return sum(x) / x.length;
  }

  /// Variance of vector elements.
  static double variance(Float64List x, {bool sample = true}) {
    final n = x.length;
    if (n == 0 || (sample && n < 2)) return double.nan;
    final avg = mean(x);
    var sumSq = 0.0;
    for (var i = 0; i < n; i++) {
      final diff = x[i] - avg;
      sumSq += diff * diff;
    }
    return sumSq / (sample ? (n - 1) : n);
  }

  // --- Signal Processing (Convolution & Correlation) ---

  /// Computes valid 1D linear convolution:
  /// `result[n] = sum_{p=0}^{P-1} signal[n + p] * filter[P - 1 - p]`.
  static Float64List convolve(Float64List signal, Float64List filter) {
    final sLen = signal.length;
    final fLen = filter.length;
    final rLen = sLen - fLen + 1;
    if (rLen <= 0) return Float64List(0);
    final result = Float64List(rLen);
    for (var n = 0; n < rLen; n++) {
      var sum = 0.0;
      for (var p = 0; p < fLen; p++) {
        sum += signal[n + p] * filter[fLen - 1 - p];
      }
      result[n] = sum;
    }
    return result;
  }

  /// Computes valid 1D cross-correlation:
  /// `result[n] = sum_{p=0}^{P-1} signal[n + p] * filter[p]`.
  static Float64List correlate(Float64List signal, Float64List filter) {
    final sLen = signal.length;
    final fLen = filter.length;
    final rLen = sLen - fLen + 1;
    if (rLen <= 0) return Float64List(0);
    final result = Float64List(rLen);
    for (var n = 0; n < rLen; n++) {
      var sum = 0.0;
      for (var p = 0; p < fLen; p++) {
        sum += signal[n + p] * filter[p];
      }
      result[n] = sum;
    }
    return result;
  }
}
