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
      final meanVal = vdsp.meanv(x: x, n: n);
      final measqVal = vdsp.measqv(x: x, n: n);
      if (meanVal != null && measqVal != null) {
        final popVar = measqVal - meanVal * meanVal;
        return sample ? (popVar * n / (n - 1)) : popVar;
      }
    }

    if (mode == AccelerationMode.accelerated) {
      throw StateError('Native hardware variance execution failed.');
    }
    return PureDartFft.variance(x, sample: sample);
  }
}
