import 'dart:typed_data';

import 'package:checks/checks.dart';
import 'package:data/src/acceleration/blas/cblas_constants.dart';
import 'package:data/src/acceleration/lapack/lapack_dart.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('LapackDart Edge Cases', () {
    test('dpotrf fails on non-positive-definite matrix', () {
      final a = Float64List.fromList([-1.0, 0.0, 0.0, 1.0]);
      check(LapackDart.dpotrf(uplo: cblasUpper, n: 2, a: a, aOffset: 0, lda: 2))
          .isFalse;
    });

    test('dpotrf lower triangular branch', () {
      final a = Float64List.fromList([4.0, 2.0, 2.0, 5.0]);
      check(LapackDart.dpotrf(uplo: cblasLower, n: 2, a: a, aOffset: 0, lda: 2))
          .isTrue;
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
      ).isFalse;
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
      ).isTrue;
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
      ).isTrue;
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
      ).isTrue;
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
      ).isTrue;

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
      ).isTrue;
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
      ).isTrue;
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
      ).isTrue;
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
      ).isTrue;
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
      ).isTrue;
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
        ).isTrue;
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
      ).isFalse;
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
      ).isFalse;
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
      ).isFalse;
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
      ).isFalse;
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
      ).isFalse;
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
      ).isFalse;

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
      ).isTrue;

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
      ).isFalse;
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
      ).isFalse;

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
      ).isFalse;
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
      check(success).isTrue;
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
      check(ok).isTrue;
      check(s[0]).equals(0.0);
      check(s[1]).equals(0.0);
      for (var i = 0; i < 4; i++) {
        check(u[i].isNaN).isFalse;
        check(vt[i].isNaN).isFalse;
      }
    });

    test('dgesvd avoids overflow and underflow on extreme singular values', () {
      final huge = Float64List.fromList([1e200, 0.0, 0.0, 2e200]);
      final sHuge = Float64List(2);
      final uHuge = Float64List(4);
      final vtHuge = Float64List(4);
      check(
        LapackDart.dgesvd(
          jobu: 'A',
          jobvt: 'A',
          m: 2,
          n: 2,
          a: huge,
          aOffset: 0,
          lda: 2,
          s: sHuge,
          sOffset: 0,
          u: uHuge,
          vt: vtHuge,
        ),
      ).isTrue;
      check(sHuge[0]).isCloseTo(2e200, 1e186);
      check(sHuge[1]).isCloseTo(1e200, 1e186);

      final tiny = Float64List.fromList([1e-200, 0.0, 0.0, 2e-200]);
      final sTiny = Float64List(2);
      final uTiny = Float64List(4);
      final vtTiny = Float64List(4);
      check(
        LapackDart.dgesvd(
          jobu: 'A',
          jobvt: 'A',
          m: 2,
          n: 2,
          a: tiny,
          aOffset: 0,
          lda: 2,
          s: sTiny,
          sOffset: 0,
          u: uTiny,
          vt: vtTiny,
        ),
      ).isTrue;
      check(sTiny[0]).isCloseTo(2e-200, 1e-214);
      check(sTiny[1]).isCloseTo(1e-200, 1e-214);
    });

    test(
      'dpotrf rejects non-finite entries and ignores unreferenced triangle',
      () {
        check(
          LapackDart.dpotrf(
            uplo: cblasUpper,
            n: 2,
            a: Float64List.fromList([4.0, double.infinity, 2.0, 5.0]),
            aOffset: 0,
            lda: 2,
          ),
        ).isFalse;
        check(
          LapackDart.dpotrf(
            uplo: cblasLower,
            n: 2,
            a: Float64List.fromList([4.0, 2.0, double.nan, 5.0]),
            aOffset: 0,
            lda: 2,
          ),
        ).isFalse;

        // Unreferenced triangle contains NaN
        final upper = Float64List.fromList([4.0, 2.0, double.nan, 5.0]);
        check(
          LapackDart.dpotrf(
            uplo: cblasUpper,
            n: 2,
            a: upper,
            aOffset: 0,
            lda: 2,
          ),
        ).isTrue;
        check(upper[0]).isCloseTo(2.0, 1e-10);
        check(upper[1]).isCloseTo(1.0, 1e-10);
        check(upper[3]).isCloseTo(2.0, 1e-10);
      },
    );

    test(
      'dgels handles tiny well-conditioned matrices and rank deficiency',
      () {
        final tinyA = Float64List.fromList([1e-15, 0.0, 0.0, 1e-15]);
        final tinyB = Float64List.fromList([1e-15, 2e-15]);
        check(
          LapackDart.dgels(
            m: 2,
            n: 2,
            nrhs: 1,
            a: tinyA,
            aOffset: 0,
            lda: 2,
            b: tinyB,
            bOffset: 0,
            ldb: 1,
          ),
        ).isTrue;
        check(tinyB[0]).isCloseTo(1.0, 1e-10);
        check(tinyB[1]).isCloseTo(2.0, 1e-10);

        final zeroA = Float64List(4);
        final zeroB = Float64List.fromList([1.0, 2.0]);
        check(
          LapackDart.dgels(
            m: 2,
            n: 2,
            nrhs: 1,
            a: zeroA,
            aOffset: 0,
            lda: 2,
            b: zeroB,
            bOffset: 0,
            ldb: 1,
          ),
        ).isFalse;
      },
    );

    test('dsyev and ssyev support jobz N, lower triangle, sorting, zero, and scaling', () {
      // Unreferenced triangle contains NaN for both cblasUpper and cblasLower
      final upperMat = Float64List.fromList([
        5.0, 0.0, 0.0, //
        double.nan, 1.0, 0.0,
        double.nan, double.nan, 3.0,
      ]);
      final wUpper = Float64List(3);
      check(
        LapackDart.dsyev(
          jobz: 'N',
          uplo: cblasUpper,
          n: 3,
          a: upperMat,
          aOffset: 0,
          lda: 3,
          w: wUpper,
          wOffset: 0,
        ),
      ).isTrue;
      check(wUpper[0]).isCloseTo(1.0, 1e-10);
      check(wUpper[1]).isCloseTo(3.0, 1e-10);
      check(wUpper[2]).isCloseTo(5.0, 1e-10);

      final lowerMat = Float32List.fromList([
        2.0, double.nan, //
        1.0, 2.0,
      ]);
      final wLower = Float32List(2);
      check(
        LapackDart.ssyev(
          jobz: 'V',
          uplo: cblasLower,
          n: 2,
          a: lowerMat,
          aOffset: 0,
          lda: 2,
          w: wLower,
          wOffset: 0,
        ),
      ).isTrue;
      check(wLower[0]).isCloseTo(1.0, 1e-5);
      check(wLower[1]).isCloseTo(3.0, 1e-5);

      // Zero matrix and extreme scaling
      final zeroSym = Float64List(4);
      final wZero = Float64List(2);
      check(
        LapackDart.dsyev(
          jobz: 'V',
          uplo: cblasUpper,
          n: 2,
          a: zeroSym,
          aOffset: 0,
          lda: 2,
          w: wZero,
          wOffset: 0,
        ),
      ).isTrue;
      check(wZero).deepEquals([0.0, 0.0]);
      check(zeroSym).deepEquals([1.0, 0.0, 0.0, 1.0]);

      final hugeSym = Float64List.fromList([1e200, 1e200, 1e200, 1e200]);
      final wHuge = Float64List(2);
      check(
        LapackDart.dsyev(
          jobz: 'V',
          uplo: cblasUpper,
          n: 2,
          a: hugeSym,
          aOffset: 0,
          lda: 2,
          w: wHuge,
          wOffset: 0,
        ),
      ).isTrue;
      check(wHuge[0]).isCloseTo(0.0, 1e186);
      check(wHuge[1]).isCloseTo(2e200, 1e186);

      // jobz == 'V' with out-of-order diagonal exercises eigenvector column swaps
      final unsortedSym = Float64List.fromList([
        5.0, 0.0, 0.0, //
        0.0, 1.0, 0.0,
        0.0, 0.0, 3.0,
      ]);
      final wUnsorted = Float64List(3);
      check(
        LapackDart.dsyev(
          jobz: 'V',
          uplo: cblasUpper,
          n: 3,
          a: unsortedSym,
          aOffset: 0,
          lda: 3,
          w: wUnsorted,
          wOffset: 0,
        ),
      ).isTrue;
      check(wUnsorted).deepEquals([1.0, 3.0, 5.0]);

      // Rank-deficient column-zero matrix in dgesvd exercises kase==2 & zero column U fill
      final zeroColSvd = Float64List.fromList([0.0, 3.0, 0.0, 4.0]);
      final sZeroCol = Float64List(2);
      final uZeroCol = Float64List(4);
      final vtZeroCol = Float64List(4);
      check(
        LapackDart.dgesvd(
          jobu: 'A',
          jobvt: 'A',
          m: 2,
          n: 2,
          a: zeroColSvd,
          aOffset: 0,
          lda: 2,
          s: sZeroCol,
          sOffset: 0,
          u: uZeroCol,
          ldu: 2,
          vt: vtZeroCol,
          ldvt: 2,
        ),
      ).isTrue;
      check(sZeroCol[0]).isCloseTo(5.0, 1e-10);
      check(sZeroCol[1]).isCloseTo(0.0, 1e-10);
    });
  });
}
