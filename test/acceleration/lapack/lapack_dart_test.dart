import 'dart:typed_data';

import 'package:checks/checks.dart';
import 'package:data/src/acceleration/blas/cblas_constants.dart';
import 'package:data/src/acceleration/lapack/lapack_dart.dart';
import 'package:test/test.dart';

void main() {
  group('LapackDart Edge Cases', () {
    test('dpotrf fails on non-positive-definite matrix', () {
      final a = Float64List.fromList([-1.0, 0.0, 0.0, 1.0]);
      check(LapackDart.dpotrf(uplo: cblasUpper, n: 2, a: a, aOffset: 0, lda: 2))
          .isFalse();
    });

    test('dpotrf lower triangular branch', () {
      final a = Float64List.fromList([4.0, 2.0, 2.0, 5.0]);
      check(LapackDart.dpotrf(uplo: cblasLower, n: 2, a: a, aOffset: 0, lda: 2))
          .isTrue();
      check(a[0]).isCloseTo(2.0, 1e-10);
      check(a[2]).isCloseTo(1.0, 1e-10);
      check(a[3]).isCloseTo(2.0, 1e-10);
    });

    test('dgesv fails on singular matrix', () {
      final a = Float64List.fromList([1.0, 2.0, 2.0, 4.0]);
      final b = Float64List.fromList([3.0, 6.0]);
      check(
        LapackDart.dgesv(
          n: 2,
          nrhs: 1,
          a: a,
          aOffset: 0,
          lda: 2,
          b: b,
          bOffset: 0,
          ldb: 1,
        ),
      ).isFalse();
    });

    test('dgels underdetermined system (m < n)', () {
      // 2 equations, 3 unknowns
      final a = Float64List.fromList([1.0, 0.0, 1.0, 0.0, 1.0, 1.0]);
      final b = Float64List.fromList([2.0, 3.0, 0.0]);
      check(
        LapackDart.dgels(
          m: 2,
          n: 3,
          nrhs: 1,
          a: a,
          aOffset: 0,
          lda: 3,
          b: b,
          bOffset: 0,
          ldb: 1,
        ),
      ).isTrue();
      check(b[0]).isA<double>();
      check(b[1]).isA<double>();
    });

    test('dsyev n = 0 and n = 1 scalar case', () {
      final a0 = Float64List(0);
      final w0 = Float64List(0);
      check(
        LapackDart.dsyev(
          jobz: 'V',
          uplo: cblasUpper,
          n: 0,
          a: a0,
          aOffset: 0,
          lda: 1,
          w: w0,
          wOffset: 0,
        ),
      ).isTrue();
      check(
        LapackDart.ssyev(
          jobz: 'V',
          uplo: cblasUpper,
          n: 0,
          a: Float32List(0),
          aOffset: 0,
          lda: 1,
          w: Float32List(0),
          wOffset: 0,
        ),
      ).isTrue();

      final a = Float64List.fromList([42.0]);
      final w = Float64List(1);
      check(
        LapackDart.dsyev(
          jobz: 'V',
          uplo: cblasUpper,
          n: 1,
          a: a,
          aOffset: 0,
          lda: 1,
          w: w,
          wOffset: 0,
        ),
      ).isTrue();
      check(w[0]).equals(42.0);
      check(a[0]).equals(1.0);
    });
  });
}
