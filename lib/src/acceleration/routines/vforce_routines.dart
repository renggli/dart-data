import 'dart:math' as math;
import 'dart:typed_data';

import '../fallback/pure_dart_vforce.dart';
import '../vdsp/vdsp.dart';
import 'dispatcher.dart';

/// Vectorized transcendental and reduction routines coordinating between
/// vForce/vDSP and pure Dart.
abstract final class VforceRoutines {
  /// Computes elementwise sine: `output[i] = sin(input[i])`.
  static Float64List vsin(Float64List input, {required VdspLibrary vdsp}) =>
      executeAccelerated(
        feature: 'vForce',
        operation: 'vvsin',
        isAvailable: vdsp.hasVForce,
        canAccelerate: input.length >= 64,
        accelerate: () {
          final out = Float64List(input.length);
          return vdsp.vvsin(input: input, output: out, n: input.length)
              ? out
              : null;
        },
        fallback: () => PureDartVforce.vsin(input),
      );

  /// Computes elementwise cosine: `output[i] = cos(input[i])`.
  static Float64List vcos(Float64List input, {required VdspLibrary vdsp}) =>
      executeAccelerated(
        feature: 'vForce',
        operation: 'vvcos',
        isAvailable: vdsp.hasVForce,
        canAccelerate: input.length >= 64,
        accelerate: () {
          final out = Float64List(input.length);
          return vdsp.vvcos(input: input, output: out, n: input.length)
              ? out
              : null;
        },
        fallback: () => PureDartVforce.vcos(input),
      );

  /// Computes elementwise exponential: `output[i] = exp(input[i])`.
  static Float64List vexp(Float64List input, {required VdspLibrary vdsp}) =>
      executeAccelerated(
        feature: 'vForce',
        operation: 'vvexp',
        isAvailable: vdsp.hasVForce,
        canAccelerate: input.length >= 64,
        accelerate: () {
          final out = Float64List(input.length);
          return vdsp.vvexp(input: input, output: out, n: input.length)
              ? out
              : null;
        },
        fallback: () => PureDartVforce.vexp(input),
      );

  /// Computes elementwise natural logarithm: `output[i] = ln(input[i])`.
  static Float64List vlog(Float64List input, {required VdspLibrary vdsp}) =>
      executeAccelerated(
        feature: 'vForce',
        operation: 'vvlog',
        isAvailable: vdsp.hasVForce,
        canAccelerate: input.length >= 64,
        accelerate: () {
          final out = Float64List(input.length);
          return vdsp.vvlog(input: input, output: out, n: input.length)
              ? out
              : null;
        },
        fallback: () => PureDartVforce.vlog(input),
      );

  /// Computes elementwise square root: `output[i] = sqrt(input[i])`.
  static Float64List vsqrt(Float64List input, {required VdspLibrary vdsp}) =>
      executeAccelerated(
        feature: 'vForce',
        operation: 'vvsqrt',
        isAvailable: vdsp.hasVForce,
        canAccelerate: input.length >= 64,
        accelerate: () {
          final out = Float64List(input.length);
          return vdsp.vvsqrt(input: input, output: out, n: input.length)
              ? out
              : null;
        },
        fallback: () => PureDartVforce.vsqrt(input),
      );

  /// Computes elementwise power: `output[i] = pow(base[i], exponent[i])`.
  static Float64List vpow(
    Float64List base,
    Float64List exponent, {
    required VdspLibrary vdsp,
  }) {
    final n = math.min(base.length, exponent.length);
    return executeAccelerated(
      feature: 'vForce',
      operation: 'vvpow',
      isAvailable: vdsp.hasVForce,
      canAccelerate: n >= 64,
      accelerate: () {
        final out = Float64List(n);
        return vdsp.vvpow(base: base, exponent: exponent, output: out, n: n)
            ? out
            : null;
      },
      fallback: () => PureDartVforce.vpow(base, exponent),
    );
  }

  // --- Vector Reductions ---

  /// Computes sum of elements in [x].
  static double sum(Float64List x, {required VdspLibrary vdsp}) =>
      executeAccelerated(
        feature: 'vector reductions',
        operation: 'vDSP_sveD',
        isAvailable: vdsp.hasReductions,
        canAccelerate: x.length >= 64,
        accelerate: () => vdsp.sve(x: x, n: x.length),
        fallback: () => PureDartVforce.sum(x),
      );

  /// Computes arithmetic mean of elements in [x].
  static double mean(Float64List x, {required VdspLibrary vdsp}) {
    if (x.isEmpty) return double.nan;
    return executeAccelerated(
      feature: 'vector reductions',
      operation: 'vDSP_meanvD',
      isAvailable: vdsp.hasReductions,
      canAccelerate: x.length >= 64,
      accelerate: () => vdsp.meanv(x: x, n: x.length),
      fallback: () => PureDartVforce.mean(x),
    );
  }

  /// Computes variance of elements in [x].
  static double variance(
    Float64List x, {
    required VdspLibrary vdsp,
    bool sample = true,
  }) {
    final n = x.length;
    if (n == 0 || (sample && n < 2)) return double.nan;
    return executeAccelerated(
      feature: 'vector reductions',
      operation: 'variance',
      isAvailable: vdsp.hasReductions,
      canAccelerate: n >= 64,
      accelerate: () => vdsp.variance(x: x, n: n, sample: sample),
      fallback: () => PureDartVforce.variance(x, sample: sample),
    );
  }

  // --- Signal Processing ---

  /// Computes 1D valid linear convolution of [signal] and [filter].
  static Float64List convolve(
    Float64List signal,
    Float64List filter, {
    required VdspLibrary vdsp,
  }) {
    final rLen = signal.length - filter.length + 1;
    if (rLen <= 0) return Float64List(0);

    return executeAccelerated(
      feature: 'vDSP',
      operation: 'convolution',
      isAvailable: vdsp.isAvailable,
      canAccelerate: signal.length >= 64,
      accelerate: () {
        final result = Float64List(rLen);
        final success = vdsp.conv1d(
          signal: signal,
          filter: filter,
          result: result,
        );
        return success ? result : null;
      },
      fallback: () => PureDartVforce.convolve(signal, filter),
    );
  }

  /// Computes 1D valid cross-correlation of [signal] and [filter].
  static Float64List correlate(
    Float64List signal,
    Float64List filter, {
    required VdspLibrary vdsp,
  }) {
    final rLen = signal.length - filter.length + 1;
    if (rLen <= 0) return Float64List(0);

    return executeAccelerated(
      feature: 'vDSP',
      operation: 'cross-correlation',
      isAvailable: vdsp.isAvailable,
      canAccelerate: signal.length >= 64,
      accelerate: () {
        final result = Float64List(rLen);
        final success = vdsp.xcorr1d(
          signal: signal,
          filter: filter,
          result: result,
        );
        return success ? result : null;
      },
      fallback: () => PureDartVforce.correlate(signal, filter),
    );
  }
}
