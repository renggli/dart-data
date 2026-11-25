import 'dart:typed_data';

import '../../type/utils/memory.dart';
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
  ///
  /// Safe for full in-place updates (`output == input`) and partially
  /// overlapping views. Throws [RangeError] if [output] is shorter than [input].
  static Float64List vsin({required Float64List input, Float64List? output}) =>
      _unaryOp(
        input: input,
        output: output,
        operation: 'vsin',
        nativeFn: VforceNative.vsin,
        dartFn: VforceDart.vsin,
      );

  /// Computes elementwise cosine: `output[i] = cos(input[i])`.
  ///
  /// Safe for full in-place updates (`output == input`) and partially
  /// overlapping views. Throws [RangeError] if [output] is shorter than [input].
  static Float64List vcos({required Float64List input, Float64List? output}) =>
      _unaryOp(
        input: input,
        output: output,
        operation: 'vcos',
        nativeFn: VforceNative.vcos,
        dartFn: VforceDart.vcos,
      );

  /// Computes elementwise exponential: `output[i] = exp(input[i])`.
  ///
  /// Safe for full in-place updates (`output == input`) and partially
  /// overlapping views. Throws [RangeError] if [output] is shorter than [input].
  static Float64List vexp({required Float64List input, Float64List? output}) =>
      _unaryOp(
        input: input,
        output: output,
        operation: 'vexp',
        nativeFn: VforceNative.vexp,
        dartFn: VforceDart.vexp,
      );

  /// Computes elementwise natural logarithm: `output[i] = ln(input[i])`.
  ///
  /// Safe for full in-place updates (`output == input`) and partially
  /// overlapping views. Throws [RangeError] if [output] is shorter than [input].
  static Float64List vlog({required Float64List input, Float64List? output}) =>
      _unaryOp(
        input: input,
        output: output,
        operation: 'vlog',
        nativeFn: VforceNative.vlog,
        dartFn: VforceDart.vlog,
      );

  /// Computes elementwise square root: `output[i] = sqrt(input[i])`.
  ///
  /// Safe for full in-place updates (`output == input`) and partially
  /// overlapping views. Throws [RangeError] if [output] is shorter than [input].
  static Float64List vsqrt({required Float64List input, Float64List? output}) =>
      _unaryOp(
        input: input,
        output: output,
        operation: 'vsqrt',
        nativeFn: VforceNative.vsqrt,
        dartFn: VforceDart.vsqrt,
      );

  /// Computes elementwise power: `output[i] = pow(base[i], exponent[i])`.
  ///
  /// Safe for full in-place updates and partially overlapping views. Throws
  /// [ArgumentError] if [base] and [exponent] lengths differ, or [RangeError]
  /// if [output] is shorter than [base].
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

    final needsCopy =
        (hasOverlap(dest, 0, base, 0, len) &&
            !sameStartAddress(dest, 0, base, 0)) ||
        (hasOverlap(dest, 0, exponent, 0, len) &&
            !sameStartAddress(dest, 0, exponent, 0));
    final target = needsCopy ? Float64List(len) : dest;

    executeAcceleratedVoid(
      feature: 'vForce',
      operation: 'vpow',
      isAvailable: VforceNative.hasVForce,
      accelerate: () => VforceNative.vpow(
        base: base,
        exponent: exponent,
        output: target,
        n: len,
      ),
      fallback: () => VforceDart.vpow(
        base: base,
        exponent: exponent,
        output: target,
        n: len,
      ),
    );
    if (needsCopy) {
      dest.setRange(0, len, target);
    }
    return dest;
  }

  /// Computes the sum of vector elements (`0.0` if [x] is empty).
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

  /// Computes the arithmetic mean of vector elements ([double.nan] if [x] is
  /// empty).
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

  /// Computes the sample (`n >= 2`) or population (`n >= 1`) variance of vector
  /// elements, returning [double.nan] for insufficient length or non-finite inputs.
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
  ///
  /// Safe when [output] overlaps [signal] or [filter]. Returns an empty list
  /// (or unmodified [output]) when `filter.isEmpty` or `signal.length < filter.length`.
  static Float64List convolve({
    required Float64List signal,
    required Float64List filter,
    Float64List? output,
  }) {
    final sLen = signal.length;
    final fLen = filter.length;
    final rLen = fLen == 0 ? 0 : sLen - fLen + 1;
    if (output != null && output.length < rLen) {
      throw RangeError(
        'Output buffer length (${output.length}) must be at least result length ($rLen)',
      );
    }
    final dest = output ?? Float64List(rLen < 0 ? 0 : rLen);
    if (rLen <= 0) return dest;

    final needsCopy =
        hasOverlap(dest, 0, signal, 0, rLen, sLen) ||
        hasOverlap(dest, 0, filter, 0, rLen, fLen);
    final target = needsCopy ? Float64List(rLen) : dest;

    executeAcceleratedVoid(
      feature: 'vDSP',
      operation: 'convolve',
      isAvailable: VforceNative.hasConvolution,
      accelerate: () =>
          VforceNative.convolve(signal: signal, filter: filter, output: target),
      fallback: () => VforceDart.convolve(
        signal: signal,
        filter: filter,
        output: target,
        resultLength: rLen,
      ),
    );
    if (needsCopy) {
      dest.setRange(0, rLen, target);
    }
    return dest;
  }

  /// Computes valid 1D cross-correlation:
  /// `output[n] = sum_{p=0}^{P-1} signal[n + p] * filter[p]`.
  ///
  /// Safe when [output] overlaps [signal] or [filter]. Returns an empty list
  /// (or unmodified [output]) when `filter.isEmpty` or `signal.length < filter.length`.
  static Float64List correlate({
    required Float64List signal,
    required Float64List filter,
    Float64List? output,
  }) {
    final sLen = signal.length;
    final fLen = filter.length;
    final rLen = fLen == 0 ? 0 : sLen - fLen + 1;
    if (output != null && output.length < rLen) {
      throw RangeError(
        'Output buffer length (${output.length}) must be at least result length ($rLen)',
      );
    }
    final dest = output ?? Float64List(rLen < 0 ? 0 : rLen);
    if (rLen <= 0) return dest;

    final needsCopy =
        hasOverlap(dest, 0, signal, 0, rLen, sLen) ||
        hasOverlap(dest, 0, filter, 0, rLen, fLen);
    final target = needsCopy ? Float64List(rLen) : dest;

    executeAcceleratedVoid(
      feature: 'vDSP',
      operation: 'correlate',
      isAvailable: VforceNative.hasConvolution,
      accelerate: () => VforceNative.correlate(
        signal: signal,
        filter: filter,
        output: target,
      ),
      fallback: () => VforceDart.correlate(
        signal: signal,
        filter: filter,
        output: target,
        resultLength: rLen,
      ),
    );
    if (needsCopy) {
      dest.setRange(0, rLen, target);
    }
    return dest;
  }

  static Float64List _unaryOp({
    required Float64List input,
    required Float64List? output,
    required String operation,
    required bool Function({
      required Float64List input,
      required Float64List output,
      required int n,
    })
    nativeFn,
    required void Function({
      required Float64List input,
      required Float64List output,
      required int n,
    })
    dartFn,
  }) {
    final len = input.length;
    if (output != null && output.length < len) {
      throw RangeError(
        'Output buffer length (${output.length}) must be at least input length ($len)',
      );
    }
    final dest = output ?? Float64List(len);
    if (len == 0) return dest;

    final needsCopy =
        hasOverlap(dest, 0, input, 0, len) &&
        !sameStartAddress(dest, 0, input, 0);
    final target = needsCopy ? Float64List(len) : dest;

    executeAcceleratedVoid(
      feature: 'vForce',
      operation: operation,
      isAvailable: VforceNative.hasVForce,
      accelerate: () => nativeFn(input: input, output: target, n: len),
      fallback: () => dartFn(input: input, output: target, n: len),
    );
    if (needsCopy) {
      dest.setRange(0, len, target);
    }
    return dest;
  }
}
