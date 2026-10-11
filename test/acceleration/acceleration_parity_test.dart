import 'dart:typed_data';

import 'package:checks/checks.dart';
import 'package:data/acceleration.dart';
import 'package:test/test.dart';

void main() {
  group('Backend Acceleration Parity', () {
    tearDown(() {
      AccelerationManager.mode = AccelerationMode.auto;
    });

    group('Level 1 Vector Operations Parity', () {
      test('ddot parity between dart and auto/accelerated', () {
        final x = Float64List.fromList([1.5, -2.0, 3.25, 4.0, -0.5]);
        final y = Float64List.fromList([2.0, 3.5, -1.0, 0.5, 6.0]);

        AccelerationManager.mode = AccelerationMode.dart;
        final dartDot = AccelerationManager.ddot(n: 5, x: x, y: y)!;

        AccelerationManager.mode = AccelerationMode.auto;
        final autoDot = AccelerationManager.ddot(n: 5, x: x, y: y)!;

        check(autoDot).isCloseTo(dartDot, 1e-10);

        if (AccelerationManager.isNativeAvailable) {
          AccelerationManager.mode = AccelerationMode.accelerated;
          final accDot = AccelerationManager.ddot(n: 5, x: x, y: y)!;
          check(accDot).isCloseTo(dartDot, 1e-10);
        }
      });

      test('sdot parity between dart and auto/accelerated', () {
        final x = Float32List.fromList([1.5, -2.0, 3.25, 4.0]);
        final y = Float32List.fromList([2.0, 3.5, -1.0, 0.5]);

        AccelerationManager.mode = AccelerationMode.dart;
        final dartDot = AccelerationManager.sdot(n: 4, x: x, y: y)!;

        AccelerationManager.mode = AccelerationMode.auto;
        final autoDot = AccelerationManager.sdot(n: 4, x: x, y: y)!;

        check(autoDot).isCloseTo(dartDot, 1e-5);
      });

      test('dnrm2 and snrm2 parity', () {
        final x64 = Float64List.fromList([3.0, 4.0, 12.0]);
        AccelerationManager.mode = AccelerationMode.dart;
        final dartNorm64 = AccelerationManager.dnrm2(n: 3, x: x64)!;

        AccelerationManager.mode = AccelerationMode.auto;
        final autoNorm64 = AccelerationManager.dnrm2(n: 3, x: x64)!;
        check(autoNorm64).isCloseTo(dartNorm64, 1e-10);

        final x32 = Float32List.fromList([3.0, 4.0]);
        AccelerationManager.mode = AccelerationMode.dart;
        final dartNorm32 = AccelerationManager.snrm2(n: 2, x: x32)!;

        AccelerationManager.mode = AccelerationMode.auto;
        final autoNorm32 = AccelerationManager.snrm2(n: 2, x: x32)!;
        check(autoNorm32).isCloseTo(dartNorm32, 1e-5);
      });

      test('daxpy and saxpy parity', () {
        final x = Float64List.fromList([1.0, 2.0, 3.0]);
        final yDart = Float64List.fromList([4.0, 5.0, 6.0]);
        final yAuto = Float64List.fromList([4.0, 5.0, 6.0]);

        AccelerationManager.mode = AccelerationMode.dart;
        AccelerationManager.daxpy(n: 3, alpha: 2.5, x: x, y: yDart);

        AccelerationManager.mode = AccelerationMode.auto;
        AccelerationManager.daxpy(n: 3, alpha: 2.5, x: x, y: yAuto);

        for (var i = 0; i < 3; i++) {
          check(yAuto[i]).isCloseTo(yDart[i], 1e-10);
        }
      });
    });

    group('Level 2 Matrix-Vector Parity', () {
      test('dgemv parity', () {
        final a = Float64List.fromList([1.0, 2.0, 3.0, 4.0, 5.0, 6.0]);
        final x = Float64List.fromList([2.0, -1.0, 3.0]);

        final yDart = Float64List.fromList([1.0, 2.0]);
        final yAuto = Float64List.fromList([1.0, 2.0]);

        AccelerationManager.mode = AccelerationMode.dart;
        AccelerationManager.dgemv(
          m: 2,
          n: 3,
          alpha: 1.5,
          a: a,
          lda: 3,
          x: x,
          incX: 1,
          beta: 0.5,
          y: yDart,
          incY: 1,
        );

        AccelerationManager.mode = AccelerationMode.auto;
        AccelerationManager.dgemv(
          m: 2,
          n: 3,
          alpha: 1.5,
          a: a,
          lda: 3,
          x: x,
          incX: 1,
          beta: 0.5,
          y: yAuto,
          incY: 1,
        );

        for (var i = 0; i < 2; i++) {
          check(yAuto[i]).isCloseTo(yDart[i], 1e-10);
        }
      });

      test('dtrmv parity', () {
        final a = Float64List.fromList([3.0, 2.0, 0.0, 4.0]);
        final xDart = Float64List.fromList([2.0, 5.0]);
        final xAuto = Float64List.fromList([2.0, 5.0]);

        AccelerationManager.mode = AccelerationMode.dart;
        AccelerationManager.dtrmv(n: 2, a: a, lda: 2, x: xDart);

        AccelerationManager.mode = AccelerationMode.auto;
        AccelerationManager.dtrmv(n: 2, a: a, lda: 2, x: xAuto);

        for (var i = 0; i < 2; i++) {
          check(xAuto[i]).isCloseTo(xDart[i], 1e-10);
        }
      });
    });

    group('Level 3 Matrix-Matrix Parity', () {
      test('dgemm parity', () {
        final a = Float64List.fromList([1.0, 2.0, 3.0, 4.0, 5.0, 6.0]); // 3x2
        final b = Float64List.fromList([
          7.0,
          8.0,
          9.0,
          10.0,
          11.0,
          12.0,
        ]); // 2x3

        final cDart = Float64List(9);
        final cAuto = Float64List(9);

        AccelerationManager.mode = AccelerationMode.dart;
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
          c: cDart,
          ldc: 3,
        );

        AccelerationManager.mode = AccelerationMode.auto;
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
          c: cAuto,
          ldc: 3,
        );

        for (var i = 0; i < 9; i++) {
          check(cAuto[i]).isCloseTo(cDart[i], 1e-10);
        }

        if (AccelerationManager.isNativeAvailable) {
          final cAcc = Float64List(9);
          AccelerationManager.mode = AccelerationMode.accelerated;
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
            c: cAcc,
            ldc: 3,
          );
          for (var i = 0; i < 9; i++) {
            check(cAcc[i]).isCloseTo(cDart[i], 1e-10);
          }
        }
      });

      test('dsyrk parity', () {
        final a = Float64List.fromList([1.0, 2.0, 3.0, 4.0]);
        final cDart = Float64List(4);
        final cAuto = Float64List(4);

        AccelerationManager.mode = AccelerationMode.dart;
        AccelerationManager.dsyrk(
          n: 2,
          k: 2,
          alpha: 1.0,
          a: a,
          lda: 2,
          beta: 0.0,
          c: cDart,
          ldc: 2,
        );

        AccelerationManager.mode = AccelerationMode.auto;
        AccelerationManager.dsyrk(
          n: 2,
          k: 2,
          alpha: 1.0,
          a: a,
          lda: 2,
          beta: 0.0,
          c: cAuto,
          ldc: 2,
        );

        // Check upper triangle
        check(cAuto[0]).isCloseTo(cDart[0], 1e-10);
        check(cAuto[1]).isCloseTo(cDart[1], 1e-10);
        check(cAuto[3]).isCloseTo(cDart[3], 1e-10);
      });
    });

    group('LAPACK Parity', () {
      test('dpotrf Cholesky parity', () {
        // Symmetric positive-definite matrix:
        // [4, 2]
        // [2, 5]
        final aDart = Float64List.fromList([4.0, 2.0, 2.0, 5.0]);
        final aAuto = Float64List.fromList([4.0, 2.0, 2.0, 5.0]);

        AccelerationManager.mode = AccelerationMode.dart;
        final dartOk = AccelerationManager.dpotrf(n: 2, a: aDart, lda: 2);
        check(dartOk).isTrue();

        AccelerationManager.mode = AccelerationMode.auto;
        final autoOk = AccelerationManager.dpotrf(n: 2, a: aAuto, lda: 2);
        check(autoOk).isTrue();

        // Upper triangle factor U: U[0,0] = 2.0, U[0,1] = 1.0, U[1,1] = 2.0
        check(aAuto[0]).isCloseTo(aDart[0], 1e-10);
        check(aAuto[1]).isCloseTo(aDart[1], 1e-10);
        check(aAuto[3]).isCloseTo(aDart[3], 1e-10);
      });

      test('dgesv linear solve parity', () {
        // [2, 1] [x0] = [5]  => x0 = 1, x1 = 3
        // [1, 3] [x1] = [10]
        final aDart = Float64List.fromList([2.0, 1.0, 1.0, 3.0]);
        final bDart = Float64List.fromList([5.0, 10.0]);

        final aAuto = Float64List.fromList([2.0, 1.0, 1.0, 3.0]);
        final bAuto = Float64List.fromList([5.0, 10.0]);

        AccelerationManager.mode = AccelerationMode.dart;
        final dartOk = AccelerationManager.dgesv(
          n: 2,
          nrhs: 1,
          a: aDart,
          lda: 2,
          b: bDart,
          ldb: 1,
        );
        check(dartOk).isTrue();

        AccelerationManager.mode = AccelerationMode.auto;
        final autoOk = AccelerationManager.dgesv(
          n: 2,
          nrhs: 1,
          a: aAuto,
          lda: 2,
          b: bAuto,
          ldb: 1,
        );
        check(autoOk).isTrue();

        check(bAuto[0]).isCloseTo(bDart[0], 1e-10);
        check(bAuto[1]).isCloseTo(bDart[1], 1e-10);
      });

      test('dsyev eigenvalue parity', () {
        // [2, 1]
        // [1, 2]
        // Eigenvalues are 1.0 and 3.0
        final aDart = Float64List.fromList([2.0, 1.0, 1.0, 2.0]);
        final wDart = Float64List(2);

        final aAuto = Float64List.fromList([2.0, 1.0, 1.0, 2.0]);
        final wAuto = Float64List(2);

        AccelerationManager.mode = AccelerationMode.dart;
        final dartOk = AccelerationManager.dsyev(
          n: 2,
          a: aDart,
          lda: 2,
          w: wDart,
        );
        check(dartOk).isTrue();

        AccelerationManager.mode = AccelerationMode.auto;
        final autoOk = AccelerationManager.dsyev(
          n: 2,
          a: aAuto,
          lda: 2,
          w: wAuto,
        );
        check(autoOk).isTrue();

        check(wAuto[0]).isCloseTo(wDart[0], 1e-10);
        check(wAuto[1]).isCloseTo(wDart[1], 1e-10);
      });
    });
  });
}
