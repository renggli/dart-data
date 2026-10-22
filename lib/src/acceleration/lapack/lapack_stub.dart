// coverage:ignore-file
import 'dart:typed_data';

/// Stub for native LAPACK when FFI is unavailable.
abstract final class LapackNative {
  static bool get isAvailable => false;
  static bool get hasDpotrf => false;
  static bool get hasDgesv => false;
  static bool get hasDgels => false;
  static bool get hasDsyev => false;
  static bool get hasSsyev => false;

  static bool? dpotrf({
    required int uplo,
    required int n,
    required Float64List a,
    required int aOffset,
    required int lda,
  }) => null;

  static bool? dgesv({
    required int n,
    required int nrhs,
    required Float64List a,
    required int aOffset,
    required int lda,
    required Float64List b,
    required int bOffset,
    required int ldb,
  }) => null;

  static bool? dgels({
    required int m,
    required int n,
    required int nrhs,
    required Float64List a,
    required int aOffset,
    required int lda,
    required Float64List b,
    required int bOffset,
    required int ldb,
  }) => null;

  static bool? dsyev({
    required String jobz,
    required int uplo,
    required int n,
    required Float64List a,
    required int aOffset,
    required int lda,
    required Float64List w,
    required int wOffset,
  }) => null;

  static bool? ssyev({
    required String jobz,
    required int uplo,
    required int n,
    required Float32List a,
    required int aOffset,
    required int lda,
    required Float32List w,
    required int wOffset,
  }) => null;
}
