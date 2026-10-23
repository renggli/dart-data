import 'dart:typed_data';

import 'package:checks/checks.dart';
import 'package:data/acceleration.dart';
import 'package:test/test.dart';

import '../test_utils.dart';

void main() {
  group('Lapack Factorizations & Solvers', () {
    accelerationTest('dpotrf Cholesky factorization', () {
      final a = Float64List.fromList([4.0, 2.0, 2.0, 5.0]);
      final ok = Lapack.dpotrf(n: 2, a: a, lda: 2);
      check(ok).isTrue();
      // L = [[2, 0], [1, 2]]
      check(a[0]).isCloseTo(2.0, 1e-10);
      check(a[1]).isCloseTo(1.0, 1e-10);
      check(a[3]).isCloseTo(2.0, 1e-10);
    });

    accelerationTest(
      'dpotrf on non-SPD matrix returns false without throwing',
      () {
        final a = Float64List.fromList([4.0, 6.0, 6.0, 5.0]);
        final ok = Lapack.dpotrf(n: 2, a: a, lda: 2);
        check(ok).isFalse();
      },
    );

    accelerationTest('dgesv linear system solve', () {
      final a = Float64List.fromList([2.0, 1.0, 1.0, 3.0]);
      final b = Float64List.fromList([5.0, 5.0]);
      final ok = Lapack.dgesv(n: 2, nrhs: 1, a: a, lda: 2, b: b, ldb: 1);
      check(ok).isTrue();
      check(b[0]).isCloseTo(2.0, 1e-10);
      check(b[1]).isCloseTo(1.0, 1e-10);
    });

    accelerationTest(
      'dgesv on singular matrix returns false without throwing',
      () {
        final a = Float64List.fromList([1.0, 2.0, 2.0, 4.0]);
        final b = Float64List.fromList([1.0, 2.0]);
        final ok = Lapack.dgesv(n: 2, nrhs: 1, a: a, lda: 2, b: b, ldb: 1);
        check(ok).isFalse();
      },
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
      check(ok).isTrue();
      // RHS 1 solution is [0, 1], RHS 2 solution is [1, 0]
      check(b[0 * 2 + 0]).isCloseTo(0.0, 1e-9);
      check(b[0 * 2 + 1]).isCloseTo(1.0, 1e-9);
      check(b[1 * 2 + 0]).isCloseTo(1.0, 1e-9);
      check(b[1 * 2 + 1]).isCloseTo(0.0, 1e-9);
    });

    accelerationTest('dsyev symmetric eigenvalue solve', () {
      final a0 = [2.0, 1.0, 0.0, 1.0, 3.0, 1.0, 0.0, 1.0, 2.0];
      final a = Float64List.fromList(a0);
      final w = Float64List(3);
      final ok = Lapack.dsyev(n: 3, a: a, lda: 3, w: w);
      check(ok).isTrue();
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
    });

    accelerationTest('ssyev float32 eigenvalue solve', () {
      final a = Float32List.fromList([2.0, 1.0, 1.0, 2.0]);
      final w = Float32List(2);
      final ok = Lapack.ssyev(n: 2, a: a, lda: 2, w: w);
      check(ok).isTrue();
      check(w[0]).isCloseTo(1.0, 1e-5);
      check(w[1]).isCloseTo(3.0, 1e-5);
    });

    accelerationTest('Lapack routines handle n = 0 without error', () {
      final empty64 = Float64List(0);
      final empty32 = Float32List(0);
      check(Lapack.dpotrf(n: 0, a: empty64, lda: 1)).isTrue();
      check(Lapack.dgesv(n: 0, nrhs: 0, a: empty64, lda: 1, b: empty64, ldb: 1))
          .isTrue();
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
      ).isTrue();
      check(Lapack.dsyev(n: 0, a: empty64, lda: 1, w: empty64)).isTrue();
      check(Lapack.ssyev(n: 0, a: empty32, lda: 1, w: empty32)).isTrue();
    });

    test('Lapack routines validate bounds and argument constraints', () {
      final a = Float64List(4);
      final w = Float64List(2);
      check(() => Lapack.dpotrf(uplo: 999, n: 2, a: a, lda: 2))
          .throws<ArgumentError>();
      check(() => Lapack.dpotrf(n: 2, a: Float64List(2), lda: 2))
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
    });
  });
}
