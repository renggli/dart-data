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
  });
}
