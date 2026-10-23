import 'dart:typed_data';

import 'package:checks/checks.dart';
import 'package:data/src/acceleration/blas/blas_dart.dart';
import 'package:data/src/acceleration/blas/cblas_constants.dart';
import 'package:test/test.dart';

void main() {
  group('BlasDart Edge Cases', () {
    test('dgemm with zero dimensions returns true', () {
      final a = Float64List(0);
      final b = Float64List(0);
      final c = Float64List(0);
      check(
        BlasDart.dgemm(
          transA: cblasNoTrans,
          transB: cblasNoTrans,
          m: 0,
          n: 0,
          k: 0,
          alpha: 1.0,
          a: a,
          aOffset: 0,
          lda: 0,
          b: b,
          bOffset: 0,
          ldb: 0,
          beta: 0.0,
          c: c,
          cOffset: 0,
          ldc: 0,
        ),
      ).isTrue();
    });

    test('dgemm with beta != 1.0 scales C', () {
      final a = Float64List.fromList([1.0]);
      final b = Float64List.fromList([2.0]);
      final c = Float64List.fromList([10.0]);
      check(
        BlasDart.dgemm(
          transA: cblasNoTrans,
          transB: cblasNoTrans,
          m: 1,
          n: 1,
          k: 1,
          alpha: 1.0,
          a: a,
          aOffset: 0,
          lda: 1,
          b: b,
          bOffset: 0,
          ldb: 1,
          beta: 0.5,
          c: c,
          cOffset: 0,
          ldc: 1,
        ),
      ).isTrue();
      check(c[0]).isCloseTo(10.0 * 0.5 + 2.0, 1e-10);
    });

    test('dgemm transA && transB', () {
      final a = Float64List.fromList([1.0, 3.0, 2.0, 4.0]);
      final b = Float64List.fromList([5.0, 7.0, 6.0, 8.0]);
      final c = Float64List(4);
      check(
        BlasDart.dgemm(
          transA: cblasTrans,
          transB: cblasTrans,
          m: 2,
          n: 2,
          k: 2,
          alpha: 1.0,
          a: a,
          aOffset: 0,
          lda: 2,
          b: b,
          bOffset: 0,
          ldb: 2,
          beta: 0.0,
          c: c,
          cOffset: 0,
          ldc: 2,
        ),
      ).isTrue();
      check(c[0]).isCloseTo(19.0, 1e-10);
      check(c[1]).isCloseTo(22.0, 1e-10);
      check(c[2]).isCloseTo(43.0, 1e-10);
      check(c[3]).isCloseTo(50.0, 1e-10);
    });

    test('sgemm transA && transB', () {
      final a = Float32List.fromList([1.0, 3.0, 2.0, 4.0]);
      final b = Float32List.fromList([5.0, 7.0, 6.0, 8.0]);
      final c = Float32List(4);
      check(
        BlasDart.sgemm(
          transA: cblasTrans,
          transB: cblasTrans,
          m: 2,
          n: 2,
          k: 2,
          alpha: 1.0,
          a: a,
          aOffset: 0,
          lda: 2,
          b: b,
          bOffset: 0,
          ldb: 2,
          beta: 0.0,
          c: c,
          cOffset: 0,
          ldc: 2,
        ),
      ).isTrue();
      check(c[0]).isCloseTo(19.0, 1e-5);
      check(c[1]).isCloseTo(22.0, 1e-5);
      check(c[2]).isCloseTo(43.0, 1e-5);
      check(c[3]).isCloseTo(50.0, 1e-5);
    });

    test('dsymm right side', () {
      final a = Float64List.fromList([2.0, 1.0, 1.0, 3.0]);
      final b = Float64List.fromList([1.0, 2.0, 3.0, 4.0]);
      final c = Float64List(4);
      check(
        BlasDart.dsymm(
          side: cblasRight,
          uplo: cblasUpper,
          m: 2,
          n: 2,
          alpha: 1.0,
          a: a,
          aOffset: 0,
          lda: 2,
          b: b,
          bOffset: 0,
          ldb: 2,
          beta: 0.0,
          c: c,
          cOffset: 0,
          ldc: 2,
        ),
      ).isTrue();
      check(c[0]).isCloseTo(4.0, 1e-10);
      check(c[1]).isCloseTo(7.0, 1e-10);
      check(c[2]).isCloseTo(10.0, 1e-10);
      check(c[3]).isCloseTo(15.0, 1e-10);
    });

    test('dtrmm right side transposed', () {
      final a = Float64List.fromList([2.0, 3.0, 0.0, 4.0]);
      final b = Float64List.fromList([1.0, 2.0, 3.0, 4.0]);
      check(
        BlasDart.dtrmm(
          side: cblasRight,
          uplo: cblasUpper,
          transA: cblasTrans,
          diag: cblasNonUnit,
          m: 2,
          n: 2,
          alpha: 1.0,
          a: a,
          aOffset: 0,
          lda: 2,
          b: b,
          bOffset: 0,
          ldb: 2,
        ),
      ).isTrue();
      check(b[0]).isCloseTo(8.0, 1e-10);
      check(b[1]).isCloseTo(8.0, 1e-10);
      check(b[2]).isCloseTo(18.0, 1e-10);
      check(b[3]).isCloseTo(16.0, 1e-10);
    });

    test('dgemv with cblasConjTrans', () {
      final a = Float64List.fromList([1.0, 2.0, 3.0, 4.0]);
      final x = Float64List.fromList([1.0, 1.0]);
      final y = Float64List(2);
      check(
        BlasDart.dgemv(
          transA: cblasConjTrans,
          m: 2,
          n: 2,
          alpha: 1.0,
          a: a,
          aOffset: 0,
          lda: 2,
          x: x,
          xOffset: 0,
          incX: 1,
          beta: 0.0,
          y: y,
          yOffset: 0,
          incY: 1,
        ),
      ).isTrue();
      check(y[0]).isCloseTo(4.0, 1e-10);
      check(y[1]).isCloseTo(6.0, 1e-10);
    });

    test('dgemm with cblasConjTrans matches cblasTrans', () {
      final a = Float64List.fromList([1.0, 3.0, 2.0, 4.0]);
      final b = Float64List.fromList([5.0, 6.0, 7.0, 8.0]);
      final c = Float64List(4);
      check(
        BlasDart.dgemm(
          transA: cblasConjTrans,
          transB: cblasNoTrans,
          m: 2,
          n: 2,
          k: 2,
          alpha: 1.0,
          a: a,
          aOffset: 0,
          lda: 2,
          b: b,
          bOffset: 0,
          ldb: 2,
          beta: 0.0,
          c: c,
          cOffset: 0,
          ldc: 2,
        ),
      ).isTrue();
      check(c[0]).isCloseTo(19.0, 1e-10);
      check(c[1]).isCloseTo(22.0, 1e-10);
      check(c[2]).isCloseTo(43.0, 1e-10);
      check(c[3]).isCloseTo(50.0, 1e-10);
    });

    test('ddot and daxpy with negative increments', () {
      final x = Float64List.fromList([1.0, 2.0, 3.0]);
      final y = Float64List.fromList([4.0, 5.0, 6.0]);
      final dot = BlasDart.ddot(
        n: 3,
        x: x,
        xOffset: 0,
        incX: -1,
        y: y,
        yOffset: 0,
        incY: 1,
      );
      check(dot).isCloseTo(28.0, 1e-10);

      check(
        BlasDart.daxpy(
          n: 3,
          alpha: 2.0,
          x: x,
          xOffset: 0,
          incX: -1,
          y: y,
          yOffset: 0,
          incY: 1,
        ),
      ).isTrue();
      check(y[0]).isCloseTo(10.0, 1e-10);
      check(y[1]).isCloseTo(9.0, 1e-10);
      check(y[2]).isCloseTo(8.0, 1e-10);
    });

    test('dnrm2 scaled accumulation avoids overflow and underflow', () {
      final large = Float64List.fromList([1e200, 1e200]);
      check(BlasDart.dnrm2(n: 2, x: large, xOffset: 0, incX: 1))
          .isCloseTo(1.414213562373095e200, 1e190);

      final small = Float64List.fromList([1e-200, 1e-200]);
      check(BlasDart.dnrm2(n: 2, x: small, xOffset: 0, incX: 1))
          .isCloseTo(1.414213562373095e-200, 1e-210);
    });

    test('dsyrk with cblasConjTrans', () {
      final a = Float64List.fromList([1.0, 2.0, 3.0, 4.0]);
      final c = Float64List(4);
      check(
        BlasDart.dsyrk(
          uplo: cblasUpper,
          trans: cblasConjTrans,
          n: 2,
          k: 2,
          alpha: 1.0,
          a: a,
          aOffset: 0,
          lda: 2,
          beta: 0.0,
          c: c,
          cOffset: 0,
          ldc: 2,
        ),
      ).isTrue();
      check(c[0]).isCloseTo(10.0, 1e-10);
      check(c[1]).isCloseTo(14.0, 1e-10);
      check(c[2]).isCloseTo(14.0, 1e-10);
      check(c[3]).isCloseTo(20.0, 1e-10);
    });

    test('dtrmm with cblasConjTrans', () {
      final a = Float64List.fromList([2.0, 3.0, 0.0, 4.0]);
      final b = Float64List.fromList([1.0, 2.0, 3.0, 4.0]);
      check(
        BlasDart.dtrmm(
          side: cblasRight,
          uplo: cblasUpper,
          transA: cblasConjTrans,
          diag: cblasNonUnit,
          m: 2,
          n: 2,
          alpha: 1.0,
          a: a,
          aOffset: 0,
          lda: 2,
          b: b,
          bOffset: 0,
          ldb: 2,
        ),
      ).isTrue();
      check(b[0]).isCloseTo(8.0, 1e-10);
      check(b[1]).isCloseTo(8.0, 1e-10);
      check(b[2]).isCloseTo(18.0, 1e-10);
      check(b[3]).isCloseTo(16.0, 1e-10);
    });

    test('dsyr2 with cblasUpper and cblasLower', () {
      final x = Float64List.fromList([1.0, 2.0]);
      final y = Float64List.fromList([3.0, 4.0]);
      // A = [0 0; 0 0]
      final aUpper = Float64List(4);
      check(
        BlasDart.dsyr2(
          uplo: cblasUpper,
          n: 2,
          alpha: 1.0,
          x: x,
          xOffset: 0,
          incX: 1,
          y: y,
          yOffset: 0,
          incY: 1,
          a: aUpper,
          aOffset: 0,
          lda: 2,
        ),
      ).isTrue();
      // x * y^T + y * x^T:
      // (0,0) = 1*3 + 3*1 = 6
      // (0,1) = 1*4 + 3*2 = 10
      // (1,0) = 2*3 + 4*1 = 10
      // (1,1) = 2*4 + 4*2 = 16
      check(aUpper[0]).isCloseTo(6.0, 1e-10);
      check(aUpper[1]).isCloseTo(10.0, 1e-10);
      check(aUpper[2]).isCloseTo(10.0, 1e-10);
      check(aUpper[3]).isCloseTo(16.0, 1e-10);

      final aLower = Float64List(4);
      check(
        BlasDart.dsyr2(
          uplo: cblasLower,
          n: 2,
          alpha: 1.0,
          x: x,
          xOffset: 0,
          incX: 1,
          y: y,
          yOffset: 0,
          incY: 1,
          a: aLower,
          aOffset: 0,
          lda: 2,
        ),
      ).isTrue();
      check(aLower[0]).isCloseTo(6.0, 1e-10);
      check(aLower[1]).isCloseTo(10.0, 1e-10);
      check(aLower[2]).isCloseTo(10.0, 1e-10);
      check(aLower[3]).isCloseTo(16.0, 1e-10);
    });

    test('dgemv with zero-size matrix and cblasConjTrans', () {
      final a = Float64List(0);
      final x = Float64List.fromList([1.0, 2.0]);
      final y = Float64List.fromList([3.0, 4.0, 5.0]);
      // m = 0, n = 3, trans = ConjTrans -> lenY = n = 3
      check(
        BlasDart.dgemv(
          transA: cblasConjTrans,
          m: 0,
          n: 3,
          alpha: 1.0,
          a: a,
          aOffset: 0,
          lda: 3,
          x: x,
          xOffset: 0,
          incX: 1,
          beta: 2.0,
          y: y,
          yOffset: 0,
          incY: 1,
        ),
      ).isTrue();
      check(y[0]).isCloseTo(6.0, 1e-10);
      check(y[1]).isCloseTo(8.0, 1e-10);
      check(y[2]).isCloseTo(10.0, 1e-10);
    });
  });
}
