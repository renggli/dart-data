import 'dart:math' as math;
import 'dart:typed_data';

/// Pure Dart reference implementation of vectorized math, reductions, and
/// signal processing routines.
abstract final class VforceDart {
  /// Computes elementwise sine: `output[i] = sin(input[i])`.
  static void vsin({
    required Float64List input,
    required Float64List output,
    required int n,
  }) {
    for (var i = 0; i < n; i++) {
      output[i] = math.sin(input[i]);
    }
  }

  /// Computes elementwise cosine: `output[i] = cos(input[i])`.
  static void vcos({
    required Float64List input,
    required Float64List output,
    required int n,
  }) {
    for (var i = 0; i < n; i++) {
      output[i] = math.cos(input[i]);
    }
  }

  /// Computes elementwise exponential: `output[i] = exp(input[i])`.
  static void vexp({
    required Float64List input,
    required Float64List output,
    required int n,
  }) {
    for (var i = 0; i < n; i++) {
      output[i] = math.exp(input[i]);
    }
  }

  /// Computes elementwise natural logarithm: `output[i] = ln(input[i])`.
  static void vlog({
    required Float64List input,
    required Float64List output,
    required int n,
  }) {
    for (var i = 0; i < n; i++) {
      output[i] = math.log(input[i]);
    }
  }

  /// Computes elementwise square root: `output[i] = sqrt(input[i])`.
  static void vsqrt({
    required Float64List input,
    required Float64List output,
    required int n,
  }) {
    for (var i = 0; i < n; i++) {
      output[i] = math.sqrt(input[i]);
    }
  }

  /// Computes elementwise power: `output[i] = pow(base[i], exponent[i])`.
  static void vpow({
    required Float64List base,
    required Float64List exponent,
    required Float64List output,
    required int n,
  }) {
    for (var i = 0; i < n; i++) {
      output[i] = math.pow(base[i], exponent[i]).toDouble();
    }
  }

  /// Computes the arithmetic sum of vector elements.
  static double sum({required Float64List x, required int n}) {
    var total = 0.0;
    for (var i = 0; i < n; i++) {
      total += x[i];
    }
    return total;
  }

  /// Computes the arithmetic mean of vector elements.
  static double mean({required Float64List x, required int n}) {
    if (n == 0) return double.nan;
    return sum(x: x, n: n) / n;
  }

  /// Computes the sample or population variance of vector elements.
  static double variance({
    required Float64List x,
    required int n,
    required bool sample,
  }) {
    if (n == 0 || (sample && n < 2)) return double.nan;
    final avg = mean(x: x, n: n);
    var sumSq = 0.0;
    for (var i = 0; i < n; i++) {
      final diff = x[i] - avg;
      sumSq += diff * diff;
    }
    return sumSq / (sample ? (n - 1) : n);
  }

  /// Computes valid 1D linear convolution:
  /// `output[n] = sum_{p=0}^{P-1} signal[n + p] * filter[P - 1 - p]`.
  static void convolve({
    required Float64List signal,
    required Float64List filter,
    required Float64List output,
    required int resultLength,
  }) {
    final fLen = filter.length;
    for (var n = 0; n < resultLength; n++) {
      var s = 0.0;
      for (var p = 0; p < fLen; p++) {
        s += signal[n + p] * filter[fLen - 1 - p];
      }
      output[n] = s;
    }
  }

  /// Computes valid 1D cross-correlation:
  /// `output[n] = sum_{p=0}^{P-1} signal[n + p] * filter[p]`.
  static void correlate({
    required Float64List signal,
    required Float64List filter,
    required Float64List output,
    required int resultLength,
  }) {
    final fLen = filter.length;
    for (var n = 0; n < resultLength; n++) {
      var s = 0.0;
      for (var p = 0; p < fLen; p++) {
        s += signal[n + p] * filter[p];
      }
      output[n] = s;
    }
  }
}
