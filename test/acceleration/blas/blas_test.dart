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

    accelerationTest('snrm2 Euclidean norm', () {
      final x = Float32List.fromList([3.0, 4.0]);
      final norm = Blas.snrm2(n: 2, x: x);
      check(norm).isCloseTo(5.0, 1e-5);
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
}
