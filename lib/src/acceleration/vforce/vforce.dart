import 'dart:typed_data';

import '../utils/dispatcher.dart';
import 'vforce_dart.dart';
import 'vforce_stub.dart' if (dart.library.ffi) 'vforce_native.dart';

/// Vectorized transcendental functions, reductions, and 1D signal processing.
///
/// Automatically routes execution between Apple vForce/vDSP (via FFI) and
/// optimized pure Dart fallbacks according to acceleration mode.
abstract final class Vforce {
  /// Whether native vForce or vDSP acceleration is available on the current
  /// platform.
  static bool get isAvailable => VforceNative.isAvailable;

  /// Computes elementwise sine: `output[i] = sin(input[i])`.
  static Float64List vsin({required Float64List input, Float64List? output}) {
    final len = input.length;
    if (output != null && output.length < len) {
      throw RangeError(
        'Output buffer length (${output.length}) must be at least input length ($len)',
      );
    }
    final dest = output ?? Float64List(len);
    if (len == 0) return dest;

    executeAcceleratedVoid(
      feature: 'vForce',
      operation: 'vsin',
      isAvailable: VforceNative.hasVForce,
      accelerate: () => VforceNative.vsin(input: input, output: dest, n: len),
      fallback: () => VforceDart.vsin(input: input, output: dest, n: len),
    );
    return dest;
  }

  /// Computes elementwise cosine: `output[i] = cos(input[i])`.
  static Float64List vcos({required Float64List input, Float64List? output}) {
    final len = input.length;
    if (output != null && output.length < len) {
      throw RangeError(
        'Output buffer length (${output.length}) must be at least input length ($len)',
      );
    }
    final dest = output ?? Float64List(len);
    if (len == 0) return dest;

    executeAcceleratedVoid(
      feature: 'vForce',
      operation: 'vcos',
      isAvailable: VforceNative.hasVForce,
      accelerate: () => VforceNative.vcos(input: input, output: dest, n: len),
      fallback: () => VforceDart.vcos(input: input, output: dest, n: len),
    );
    return dest;
  }

  /// Computes elementwise exponential: `output[i] = exp(input[i])`.
  static Float64List vexp({required Float64List input, Float64List? output}) {
    final len = input.length;
    if (output != null && output.length < len) {
      throw RangeError(
        'Output buffer length (${output.length}) must be at least input length ($len)',
      );
    }
    final dest = output ?? Float64List(len);
    if (len == 0) return dest;

    executeAcceleratedVoid(
      feature: 'vForce',
      operation: 'vexp',
      isAvailable: VforceNative.hasVForce,
      accelerate: () => VforceNative.vexp(input: input, output: dest, n: len),
      fallback: () => VforceDart.vexp(input: input, output: dest, n: len),
    );
    return dest;
  }

  /// Computes elementwise natural logarithm: `output[i] = ln(input[i])`.
  static Float64List vlog({required Float64List input, Float64List? output}) {
    final len = input.length;
    if (output != null && output.length < len) {
      throw RangeError(
        'Output buffer length (${output.length}) must be at least input length ($len)',
      );
    }
    final dest = output ?? Float64List(len);
    if (len == 0) return dest;

    executeAcceleratedVoid(
      feature: 'vForce',
      operation: 'vlog',
      isAvailable: VforceNative.hasVForce,
      accelerate: () => VforceNative.vlog(input: input, output: dest, n: len),
      fallback: () => VforceDart.vlog(input: input, output: dest, n: len),
    );
    return dest;
  }

  /// Computes elementwise square root: `output[i] = sqrt(input[i])`.
  static Float64List vsqrt({required Float64List input, Float64List? output}) {
    final len = input.length;
    if (output != null && output.length < len) {
      throw RangeError(
        'Output buffer length (${output.length}) must be at least input length ($len)',
      );
    }
    final dest = output ?? Float64List(len);
    if (len == 0) return dest;

    executeAcceleratedVoid(
      feature: 'vForce',
      operation: 'vsqrt',
      isAvailable: VforceNative.hasVForce,
      accelerate: () => VforceNative.vsqrt(input: input, output: dest, n: len),
      fallback: () => VforceDart.vsqrt(input: input, output: dest, n: len),
    );
    return dest;
  }

  /// Computes elementwise power: `output[i] = pow(base[i], exponent[i])`.
  static Float64List vpow({
    required Float64List base,
    required Float64List exponent,
    Float64List? output,
  }) {
    if (base.length != exponent.length) {
      throw ArgumentError(
        'Base and exponent vectors must have matching lengths: '
        '${base.length} != ${exponent.length}',
      );
    }
    final len = base.length;
    if (output != null && output.length < len) {
      throw RangeError(
        'Output buffer length (${output.length}) must be at least base length ($len)',
      );
    }
    final dest = output ?? Float64List(len);
    if (len == 0) return dest;

    executeAcceleratedVoid(
      feature: 'vForce',
      operation: 'vpow',
      isAvailable: VforceNative.hasVForce,
      accelerate: () => VforceNative.vpow(
        base: base,
        exponent: exponent,
        output: dest,
        n: len,
      ),
      fallback: () =>
          VforceDart.vpow(base: base, exponent: exponent, output: dest, n: len),
    );
    return dest;
  }

  /// Computes the sum of vector elements.
  static double sum({required Float64List x}) {
    final len = x.length;
    if (len == 0) return 0.0;

    return executeAccelerated(
      feature: 'vDSP',
      operation: 'sum',
      isAvailable: VforceNative.hasReductions,
      accelerate: () => VforceNative.sum(x: x, n: len),
      fallback: () => VforceDart.sum(x: x, n: len),
    );
  }

  /// Computes the arithmetic mean of vector elements.
  static double mean({required Float64List x}) {
    final len = x.length;
    if (len == 0) return double.nan;

    return executeAccelerated(
      feature: 'vDSP',
      operation: 'mean',
      isAvailable: VforceNative.hasReductions,
      accelerate: () => VforceNative.mean(x: x, n: len),
      fallback: () => VforceDart.mean(x: x, n: len),
    );
  }

  /// Computes the sample or population variance of vector elements.
  static double variance({required Float64List x, bool sample = true}) {
    final len = x.length;
    if (len == 0 || (sample && len < 2)) return double.nan;

    return executeAccelerated(
      feature: 'vDSP',
      operation: 'variance',
      isAvailable: VforceNative.hasReductions,
      accelerate: () => VforceNative.variance(x: x, n: len, sample: sample),
      fallback: () => VforceDart.variance(x: x, n: len, sample: sample),
    );
  }

  /// Computes valid 1D linear convolution:
  /// `output[n] = sum_{p=0}^{P-1} signal[n + p] * filter[P - 1 - p]`.
  static Float64List convolve({
    required Float64List signal,
    required Float64List filter,
    Float64List? output,
  }) {
    final sLen = signal.length;
    final fLen = filter.length;
    final rLen = fLen == 0 ? 0 : sLen - fLen + 1;
    if (rLen <= 0) return Float64List(0);
    if (output != null && output.length < rLen) {
      throw RangeError(
        'Output buffer length (${output.length}) must be at least result length ($rLen)',
      );
    }
    final dest = output ?? Float64List(rLen);

    executeAcceleratedVoid(
      feature: 'vDSP',
      operation: 'convolve',
      isAvailable: VforceNative.hasConvolution,
      accelerate: () =>
          VforceNative.convolve(signal: signal, filter: filter, output: dest),
      fallback: () => VforceDart.convolve(
        signal: signal,
        filter: filter,
        output: dest,
        resultLength: rLen,
      ),
    );
    return dest;
  }

  /// Computes valid 1D cross-correlation:
  /// `output[n] = sum_{p=0}^{P-1} signal[n + p] * filter[p]`.
  static Float64List correlate({
    required Float64List signal,
    required Float64List filter,
    Float64List? output,
  }) {
    final sLen = signal.length;
    final fLen = filter.length;
    final rLen = fLen == 0 ? 0 : sLen - fLen + 1;
    if (rLen <= 0) return Float64List(0);
    if (output != null && output.length < rLen) {
      throw RangeError(
        'Output buffer length (${output.length}) must be at least result length ($rLen)',
      );
    }
    final dest = output ?? Float64List(rLen);

    executeAcceleratedVoid(
      feature: 'vDSP',
      operation: 'correlate',
      isAvailable: VforceNative.hasConvolution,
      accelerate: () =>
          VforceNative.correlate(signal: signal, filter: filter, output: dest),
      fallback: () => VforceDart.correlate(
        signal: signal,
        filter: filter,
        output: dest,
        resultLength: rLen,
      ),
    );
    return dest;
  }
}
