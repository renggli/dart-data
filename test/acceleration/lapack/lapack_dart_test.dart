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

    test('dgels overdetermined system (m > n)', () {
      final a = Float64List.fromList([1.0, 1.0, 1.0, 2.0, 1.0, 3.0]);
      final b = Float64List.fromList([6.0, 0.0, 0.0]);
      check(
        LapackDart.dgels(
          m: 3,
          n: 2,
          nrhs: 1,
          a: a,
          aOffset: 0,
          lda: 2,
          b: b,
          bOffset: 0,
          ldb: 1,
        ),
      ).isTrue();
      check(b[0]).isCloseTo(8.0, 1e-10);
      check(b[1]).isCloseTo(-3.0, 1e-10);
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
      check(b[0]).isCloseTo(1.0 / 3.0, 1e-10);
      check(b[1]).isCloseTo(4.0 / 3.0, 1e-10);
      check(b[2]).isCloseTo(5.0 / 3.0, 1e-10);
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

    test('dpotrf only accesses referenced triangle', () {
      // Upper triangle valid, lower triangle contains NaNs
      final aUpper = Float64List.fromList([
        4.0, 2.0, // row 0: a[0,0]=4, a[0,1]=2
        double.nan, 5.0, // row 1: lower triangle NaN, a[1,1]=5
      ]);
      check(
        LapackDart.dpotrf(
          uplo: cblasUpper,
          n: 2,
          a: aUpper,
          aOffset: 0,
          lda: 2,
        ),
      ).isTrue();
      check(aUpper[0]).isCloseTo(2.0, 1e-10);
      check(aUpper[1]).isCloseTo(1.0, 1e-10);
      check(aUpper[3]).isCloseTo(2.0, 1e-10);

      // Lower triangle valid, upper triangle contains NaNs
      final aLower = Float64List.fromList([
        4.0, double.nan, // row 0: a[0,0]=4, upper triangle NaN
        2.0, 5.0, // row 1: a[1,0]=2, a[1,1]=5
      ]);
      check(
        LapackDart.dpotrf(
          uplo: cblasLower,
          n: 2,
          a: aLower,
          aOffset: 0,
          lda: 2,
        ),
      ).isTrue();
      check(aLower[0]).isCloseTo(2.0, 1e-10);
      check(aLower[2]).isCloseTo(1.0, 1e-10);
      check(aLower[3]).isCloseTo(2.0, 1e-10);
    });

    test('dsyev and ssyev only access referenced triangle', () {
      // Upper triangle valid, lower triangle NaN
      final aUpper = Float64List.fromList([
        2.0, 1.0, //
        double.nan, 2.0, //
      ]);
      final wUpper = Float64List(2);
      check(
        LapackDart.dsyev(
          jobz: 'N',
          uplo: cblasUpper,
          n: 2,
          a: aUpper,
          aOffset: 0,
          lda: 2,
          w: wUpper,
          wOffset: 0,
        ),
      ).isTrue();
      check(wUpper[0]).isCloseTo(1.0, 1e-10);
      check(wUpper[1]).isCloseTo(3.0, 1e-10);

      // Lower triangle valid, upper triangle NaN
      final aLower = Float64List.fromList([
        2.0, double.nan, //
        1.0, 2.0, //
      ]);
      final wLower = Float64List(2);
      check(
        LapackDart.dsyev(
          jobz: 'N',
          uplo: cblasLower,
          n: 2,
          a: aLower,
          aOffset: 0,
          lda: 2,
          w: wLower,
          wOffset: 0,
        ),
      ).isTrue();
      check(wLower[0]).isCloseTo(1.0, 1e-10);
      check(wLower[1]).isCloseTo(3.0, 1e-10);
    });

    test(
      'dgesv handles padded lda and ldb without accessing out of bounds',
      () {
        // 2x2 system with lda=3, so size needed is (2-1)*3 + 2 = 5 elements
        final a = Float64List.fromList([
          3.0, 1.0, 999.0, // row 0: 3, 1, pad
          1.0, 2.0, // row 1: 1, 2 (no trailing pad)
        ]);
        // 2x1 rhs with ldb=2, so size needed is (2-1)*2 + 1 = 3 elements
        final b = Float64List.fromList([
          9.0, 999.0, // row 0: 9, pad
          8.0, // row 1: 8 (no trailing pad)
        ]);
        check(
          LapackDart.dgesv(
            n: 2,
            nrhs: 1,
            a: a,
            aOffset: 0,
            lda: 3,
            b: b,
            bOffset: 0,
            ldb: 2,
          ),
        ).isTrue();
        check(b[0]).isCloseTo(2.0, 1e-10);
        check(b[2]).isCloseTo(3.0, 1e-10);
      },
    );

    test('dgesvd invalid arguments and edge cases in pure Dart', () {
      final a = Float64List(4);
      final s = Float64List(2);
      final u = Float64List(4);
      final vt = Float64List(4);

      // Invalid dimensions and leading dimensions
      check(
        LapackDart.dgesvd(
          jobu: 'A',
          jobvt: 'A',
          m: -1,
          n: 2,
          a: a,
          aOffset: 0,
          lda: 2,
          s: s,
          sOffset: 0,
          u: u,
          vt: vt,
        ),
      ).isFalse();
      check(
        LapackDart.dgesvd(
          jobu: 'A',
          jobvt: 'A',
          m: 2,
          n: 2,
          a: a,
          aOffset: 0,
          lda: 1,
          s: s,
          sOffset: 0,
          u: u,
          vt: vt,
        ),
      ).isFalse();
      check(
        LapackDart.dgesvd(
          jobu: 'INVALID',
          jobvt: 'A',
          m: 2,
          n: 2,
          a: a,
          aOffset: 0,
          lda: 2,
          s: s,
          sOffset: 0,
          u: u,
          vt: vt,
        ),
      ).isFalse();
      check(
        LapackDart.dgesvd(
          jobu: 'A',
          jobvt: 'INVALID',
          m: 2,
          n: 2,
          a: a,
          aOffset: 0,
          lda: 2,
          s: s,
          sOffset: 0,
          u: u,
          vt: vt,
        ),
      ).isFalse();
      check(
        LapackDart.dgesvd(
          jobu: 'A',
          jobvt: 'A',
          m: 2,
          n: 2,
          a: a,
          aOffset: 0,
          lda: 2,
          s: s,
          sOffset: 0,
          u: null,
          vt: vt,
        ),
      ).isFalse();
      check(
        LapackDart.dgesvd(
          jobu: 'A',
          jobvt: 'A',
          m: 2,
          n: 2,
          a: a,
          aOffset: 0,
          lda: 2,
          s: s,
          sOffset: 0,
          u: u,
          vt: null,
        ),
      ).isFalse();

      // m = 0 or n = 0
      check(
        LapackDart.dgesvd(
          jobu: 'N',
          jobvt: 'N',
          m: 0,
          n: 2,
          a: a,
          aOffset: 0,
          lda: 2,
          s: s,
          sOffset: 0,
        ),
      ).isTrue();

      // Buffer bounds
      check(
        LapackDart.dgesvd(
          jobu: 'N',
          jobvt: 'N',
          m: 2,
          n: 2,
          a: Float64List(2),
          aOffset: 0,
          lda: 2,
          s: s,
          sOffset: 0,
        ),
      ).isFalse();
      check(
        LapackDart.dgesvd(
          jobu: 'N',
          jobvt: 'N',
          m: 2,
          n: 2,
          a: a,
          aOffset: 0,
          lda: 2,
          s: Float64List(1),
          sOffset: 0,
        ),
      ).isFalse();

      // NaN in input
      final nanA = Float64List.fromList([double.nan, 1.0, 2.0, 3.0]);
      check(
        LapackDart.dgesvd(
          jobu: 'N',
          jobvt: 'N',
          m: 2,
          n: 2,
          a: nanA,
          aOffset: 0,
          lda: 2,
          s: s,
          sOffset: 0,
        ),
      ).isFalse();
    });

    test('dgesvd wide matrix m < n with jobu A in pure Dart', () {
      final a = Float64List.fromList([1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0]);
      final s = Float64List(2);
      final u = Float64List(4);
      final vt = Float64List(16);
      final success = LapackDart.dgesvd(
        jobu: 'A',
        jobvt: 'A',
        m: 2,
        n: 4,
        a: a,
        aOffset: 0,
        lda: 4,
        s: s,
        sOffset: 0,
        u: u,
        ldu: 2,
        vt: vt,
        ldvt: 4,
      );
      check(success).isTrue();
    });

    test('dgesvd all-zero matrix does not produce NaNs', () {
      final a = Float64List(4);
      final s = Float64List(2);
      final u = Float64List(4);
      final vt = Float64List(4);
      final ok = LapackDart.dgesvd(
        jobu: 'A',
        jobvt: 'A',
        m: 2,
        n: 2,
        a: a,
        aOffset: 0,
        lda: 2,
        s: s,
        sOffset: 0,
        u: u,
        ldu: 2,
        vt: vt,
        ldvt: 2,
      );
      check(ok).isTrue();
      check(s[0]).equals(0.0);
      check(s[1]).equals(0.0);
      for (var i = 0; i < 4; i++) {
        check(u[i].isNaN).isFalse();
        check(vt[i].isNaN).isFalse();
      }
    });
  });
}
