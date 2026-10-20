import 'dart:math' as math;
import 'dart:typed_data';

/// Pure Dart reference implementations of vectorized transcendental math,
/// reductions, and 1D signal processing.
abstract final class PureDartVforce {
  /// Computes elementwise sine: `output[i] = sin(input[i])`.
  static Float64List vsin(Float64List input) {
    final len = input.length;
    final out = Float64List(len);
    for (var i = 0; i < len; i++) {
      out[i] = math.sin(input[i]);
    }
    return out;
  }

  /// Computes elementwise cosine: `output[i] = cos(input[i])`.
  static Float64List vcos(Float64List input) {
    final len = input.length;
    final out = Float64List(len);
    for (var i = 0; i < len; i++) {
      out[i] = math.cos(input[i]);
    }
    return out;
  }

  /// Computes elementwise exponential: `output[i] = exp(input[i])`.
  static Float64List vexp(Float64List input) {
    final len = input.length;
    final out = Float64List(len);
    for (var i = 0; i < len; i++) {
      out[i] = math.exp(input[i]);
    }
    return out;
  }

  /// Computes elementwise natural logarithm: `output[i] = ln(input[i])`.
  static Float64List vlog(Float64List input) {
    final len = input.length;
    final out = Float64List(len);
    for (var i = 0; i < len; i++) {
      out[i] = math.log(input[i]);
    }
    return out;
  }

  /// Computes elementwise square root: `output[i] = sqrt(input[i])`.
  static Float64List vsqrt(Float64List input) {
    final len = input.length;
    final out = Float64List(len);
    for (var i = 0; i < len; i++) {
      out[i] = math.sqrt(input[i]);
    }
    return out;
  }

  /// Computes elementwise power: `output[i] = pow(base[i], exponent[i])`.
  static Float64List vpow(Float64List base, Float64List exponent) {
    final len = math.min(base.length, exponent.length);
    final out = Float64List(len);
    for (var i = 0; i < len; i++) {
      out[i] = math.pow(base[i], exponent[i]).toDouble();
    }
    return out;
  }

  /// Computes the arithmetic sum of vector elements.
  static double sum(Float64List x) {
    var total = 0.0;
    for (var i = 0; i < x.length; i++) {
      total += x[i];
    }
    return total;
  }

  /// Computes the arithmetic mean of vector elements.
  static double mean(Float64List x) {
    if (x.isEmpty) return double.nan;
    return sum(x) / x.length;
  }

  /// Computes the sample or population variance of vector elements.
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
