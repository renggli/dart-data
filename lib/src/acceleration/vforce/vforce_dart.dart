import 'dart:math' as math;
import 'dart:typed_data';

import '../../type/utils/memory.dart';

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
    final avg = sum(x: x, n: n) / n;
    if (avg.isFinite) return avg;
    for (var i = 0; i < n; i++) {
      if (!x[i].isFinite) return avg;
    }
    var welfordMean = 0.0;
    for (var i = 0; i < n; i++) {
      welfordMean += (x[i] - welfordMean) / (i + 1);
    }
    return welfordMean;
  }

  /// Computes the sample or population variance of vector elements.
  static double variance({
    required Float64List x,
    required int n,
    required bool sample,
  }) {
    if (n == 0 || (sample && n < 2)) return double.nan;
    final avg = mean(x: x, n: n);
    if (!avg.isFinite) return double.nan;
    var sumSq = 0.0;
    for (var i = 0; i < n; i++) {
      final diff = x[i] - avg;
      sumSq += diff * diff;
    }
    final divisor = sample ? n - 1 : n;
    if (sumSq.isFinite) {
      return sumSq / divisor;
    }
    var maxDiff = 0.0;
    for (var i = 0; i < n; i++) {
      final ad = (x[i] - avg).abs();
      if (!ad.isFinite) return double.nan;
      if (ad > maxDiff) maxDiff = ad;
    }
    if (maxDiff == 0.0) return 0.0;
    var scaledSumSq = 0.0;
    for (var i = 0; i < n; i++) {
      final d = (x[i] - avg) / maxDiff;
      scaledSumSq += d * d;
    }
    return maxDiff * maxDiff * (scaledSumSq / divisor);
  }

  /// Computes valid 1D linear convolution:
  /// `output[n] = sum_{p=0}^{P-1} signal[n + p] * filter[P - 1 - p]`.
  static void convolve({
    required Float64List signal,
    required Float64List filter,
    required Float64List output,
    required int resultLength,
  }) {
    if (resultLength <= 0) return;
    final fLen = filter.length;
    final sLen = signal.length;
    final needsCopy =
        hasOverlap(output, 0, signal, 0, resultLength, sLen) ||
        hasOverlap(output, 0, filter, 0, resultLength, fLen);
    final target = needsCopy ? Float64List(resultLength) : output;
    for (var n = 0; n < resultLength; n++) {
      var s = 0.0;
      for (var p = 0; p < fLen; p++) {
        s += signal[n + p] * filter[fLen - 1 - p];
      }
      target[n] = s;
    }
    if (needsCopy) {
      output.setRange(0, resultLength, target);
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
    if (resultLength <= 0) return;
    final fLen = filter.length;
    final sLen = signal.length;
    final needsCopy =
        hasOverlap(output, 0, signal, 0, resultLength, sLen) ||
        hasOverlap(output, 0, filter, 0, resultLength, fLen);
    final target = needsCopy ? Float64List(resultLength) : output;
    for (var n = 0; n < resultLength; n++) {
      var s = 0.0;
      for (var p = 0; p < fLen; p++) {
        s += signal[n + p] * filter[p];
      }
      target[n] = s;
    }
    if (needsCopy) {
      output.setRange(0, resultLength, target);
    }
  }
}
