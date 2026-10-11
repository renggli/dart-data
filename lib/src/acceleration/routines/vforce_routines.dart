import 'dart:typed_data';

import '../acceleration_manager.dart';
import '../acceleration_mode.dart';
import '../fallback/pure_dart_fft.dart';
import '../vdsp/vdsp.dart';

/// Vectorized transcendental and reduction routines coordinating between
/// vForce/vDSP and pure Dart.
abstract final class VforceRoutines {
  /// Computes elementwise sine: `output[i] = sin(input[i])`.
  static Float64List vsin(Float64List input, {required VdspLibrary vdsp}) {
    final mode = AccelerationManager.mode;
    if (mode == AccelerationMode.dart) {
      return PureDartFft.vsin(input);
    }
    if (mode == AccelerationMode.accelerated && !vdsp.hasVForce) {
      throw StateError(
        'AccelerationMode.accelerated requested but native vForce is unavailable.',
      );
    }

    final n = input.length;
    if (vdsp.hasVForce && (n >= 64 || mode == AccelerationMode.accelerated)) {
      final out = Float64List(n);
      final success = vdsp.vvsin(input: input, output: out, n: n);
      if (success) return out;
    }

    if (mode == AccelerationMode.accelerated) {
      throw StateError('Native hardware vvsin execution failed.');
    }
    return PureDartFft.vsin(input);
  }

  /// Computes elementwise cosine: `output[i] = cos(input[i])`.
  static Float64List vcos(Float64List input, {required VdspLibrary vdsp}) {
    final mode = AccelerationManager.mode;
    if (mode == AccelerationMode.dart) {
      return PureDartFft.vcos(input);
    }
    if (mode == AccelerationMode.accelerated && !vdsp.hasVForce) {
      throw StateError(
        'AccelerationMode.accelerated requested but native vForce is unavailable.',
      );
    }

    final n = input.length;
    if (vdsp.hasVForce && (n >= 64 || mode == AccelerationMode.accelerated)) {
      final out = Float64List(n);
      final success = vdsp.vvcos(input: input, output: out, n: n);
      if (success) return out;
    }

    if (mode == AccelerationMode.accelerated) {
      throw StateError('Native hardware vvcos execution failed.');
    }
    return PureDartFft.vcos(input);
  }

  /// Computes elementwise exponential: `output[i] = exp(input[i])`.
  static Float64List vexp(Float64List input, {required VdspLibrary vdsp}) {
    final mode = AccelerationManager.mode;
    if (mode == AccelerationMode.dart) {
      return PureDartFft.vexp(input);
    }
    if (mode == AccelerationMode.accelerated && !vdsp.hasVForce) {
      throw StateError(
        'AccelerationMode.accelerated requested but native vForce is unavailable.',
      );
    }

    final n = input.length;
    if (vdsp.hasVForce && (n >= 64 || mode == AccelerationMode.accelerated)) {
      final out = Float64List(n);
      final success = vdsp.vvexp(input: input, output: out, n: n);
      if (success) return out;
    }

    if (mode == AccelerationMode.accelerated) {
      throw StateError('Native hardware vvexp execution failed.');
    }
    return PureDartFft.vexp(input);
  }

  /// Computes elementwise natural logarithm: `output[i] = ln(input[i])`.
  static Float64List vlog(Float64List input, {required VdspLibrary vdsp}) {
    final mode = AccelerationManager.mode;
    if (mode == AccelerationMode.dart) {
      return PureDartFft.vlog(input);
    }
    if (mode == AccelerationMode.accelerated && !vdsp.hasVForce) {
      throw StateError(
        'AccelerationMode.accelerated requested but native vForce is unavailable.',
      );
    }

    final n = input.length;
    if (vdsp.hasVForce && (n >= 64 || mode == AccelerationMode.accelerated)) {
      final out = Float64List(n);
      final success = vdsp.vvlog(input: input, output: out, n: n);
      if (success) return out;
    }

    if (mode == AccelerationMode.accelerated) {
      throw StateError('Native hardware vvlog execution failed.');
    }
    return PureDartFft.vlog(input);
  }

  /// Computes elementwise square root: `output[i] = sqrt(input[i])`.
  static Float64List vsqrt(Float64List input, {required VdspLibrary vdsp}) {
    final mode = AccelerationManager.mode;
    if (mode == AccelerationMode.dart) {
      return PureDartFft.vsqrt(input);
    }
    if (mode == AccelerationMode.accelerated && !vdsp.hasVForce) {
      throw StateError(
        'AccelerationMode.accelerated requested but native vForce is unavailable.',
      );
    }

    final n = input.length;
    if (vdsp.hasVForce && (n >= 64 || mode == AccelerationMode.accelerated)) {
      final out = Float64List(n);
      final success = vdsp.vvsqrt(input: input, output: out, n: n);
      if (success) return out;
    }

    if (mode == AccelerationMode.accelerated) {
      throw StateError('Native hardware vvsqrt execution failed.');
    }
    return PureDartFft.vsqrt(input);
  }

  /// Computes elementwise power: `output[i] = pow(base[i], exponent[i])`.
  static Float64List vpow(
    Float64List base,
    Float64List exponent, {
    required VdspLibrary vdsp,
  }) {
    final mode = AccelerationManager.mode;
    if (mode == AccelerationMode.dart) {
      return PureDartFft.vpow(base, exponent);
    }
    if (mode == AccelerationMode.accelerated && !vdsp.hasVForce) {
      throw StateError(
        'AccelerationMode.accelerated requested but native vForce is unavailable.',
      );
    }

    final n = base.length < exponent.length ? base.length : exponent.length;
    if (vdsp.hasVForce && (n >= 64 || mode == AccelerationMode.accelerated)) {
      final out = Float64List(n);
      final success = vdsp.vvpow(
        base: base,
        exponent: exponent,
        output: out,
        n: n,
      );
      if (success) return out;
    }

    if (mode == AccelerationMode.accelerated) {
      throw StateError('Native hardware vvpow execution failed.');
    }
    return PureDartFft.vpow(base, exponent);
  }

  // --- Vector Reductions ---

  /// Computes sum of elements in [x].
  static double sum(Float64List x, {required VdspLibrary vdsp}) {
    final mode = AccelerationManager.mode;
    if (mode == AccelerationMode.dart) {
      return PureDartFft.sum(x);
    }
    if (mode == AccelerationMode.accelerated && !vdsp.hasReductions) {
      throw StateError(
        'AccelerationMode.accelerated requested but native vector reductions are unavailable.',
      );
    }

    final n = x.length;
    if (vdsp.hasReductions &&
        (n >= 64 || mode == AccelerationMode.accelerated)) {
      final val = vdsp.sve(x: x, n: n);
      if (val != null) return val;
    }

    if (mode == AccelerationMode.accelerated) {
      throw StateError('Native hardware vDSP_sveD execution failed.');
    }
    return PureDartFft.sum(x);
  }

  /// Computes arithmetic mean of elements in [x].
  static double mean(Float64List x, {required VdspLibrary vdsp}) {
    final mode = AccelerationManager.mode;
    if (mode == AccelerationMode.dart) {
      return PureDartFft.mean(x);
    }
    if (mode == AccelerationMode.accelerated && !vdsp.hasReductions) {
      throw StateError(
        'AccelerationMode.accelerated requested but native vector reductions are unavailable.',
      );
    }

    final n = x.length;
    if (n == 0) return double.nan;
    if (vdsp.hasReductions &&
        (n >= 64 || mode == AccelerationMode.accelerated)) {
      final val = vdsp.meanv(x: x, n: n);
      if (val != null) return val;
    }

    if (mode == AccelerationMode.accelerated) {
      throw StateError('Native hardware vDSP_meanvD execution failed.');
    }
    return PureDartFft.mean(x);
  }

  /// Computes variance of elements in [x].
  static double variance(
    Float64List x, {
    required VdspLibrary vdsp,
    bool sample = true,
  }) {
    final mode = AccelerationManager.mode;
    if (mode == AccelerationMode.dart) {
      return PureDartFft.variance(x, sample: sample);
    }
    if (mode == AccelerationMode.accelerated && !vdsp.hasReductions) {
      throw StateError(
        'AccelerationMode.accelerated requested but native vector reductions are unavailable.',
      );
    }

    final n = x.length;
    if (n == 0 || (sample && n < 2)) return double.nan;
    if (vdsp.hasReductions &&
        (n >= 64 || mode == AccelerationMode.accelerated)) {
      final val = vdsp.variance(x: x, n: n, sample: sample);
      if (val != null) return val;
    }

    if (mode == AccelerationMode.accelerated) {
      throw StateError('Native hardware variance execution failed.');
    }
    return PureDartFft.variance(x, sample: sample);
  }

  // --- Signal Processing ---

  /// Computes 1D valid linear convolution of [signal] and [filter].
  static Float64List convolve(
    Float64List signal,
    Float64List filter, {
    required VdspLibrary vdsp,
  }) {
    final mode = AccelerationManager.mode;
    if (mode == AccelerationMode.dart) {
      return PureDartFft.convolve(signal, filter);
    }
    if (mode == AccelerationMode.accelerated && !vdsp.isAvailable) {
      throw StateError(
        'AccelerationMode.accelerated requested but native acceleration is unavailable.',
      );
    }

    final sLen = signal.length;
    final fLen = filter.length;
    final rLen = sLen - fLen + 1;
    if (rLen <= 0) return Float64List(0);

    if (vdsp.isAvailable &&
        (sLen >= 64 || mode == AccelerationMode.accelerated)) {
      final result = Float64List(rLen);
      final ok = vdsp.conv1d(signal: signal, filter: filter, result: result);
      if (ok) return result;
    }

    if (mode == AccelerationMode.accelerated) {
      throw StateError('Native hardware convolution execution failed.');
    }
    return PureDartFft.convolve(signal, filter);
  }

  /// Computes 1D valid cross-correlation of [signal] and [filter].
  static Float64List correlate(
    Float64List signal,
    Float64List filter, {
    required VdspLibrary vdsp,
  }) {
    final mode = AccelerationManager.mode;
    if (mode == AccelerationMode.dart) {
      return PureDartFft.correlate(signal, filter);
    }
    if (mode == AccelerationMode.accelerated && !vdsp.isAvailable) {
      throw StateError(
        'AccelerationMode.accelerated requested but native acceleration is unavailable.',
      );
    }

    final sLen = signal.length;
    final fLen = filter.length;
    final rLen = sLen - fLen + 1;
    if (rLen <= 0) return Float64List(0);

    if (vdsp.isAvailable &&
        (sLen >= 64 || mode == AccelerationMode.accelerated)) {
      final result = Float64List(rLen);
      final ok = vdsp.xcorr1d(signal: signal, filter: filter, result: result);
      if (ok) return result;
    }

    if (mode == AccelerationMode.accelerated) {
      throw StateError('Native hardware cross-correlation execution failed.');
    }
    return PureDartFft.correlate(signal, filter);
  }
}
