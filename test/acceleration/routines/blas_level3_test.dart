import 'dart:typed_data';

import 'package:checks/checks.dart';
import 'package:data/acceleration.dart';
import 'package:test/test.dart';

import '../test_utils.dart';

void main() {
  group('BlasLevel3 Routines', () {
    accelerationTest('dgemm general matrix multiply', () {
      final a = Float64List.fromList([1.0, 2.0, 3.0, 4.0]);
      final b = Float64List.fromList([2.0, 0.0, 1.0, 2.0]);
      final c = Float64List(4);

      final ok = AccelerationManager.dgemm(
        m: 2,
        n: 2,
        k: 2,
        alpha: 1.0,
        a: a,
        lda: 2,
        b: b,
        ldb: 2,
        beta: 0.0,
        c: c,
        ldc: 2,
      );
      check(ok).isTrue();
      // [1*2 + 2*1, 1*0 + 2*2, 3*2 + 4*1, 3*0 + 4*2] = [4, 4, 10, 8]
      check(c[0]).isCloseTo(4.0, 1e-10);
      check(c[1]).isCloseTo(4.0, 1e-10);
      check(c[2]).isCloseTo(10.0, 1e-10);
      check(c[3]).isCloseTo(8.0, 1e-10);
    });

    accelerationTest('sgemm single-precision general matrix multiply', () {
      final a = Float32List.fromList([1.0, 2.0, 3.0, 4.0]);
      final b = Float32List.fromList([2.0, 0.0, 1.0, 2.0]);
      final c = Float32List(4);

      final ok = AccelerationManager.sgemm(
        m: 2,
        n: 2,
        k: 2,
        alpha: 1.0,
        a: a,
        lda: 2,
        b: b,
        ldb: 2,
        beta: 0.0,
        c: c,
        ldc: 2,
      );
      check(ok).isTrue();
      check(c[0]).isCloseTo(4.0, 1e-5);
      check(c[1]).isCloseTo(4.0, 1e-5);
      check(c[2]).isCloseTo(10.0, 1e-5);
      check(c[3]).isCloseTo(8.0, 1e-5);
    });

    accelerationTest('dsyrk symmetric rank-k update', () {
      final a = Float64List.fromList([1.0, 2.0, 3.0, 4.0]);
      final c = Float64List(4);

      final ok = AccelerationManager.dsyrk(
        uplo: cblasUpper,
        n: 2,
        k: 2,
        alpha: 1.0,
        a: a,
        lda: 2,
        beta: 0.0,
        c: c,
        ldc: 2,
      );
      check(ok).isTrue();
      // C = A * A^T
      // C_00 = 1*1 + 2*2 = 5
      // C_01 = 1*3 + 2*4 = 11
      // C_11 = 3*3 + 4*4 = 25
      check(c[0]).isCloseTo(5.0, 1e-10);
      check(c[1]).isCloseTo(11.0, 1e-10);
      check(c[3]).isCloseTo(25.0, 1e-10);
    });

    accelerationTest('ssyrk single-precision symmetric rank-k update', () {
      final a = Float32List.fromList([1.0, 2.0, 3.0, 4.0]);
      final c = Float32List(4);

      final ok = AccelerationManager.ssyrk(
        uplo: cblasUpper,
        n: 2,
        k: 2,
        alpha: 1.0,
        a: a,
        lda: 2,
        beta: 0.0,
        c: c,
        ldc: 2,
      );
      check(ok).isTrue();
      check(c[0]).isCloseTo(5.0, 1e-5);
      check(c[1]).isCloseTo(11.0, 1e-5);
      check(c[3]).isCloseTo(25.0, 1e-5);
    });

    accelerationTest('dsymm symmetric matrix-matrix multiply', () {
      final a = Float64List.fromList([2.0, 1.0, 1.0, 3.0]);
      final b = Float64List.fromList([1.0, 2.0, 3.0, 4.0]);
      final c = Float64List(4);

      final ok = AccelerationManager.dsymm(
        side: cblasLeft,
        uplo: cblasUpper,
        m: 2,
        n: 2,
        alpha: 1.0,
        a: a,
        lda: 2,
        b: b,
        ldb: 2,
        beta: 0.0,
        c: c,
        ldc: 2,
      );
      check(ok).isTrue();
      // [2*1 + 1*3, 2*2 + 1*4, 1*1 + 3*3, 1*2 + 3*4] = [5, 8, 10, 14]
      check(c[0]).isCloseTo(5.0, 1e-10);
      check(c[1]).isCloseTo(8.0, 1e-10);
      check(c[2]).isCloseTo(10.0, 1e-10);
      check(c[3]).isCloseTo(14.0, 1e-10);
    });

    accelerationTest('ssymm single-precision symmetric matrix multiply', () {
      final a = Float32List.fromList([2.0, 1.0, 1.0, 3.0]);
      final b = Float32List.fromList([1.0, 2.0, 3.0, 4.0]);
      final c = Float32List(4);

      final ok = AccelerationManager.ssymm(
        side: cblasLeft,
        uplo: cblasUpper,
        m: 2,
        n: 2,
        alpha: 1.0,
        a: a,
        lda: 2,
        b: b,
        ldb: 2,
        beta: 0.0,
        c: c,
        ldc: 2,
      );
      check(ok).isTrue();
      check(c[0]).isCloseTo(5.0, 1e-5);
      check(c[1]).isCloseTo(8.0, 1e-5);
      check(c[2]).isCloseTo(10.0, 1e-5);
      check(c[3]).isCloseTo(14.0, 1e-5);
    });

    accelerationTest('dtrmm triangular matrix-matrix multiply', () {
      final a = Float64List.fromList([2.0, 1.0, 0.0, 3.0]);
      final b = Float64List.fromList([1.0, 2.0, 3.0, 4.0]);

      final ok = AccelerationManager.dtrmm(
        side: cblasLeft,
        uplo: cblasUpper,
        m: 2,
        n: 2,
        alpha: 1.0,
        a: a,
        lda: 2,
        b: b,
        ldb: 2,
      );
      check(ok).isTrue();
      // B <- A * B
      // B_00 = 2*1 + 1*3 = 5
      // B_01 = 2*2 + 1*4 = 8
      // B_10 = 0*1 + 3*3 = 9
      // B_11 = 0*2 + 3*4 = 12
      check(b[0]).isCloseTo(5.0, 1e-10);
      check(b[1]).isCloseTo(8.0, 1e-10);
      check(b[2]).isCloseTo(9.0, 1e-10);
      check(b[3]).isCloseTo(12.0, 1e-10);
    });

    accelerationTest(
      'strmm single-precision triangular matrix-matrix multiply',
      () {
        final a = Float32List.fromList([2.0, 1.0, 0.0, 3.0]);
        final b = Float32List.fromList([1.0, 2.0, 3.0, 4.0]);

        final ok = AccelerationManager.strmm(
          side: cblasLeft,
          uplo: cblasUpper,
          m: 2,
          n: 2,
          alpha: 1.0,
          a: a,
          lda: 2,
          b: b,
          ldb: 2,
        );
        check(ok).isTrue();
        check(b[0]).isCloseTo(5.0, 1e-5);
        check(b[1]).isCloseTo(8.0, 1e-5);
        check(b[2]).isCloseTo(9.0, 1e-5);
        check(b[3]).isCloseTo(12.0, 1e-5);
      },
    );

    accelerationTest(
      'dsymm and ssymm with side: cblasRight, uplo: cblasLower',
      () {
        final a = Float64List.fromList([2.0, 1.0, 1.0, 3.0]);
        final b = Float64List.fromList([1.0, 2.0, 3.0, 4.0]);
        final c = Float64List(4);

        final okD = AccelerationManager.dsymm(
          side: cblasRight,
          uplo: cblasLower,
          m: 2,
          n: 2,
          alpha: 1.0,
          a: a,
          lda: 2,
          b: b,
          ldb: 2,
          beta: 0.0,
          c: c,
          ldc: 2,
        );
        check(okD).isTrue();
        // B * A:
        // [1*2 + 2*1, 1*1 + 2*3, 3*2 + 4*1, 3*1 + 4*3] = [4, 7, 10, 15]
        check(c[0]).isCloseTo(4.0, 1e-10);
        check(c[1]).isCloseTo(7.0, 1e-10);
        check(c[2]).isCloseTo(10.0, 1e-10);
        check(c[3]).isCloseTo(15.0, 1e-10);

        final a32 = Float32List.fromList([2.0, 1.0, 1.0, 3.0]);
        final b32 = Float32List.fromList([1.0, 2.0, 3.0, 4.0]);
        final c32 = Float32List(4);
        final okS = AccelerationManager.ssymm(
          side: cblasRight,
          uplo: cblasLower,
          m: 2,
          n: 2,
          alpha: 1.0,
          a: a32,
          lda: 2,
          b: b32,
          ldb: 2,
          beta: 0.0,
          c: c32,
          ldc: 2,
        );
        check(okS).isTrue();
        check(c32[0]).isCloseTo(4.0, 1e-5);
        check(c32[1]).isCloseTo(7.0, 1e-5);
        check(c32[2]).isCloseTo(10.0, 1e-5);
        check(c32[3]).isCloseTo(15.0, 1e-5);
      },
    );

    accelerationTest('dtrmm and strmm with side: cblasRight, uplo: cblasLower, trans: cblasTrans, diag: cblasUnit', () {
      // Lower unit triangular A = [[1, 0], [2, 1]]
      // A^T = [[1, 2], [0, 1]]
      final a = Float64List.fromList([99.0, 0.0, 2.0, 99.0]); // diag ignored
      final b = Float64List.fromList([1.0, 2.0, 3.0, 4.0]);

      final okD = AccelerationManager.dtrmm(
        side: cblasRight,
        uplo: cblasLower,
        transA: cblasTrans,
        diag: cblasUnit,
        m: 2,
        n: 2,
        alpha: 1.0,
        a: a,
        lda: 2,
        b: b,
        ldb: 2,
      );
      check(okD).isTrue();
      // B <- B * A^T
      // [[1, 2], [3, 4]] * [[1, 2], [0, 1]] =
      // [[1*1 + 2*0, 1*2 + 2*1], [3*1 + 4*0, 3*2 + 4*1]] = [[1, 4], [3, 10]]
      check(b[0]).isCloseTo(1.0, 1e-10);
      check(b[1]).isCloseTo(4.0, 1e-10);
      check(b[2]).isCloseTo(3.0, 1e-10);
      check(b[3]).isCloseTo(10.0, 1e-10);

      final a32 = Float32List.fromList([99.0, 0.0, 2.0, 99.0]);
      final b32 = Float32List.fromList([1.0, 2.0, 3.0, 4.0]);
      final okS = AccelerationManager.strmm(
        side: cblasRight,
        uplo: cblasLower,
        transA: cblasTrans,
        diag: cblasUnit,
        m: 2,
        n: 2,
        alpha: 1.0,
        a: a32,
        lda: 2,
        b: b32,
        ldb: 2,
      );
      check(okS).isTrue();
      check(b32[0]).isCloseTo(1.0, 1e-5);
      check(b32[1]).isCloseTo(4.0, 1e-5);
      check(b32[2]).isCloseTo(3.0, 1e-5);
      check(b32[3]).isCloseTo(10.0, 1e-5);
    });
  });
}
