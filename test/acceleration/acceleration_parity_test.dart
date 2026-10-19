import 'dart:typed_data';

import 'package:checks/checks.dart';
import 'package:data/acceleration.dart';
import 'package:test/test.dart';

import 'test_utils.dart';

void main() {
  group('Backend Acceleration Parity', () {
    group('Level 1 Vector Operations Parity', () {
      accelerationTest('ddot', () {
        final x = Float64List.fromList([1.5, -2.0, 3.25, 4.0, -0.5]);
        final y = Float64List.fromList([2.0, 3.5, -1.0, 0.5, 6.0]);
        final dot = AccelerationManager.ddot(n: 5, x: x, y: y)!;
        check(dot).isCloseTo(-8.25, 1e-10);
      });

      accelerationTest('sdot', () {
        final x = Float32List.fromList([1.5, -2.0, 3.25, 4.0]);
        final y = Float32List.fromList([2.0, 3.5, -1.0, 0.5]);
        final dot = AccelerationManager.sdot(n: 4, x: x, y: y)!;
        check(dot).isCloseTo(-5.25, 1e-5);
      });

      accelerationTest('dnrm2 and snrm2', () {
        final x64 = Float64List.fromList([3.0, 4.0, 12.0]);
        final norm64 = AccelerationManager.dnrm2(n: 3, x: x64)!;
        check(norm64).isCloseTo(13.0, 1e-10);

        final x32 = Float32List.fromList([3.0, 4.0]);
        final norm32 = AccelerationManager.snrm2(n: 2, x: x32)!;
        check(norm32).isCloseTo(5.0, 1e-5);
      });

      accelerationTest('daxpy and saxpy', () {
        final x = Float64List.fromList([1.0, 2.0, 3.0]);
        final y = Float64List.fromList([4.0, 5.0, 6.0]);
        AccelerationManager.daxpy(n: 3, alpha: 2.5, x: x, y: y);
        check(y[0]).isCloseTo(6.5, 1e-10);
        check(y[1]).isCloseTo(10.0, 1e-10);
        check(y[2]).isCloseTo(13.5, 1e-10);
      });
    });

    group('Level 2 Matrix-Vector Parity', () {
      accelerationTest('dgemv', () {
        final a = Float64List.fromList([1.0, 2.0, 3.0, 4.0, 5.0, 6.0]);
        final x = Float64List.fromList([2.0, -1.0, 3.0]);
        final y = Float64List.fromList([1.0, 2.0]);

        AccelerationManager.dgemv(
          m: 2,
          n: 3,
          alpha: 1.5,
          a: a,
          lda: 3,
          x: x,
          incX: 1,
          beta: 0.5,
          y: y,
          incY: 1,
        );

        check(y[0]).isCloseTo(14.0, 1e-10);
        check(y[1]).isCloseTo(32.5, 1e-10);
      });

      accelerationTest('dtrmv', () {
        final a = Float64List.fromList([3.0, 2.0, 0.0, 4.0]);
        final x = Float64List.fromList([2.0, 5.0]);

        AccelerationManager.dtrmv(n: 2, a: a, lda: 2, x: x);

        check(x[0]).isCloseTo(16.0, 1e-10);
        check(x[1]).isCloseTo(20.0, 1e-10);
      });
    });

    group('Level 3 Matrix-Matrix Parity', () {
      accelerationTest('dgemm', () {
        final a = Float64List.fromList([1.0, 2.0, 3.0, 4.0, 5.0, 6.0]);
        final b = Float64List.fromList([7.0, 8.0, 9.0, 10.0, 11.0, 12.0]);
        final c = Float64List(9);

        AccelerationManager.dgemm(
          m: 3,
          n: 3,
          k: 2,
          alpha: 1.0,
          a: a,
          lda: 2,
          b: b,
          ldb: 3,
          beta: 0.0,
          c: c,
          ldc: 3,
        );

        check(c[0]).isCloseTo(27.0, 1e-10);
        check(c[1]).isCloseTo(30.0, 1e-10);
        check(c[2]).isCloseTo(33.0, 1e-10);
        check(c[3]).isCloseTo(61.0, 1e-10);
        check(c[4]).isCloseTo(68.0, 1e-10);
        check(c[5]).isCloseTo(75.0, 1e-10);
        check(c[6]).isCloseTo(95.0, 1e-10);
        check(c[7]).isCloseTo(106.0, 1e-10);
        check(c[8]).isCloseTo(117.0, 1e-10);
      });

      accelerationTest('dsyrk', () {
        final a = Float64List.fromList([1.0, 2.0, 3.0, 4.0]);
        final c = Float64List(4);

        AccelerationManager.dsyrk(
          n: 2,
          k: 2,
          alpha: 1.0,
          a: a,
          lda: 2,
          beta: 0.0,
          c: c,
          ldc: 2,
        );

        check(c[0]).isCloseTo(5.0, 1e-10);
        check(c[1]).isCloseTo(11.0, 1e-10);
        check(c[3]).isCloseTo(25.0, 1e-10);
      });
    });

    group('LAPACK Parity', () {
      accelerationTest('dpotrf Cholesky', () {
        final a = Float64List.fromList([4.0, 2.0, 2.0, 5.0]);
        final ok = AccelerationManager.dpotrf(n: 2, a: a, lda: 2);
        check(ok).isTrue();

        check(a[0]).isCloseTo(2.0, 1e-10);
        check(a[1]).isCloseTo(1.0, 1e-10);
        check(a[3]).isCloseTo(2.0, 1e-10);
      });

      accelerationTest('dgesv linear solve', () {
        final a = Float64List.fromList([2.0, 1.0, 1.0, 3.0]);
        final b = Float64List.fromList([5.0, 10.0]);

        final ok = AccelerationManager.dgesv(
          n: 2,
          nrhs: 1,
          a: a,
          lda: 2,
          b: b,
          ldb: 1,
        );
        check(ok).isTrue();

        check(b[0]).isCloseTo(1.0, 1e-10);
        check(b[1]).isCloseTo(3.0, 1e-10);
      });

      accelerationTest('dsyev eigenvalue', () {
        final a = Float64List.fromList([2.0, 1.0, 1.0, 2.0]);
        final w = Float64List(2);

        final ok = AccelerationManager.dsyev(n: 2, a: a, lda: 2, w: w);
        check(ok).isTrue();

        check(w[0]).isCloseTo(1.0, 1e-10);
        check(w[1]).isCloseTo(3.0, 1e-10);
      });
    });
  });
}
