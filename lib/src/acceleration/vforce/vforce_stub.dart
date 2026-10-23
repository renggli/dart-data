// coverage:ignore-file
import 'dart:typed_data';

/// Stub for native vForce / vDSP when FFI is unavailable.
abstract final class VforceNative {
  static bool get isAvailable => false;
  static bool get hasVForce => false;
  static bool get hasReductions => false;
  static bool get hasConvolution => false;

  static bool vsin({
    required Float64List input,
    required Float64List output,
    required int n,
  }) => false;

  static bool vcos({
    required Float64List input,
    required Float64List output,
    required int n,
  }) => false;

  static bool vexp({
    required Float64List input,
    required Float64List output,
    required int n,
  }) => false;

  static bool vlog({
    required Float64List input,
    required Float64List output,
    required int n,
  }) => false;

  static bool vsqrt({
    required Float64List input,
    required Float64List output,
    required int n,
  }) => false;

  static bool vpow({
    required Float64List base,
    required Float64List exponent,
    required Float64List output,
    required int n,
  }) => false;

  static double? sum({required Float64List x, required int n}) => null;

  static double? mean({required Float64List x, required int n}) => null;

  static double? variance({
    required Float64List x,
    required int n,
    required bool sample,
  }) => null;

  static bool convolve({
    required Float64List signal,
    required Float64List filter,
    required Float64List output,
  }) => false;

  static bool correlate({
    required Float64List signal,
    required Float64List filter,
    required Float64List output,
  }) => false;
}
