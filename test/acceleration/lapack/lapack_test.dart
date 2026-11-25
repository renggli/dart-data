import 'dart:typed_data';

import 'package:checks/checks.dart';
import 'package:data/acceleration.dart';
import 'package:test/scaffolding.dart';

import '../test_utils.dart';

void main() {
  group('Lapack Factorizations & Solvers', () {
    accelerationTest('dpotrf Cholesky factorization', () {
      final a = Float64List.fromList([4.0, 2.0, 2.0, 5.0]);
      final ok = Lapack.dpotrf(n: 2, a: a, lda: 2);
      check(ok).isTrue;
      // L = [[2, 0], [1, 2]]
      check(a[0]).isCloseTo(2.0, 1e-10);
      check(a[1]).isCloseTo(1.0, 1e-10);
      check(a[3]).isCloseTo(2.0, 1e-10);
    }, isSupported: Lapack.isAvailable);

    accelerationTest(
      'dpotrf on non-SPD matrix returns false without throwing',
      () {
        final a = Float64List.fromList([4.0, 6.0, 6.0, 5.0]);
        final ok = Lapack.dpotrf(n: 2, a: a, lda: 2);
        check(ok).isFalse;
      },
      isSupported: Lapack.isAvailable,
    );

    accelerationTest('dgesv linear system solve', () {
      final a = Float64List.fromList([2.0, 1.0, 1.0, 3.0]);
      final b = Float64List.fromList([5.0, 5.0]);
      final ok = Lapack.dgesv(n: 2, nrhs: 1, a: a, lda: 2, b: b, ldb: 1);
      check(ok).isTrue;
      check(b[0]).isCloseTo(2.0, 1e-10);
      check(b[1]).isCloseTo(1.0, 1e-10);
    }, isSupported: Lapack.isAvailable);

    accelerationTest(
      'dgesv on singular matrix returns false without throwing',
      () {
        final a = Float64List.fromList([1.0, 2.0, 2.0, 4.0]);
        final b = Float64List.fromList([1.0, 2.0]);
        final ok = Lapack.dgesv(n: 2, nrhs: 1, a: a, lda: 2, b: b, ldb: 1);
        check(ok).isFalse;
      },
      isSupported: Lapack.isAvailable,
    );

    accelerationTest('dgels linear least squares overdetermined', () {
      // 3 equations, 2 unknowns, 2 RHS, lda = 3 > n, ldb = 2
      final a = Float64List.fromList([
        1.0, 1.0, 99.0, // row 0 (padded)
        1.0, 2.0, 99.0, // row 1 (padded)
        1.0, 3.0, 99.0, // row 2 (padded)
      ]);
      final b = Float64List.fromList([
        1.0, 1.0, // row 0: RHS1=1, RHS2=1
        2.0, 1.0, // row 1: RHS1=2, RHS2=1
        3.0, 1.0, // row 2: RHS1=3, RHS2=1
      ]);
      final ok = Lapack.dgels(m: 3, n: 2, nrhs: 2, a: a, lda: 3, b: b, ldb: 2);
      check(ok).isTrue;
      // RHS 1 solution is [0, 1], RHS 2 solution is [1, 0]
      check(b[0 * 2 + 0]).isCloseTo(0.0, 1e-9);
      check(b[0 * 2 + 1]).isCloseTo(1.0, 1e-9);
      check(b[1 * 2 + 0]).isCloseTo(1.0, 1e-9);
      check(b[1 * 2 + 1]).isCloseTo(0.0, 1e-9);
    }, isSupported: Lapack.isAvailable);

    accelerationTest('dsyev symmetric eigenvalue solve', () {
      final a0 = [2.0, 1.0, 0.0, 1.0, 3.0, 1.0, 0.0, 1.0, 2.0];
      final a = Float64List.fromList(a0);
      final w = Float64List(3);
      final ok = Lapack.dsyev(n: 3, a: a, lda: 3, w: w);
      check(ok).isTrue;
      // Eigenvalues of tridiagonal [[2,1,0],[1,3,1],[0,1,2]] are 1, 2, 4
      check(w[0]).isCloseTo(1.0, 1e-9);
      check(w[1]).isCloseTo(2.0, 1e-9);
      check(w[2]).isCloseTo(4.0, 1e-9);

      // Verify that eigenvectors are stored in columns of a: A0 * v_j = lambda_j * v_j
      for (var j = 0; j < 3; j++) {
        final lambda = w[j];
        for (var i = 0; i < 3; i++) {
          var avI = 0.0;
          for (var k = 0; k < 3; k++) {
            avI += a0[i * 3 + k] * a[k * 3 + j];
          }
          final lvI = lambda * a[i * 3 + j];
          check(avI).isCloseTo(lvI, 1e-9);
        }
      }
    }, isSupported: Lapack.isAvailable);

    accelerationTest('ssyev float32 eigenvalue solve', () {
      final a0 = [2.0, 1.0, 1.0, 2.0];
      final a = Float32List.fromList(a0);
      final w = Float32List(2);
      final ok = Lapack.ssyev(n: 2, a: a, lda: 2, w: w);
      check(ok).isTrue;
      check(w[0]).isCloseTo(1.0, 1e-5);
      check(w[1]).isCloseTo(3.0, 1e-5);

      for (var j = 0; j < 2; j++) {
        final lambda = w[j];
        for (var i = 0; i < 2; i++) {
          var avI = 0.0;
          for (var k = 0; k < 2; k++) {
            avI += a0[i * 2 + k] * a[k * 2 + j];
          }
          final lvI = lambda * a[i * 2 + j];
          check(avI).isCloseTo(lvI, 1e-5);
        }
      }
    }, isSupported: Lapack.isAvailable);

    accelerationTest('dgesvd singular value decomposition', () {
      // 3x2 matrix A:
      // [1, 2]
      // [3, 4]
      // [5, 6]
      final a0 = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0];
      final a = Float64List.fromList(a0);
      final s = Float64List(2);
      final u = Float64List(3 * 3);
      final vt = Float64List(2 * 2);

      final ok = Lapack.dgesvd(
        m: 3,
        n: 2,
        a: a,
        lda: 2,
        s: s,
        u: u,
        ldu: 3,
        vt: vt,
        ldvt: 2,
      );
      check(ok).isTrue;

      // Singular values descending
      check(s[0]).isGreaterThan(s[1]);
      check(s[0]).isCloseTo(9.525518, 1e-4);
      check(s[1]).isCloseTo(0.514300, 1e-4);

      // Verify A = U * S * VT
      // U is 3x3 (ldu=3), VT is 2x2 (ldvt=2)
      for (var r = 0; r < 3; r++) {
        for (var c = 0; c < 2; c++) {
          var sum = 0.0;
          for (var k = 0; k < 2; k++) {
            sum += u[r * 3 + k] * s[k] * vt[k * 2 + c];
          }
          check(sum).isCloseTo(a0[r * 2 + c], 1e-5);
        }
      }

      // Check U is orthogonal: U^T * U = I_3
      for (var r = 0; r < 3; r++) {
        for (var c = 0; c < 3; c++) {
          var dot = 0.0;
          for (var k = 0; k < 3; k++) {
            dot += u[k * 3 + r] * u[k * 3 + c];
          }
          check(dot).isCloseTo(r == c ? 1.0 : 0.0, 1e-5);
        }
      }

      // Check VT is orthogonal: VT * VT^T = I_2
      for (var r = 0; r < 2; r++) {
        for (var c = 0; c < 2; c++) {
          var dot = 0.0;
          for (var k = 0; k < 2; k++) {
            dot += vt[r * 2 + k] * vt[c * 2 + k];
          }
          check(dot).isCloseTo(r == c ? 1.0 : 0.0, 1e-5);
        }
      }
    }, isSupported: Lapack.isAvailable);

    accelerationTest('dgesvd values-only with jobu: N, jobvt: N', () {
      final a = Float64List.fromList([1.0, 2.0, 3.0, 4.0, 5.0, 6.0]);
      final s = Float64List(2);

      final ok = Lapack.dgesvd(
        jobu: 'N',
        jobvt: 'N',
        m: 3,
        n: 2,
        a: a,
        lda: 2,
        s: s,
      );
      check(ok).isTrue;
      check(s[0]).isCloseTo(9.525518, 1e-4);
      check(s[1]).isCloseTo(0.514300, 1e-4);
    }, isSupported: Lapack.isAvailable);

    accelerationTest('dgesvd wide matrix (m < n)', () {
      final a0 = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0];
      final a = Float64List.fromList(a0);
      final s = Float64List(2);
      final u = Float64List(2 * 2);
      final vt = Float64List(3 * 3);

      final ok = Lapack.dgesvd(
        m: 2,
        n: 3,
        a: a,
        lda: 3,
        s: s,
        u: u,
        ldu: 2,
        vt: vt,
        ldvt: 3,
      );
      check(ok).isTrue;

      // Verify A = U * S * VT
      for (var r = 0; r < 2; r++) {
        for (var c = 0; c < 3; c++) {
          var sum = 0.0;
          for (var k = 0; k < 2; k++) {
            sum += u[r * 2 + k] * s[k] * vt[k * 3 + c];
          }
          check(sum).isCloseTo(a0[r * 3 + c], 1e-5);
        }
      }
    }, isSupported: Lapack.isAvailable);

    accelerationTest('Lapack routines handle n = 0 without error', () {
      final empty64 = Float64List(0);
      final empty32 = Float32List(0);
      check(Lapack.dpotrf(n: 0, a: empty64, lda: 1)).isTrue;
      check(Lapack.dgesv(n: 0, nrhs: 0, a: empty64, lda: 1, b: empty64, ldb: 1))
          .isTrue;
      check(
        Lapack.dgels(
          m: 0,
          n: 0,
          nrhs: 0,
          a: empty64,
          lda: 1,
          b: empty64,
          ldb: 1,
        ),
      ).isTrue;
      check(Lapack.dsyev(n: 0, a: empty64, lda: 1, w: empty64)).isTrue;
      check(Lapack.ssyev(n: 0, a: empty32, lda: 1, w: empty32)).isTrue;
      check(
        Lapack.dgesvd(
          m: 0,
          n: 0,
          a: empty64,
          lda: 1,
          s: empty64,
          jobu: 'N',
          jobvt: 'N',
        ),
      ).isTrue;
    }, isSupported: Lapack.isAvailable);

    accelerationTest('dgesvd does not mutate input matrix a', () {
      final a = Float64List.fromList([1.0, 2.0, 3.0, 4.0, 5.0, 6.0]);
      final aExpected = Float64List.fromList(a);
      final s = Float64List(2);
      final ok = Lapack.dgesvd(
        jobu: 'N',
        jobvt: 'N',
        m: 3,
        n: 2,
        a: a,
        lda: 2,
        s: s,
      );
      check(ok).isTrue;
      check(a).deepEquals(aExpected);
    }, isSupported: Lapack.isAvailable);

    accelerationTest('dgels does not mutate input matrix a', () {
      final a = Float64List.fromList([1.0, 1.0, 1.0, 2.0, 1.0, 3.0]);
      final aExpected = Float64List.fromList(a);
      final b = Float64List.fromList([1.0, 2.0, 3.0]);
      final ok = Lapack.dgels(m: 3, n: 2, nrhs: 1, a: a, lda: 2, b: b, ldb: 1);
      check(ok).isTrue;
      check(a).deepEquals(aExpected);
    }, isSupported: Lapack.isAvailable);

    accelerationTest('Lapack returns false on NaN inputs', () {
      final nanMat1 = Float64List.fromList([double.nan, 0.0, 0.0, 1.0]);
      check(Lapack.dpotrf(uplo: cblasUpper, n: 2, a: nanMat1, lda: 2)).isFalse;
      final nanMat2 = Float64List.fromList([double.nan, 0.0, 0.0, 1.0]);
      final b1 = Float64List.fromList([1.0, 1.0]);
      check(Lapack.dgesv(n: 2, nrhs: 1, a: nanMat2, lda: 2, b: b1, ldb: 1))
          .isFalse;
      final validA1 = Float64List.fromList([1.0, 0.0, 0.0, 1.0]);
      final nanB1 = Float64List.fromList([double.nan, 1.0]);
      check(Lapack.dgesv(n: 2, nrhs: 1, a: validA1, lda: 2, b: nanB1, ldb: 1))
          .isFalse;
      final nanMat3 = Float64List.fromList([double.nan, 0.0, 0.0, 1.0]);
      final b2 = Float64List.fromList([1.0, 1.0]);
      check(
        Lapack.dgels(m: 2, n: 2, nrhs: 1, a: nanMat3, lda: 2, b: b2, ldb: 1),
      ).isFalse;
      final validA2 = Float64List.fromList([1.0, 0.0, 0.0, 1.0]);
      final nanB2 = Float64List.fromList([double.nan, 1.0]);
      check(
        Lapack.dgels(m: 2, n: 2, nrhs: 1, a: validA2, lda: 2, b: nanB2, ldb: 1),
      ).isFalse;

      final infPotrf = Float64List.fromList([4.0, 0.0, 0.0, double.infinity]);
      check(Lapack.dpotrf(uplo: cblasUpper, n: 2, a: infPotrf, lda: 2)).isFalse;
      final infOffPotrf = Float64List.fromList([
        4.0,
        double.infinity,
        0.0,
        5.0,
      ]);
      check(Lapack.dpotrf(uplo: cblasUpper, n: 2, a: infOffPotrf, lda: 2))
          .isFalse;
      final singleInfPotrf = Float64List.fromList([double.infinity]);
      check(Lapack.dpotrf(uplo: cblasUpper, n: 1, a: singleInfPotrf, lda: 1))
          .isFalse;

      final nanSym1 = Float64List.fromList([double.nan]);
      final w1 = Float64List(1);
      check(Lapack.dsyev(n: 1, a: nanSym1, lda: 1, w: w1)).isFalse;

      final nanSym2 = Float64List.fromList([double.nan, 0.0, 0.0, 1.0]);
      final w2 = Float64List(2);
      check(Lapack.dsyev(n: 2, a: nanSym2, lda: 2, w: w2)).isFalse;

      final infSym2 = Float64List.fromList([double.infinity, 1.0, 1.0, 2.0]);
      check(Lapack.dsyev(n: 2, a: infSym2, lda: 2, w: w2)).isFalse;

      final nanSym32 = Float32List.fromList([double.nan, 0.0, 0.0, 1.0]);
      final w2f = Float32List(2);
      check(Lapack.ssyev(n: 2, a: nanSym32, lda: 2, w: w2f)).isFalse;

      final nanSvd = Float64List.fromList([double.nan, 1.0, 2.0, 3.0]);
      final sSvd = Float64List(2);
      check(
        Lapack.dgesvd(
          m: 2,
          n: 2,
          a: nanSvd,
          lda: 2,
          s: sSvd,
          jobu: 'N',
          jobvt: 'N',
        ),
      ).isFalse;
    }, isSupported: Lapack.isAvailable);

    accelerationTest('dpotrf and dsyev ignore unreferenced triangle', () {
      final upperSpd = Float64List.fromList([4.0, 2.0, double.nan, 5.0]);
      check(Lapack.dpotrf(uplo: cblasUpper, n: 2, a: upperSpd, lda: 2)).isTrue;
      check(upperSpd[0]).isCloseTo(2.0, 1e-10);
      check(upperSpd[1]).isCloseTo(1.0, 1e-10);
      check(upperSpd[3]).isCloseTo(2.0, 1e-10);

      final lowerSym = Float64List.fromList([2.0, double.nan, 1.0, 2.0]);
      final wSym = Float64List(2);
      check(
        Lapack.dsyev(
          jobz: 'V',
          uplo: cblasLower,
          n: 2,
          a: lowerSym,
          lda: 2,
          w: wSym,
        ),
      ).isTrue;
      check(wSym[0]).isCloseTo(1.0, 1e-10);
      check(wSym[1]).isCloseTo(3.0, 1e-10);

      final lowerSym32 = Float32List.fromList([2.0, double.nan, 1.0, 2.0]);
      final wSym32 = Float32List(2);
      check(
        Lapack.ssyev(
          jobz: 'N',
          uplo: cblasLower,
          n: 2,
          a: lowerSym32,
          lda: 2,
          w: wSym32,
        ),
      ).isTrue;
      check(wSym32[0]).isCloseTo(1.0, 1e-5);
      check(wSym32[1]).isCloseTo(3.0, 1e-5);
    }, isSupported: Lapack.isAvailable);

    accelerationTest(
      'dsyev and dgesvd handle zero and extreme-scale matrices',
      () {
        final zeroSym = Float64List(4);
        final wZero = Float64List(2);
        check(Lapack.dsyev(jobz: 'N', n: 2, a: zeroSym, lda: 2, w: wZero))
            .isTrue;
        check(wZero).deepEquals([0.0, 0.0]);

        final hugeSym = Float64List.fromList([1e200, 1e200, 1e200, 1e200]);
        final wHuge = Float64List(2);
        check(Lapack.dsyev(n: 2, a: hugeSym, lda: 2, w: wHuge)).isTrue;
        check(wHuge[0]).isCloseTo(0.0, 1e186);
        check(wHuge[1]).isCloseTo(2e200, 1e186);

        final zeroSvd = Float64List(4);
        final sZero = Float64List(2);
        final uZero = Float64List(4);
        final vtZero = Float64List(4);
        check(
          Lapack.dgesvd(
            m: 2,
            n: 2,
            a: zeroSvd,
            lda: 2,
            s: sZero,
            u: uZero,
            ldu: 2,
            vt: vtZero,
            ldvt: 2,
          ),
        ).isTrue;
        check(sZero).deepEquals([0.0, 0.0]);

        final hugeSvd = Float64List.fromList([1e200, 0.0, 0.0, 2e200]);
        final sHuge = Float64List(2);
        check(
          Lapack.dgesvd(
            jobu: 'N',
            jobvt: 'N',
            m: 2,
            n: 2,
            a: hugeSvd,
            lda: 2,
            s: sHuge,
          ),
        ).isTrue;
        check(sHuge[0]).isCloseTo(2e200, 1e186);
        check(sHuge[1]).isCloseTo(1e200, 1e186);

        final tinySvd = Float64List.fromList([1e-200, 0.0, 0.0, 2e-200]);
        final sTiny = Float64List(2);
        check(
          Lapack.dgesvd(
            jobu: 'N',
            jobvt: 'N',
            m: 2,
            n: 2,
            a: tinySvd,
            lda: 2,
            s: sTiny,
          ),
        ).isTrue;
        check(sTiny[0]).isCloseTo(2e-200, 1e-214);
        check(sTiny[1]).isCloseTo(1e-200, 1e-214);
      },
      isSupported: Lapack.isAvailable,
    );

    accelerationTest(
      'dgels solves tiny scaled systems and rejects zero matrices',
      () {
        final tinyA = Float64List.fromList([1e-15, 0.0, 0.0, 1e-15]);
        final tinyB = Float64List.fromList([1e-15, 2e-15]);
        check(
          Lapack.dgels(m: 2, n: 2, nrhs: 1, a: tinyA, lda: 2, b: tinyB, ldb: 1),
        ).isTrue;
        check(tinyB[0]).isCloseTo(1.0, 1e-10);
        check(tinyB[1]).isCloseTo(2.0, 1e-10);

        final zeroA = Float64List(4);
        final zeroB = Float64List.fromList([1.0, 2.0]);
        check(
          Lapack.dgels(m: 2, n: 2, nrhs: 1, a: zeroA, lda: 2, b: zeroB, ldb: 1),
        ).isFalse;
      },
      isSupported: Lapack.isAvailable,
    );

    test('Lapack routines validate bounds and argument constraints', () {
      final a = Float64List(4);
      final w = Float64List(2);
      check(() => Lapack.dpotrf(uplo: 999, n: 2, a: a, lda: 2))
          .throws<ArgumentError>();
      check(() => Lapack.dpotrf(n: 2, a: Float64List(2), lda: 2))
          .throws<RangeError>();
      check(() => Lapack.dpotrf(n: 0, a: a, aOffset: -1, lda: 1))
          .throws<RangeError>();
      check(
        () => Lapack.dgesv(
          n: 2,
          nrhs: 1,
          a: a,
          lda: 2,
          b: Float64List(1),
          ldb: 1,
        ),
      ).throws<RangeError>();
      check(() => Lapack.dsyev(jobz: 'X', n: 2, a: a, lda: 2, w: w))
          .throws<ArgumentError>();
      check(() => Lapack.dsyev(n: 2, a: a, lda: 2, w: Float64List(1)))
          .throws<RangeError>();
      check(() => Lapack.dsyev(n: 0, a: a, lda: 1, w: w, wOffset: -1))
          .throws<RangeError>();
      check(() => Lapack.dpotrf(n: -1, a: a, lda: 2)).throws<ArgumentError>();
      check(() => Lapack.dgesv(n: -1, nrhs: 1, a: a, lda: 2, b: w, ldb: 1))
          .throws<ArgumentError>();
      check(() => Lapack.dgesv(n: 2, nrhs: -1, a: a, lda: 2, b: w, ldb: 1))
          .throws<ArgumentError>();
      check(
        () => Lapack.dgels(m: -1, n: 2, nrhs: 1, a: a, lda: 2, b: w, ldb: 1),
      ).throws<ArgumentError>();
      check(
        () => Lapack.dgels(m: 2, n: -1, nrhs: 1, a: a, lda: 2, b: w, ldb: 1),
      ).throws<ArgumentError>();
      check(
        () => Lapack.dgels(m: 2, n: 2, nrhs: -1, a: a, lda: 2, b: w, ldb: 1),
      ).throws<ArgumentError>();
      check(() => Lapack.dsyev(n: -1, a: a, lda: 2, w: w))
          .throws<ArgumentError>();
      final af = Float32List(4);
      final wf = Float32List(2);
      check(() => Lapack.ssyev(jobz: 'X', n: 2, a: af, lda: 2, w: wf))
          .throws<ArgumentError>();
      check(() => Lapack.ssyev(n: -1, a: af, lda: 2, w: wf))
          .throws<ArgumentError>();
      check(() => Lapack.dgesvd(jobu: 'X', m: 2, n: 2, a: a, lda: 2, s: w))
          .throws<ArgumentError>();
      check(() => Lapack.dgesvd(jobvt: 'X', m: 2, n: 2, a: a, lda: 2, s: w))
          .throws<ArgumentError>();
      check(() => Lapack.dgesvd(m: -1, n: 2, a: a, lda: 2, s: w))
          .throws<ArgumentError>();
      check(() => Lapack.dgesvd(m: 2, n: -1, a: a, lda: 2, s: w))
          .throws<ArgumentError>();
      check(() => Lapack.dgesvd(m: 2, n: 2, a: a, lda: 1, s: w))
          .throws<ArgumentError>();
      check(() => Lapack.dgesvd(m: 2, n: 2, a: a, lda: 2, s: Float64List(1)))
          .throws<RangeError>();
      check(
        () => Lapack.dgesvd(m: 2, n: 2, a: a, lda: 2, s: w, jobu: 'A', u: null),
      ).throws<ArgumentError>();
      check(
        () => Lapack.dgesvd(
          m: 2,
          n: 2,
          a: a,
          lda: 2,
          s: w,
          jobu: 'N',
          jobvt: 'A',
          vt: null,
        ),
      ).throws<ArgumentError>();
    });
  });
}
