import 'dart:typed_data';

import 'package:checks/checks.dart';
import 'package:data/acceleration.dart';
import 'package:test/test.dart';

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
      check(ok).isTrue();
      check(y[0]).isCloseTo(6.0, 1e-10);
      check(y[1]).isCloseTo(9.0, 1e-10);
      check(y[2]).isCloseTo(12.0, 1e-10);
    });

    accelerationTest('daxpy with negative stride', () {
      final x = Float64List.fromList([1.0, 2.0, 3.0]);
      final y = Float64List.fromList([4.0, 5.0, 6.0]);
      final ok = Blas.daxpy(n: 3, alpha: 2.0, x: x, incX: -1, y: y, incY: 1);
      check(ok).isTrue();
      check(y[0]).isCloseTo(10.0, 1e-10);
      check(y[1]).isCloseTo(9.0, 1e-10);
      check(y[2]).isCloseTo(8.0, 1e-10);
    });

    accelerationTest('saxpy vector update', () {
      final x = Float32List.fromList([1.0, 2.0, 3.0]);
      final y = Float32List.fromList([4.0, 5.0, 6.0]);
      final ok = Blas.saxpy(n: 3, alpha: 2.0, x: x, y: y);
      check(ok).isTrue();
      check(y[0]).isCloseTo(6.0, 1e-5);
      check(y[1]).isCloseTo(9.0, 1e-5);
      check(y[2]).isCloseTo(12.0, 1e-5);
    });

    accelerationTest('dscal vector scaling', () {
      final x = Float64List.fromList([1.0, 2.0, 3.0]);
      final ok = Blas.dscal(n: 3, alpha: 2.5, x: x);
      check(ok).isTrue();
      check(x[0]).isCloseTo(2.5, 1e-10);
      check(x[1]).isCloseTo(5.0, 1e-10);
      check(x[2]).isCloseTo(7.5, 1e-10);
    });

    accelerationTest('sscal vector scaling', () {
      final x = Float32List.fromList([1.0, 2.0, 3.0]);
      final ok = Blas.sscal(n: 3, alpha: 2.5, x: x);
      check(ok).isTrue();
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
      check(ok).isTrue();
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
      check(ok).isTrue();
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
      check(ok).isTrue();
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
      check(ok).isTrue();
      check(y[0]).isCloseTo(3.0, 1e-5);
      check(y[1]).isCloseTo(7.0, 1e-5);
    });

    accelerationTest('dsyr2 symmetric rank-2 update', () {
      final a = Float64List.fromList([1.0, 0.0, 0.0, 1.0]);
      final x = Float64List.fromList([1.0, 2.0]);
      final y = Float64List.fromList([3.0, 4.0]);
      final ok = Blas.dsyr2(n: 2, alpha: 1.0, x: x, y: y, a: a, lda: 2);
      check(ok).isTrue();
      check(a[0]).isCloseTo(1.0 + 2.0 * (1.0 * 3.0), 1e-10);
      check(a[1]).isCloseTo(1.0 * 4.0 + 2.0 * 3.0, 1e-10);
      check(a[3]).isCloseTo(1.0 + 2.0 * (2.0 * 4.0), 1e-10);
    });

    accelerationTest('ssyr2 symmetric rank-2 update', () {
      final a = Float32List.fromList([1.0, 0.0, 0.0, 1.0]);
      final x = Float32List.fromList([1.0, 2.0]);
      final y = Float32List.fromList([3.0, 4.0]);
      final ok = Blas.ssyr2(n: 2, alpha: 1.0, x: x, y: y, a: a, lda: 2);
      check(ok).isTrue();
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
      check(ok).isTrue();
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
      check(ok).isTrue();
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
      check(okUpper).isTrue();
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
      check(okLower).isTrue();
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
      check(ok).isTrue();
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
      check(ok).isTrue();
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
      check(ok).isTrue();
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
      check(ok).isTrue();
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
      check(ok).isTrue();
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
      check(ok).isTrue();
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
      check(ok).isTrue();
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
      check(ok).isTrue();
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
      check(ok).isTrue();
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
      check(ok).isTrue();
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
      check(Blas.daxpy(n: 0, alpha: 2.0, x: x64, y: y64)).isTrue();
      check(Blas.dscal(n: 0, alpha: 2.0, x: x64)).isTrue();

      final x32 = Float32List(0);
      final y32 = Float32List(0);
      check(Blas.sdot(n: 0, x: x32, y: y32)).equals(0.0);
      check(Blas.snrm2(n: 0, x: x32)).equals(0.0);
      check(Blas.saxpy(n: 0, alpha: 2.0, x: x32, y: y32)).isTrue();
      check(Blas.sscal(n: 0, alpha: 2.0, x: x32)).isTrue();

      final a64 = Float64List(0);
      final b64 = Float64List(0);
      final c64 = Float64List(0);
      check(Blas.dgemv(m: 0, n: 0, a: a64, lda: 1, x: x64, y: y64)).isTrue();
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
      ).isTrue();

      final a32 = Float32List(0);
      final b32 = Float32List(0);
      final c32 = Float32List(0);
      check(Blas.sgemv(m: 0, n: 0, a: a32, lda: 1, x: x32, y: y32)).isTrue();
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
      ).isTrue();
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
        check(okZero).isTrue();
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
        check(okScaled).isTrue();
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
        check(okGemvZero).isTrue();
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
        check(okGemvScaled).isTrue();
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
        check(okGemvTrans).isTrue();
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
        check(okGemvNeg).isTrue();
        check(yNegStride[0]).isCloseTo(30.0, 1e-10);
        check(yNegStride[1]).isCloseTo(60.0, 1e-10);
      },
    );

    accelerationTest('1-vector routines with incX < 0 are no-op / 0.0', () {
      final x64 = Float64List.fromList([3.0, 4.0]);
      check(Blas.dnrm2(n: 2, x: x64, incX: -1)).equals(0.0);
      check(Blas.dscal(n: 2, alpha: 2.0, x: x64, incX: -1)).isTrue();
      check(x64[0]).equals(3.0);
      check(x64[1]).equals(4.0);

      final x32 = Float32List.fromList([3.0, 4.0]);
      check(Blas.snrm2(n: 2, x: x32, incX: -1)).equals(0.0);
      check(Blas.sscal(n: 2, alpha: 2.0, x: x32, incX: -1)).isTrue();
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
        ).isTrue();
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
        ).isTrue();
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
        ).isTrue();
        check(c64[0]).equals(0.0);
        check(c64[3]).equals(0.0);

        final b64 = Float64List.fromList([1.0, 2.0, 3.0, 4.0]);
        check(
          Blas.dtrmm(m: 2, n: 2, alpha: 0.0, a: nan64, lda: 2, b: b64, ldb: 2),
        ).isTrue();
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
  });
}
