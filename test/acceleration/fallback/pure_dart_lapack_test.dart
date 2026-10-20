import 'dart:typed_data';

import 'package:checks/checks.dart';
import 'package:data/src/acceleration/blas/cblas.dart';
import 'package:data/src/acceleration/fallback/pure_dart_lapack.dart';
import 'package:test/test.dart';

void main() {
  group('PureDartLapack', () {
    test('pureDartDsyev 1x1 base case', () {
      final a = Float64List.fromList([42.0]);
      final w = Float64List(1);
      final ok = PureDartLapack.dsyev(
        jobz: 'V',
        uplo: cblasUpper,
        n: 1,
        a: a,
        aOffset: 0,
        lda: 1,
        w: w,
        wOffset: 0,
      );
      check(ok).isTrue();
      check(w[0]).isCloseTo(42.0, 1e-10);
      check(a[0]).isCloseTo(1.0, 1e-10);
    });

    test('pureDartDsyev 2x2 eigenvalue and eigenvectors', () {
      final a = Float64List.fromList([2.0, 1.0, 1.0, 2.0]);
      final w = Float64List(2);
      final ok = PureDartLapack.dsyev(
        jobz: 'V',
        uplo: cblasUpper,
        n: 2,
        a: a,
        aOffset: 0,
        lda: 2,
        w: w,
        wOffset: 0,
      );
      check(ok).isTrue();
      check(w[0]).isCloseTo(1.0, 1e-10);
      check(w[1]).isCloseTo(3.0, 1e-10);
    });

    test('pureDartSsyev 2x2 single-precision', () {
      final a = Float32List.fromList([2.0, 1.0, 1.0, 2.0]);
      final w = Float32List(2);
      final ok = PureDartLapack.ssyev(
        jobz: 'V',
        uplo: cblasUpper,
        n: 2,
        a: a,
        aOffset: 0,
        lda: 2,
        w: w,
        wOffset: 0,
      );
      check(ok).isTrue();
      check(w[0]).isCloseTo(1.0, 1e-5);
      check(w[1]).isCloseTo(3.0, 1e-5);
    });

    test('pureDartLuSolve solves system and detects singular matrix', () {
      final a = Float64List.fromList([2.0, 1.0, 1.0, 3.0]);
      final b = Float64List.fromList([5.0, 10.0]);
      final ok = PureDartLapack.luSolve(2, 1, a, 0, 2, b, 0, 1);
      check(ok).isTrue();
      check(b[0]).isCloseTo(1.0, 1e-10);
      check(b[1]).isCloseTo(3.0, 1e-10);

      // Singular matrix
      final aSingular = Float64List.fromList([1.0, 2.0, 2.0, 4.0]);
      final bSingular = Float64List.fromList([3.0, 6.0]);
      final singularOk = PureDartLapack.luSolve(
        2,
        1,
        aSingular,
        0,
        2,
        bSingular,
        0,
        1,
      );
      check(singularOk).isFalse();
    });

    test('pureDartDpotrf Cholesky factorization', () {
      final a = Float64List.fromList([4.0, 12.0, 12.0, 45.0]);
      final ok = PureDartLapack.dpotrf(uplo: cblasUpper, n: 2, a: a, lda: 2);
      check(ok).isTrue();
      check(a[0]).isCloseTo(2.0, 1e-10);
      check(a[1]).isCloseTo(6.0, 1e-10);
      check(a[3]).isCloseTo(3.0, 1e-10);

      final notPosDef = Float64List.fromList([-1.0, 0.0, 0.0, 2.0]);
      check(PureDartLapack.dpotrf(uplo: cblasUpper, n: 2, a: notPosDef, lda: 2))
          .isFalse();
    });
  });
}
