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

    test('pureDartDsyev with lower triangle and diagonal matrix', () {
      // Diagonal 3x3 matrix: off-diagonal elements in row are zero (scale == 0.0)
      final a = Float64List.fromList([
        1.0,
        0.0,
        0.0,
        0.0,
        2.0,
        0.0,
        0.0,
        0.0,
        3.0,
      ]);
      final w = Float64List(3);
      final ok = PureDartLapack.dsyev(
        jobz: 'V',
        uplo: cblasLower,
        n: 3,
        a: a,
        aOffset: 0,
        lda: 3,
        w: w,
        wOffset: 0,
      );
      check(ok).isTrue();
      check(w[0]).isCloseTo(1.0, 1e-10);
      check(w[1]).isCloseTo(2.0, 1e-10);
      check(w[2]).isCloseTo(3.0, 1e-10);
    });

    test(
      'pureDartDgels overdetermined (m >= n) and underdetermined (m < n)',
      () {
        // Overdetermined: 3 x 2
        // [1 1; 1 2; 1 3] * [c0; c1] = [2; 3; 5] -> c0 = 1/3, c1 = 1.5
        final aOver = Float64List.fromList([1.0, 1.0, 1.0, 2.0, 1.0, 3.0]);
        final bOver = Float64List.fromList([2.0, 3.0, 5.0]);
        final okOver = PureDartLapack.dgels(
          m: 3,
          n: 2,
          nrhs: 1,
          a: aOver,
          aOffset: 0,
          lda: 2,
          b: bOver,
          bOffset: 0,
          ldb: 1,
        );
        check(okOver).isTrue();
        check(bOver[0]).isCloseTo(1.0 / 3.0, 1e-10);
        check(bOver[1]).isCloseTo(1.5, 1e-10);

        // Underdetermined: 2 x 3
        // A = [1 0 0; 0 1 0], b = [4; 7] -> x = [4, 7, 0]
        final aUnder = Float64List.fromList([1.0, 0.0, 0.0, 0.0, 1.0, 0.0]);
        final bUnder = Float64List(3);
        bUnder[0] = 4.0;
        bUnder[1] = 7.0;
        final okUnder = PureDartLapack.dgels(
          m: 2,
          n: 3,
          nrhs: 1,
          a: aUnder,
          aOffset: 0,
          lda: 3,
          b: bUnder,
          bOffset: 0,
          ldb: 1,
        );
        check(okUnder).isTrue();
        check(bUnder[0]).isCloseTo(4.0, 1e-10);
        check(bUnder[1]).isCloseTo(7.0, 1e-10);
        check(bUnder[2]).isCloseTo(0.0, 1e-10);
      },
    );
  });
}
