import 'dart:typed_data';

import 'package:checks/checks.dart';
import 'package:data/acceleration.dart';
import 'package:test/test.dart';

import '../test_utils.dart';

void main() {
  group('LapackRoutines', () {
    accelerationTest('dpotrf Cholesky factorization of SPD matrix', () {
      final a = Float64List.fromList([4.0, 12.0, 12.0, 45.0]);

      final ok = AccelerationManager.dpotrf(
        uplo: cblasUpper,
        n: 2,
        a: a,
        lda: 2,
      );
      check(ok).isTrue();
      // U^T U = A: U_00 = 2, U_01 = 6, U_11 = 3 (since 6*6 + 3*3 = 45)
      check(a[0]).isCloseTo(2.0, 1e-10);
      check(a[1]).isCloseTo(6.0, 1e-10);
      check(a[3]).isCloseTo(3.0, 1e-10);
    });

    accelerationTest(
      'dpotrf returns false for non-positive-definite matrix',
      () {
        final a = Float64List.fromList([-1.0, 0.0, 0.0, 2.0]);
        final ok = AccelerationManager.dpotrf(
          uplo: cblasUpper,
          n: 2,
          a: a,
          lda: 2,
        );
        check(ok).isFalse();
      },
    );

    accelerationTest('dgesv solve linear system', () {
      final a = Float64List.fromList([3.0, 1.0, 1.0, 2.0]);
      final b = Float64List.fromList([9.0, 8.0]);

      final ok = AccelerationManager.dgesv(
        n: 2,
        nrhs: 1,
        a: a,
        lda: 2,
        b: b,
        ldb: 1,
      );
      check(ok).isTrue();
      // 3*x + y = 9, x + 2*y = 8  => x = 2, y = 3
      check(b[0]).isCloseTo(2.0, 1e-10);
      check(b[1]).isCloseTo(3.0, 1e-10);
    });

    accelerationTest('dgels least squares solve', () {
      // Overdetermined system:
      // x = 1
      // x = 2
      // x = 3
      // Normal equations: 3*x = 6 => x = 2
      final a = Float64List.fromList([1.0, 1.0, 1.0]);
      final b = Float64List.fromList([1.0, 2.0, 3.0]);

      final ok = AccelerationManager.dgels(
        m: 3,
        n: 1,
        nrhs: 1,
        a: a,
        lda: 1,
        b: b,
        ldb: 1,
      );
      check(ok).isTrue();
      check(b[0]).isCloseTo(2.0, 1e-10);
    });

    accelerationTest('dsyev eigenvalue solver', () {
      final a = Float64List.fromList([3.0, 2.0, 2.0, 6.0]);
      final w = Float64List(2);

      final ok = AccelerationManager.dsyev(n: 2, a: a, lda: 2, w: w);
      check(ok).isTrue();
      // Characteristic equation: (3-L)(6-L) - 4 = L^2 - 9L + 14 = (L-2)(L-7) =
      // 0
      // Eigenvalues: 2.0 and 7.0
      check(w[0]).isCloseTo(2.0, 1e-10);
      check(w[1]).isCloseTo(7.0, 1e-10);
    });

    accelerationTest('ssyev single-precision eigenvalue solver', () {
      final a = Float32List.fromList([3.0, 2.0, 2.0, 6.0]);
      final w = Float32List(2);

      final ok = AccelerationManager.ssyev(n: 2, a: a, lda: 2, w: w);
      check(ok).isTrue();
      check(w[0]).isCloseTo(2.0, 1e-5);
      check(w[1]).isCloseTo(7.0, 1e-5);
    });
  });
}
