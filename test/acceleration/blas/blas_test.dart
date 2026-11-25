import 'dart:typed_data';

import 'package:checks/checks.dart';
import 'package:data/acceleration.dart';
import 'package:test/scaffolding.dart';

import '../test_utils.dart';

void main() {
  group('Blas Level 1: Vector-Vector', () {
    accelerationTest('ddot with positive values', () {
      final x = Float64List.fromList([1.0, 2.0, 3.0]);
      final y = Float64List.fromList([4.0, 5.0, 6.0]);
      final dot = Blas.ddot(n: 3, x: x, y: y);
      check(dot).isCloseTo(32.0, 1e-10);
    });

    accelerationTest('ddot with offsets and strides', () {
      final x = Float64List.fromList([0.0, 1.0, 0.0, 2.0]);
      final y = Float64List.fromList([0.0, 0.0, 3.0, 0.0, 4.0]);
      final dot = Blas.ddot(
        n: 2,
        x: x,
        xOffset: 1,
        incX: 2,
        y: y,
        yOffset: 2,
        incY: 2,
      );
      check(dot).isCloseTo(1.0 * 3.0 + 2.0 * 4.0, 1e-10);
    });

    accelerationTest('ddot with negative stride', () {
      final x = Float64List.fromList([1.0, 2.0, 3.0]);
      final y = Float64List.fromList([4.0, 5.0, 6.0]);
      final dot = Blas.ddot(n: 3, x: x, incX: -1, y: y, incY: 1);
      check(dot).isCloseTo(28.0, 1e-10);
    });

    accelerationTest('sdot with negative values', () {
      final x = Float32List.fromList([1.0, -2.0, 3.0]);
      final y = Float32List.fromList([-4.0, 5.0, -6.0]);
      final dot = Blas.sdot(n: 3, x: x, y: y);
      check(dot).isCloseTo(-4.0 - 10.0 - 18.0, 1e-5);
    });

    accelerationTest('dnrm2 Euclidean norm', () {
      final x = Float64List.fromList([3.0, 4.0]);
      final norm = Blas.dnrm2(n: 2, x: x);
      check(norm).isCloseTo(5.0, 1e-10);
    });

    accelerationTest('dnrm2 large values avoid overflow', () {
      final x = Float64List.fromList([1e200, 1e200]);
      final norm = Blas.dnrm2(n: 2, x: x);
      check(norm).isCloseTo(1.414213562373095e200, 1e190);
    });

    accelerationTest('dnrm2 small values avoid underflow', () {
      final x = Float64List.fromList([1e-200, 1e-200]);
      final norm = Blas.dnrm2(n: 2, x: x);
      check(norm).isCloseTo(1.414213562373095e-200, 1e-210);
    });

    accelerationTest('snrm2 Euclidean norm', () {
      final x = Float32List.fromList([3.0, 4.0]);
      final norm = Blas.snrm2(n: 2, x: x);
      check(norm).isCloseTo(5.0, 1e-5);
    });

    accelerationTest('snrm2 large values avoid overflow', () {
      final x = Float32List.fromList([1e20, 1e20]);
      final norm = Blas.snrm2(n: 2, x: x);
      check(norm).isCloseTo(1.4142135e20, 1e15);
    });

    accelerationTest('daxpy vector update', () {
      final x = Float64List.fromList([1.0, 2.0, 3.0]);
      final y = Float64List.fromList([4.0, 5.0, 6.0]);
      final ok = Blas.daxpy(n: 3, alpha: 2.0, x: x, y: y);
      check(ok).isTrue;
      check(y[0]).isCloseTo(6.0, 1e-10);
      check(y[1]).isCloseTo(9.0, 1e-10);
      check(y[2]).isCloseTo(12.0, 1e-10);
    });

    accelerationTest('daxpy with negative stride', () {
      final x = Float64List.fromList([1.0, 2.0, 3.0]);
      final y = Float64List.fromList([4.0, 5.0, 6.0]);
      final ok = Blas.daxpy(n: 3, alpha: 2.0, x: x, incX: -1, y: y, incY: 1);
      check(ok).isTrue;
      check(y[0]).isCloseTo(10.0, 1e-10);
      check(y[1]).isCloseTo(9.0, 1e-10);
      check(y[2]).isCloseTo(8.0, 1e-10);
    });

    accelerationTest('saxpy vector update', () {
      final x = Float32List.fromList([1.0, 2.0, 3.0]);
      final y = Float32List.fromList([4.0, 5.0, 6.0]);
      final ok = Blas.saxpy(n: 3, alpha: 2.0, x: x, y: y);
      check(ok).isTrue;
      check(y[0]).isCloseTo(6.0, 1e-5);
      check(y[1]).isCloseTo(9.0, 1e-5);
      check(y[2]).isCloseTo(12.0, 1e-5);
    });

    accelerationTest('dscal vector scaling', () {
      final x = Float64List.fromList([1.0, 2.0, 3.0]);
      final ok = Blas.dscal(n: 3, alpha: 2.5, x: x);
      check(ok).isTrue;
      check(x[0]).isCloseTo(2.5, 1e-10);
      check(x[1]).isCloseTo(5.0, 1e-10);
      check(x[2]).isCloseTo(7.5, 1e-10);
    });

    accelerationTest('sscal vector scaling', () {
      final x = Float32List.fromList([1.0, 2.0, 3.0]);
      final ok = Blas.sscal(n: 3, alpha: 2.5, x: x);
      check(ok).isTrue;
      check(x[0]).isCloseTo(2.5, 1e-5);
      check(x[1]).isCloseTo(5.0, 1e-5);
      check(x[2]).isCloseTo(7.5, 1e-5);
    });
  });

  group('Blas Level 2: Matrix-Vector', () {
    accelerationTest('dgemv standard multiplication', () {
      final a = Float64List.fromList([1.0, 2.0, 3.0, 4.0]);
      final x = Float64List.fromList([1.0, 1.0]);
      final y = Float64List(2);
      final ok = Blas.dgemv(
        m: 2,
        n: 2,
        alpha: 1.0,
        a: a,
        lda: 2,
        x: x,
        beta: 0.0,
        y: y,
      );
      check(ok).isTrue;
      check(y[0]).isCloseTo(3.0, 1e-10);
      check(y[1]).isCloseTo(7.0, 1e-10);
    });

    accelerationTest('dgemv transposed multiplication', () {
      final a = Float64List.fromList([1.0, 2.0, 3.0, 4.0]);
      final x = Float64List.fromList([1.0, 1.0]);
      final y = Float64List(2);
      final ok = Blas.dgemv(
        transA: cblasTrans,
        m: 2,
        n: 2,
        alpha: 1.0,
        a: a,
        lda: 2,
        x: x,
        beta: 0.0,
        y: y,
      );
      check(ok).isTrue;
      check(y[0]).isCloseTo(4.0, 1e-10);
      check(y[1]).isCloseTo(6.0, 1e-10);
    });

    accelerationTest('dgemv conjugate transpose multiplication', () {
      final a = Float64List.fromList([1.0, 2.0, 3.0, 4.0]);
      final x = Float64List.fromList([1.0, 1.0]);
      final y = Float64List(2);
      final ok = Blas.dgemv(
        transA: cblasConjTrans,
        m: 2,
        n: 2,
        alpha: 1.0,
        a: a,
        lda: 2,
        x: x,
        beta: 0.0,
        y: y,
      );
      check(ok).isTrue;
      check(y[0]).isCloseTo(4.0, 1e-10);
      check(y[1]).isCloseTo(6.0, 1e-10);
    });

    accelerationTest('sgemv multiplication', () {
      final a = Float32List.fromList([1.0, 2.0, 3.0, 4.0]);
      final x = Float32List.fromList([1.0, 1.0]);
      final y = Float32List(2);
      final ok = Blas.sgemv(
        m: 2,
        n: 2,
        alpha: 1.0,
        a: a,
        lda: 2,
        x: x,
        beta: 0.0,
        y: y,
      );
      check(ok).isTrue;
      check(y[0]).isCloseTo(3.0, 1e-5);
      check(y[1]).isCloseTo(7.0, 1e-5);
    });

    accelerationTest('dsyr2 symmetric rank-2 update', () {
      final a = Float64List.fromList([1.0, 0.0, 0.0, 1.0]);
      final x = Float64List.fromList([1.0, 2.0]);
      final y = Float64List.fromList([3.0, 4.0]);
      final ok = Blas.dsyr2(n: 2, alpha: 1.0, x: x, y: y, a: a, lda: 2);
      check(ok).isTrue;
      check(a[0]).isCloseTo(1.0 + 2.0 * (1.0 * 3.0), 1e-10);
      check(a[1]).isCloseTo(1.0 * 4.0 + 2.0 * 3.0, 1e-10);
      check(a[3]).isCloseTo(1.0 + 2.0 * (2.0 * 4.0), 1e-10);
    });

    accelerationTest('ssyr2 symmetric rank-2 update', () {
      final a = Float32List.fromList([1.0, 0.0, 0.0, 1.0]);
      final x = Float32List.fromList([1.0, 2.0]);
      final y = Float32List.fromList([3.0, 4.0]);
      final ok = Blas.ssyr2(n: 2, alpha: 1.0, x: x, y: y, a: a, lda: 2);
      check(ok).isTrue;
      check(a[0]).isCloseTo(7.0, 1e-5);
      check(a[1]).isCloseTo(10.0, 1e-5);
      check(a[3]).isCloseTo(17.0, 1e-5);
    });

    accelerationTest('dtrmv triangular matrix-vector multiply', () {
      final a = Float64List.fromList([2.0, 3.0, 0.0, 4.0]);
      final x = Float64List.fromList([1.0, 2.0]);
      final ok = Blas.dtrmv(
        uplo: cblasUpper,
        trans: cblasNoTrans,
        diag: cblasNonUnit,
        n: 2,
        a: a,
        lda: 2,
        x: x,
      );
      check(ok).isTrue;
      check(x[0]).isCloseTo(2.0 * 1.0 + 3.0 * 2.0, 1e-10);
      check(x[1]).isCloseTo(4.0 * 2.0, 1e-10);
    });

    accelerationTest('strmv triangular matrix-vector multiply', () {
      final a = Float32List.fromList([2.0, 3.0, 0.0, 4.0]);
      final x = Float32List.fromList([1.0, 2.0]);
      final ok = Blas.strmv(
        uplo: cblasUpper,
        trans: cblasNoTrans,
        diag: cblasNonUnit,
        n: 2,
        a: a,
        lda: 2,
        x: x,
      );
      check(ok).isTrue;
      check(x[0]).isCloseTo(8.0, 1e-5);
      check(x[1]).isCloseTo(8.0, 1e-5);
    });

    accelerationTest('dsyr2 symmetric rank-2 update', () {
      final a = Float64List(4);
      final x = Float64List.fromList([1.0, 2.0]);
      final y = Float64List.fromList([3.0, 4.0]);
      final okUpper = Blas.dsyr2(
        uplo: cblasUpper,
        n: 2,
        alpha: 1.0,
        x: x,
        y: y,
        a: a,
        lda: 2,
      );
      check(okUpper).isTrue;
      check(a[0]).isCloseTo(6.0, 1e-10);
      check(a[1]).isCloseTo(10.0, 1e-10);
      check(a[2]).isCloseTo(10.0, 1e-10);
      check(a[3]).isCloseTo(16.0, 1e-10);

      final aLower = Float64List(4);
      final okLower = Blas.dsyr2(
        uplo: cblasLower,
        n: 2,
        alpha: 1.0,
        x: x,
        y: y,
        a: aLower,
        lda: 2,
      );
      check(okLower).isTrue;
      check(aLower[0]).isCloseTo(6.0, 1e-10);
      check(aLower[1]).isCloseTo(10.0, 1e-10);
      check(aLower[2]).isCloseTo(10.0, 1e-10);
      check(aLower[3]).isCloseTo(16.0, 1e-10);
    });
  });

  group('Blas Level 3: Matrix-Matrix', () {
    accelerationTest('dgemm standard multiplication', () {
      final a = Float64List.fromList([1.0, 2.0, 3.0, 4.0]);
      final b = Float64List.fromList([5.0, 6.0, 7.0, 8.0]);
      final c = Float64List(4);
      final ok = Blas.dgemm(
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
      check(ok).isTrue;
      check(c[0]).isCloseTo(19.0, 1e-10);
      check(c[1]).isCloseTo(22.0, 1e-10);
      check(c[2]).isCloseTo(43.0, 1e-10);
      check(c[3]).isCloseTo(50.0, 1e-10);
    });

    accelerationTest('dgemm transposed combinations', () {
      final a = Float64List.fromList([1.0, 3.0, 2.0, 4.0]);
      final b = Float64List.fromList([5.0, 6.0, 7.0, 8.0]);
      final c = Float64List(4);
      final ok = Blas.dgemm(
        transA: cblasTrans,
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
      check(ok).isTrue;
      check(c[0]).isCloseTo(19.0, 1e-10);
      check(c[1]).isCloseTo(22.0, 1e-10);
      check(c[2]).isCloseTo(43.0, 1e-10);
      check(c[3]).isCloseTo(50.0, 1e-10);
    });

    accelerationTest('dgemm conjugate transpose', () {
      final a = Float64List.fromList([1.0, 3.0, 2.0, 4.0]);
      final b = Float64List.fromList([5.0, 6.0, 7.0, 8.0]);
      final c = Float64List(4);
      final ok = Blas.dgemm(
        transA: cblasConjTrans,
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
      check(ok).isTrue;
      check(c[0]).isCloseTo(19.0, 1e-10);
      check(c[1]).isCloseTo(22.0, 1e-10);
      check(c[2]).isCloseTo(43.0, 1e-10);
      check(c[3]).isCloseTo(50.0, 1e-10);
    });

    accelerationTest('sgemm multiplication', () {
      final a = Float32List.fromList([1.0, 2.0, 3.0, 4.0]);
      final b = Float32List.fromList([5.0, 6.0, 7.0, 8.0]);
      final c = Float32List(4);
      final ok = Blas.sgemm(
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
      check(ok).isTrue;
      check(c[0]).isCloseTo(19.0, 1e-5);
      check(c[1]).isCloseTo(22.0, 1e-5);
      check(c[2]).isCloseTo(43.0, 1e-5);
      check(c[3]).isCloseTo(50.0, 1e-5);
    });

    accelerationTest('dsyrk symmetric rank-k update', () {
      final a = Float64List.fromList([1.0, 2.0, 3.0, 4.0]);
      final c = Float64List(4);
      final ok = Blas.dsyrk(
        uplo: cblasUpper,
        trans: cblasNoTrans,
        n: 2,
        k: 2,
        alpha: 1.0,
        a: a,
        lda: 2,
        beta: 0.0,
        c: c,
        ldc: 2,
      );
      check(ok).isTrue;
      check(c[0]).isCloseTo(5.0, 1e-10);
      check(c[1]).isCloseTo(11.0, 1e-10);
      check(c[3]).isCloseTo(25.0, 1e-10);
    });

    accelerationTest('ssyrk symmetric rank-k update', () {
      final a = Float32List.fromList([1.0, 2.0, 3.0, 4.0]);
      final c = Float32List(4);
      final ok = Blas.ssyrk(
        uplo: cblasUpper,
        trans: cblasNoTrans,
        n: 2,
        k: 2,
        alpha: 1.0,
        a: a,
        lda: 2,
        beta: 0.0,
        c: c,
        ldc: 2,
      );
      check(ok).isTrue;
      check(c[0]).isCloseTo(5.0, 1e-5);
      check(c[1]).isCloseTo(11.0, 1e-5);
      check(c[3]).isCloseTo(25.0, 1e-5);
    });

    accelerationTest('dsymm symmetric matrix multiply', () {
      final a = Float64List.fromList([2.0, 1.0, 1.0, 3.0]);
      final b = Float64List.fromList([1.0, 2.0, 3.0, 4.0]);
      final c = Float64List(4);
      final ok = Blas.dsymm(
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
      check(ok).isTrue;
      check(c[0]).isCloseTo(5.0, 1e-10);
      check(c[1]).isCloseTo(8.0, 1e-10);
      check(c[2]).isCloseTo(10.0, 1e-10);
      check(c[3]).isCloseTo(14.0, 1e-10);
    });

    accelerationTest('ssymm symmetric matrix multiply', () {
      final a = Float32List.fromList([2.0, 1.0, 1.0, 3.0]);
      final b = Float32List.fromList([1.0, 2.0, 3.0, 4.0]);
      final c = Float32List(4);
      final ok = Blas.ssymm(
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
      check(ok).isTrue;
      check(c[0]).isCloseTo(5.0, 1e-5);
      check(c[1]).isCloseTo(8.0, 1e-5);
      check(c[2]).isCloseTo(10.0, 1e-5);
      check(c[3]).isCloseTo(14.0, 1e-5);
    });

    accelerationTest('dtrmm triangular matrix multiply', () {
      final a = Float64List.fromList([2.0, 3.0, 0.0, 4.0]);
      final b = Float64List.fromList([1.0, 2.0, 3.0, 4.0]);
      final ok = Blas.dtrmm(
        side: cblasLeft,
        uplo: cblasUpper,
        transA: cblasNoTrans,
        diag: cblasNonUnit,
        m: 2,
        n: 2,
        alpha: 1.0,
        a: a,
        lda: 2,
        b: b,
        ldb: 2,
      );
      check(ok).isTrue;
      check(b[0]).isCloseTo(11.0, 1e-10);
      check(b[1]).isCloseTo(16.0, 1e-10);
      check(b[2]).isCloseTo(12.0, 1e-10);
      check(b[3]).isCloseTo(16.0, 1e-10);
    });

    accelerationTest('strmm triangular matrix multiply', () {
      final a = Float32List.fromList([2.0, 3.0, 0.0, 4.0]);
      final b = Float32List.fromList([1.0, 2.0, 3.0, 4.0]);
      final ok = Blas.strmm(
        side: cblasLeft,
        uplo: cblasUpper,
        transA: cblasNoTrans,
        diag: cblasNonUnit,
        m: 2,
        n: 2,
        alpha: 1.0,
        a: a,
        lda: 2,
        b: b,
        ldb: 2,
      );
      check(ok).isTrue;
      check(b[0]).isCloseTo(11.0, 1e-5);
      check(b[1]).isCloseTo(16.0, 1e-5);
      check(b[2]).isCloseTo(12.0, 1e-5);
      check(b[3]).isCloseTo(16.0, 1e-5);
    });
  });

  group('Blas Edge Cases & Dimension Safety', () {
    accelerationTest('0x0 zero dimensions Level 1, 2, and 3', () {
      final x64 = Float64List(0);
      final y64 = Float64List(0);
      check(Blas.ddot(n: 0, x: x64, y: y64)).equals(0.0);
      check(Blas.dnrm2(n: 0, x: x64)).equals(0.0);
      check(Blas.daxpy(n: 0, alpha: 2.0, x: x64, y: y64)).isTrue;
      check(Blas.dscal(n: 0, alpha: 2.0, x: x64)).isTrue;

      final x32 = Float32List(0);
      final y32 = Float32List(0);
      check(Blas.sdot(n: 0, x: x32, y: y32)).equals(0.0);
      check(Blas.snrm2(n: 0, x: x32)).equals(0.0);
      check(Blas.saxpy(n: 0, alpha: 2.0, x: x32, y: y32)).isTrue;
      check(Blas.sscal(n: 0, alpha: 2.0, x: x32)).isTrue;

      final a64 = Float64List(0);
      final b64 = Float64List(0);
      final c64 = Float64List(0);
      check(Blas.dgemv(m: 0, n: 0, a: a64, lda: 1, x: x64, y: y64)).isTrue;
      check(
        Blas.dgemm(
          m: 0,
          n: 0,
          k: 0,
          a: a64,
          lda: 1,
          b: b64,
          ldb: 1,
          c: c64,
          ldc: 1,
        ),
      ).isTrue;

      final a32 = Float32List(0);
      final b32 = Float32List(0);
      final c32 = Float32List(0);
      check(Blas.sgemv(m: 0, n: 0, a: a32, lda: 1, x: x32, y: y32)).isTrue;
      check(
        Blas.sgemm(
          m: 0,
          n: 0,
          k: 0,
          a: a32,
          lda: 1,
          b: b32,
          ldb: 1,
          c: c32,
          ldc: 1,
        ),
      ).isTrue;
    });

    accelerationTest(
      '2x0 * 0x2 multiplication and beta scaling with k == 0',
      () {
        final a = Float64List(0);
        final b = Float64List(0);
        final cZero = Float64List.fromList([1.0, 2.0, 3.0, 4.0]);
        final okZero = Blas.dgemm(
          m: 2,
          n: 2,
          k: 0,
          alpha: 1.0,
          a: a,
          lda: 1,
          b: b,
          ldb: 2,
          beta: 0.0,
          c: cZero,
          ldc: 2,
        );
        check(okZero).isTrue;
        check(cZero[0]).equals(0.0);
        check(cZero[1]).equals(0.0);
        check(cZero[2]).equals(0.0);
        check(cZero[3]).equals(0.0);

        final cScaled = Float64List.fromList([1.0, 2.0, 3.0, 4.0]);
        final okScaled = Blas.dgemm(
          m: 2,
          n: 2,
          k: 0,
          alpha: 1.0,
          a: a,
          lda: 1,
          b: b,
          ldb: 2,
          beta: 2.5,
          c: cScaled,
          ldc: 2,
        );
        check(okScaled).isTrue;
        check(cScaled[0]).isCloseTo(2.5, 1e-10);
        check(cScaled[1]).isCloseTo(5.0, 1e-10);
        check(cScaled[2]).isCloseTo(7.5, 1e-10);
        check(cScaled[3]).isCloseTo(10.0, 1e-10);

        final yZero = Float64List.fromList([10.0, 20.0]);
        final okGemvZero = Blas.dgemv(
          m: 2,
          n: 0,
          a: a,
          lda: 1,
          x: Float64List(0),
          beta: 0.0,
          y: yZero,
        );
        check(okGemvZero).isTrue;
        check(yZero[0]).equals(0.0);
        check(yZero[1]).equals(0.0);

        final yScaled = Float64List.fromList([10.0, 20.0]);
        final okGemvScaled = Blas.dgemv(
          m: 2,
          n: 0,
          a: a,
          lda: 1,
          x: Float64List(0),
          beta: 3.0,
          y: yScaled,
        );
        check(okGemvScaled).isTrue;
        check(yScaled[0]).isCloseTo(30.0, 1e-10);
        check(yScaled[1]).isCloseTo(60.0, 1e-10);

        final yTrans = Float64List.fromList([10.0, 20.0]);
        final okGemvTrans = Blas.dgemv(
          transA: cblasConjTrans,
          m: 0,
          n: 2,
          a: Float64List(0),
          lda: 2,
          x: Float64List(0),
          beta: 2.0,
          y: yTrans,
        );
        check(okGemvTrans).isTrue;
        check(yTrans[0]).isCloseTo(20.0, 1e-10);
        check(yTrans[1]).isCloseTo(40.0, 1e-10);

        final yNegStride = Float64List.fromList([10.0, 20.0]);
        final okGemvNeg = Blas.dgemv(
          m: 2,
          n: 0,
          a: Float64List(0),
          lda: 1,
          x: Float64List(0),
          beta: 3.0,
          y: yNegStride,
          incY: -1,
        );
        check(okGemvNeg).isTrue;
        check(yNegStride[0]).isCloseTo(30.0, 1e-10);
        check(yNegStride[1]).isCloseTo(60.0, 1e-10);
      },
    );

    accelerationTest('1-vector routines with incX < 0 are no-op / 0.0', () {
      final x64 = Float64List.fromList([3.0, 4.0]);
      check(Blas.dnrm2(n: 2, x: x64, incX: -1)).equals(0.0);
      check(Blas.dscal(n: 2, alpha: 2.0, x: x64, incX: -1)).isTrue;
      check(x64[0]).equals(3.0);
      check(x64[1]).equals(4.0);

      final x32 = Float32List.fromList([3.0, 4.0]);
      check(Blas.snrm2(n: 2, x: x32, incX: -1)).equals(0.0);
      check(Blas.sscal(n: 2, alpha: 2.0, x: x32, incX: -1)).isTrue;
      check(x32[0]).equals(3.0);
      check(x32[1]).equals(4.0);
    });

    accelerationTest(
      'alpha == 0.0 short-circuits without NaN contamination',
      () {
        final nan64 = Float64List.fromList([
          double.nan,
          double.nan,
          double.nan,
          double.nan,
        ]);
        final y64 = Float64List.fromList([1.0, 2.0]);
        check(
          Blas.dgemv(
            m: 2,
            n: 2,
            alpha: 0.0,
            a: nan64,
            lda: 2,
            x: nan64,
            beta: 2.0,
            y: y64,
          ),
        ).isTrue;
        check(y64[0]).equals(2.0);
        check(y64[1]).equals(4.0);

        final c64 = Float64List.fromList([1.0, 2.0, 2.0, 3.0]);
        check(
          Blas.dsyrk(
            n: 2,
            k: 2,
            alpha: 0.0,
            a: nan64,
            lda: 2,
            beta: 2.0,
            c: c64,
            ldc: 2,
          ),
        ).isTrue;
        check(c64[0]).equals(2.0);
        check(c64[3]).equals(6.0);

        check(
          Blas.dsymm(
            m: 2,
            n: 2,
            alpha: 0.0,
            a: nan64,
            lda: 2,
            b: nan64,
            ldb: 2,
            beta: 0.0,
            c: c64,
            ldc: 2,
          ),
        ).isTrue;
        check(c64[0]).equals(0.0);
        check(c64[3]).equals(0.0);

        final b64 = Float64List.fromList([1.0, 2.0, 3.0, 4.0]);
        check(
          Blas.dtrmm(m: 2, n: 2, alpha: 0.0, a: nan64, lda: 2, b: b64, ldb: 2),
        ).isTrue;
        check(b64[0]).equals(0.0);
        check(b64[3]).equals(0.0);
      },
    );

    test('out-of-bounds buffer views throw RangeError', () {
      final shortVec = Float64List(3);
      final otherVec = Float64List(3);
      check(() => Blas.ddot(n: 4, x: shortVec, y: otherVec))
          .throws<RangeError>();
      check(() => Blas.dnrm2(n: 4, x: shortVec)).throws<RangeError>();
      check(() => Blas.daxpy(n: 4, alpha: 1.0, x: shortVec, y: otherVec))
          .throws<RangeError>();
      check(() => Blas.dscal(n: 4, alpha: 1.0, x: shortVec))
          .throws<RangeError>();
      check(
        () => Blas.ddot(n: 2, x: shortVec, xOffset: 2, incX: 2, y: otherVec),
      ).throws<RangeError>();
      check(() => Blas.ddot(n: 2, x: shortVec, xOffset: -1, y: otherVec))
          .throws<RangeError>();

      final shortMat = Float64List(3);
      final vec2 = Float64List(2);
      check(() => Blas.dgemv(m: 2, n: 2, a: shortMat, lda: 2, x: vec2, y: vec2))
          .throws<RangeError>();
      check(
        () => Blas.dgemm(
          m: 2,
          n: 2,
          k: 2,
          a: shortMat,
          lda: 2,
          b: Float64List(4),
          ldb: 2,
          c: Float64List(4),
          ldc: 2,
        ),
      ).throws<RangeError>();
    });

    test('invalid enum or leading dimension throws ArgumentError', () {
      final mat = Float64List(4);
      final vec = Float64List(2);
      check(() => Blas.dgemv(m: 2, n: 2, a: mat, lda: 1, x: vec, y: vec))
          .throws<ArgumentError>();
      check(
        () =>
            Blas.dgemv(transA: 999, m: 2, n: 2, a: mat, lda: 2, x: vec, y: vec),
      ).throws<ArgumentError>();
      check(() => Blas.ddot(n: 2, x: vec, incX: 0, y: vec))
          .throws<ArgumentError>();
      check(
        () => Blas.dgemm(
          m: 2,
          n: 2,
          k: 2,
          a: mat,
          lda: 1,
          b: mat,
          ldb: 2,
          c: mat,
          ldc: 2,
        ),
      ).throws<ArgumentError>();
    });

    test('negative dimensions throw ArgumentError', () {
      final mat = Float64List(4);
      final vec = Float64List(2);
      check(() => Blas.ddot(n: -1, x: vec, y: vec)).throws<ArgumentError>();
      check(() => Blas.dnrm2(n: -1, x: vec)).throws<ArgumentError>();
      check(() => Blas.dgemv(m: -1, n: 2, a: mat, lda: 2, x: vec, y: vec))
          .throws<ArgumentError>();
      check(() => Blas.dgemv(m: 2, n: -1, a: mat, lda: 2, x: vec, y: vec))
          .throws<ArgumentError>();
      check(
        () => Blas.dgemm(
          m: -1,
          n: 2,
          k: 2,
          a: mat,
          lda: 2,
          b: mat,
          ldb: 2,
          c: mat,
          ldc: 2,
        ),
      ).throws<ArgumentError>();
      check(
        () => Blas.dgemm(
          m: 2,
          n: 2,
          k: -1,
          a: mat,
          lda: 2,
          b: mat,
          ldb: 2,
          c: mat,
          ldc: 2,
        ),
      ).throws<ArgumentError>();
    });

    accelerationTest('dnrm2 and snrm2 with multiple infinities and NaN', () {
      final infVec = Float64List.fromList([
        double.infinity,
        double.infinity,
        3.0,
      ]);
      check(Blas.dnrm2(n: 3, x: infVec)).equals(double.infinity);

      final nanInfVec = Float64List.fromList([
        double.infinity,
        double.nan,
        3.0,
      ]);
      check(Blas.dnrm2(n: 3, x: nanInfVec).isNaN).isTrue;

      final infVec32 = Float32List.fromList([
        double.infinity,
        double.infinity,
        3.0,
      ]);
      check(Blas.snrm2(n: 3, x: infVec32)).equals(double.infinity);

      final nanInfVec32 = Float32List.fromList([
        double.infinity,
        double.nan,
        3.0,
      ]);
      check(Blas.snrm2(n: 3, x: nanInfVec32).isNaN).isTrue;
    });

    accelerationTest('alpha == 0 short-circuits avoid NaN propagation', () {
      final nanX = Float64List.fromList([double.nan, double.nan]);
      final y = Float64List.fromList([1.0, 2.0]);
      check(Blas.daxpy(n: 2, alpha: 0.0, x: nanX, y: y)).isTrue;
      check(y).deepEquals([1.0, 2.0]);

      final nanMat = Float64List.fromList([
        double.nan,
        double.nan,
        double.nan,
        double.nan,
      ]);
      check(
        Blas.dgemv(
          m: 2,
          n: 2,
          alpha: 0.0,
          a: nanMat,
          lda: 2,
          x: nanX,
          beta: 1.0,
          y: y,
        ),
      ).isTrue;
      check(y).deepEquals([1.0, 2.0]);
    });

    accelerationTest('blocked sgemm across all transpose combinations', () {
      const m = 70;
      const n = 67;
      const k = 73;
      for (final transA in [cblasNoTrans, cblasTrans]) {
        for (final transB in [cblasNoTrans, cblasTrans]) {
          final aRows = transA == cblasNoTrans ? m : k;
          final aCols = transA == cblasNoTrans ? k : m;
          final bRows = transB == cblasNoTrans ? k : n;
          final bCols = transB == cblasNoTrans ? n : k;
          final a = Float32List.fromList(
            List<double>.generate(aRows * aCols, (i) => ((i % 7) + 1) * 0.25),
          );
          final b = Float32List.fromList(
            List<double>.generate(bRows * bCols, (i) => ((i % 5) + 1) * 0.5),
          );
          final c = Float32List(m * n)..fillRange(0, m * n, 1.0);
          final beta = transA == cblasNoTrans ? 0.0 : 2.0;
          check(
            Blas.sgemm(
              transA: transA,
              transB: transB,
              m: m,
              n: n,
              k: k,
              alpha: 1.0,
              a: a,
              lda: aCols,
              b: b,
              ldb: bCols,
              beta: beta,
              c: c,
              ldc: n,
            ),
          ).isTrue;
          var ref00 = beta * 1.0;
          for (var p = 0; p < k; p++) {
            final a0 = transA == cblasNoTrans ? a[p] : a[p * aCols];
            final b0 = transB == cblasNoTrans ? b[p * bCols] : b[p];
            ref00 += a0 * b0;
          }
          check(c[0]).isCloseTo(ref00, 1e-3);
        }
      }
    });

    accelerationTest('blocked dgemm across all transpose combinations', () {
      const m = 70;
      const n = 67;
      const k = 73;
      for (final transA in [cblasNoTrans, cblasTrans]) {
        for (final transB in [cblasNoTrans, cblasTrans]) {
          final aRows = transA == cblasNoTrans ? m : k;
          final aCols = transA == cblasNoTrans ? k : m;
          final bRows = transB == cblasNoTrans ? k : n;
          final bCols = transB == cblasNoTrans ? n : k;
          final a = Float64List.fromList(
            List<double>.generate(aRows * aCols, (i) => ((i % 7) + 1) * 0.25),
          );
          final b = Float64List.fromList(
            List<double>.generate(bRows * bCols, (i) => ((i % 5) + 1) * 0.5),
          );
          final c = Float64List(m * n)..fillRange(0, m * n, 1.0);
          check(
            Blas.dgemm(
              transA: transA,
              transB: transB,
              m: m,
              n: n,
              k: k,
              alpha: 1.0,
              a: a,
              lda: aCols,
              b: b,
              ldb: bCols,
              beta: 2.0,
              c: c,
              ldc: n,
            ),
          ).isTrue;
          var ref00 = 2.0 * 1.0;
          for (var p = 0; p < k; p++) {
            final a0 = transA == cblasNoTrans ? a[p] : a[p * aCols];
            final b0 = transB == cblasNoTrans ? b[p * bCols] : b[p];
            ref00 += a0 * b0;
          }
          check(c[0]).isCloseTo(ref00, 1e-10);
        }
      }
    });

    accelerationTest('sgemv handles transpose and alpha zero', () {
      final y32 = Float32List.fromList([2.0, 3.0]);
      check(
        Blas.sgemv(
          transA: cblasTrans,
          m: 2,
          n: 2,
          alpha: 1.0,
          a: Float32List.fromList([1.0, 2.0, 3.0, 4.0]),
          lda: 2,
          x: Float32List.fromList([1.0, 1.0]),
          beta: 0.0,
          y: y32,
        ),
      ).isTrue;
      check(y32[0]).isCloseTo(4.0, 1e-5);
      check(y32[1]).isCloseTo(6.0, 1e-5);

      check(
        Blas.sgemv(
          m: 2,
          n: 2,
          alpha: 0.0,
          a: Float32List.fromList([double.nan, 0.0, 0.0, 0.0]),
          lda: 2,
          x: Float32List.fromList([double.nan, 0.0]),
          beta: 2.0,
          y: y32,
        ),
      ).isTrue;
      check(y32[0]).isCloseTo(8.0, 1e-5);
      check(y32[1]).isCloseTo(12.0, 1e-5);

      check(
        Blas.sgemv(
          m: 2,
          n: 2,
          alpha: 0.0,
          a: Float32List(4),
          lda: 2,
          x: Float32List(2),
          beta: 0.0,
          y: y32,
        ),
      ).isTrue;
      check(y32).deepEquals([0.0, 0.0]);
    });

    accelerationTest('dtrmv/dtrsv and strmv/strsv invert each other', () {
      final a64 = Float64List.fromList([2.0, 3.0, 4.0, 5.0]);
      final a32 = Float32List.fromList(a64);
      for (final uplo in [cblasUpper, cblasLower]) {
        for (final trans in [cblasNoTrans, cblasTrans]) {
          for (final diag in [cblasNonUnit, cblasUnit]) {
            final xd = Float64List.fromList([1.0, 2.0]);
            check(
              Blas.dtrmv(
                uplo: uplo,
                trans: trans,
                diag: diag,
                n: 2,
                a: a64,
                lda: 2,
                x: xd,
              ),
            ).isTrue;
            check(
              Blas.dtrsv(
                uplo: uplo,
                trans: trans,
                diag: diag,
                n: 2,
                a: a64,
                lda: 2,
                x: xd,
              ),
            ).isTrue;
            check(xd[0]).isCloseTo(1.0, 1e-10);
            check(xd[1]).isCloseTo(2.0, 1e-10);

            final xf = Float32List.fromList([1.0, 2.0]);
            check(
              Blas.strmv(
                uplo: uplo,
                trans: trans,
                diag: diag,
                n: 2,
                a: a32,
                lda: 2,
                x: xf,
              ),
            ).isTrue;
            check(
              Blas.strsv(
                uplo: uplo,
                trans: trans,
                diag: diag,
                n: 2,
                a: a32,
                lda: 2,
                x: xf,
              ),
            ).isTrue;
            check(xf[0]).isCloseTo(1.0, 1e-5);
            check(xf[1]).isCloseTo(2.0, 1e-5);
          }
        }
      }
    });

    accelerationTest('dtrsv and strsv support negative strides', () {
      // Lower triangular L = [2 0; 3 4]; x = [1, 2]
      // Forward solve L*y = [2, 11] -> y = [1, 2]
      // Logical order with incX = -1: stored [11.0, 2.0] -> x[0]=11 (logical idx 1), x[1]=2 (logical idx 0)
      final l64 = Float64List.fromList([2.0, 0.0, 3.0, 4.0]);
      final x64 = Float64List.fromList([11.0, 2.0]);
      check(
        Blas.dtrsv(uplo: cblasLower, n: 2, a: l64, lda: 2, x: x64, incX: -1),
      ).isTrue;
      check(x64[0]).isCloseTo(2.0, 1e-10);
      check(x64[1]).isCloseTo(1.0, 1e-10);

      final x32 = Float32List.fromList([11.0, 2.0]);
      check(
        Blas.strsv(
          uplo: cblasLower,
          n: 2,
          a: Float32List.fromList(l64),
          lda: 2,
          x: x32,
          incX: -1,
        ),
      ).isTrue;
      check(x32[0]).isCloseTo(2.0, 1e-5);
      check(x32[1]).isCloseTo(1.0, 1e-5);
    });

    accelerationTest('dtrmm/dtrsm and strmm/strsm invert each other', () {
      final a64 = Float64List.fromList([2.0, 3.0, 4.0, 5.0]);
      final a32 = Float32List.fromList(a64);
      for (final uplo in [cblasUpper, cblasLower]) {
        for (final trans in [cblasNoTrans, cblasTrans]) {
          for (final diag in [cblasNonUnit, cblasUnit]) {
            for (final side in [cblasLeft, cblasRight]) {
              final bd = Float64List.fromList([1.0, 2.0, 3.0, 4.0]);
              check(
                Blas.dtrmm(
                  side: side,
                  uplo: uplo,
                  transA: trans,
                  diag: diag,
                  m: 2,
                  n: 2,
                  alpha: 2.0,
                  a: a64,
                  lda: 2,
                  b: bd,
                  ldb: 2,
                ),
              ).isTrue;
              check(
                Blas.dtrsm(
                  side: side,
                  uplo: uplo,
                  transA: trans,
                  diag: diag,
                  m: 2,
                  n: 2,
                  alpha: 0.5,
                  a: a64,
                  lda: 2,
                  b: bd,
                  ldb: 2,
                ),
              ).isTrue;
              check(bd[0]).isCloseTo(1.0, 1e-10);
              check(bd[1]).isCloseTo(2.0, 1e-10);
              check(bd[2]).isCloseTo(3.0, 1e-10);
              check(bd[3]).isCloseTo(4.0, 1e-10);

              final bf = Float32List.fromList([1.0, 2.0, 3.0, 4.0]);
              check(
                Blas.strmm(
                  side: side,
                  uplo: uplo,
                  transA: trans,
                  diag: diag,
                  m: 2,
                  n: 2,
                  alpha: 2.0,
                  a: a32,
                  lda: 2,
                  b: bf,
                  ldb: 2,
                ),
              ).isTrue;
              check(
                Blas.strsm(
                  side: side,
                  uplo: uplo,
                  transA: trans,
                  diag: diag,
                  m: 2,
                  n: 2,
                  alpha: 0.5,
                  a: a32,
                  lda: 2,
                  b: bf,
                  ldb: 2,
                ),
              ).isTrue;
              check(bf[0]).isCloseTo(1.0, 1e-4);
              check(bf[1]).isCloseTo(2.0, 1e-4);
              check(bf[2]).isCloseTo(3.0, 1e-4);
              check(bf[3]).isCloseTo(4.0, 1e-4);
            }
          }
        }
      }

      // alpha == 0 zeros B without reading A
      final bZero64 = Float64List.fromList([1.0, 2.0, 3.0, 4.0]);
      check(
        Blas.dtrsm(
          m: 2,
          n: 2,
          alpha: 0.0,
          a: Float64List.fromList([double.nan, 0.0, 0.0, 0.0]),
          lda: 2,
          b: bZero64,
          ldb: 2,
        ),
      ).isTrue;
      check(bZero64).deepEquals([0.0, 0.0, 0.0, 0.0]);

      final bZero32 = Float32List.fromList([1.0, 2.0, 3.0, 4.0]);
      check(
        Blas.strmm(m: 2, n: 2, alpha: 0.0, a: a32, lda: 2, b: bZero32, ldb: 2),
      ).isTrue;
      check(bZero32).deepEquals([0.0, 0.0, 0.0, 0.0]);
    });

    accelerationTest('dsyr2 and ssyr2 compute symmetric rank-2 update', () {
      final syr2d = Float64List(4);
      check(
        Blas.dsyr2(
          uplo: cblasLower,
          n: 2,
          alpha: 2.0,
          x: Float64List.fromList([1.0, 2.0]),
          y: Float64List.fromList([3.0, 4.0]),
          a: syr2d,
          lda: 2,
        ),
      ).isTrue;
      check(syr2d[0]).isCloseTo(12.0, 1e-10);
      check(syr2d[1]).isCloseTo(20.0, 1e-10);
      check(syr2d[2]).isCloseTo(20.0, 1e-10);
      check(syr2d[3]).isCloseTo(32.0, 1e-10);

      final syr2f = Float32List(4);
      check(
        Blas.ssyr2(
          uplo: cblasLower,
          n: 2,
          alpha: 2.0,
          x: Float32List.fromList([1.0, 2.0]),
          y: Float32List.fromList([3.0, 4.0]),
          a: syr2f,
          lda: 2,
        ),
      ).isTrue;
      check(syr2f[0]).isCloseTo(12.0, 1e-5);
      check(syr2f[1]).isCloseTo(20.0, 1e-5);
      check(syr2f[2]).isCloseTo(20.0, 1e-5);
      check(syr2f[3]).isCloseTo(32.0, 1e-5);
    });

    accelerationTest('dsyrk and ssyrk compute symmetric rank-k update', () {
      final mat2d = Float64List.fromList([2.0, 3.0, 4.0, 5.0]);
      final mat2f = Float32List.fromList(mat2d);
      for (final uplo in [cblasUpper, cblasLower]) {
        for (final trans in [cblasNoTrans, cblasTrans]) {
          final cd = Float64List.fromList([1.0, 0.0, 0.0, 1.0]);
          check(
            Blas.dsyrk(
              uplo: uplo,
              trans: trans,
              n: 2,
              k: 2,
              alpha: 1.5,
              a: mat2d,
              lda: 2,
              beta: 0.5,
              c: cd,
              ldc: 2,
            ),
          ).isTrue;
          check(cd[1]).isCloseTo(cd[2], 1e-10);

          final cf = Float32List.fromList([1.0, 0.0, 0.0, 1.0]);
          check(
            Blas.ssyrk(
              uplo: uplo,
              trans: trans,
              n: 2,
              k: 2,
              alpha: 1.5,
              a: mat2f,
              lda: 2,
              beta: 0.5,
              c: cf,
              ldc: 2,
            ),
          ).isTrue;
          check(cf[1]).isCloseTo(cf[2], 1e-5);
        }
        final czf = Float32List.fromList([1.0, 2.0, 2.0, 3.0]);
        check(
          Blas.ssyrk(
            uplo: uplo,
            n: 2,
            k: 2,
            alpha: 0.0,
            a: mat2f,
            lda: 2,
            beta: 2.0,
            c: czf,
            ldc: 2,
          ),
        ).isTrue;
        check(czf[0]).isCloseTo(2.0, 1e-5);
        check(czf[3]).isCloseTo(6.0, 1e-5);
      }
    });

    accelerationTest(
      'dsymm and ssymm read only referenced triangle and mirror output',
      () {
        final aUpper = Float64List.fromList([
          2.0, 3.0, //
          double.nan, 5.0,
        ]);
        final aLower = Float64List.fromList([
          2.0, double.nan, //
          3.0, 5.0,
        ]);
        final b = Float64List.fromList([1.0, 2.0, 3.0, 4.0]);
        // Left: A * B = [2*1+3*3, 2*2+3*4; 3*1+5*3, 3*2+5*4] = [11, 16, 18, 26]
        // Right: B * A = [1*2+2*3, 1*3+2*5; 3*2+4*3, 3*3+4*5] = [8, 13, 18, 29]
        for (final (uplo, aMat) in [
          (cblasUpper, aUpper),
          (cblasLower, aLower),
        ]) {
          for (final side in [cblasLeft, cblasRight]) {
            final c64 = Float64List(4)..fillRange(0, 4, 2.0);
            check(
              Blas.dsymm(
                side: side,
                uplo: uplo,
                m: 2,
                n: 2,
                alpha: 1.0,
                a: aMat,
                lda: 2,
                b: b,
                ldb: 2,
                beta: 0.5,
                c: c64,
                ldc: 2,
              ),
            ).isTrue;
            final expected = side == cblasLeft
                ? [12.0, 17.0, 19.0, 27.0]
                : [9.0, 14.0, 19.0, 30.0];
            for (var i = 0; i < 4; i++) {
              check(c64[i]).isCloseTo(expected[i], 1e-10);
            }

            final c32 = Float32List(4)..fillRange(0, 4, 2.0);
            check(
              Blas.ssymm(
                side: side,
                uplo: uplo,
                m: 2,
                n: 2,
                alpha: 1.0,
                a: Float32List.fromList(aMat),
                lda: 2,
                b: Float32List.fromList(b),
                ldb: 2,
                beta: 0.5,
                c: c32,
                ldc: 2,
              ),
            ).isTrue;
            for (var i = 0; i < 4; i++) {
              check(c32[i]).isCloseTo(expected[i], 1e-5);
            }
          }
        }

        // alpha == 0 paths
        final cAlpha0 = Float64List.fromList([1.0, 2.0, 3.0, 4.0]);
        check(
          Blas.dsymm(
            m: 2,
            n: 2,
            alpha: 0.0,
            a: aUpper,
            lda: 2,
            b: b,
            ldb: 2,
            beta: 2.0,
            c: cAlpha0,
            ldc: 2,
          ),
        ).isTrue;
        check(cAlpha0).deepEquals([2.0, 4.0, 6.0, 8.0]);

        final cAlpha0f = Float32List.fromList([1.0, 2.0, 3.0, 4.0]);
        check(
          Blas.ssymm(
            m: 2,
            n: 2,
            alpha: 0.0,
            a: Float32List.fromList(aLower),
            lda: 2,
            b: Float32List.fromList(b),
            ldb: 2,
            beta: 0.0,
            c: cAlpha0f,
            ldc: 2,
          ),
        ).isTrue;
        check(cAlpha0f).deepEquals([0.0, 0.0, 0.0, 0.0]);
      },
    );

    test('dtrsv, strsv, dtrsm, and strsm validate arguments and bounds', () {
      final a64 = Float64List(4);
      final x64 = Float64List(2);
      final a32 = Float32List(4);
      final x32 = Float32List(2);
      check(() => Blas.dtrsv(uplo: 999, n: 2, a: a64, lda: 2, x: x64))
          .throws<ArgumentError>();
      check(() => Blas.strsv(diag: 999, n: 2, a: a32, lda: 2, x: x32))
          .throws<ArgumentError>();
      check(() => Blas.dtrsv(n: 2, a: a64, lda: 2, x: x64, incX: 0))
          .throws<ArgumentError>();
      check(
        () => Blas.dtrsm(side: 999, m: 2, n: 2, a: a64, lda: 2, b: a64, ldb: 2),
      ).throws<ArgumentError>();
      check(
        () =>
            Blas.strsm(transA: 999, m: 2, n: 2, a: a32, lda: 2, b: a32, ldb: 2),
      ).throws<ArgumentError>();
      check(
        () => Blas.dtrsm(m: 2, n: 2, a: Float64List(2), lda: 2, b: a64, ldb: 2),
      ).throws<RangeError>();
      check(
        () => Blas.strsm(m: 2, n: 2, a: a32, lda: 2, b: Float32List(2), ldb: 2),
      ).throws<RangeError>();
    });
  });
}
