import 'dart:typed_data';

import 'package:checks/checks.dart';
import 'package:data/src/acceleration/blas/blas_dart.dart';
import 'package:data/src/acceleration/blas/cblas_constants.dart';
import 'package:test/scaffolding.dart';

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
      ).isTrue;
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
      ).isTrue;
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
      ).isTrue;
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
      ).isTrue;
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
      ).isTrue;
      check(c[0]).isCloseTo(4.0, 1e-10);
      check(c[1]).isCloseTo(7.0, 1e-10);
      check(c[2]).isCloseTo(10.0, 1e-10);
      check(c[3]).isCloseTo(15.0, 1e-10);
    });

    test('dsymm and ssymm cblasLower only reads lower triangle', () {
      final a64 = Float64List.fromList([2.0, double.nan, 1.0, 3.0]);
      final b64 = Float64List.fromList([1.0, 2.0, 3.0, 4.0]);
      final c64 = Float64List(4);
      check(
        BlasDart.dsymm(
          side: cblasLeft,
          uplo: cblasLower,
          m: 2,
          n: 2,
          alpha: 1.0,
          a: a64,
          aOffset: 0,
          lda: 2,
          b: b64,
          bOffset: 0,
          ldb: 2,
          beta: 0.0,
          c: c64,
          cOffset: 0,
          ldc: 2,
        ),
      ).isTrue;
      check(c64[0]).isCloseTo(5.0, 1e-10);
      check(c64[1]).isCloseTo(8.0, 1e-10);
      check(c64[2]).isCloseTo(10.0, 1e-10);
      check(c64[3]).isCloseTo(14.0, 1e-10);

      final cRight64 = Float64List(4);
      check(
        BlasDart.dsymm(
          side: cblasRight,
          uplo: cblasLower,
          m: 2,
          n: 2,
          alpha: 1.0,
          a: a64,
          aOffset: 0,
          lda: 2,
          b: b64,
          bOffset: 0,
          ldb: 2,
          beta: 0.0,
          c: cRight64,
          cOffset: 0,
          ldc: 2,
        ),
      ).isTrue;
      check(cRight64[0]).isCloseTo(4.0, 1e-10);
      check(cRight64[1]).isCloseTo(7.0, 1e-10);
      check(cRight64[2]).isCloseTo(10.0, 1e-10);
      check(cRight64[3]).isCloseTo(15.0, 1e-10);
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
      ).isTrue;
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
      ).isTrue;
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
      ).isTrue;
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
      ).isTrue;
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
      ).isTrue;
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
      ).isTrue;
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
      ).isTrue;
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
      ).isTrue;
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
      ).isTrue;
      check(y[0]).isCloseTo(6.0, 1e-10);
      check(y[1]).isCloseTo(8.0, 1e-10);
      check(y[2]).isCloseTo(10.0, 1e-10);
    });

    test(
      'dsymm and ssymm read only referenced triangle for upper and lower',
      () {
        // Symmetric 3x3:
        // [1 2 3]
        // [2 4 5]
        // [3 5 6]
        final aUpper = Float64List.fromList([
          1.0, 2.0, 3.0, //
          double.nan, 4.0, 5.0,
          double.nan, double.nan, 6.0,
        ]);
        final aLower = Float64List.fromList([
          1.0, double.nan, double.nan, //
          2.0, 4.0, double.nan,
          3.0, 5.0, 6.0,
        ]);
        final b = Float64List.fromList([
          1.0, 0.0, //
          2.0, 1.0,
          -1.0, 3.0,
        ]);
        // Expected A * B:
        // row 0: [1*1 + 2*2 + 3*(-1), 1*0 + 2*1 + 3*3] = [2, 11]
        // row 1: [2*1 + 4*2 + 5*(-1), 2*0 + 4*1 + 5*3] = [5, 19]
        // row 2: [3*1 + 5*2 + 6*(-1), 3*0 + 5*1 + 6*3] = [7, 23]
        final expectedLeft = [2.0, 11.0, 5.0, 19.0, 7.0, 23.0];

        for (final (uplo, aMat) in [
          (cblasUpper, aUpper),
          (cblasLower, aLower),
        ]) {
          final c = Float64List(6)..fillRange(0, 6, 1.0);
          check(
            BlasDart.dsymm(
              side: cblasLeft,
              uplo: uplo,
              m: 3,
              n: 2,
              alpha: 1.0,
              a: aMat,
              aOffset: 0,
              lda: 3,
              b: b,
              bOffset: 0,
              ldb: 2,
              beta: 0.0,
              c: c,
              cOffset: 0,
              ldc: 2,
            ),
          ).isTrue;
          for (var i = 0; i < 6; i++) {
            check(c[i]).isCloseTo(expectedLeft[i], 1e-10);
          }

          final c32 = Float32List(6)..fillRange(0, 6, 1.0);
          check(
            BlasDart.ssymm(
              side: cblasLeft,
              uplo: uplo,
              m: 3,
              n: 2,
              alpha: 1.0,
              a: Float32List.fromList(aMat),
              aOffset: 0,
              lda: 3,
              b: Float32List.fromList(b),
              bOffset: 0,
              ldb: 2,
              beta: 0.0,
              c: c32,
              cOffset: 0,
              ldc: 2,
            ),
          ).isTrue;
          for (var i = 0; i < 6; i++) {
            check(c32[i]).isCloseTo(expectedLeft[i], 1e-5);
          }
        }

        // cblasRight: C = B2x3 * A3x3
        final bRight = Float64List.fromList([
          1.0, 2.0, -1.0, //
          0.0, 1.0, 3.0,
        ]);
        // row 0: [2, 5, 7], row 1: [11, 19, 23]
        final expectedRight = [2.0, 5.0, 7.0, 11.0, 19.0, 23.0];
        for (final (uplo, aMat) in [
          (cblasUpper, aUpper),
          (cblasLower, aLower),
        ]) {
          final c = Float64List(6)..fillRange(0, 6, 1.0);
          check(
            BlasDart.dsymm(
              side: cblasRight,
              uplo: uplo,
              m: 2,
              n: 3,
              alpha: 1.0,
              a: aMat,
              aOffset: 0,
              lda: 3,
              b: bRight,
              bOffset: 0,
              ldb: 3,
              beta: 0.0,
              c: c,
              cOffset: 0,
              ldc: 3,
            ),
          ).isTrue;
          for (var i = 0; i < 6; i++) {
            check(c[i]).isCloseTo(expectedRight[i], 1e-10);
          }

          final c32 = Float32List(6)..fillRange(0, 6, 1.0);
          check(
            BlasDart.ssymm(
              side: cblasRight,
              uplo: uplo,
              m: 2,
              n: 3,
              alpha: 1.0,
              a: Float32List.fromList(aMat),
              aOffset: 0,
              lda: 3,
              b: Float32List.fromList(bRight),
              bOffset: 0,
              ldb: 3,
              beta: 0.0,
              c: c32,
              cOffset: 0,
              ldc: 3,
            ),
          ).isTrue;
          for (var i = 0; i < 6; i++) {
            check(c32[i]).isCloseTo(expectedRight[i], 1e-5);
          }
        }
      },
    );

    test('dtrmv and dtrsv invert each other across all variants', () {
      final a = Float64List.fromList([
        2.0, 1.5, -1.0, //
        0.5, 4.0, 2.0,
        -0.5, 1.0, 3.0,
      ]);
      for (final uplo in [cblasUpper, cblasLower]) {
        for (final trans in [cblasNoTrans, cblasTrans, cblasConjTrans]) {
          for (final diag in [cblasNonUnit, cblasUnit]) {
            final xOrig = Float64List.fromList([1.0, -2.0, 3.0]);
            final x = Float64List.fromList(xOrig);
            check(
              BlasDart.dtrmv(
                uplo: uplo,
                trans: trans,
                diag: diag,
                n: 3,
                a: a,
                aOffset: 0,
                lda: 3,
                x: x,
                xOffset: 0,
                incX: 1,
              ),
            ).isTrue;
            check(
              BlasDart.dtrsv(
                uplo: uplo,
                trans: trans,
                diag: diag,
                n: 3,
                a: a,
                aOffset: 0,
                lda: 3,
                x: x,
                xOffset: 0,
                incX: 1,
              ),
            ).isTrue;
            for (var i = 0; i < 3; i++) {
              check(x[i]).isCloseTo(xOrig[i], 1e-10);
            }

            final xfOrig = Float32List.fromList(xOrig);
            final xf = Float32List.fromList(xfOrig);
            final af = Float32List.fromList(a);
            check(
              BlasDart.strmv(
                uplo: uplo,
                trans: trans,
                diag: diag,
                n: 3,
                a: af,
                aOffset: 0,
                lda: 3,
                x: xf,
                xOffset: 0,
                incX: 1,
              ),
            ).isTrue;
            check(
              BlasDart.strsv(
                uplo: uplo,
                trans: trans,
                diag: diag,
                n: 3,
                a: af,
                aOffset: 0,
                lda: 3,
                x: xf,
                xOffset: 0,
                incX: 1,
              ),
            ).isTrue;
            for (var i = 0; i < 3; i++) {
              check(xf[i]).isCloseTo(xfOrig[i], 1e-5);
            }
          }
        }
      }
    });

    test('dtrmm and dtrsm invert each other across all variants', () {
      final a = Float64List.fromList([
        2.0, 1.5, -1.0, //
        0.5, 4.0, 2.0,
        -0.5, 1.0, 3.0,
      ]);
      for (final side in [cblasLeft, cblasRight]) {
        final k = side == cblasLeft ? 3 : 2;
        final aSub = k == 3 ? a : Float64List.fromList([2.0, 1.5, 0.5, 4.0]);
        for (final uplo in [cblasUpper, cblasLower]) {
          for (final transA in [cblasNoTrans, cblasTrans, cblasConjTrans]) {
            for (final diag in [cblasNonUnit, cblasUnit]) {
              final bOrig = Float64List.fromList([
                1.0, -2.0, //
                3.0, 0.5,
                -1.5, 2.5,
              ]);
              final b = Float64List.fromList(bOrig);
              check(
                BlasDart.dtrmm(
                  side: side,
                  uplo: uplo,
                  transA: transA,
                  diag: diag,
                  m: 3,
                  n: 2,
                  alpha: 2.0,
                  a: aSub,
                  aOffset: 0,
                  lda: k,
                  b: b,
                  bOffset: 0,
                  ldb: 2,
                ),
              ).isTrue;
              check(
                BlasDart.dtrsm(
                  side: side,
                  uplo: uplo,
                  transA: transA,
                  diag: diag,
                  m: 3,
                  n: 2,
                  alpha: 0.5,
                  a: aSub,
                  aOffset: 0,
                  lda: k,
                  b: b,
                  bOffset: 0,
                  ldb: 2,
                ),
              ).isTrue;
              for (var i = 0; i < 6; i++) {
                check(b[i]).isCloseTo(bOrig[i], 1e-10);
              }

              final bfOrig = Float32List.fromList(bOrig);
              final bf = Float32List.fromList(bfOrig);
              final afSub = Float32List.fromList(aSub);
              check(
                BlasDart.strmm(
                  side: side,
                  uplo: uplo,
                  transA: transA,
                  diag: diag,
                  m: 3,
                  n: 2,
                  alpha: 2.0,
                  a: afSub,
                  aOffset: 0,
                  lda: k,
                  b: bf,
                  bOffset: 0,
                  ldb: 2,
                ),
              ).isTrue;
              check(
                BlasDart.strsm(
                  side: side,
                  uplo: uplo,
                  transA: transA,
                  diag: diag,
                  m: 3,
                  n: 2,
                  alpha: 0.5,
                  a: afSub,
                  aOffset: 0,
                  lda: k,
                  b: bf,
                  bOffset: 0,
                  ldb: 2,
                ),
              ).isTrue;
              for (var i = 0; i < 6; i++) {
                check(bf[i]).isCloseTo(bfOrig[i], 1e-4);
              }
            }
          }
        }
      }
    });

    test('blocked 72x72 dgemm and sgemm cover remainder tiles across all transposes', () {
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
            List<double>.generate(aRows * aCols, (i) => ((i % 7) - 3) * 0.25),
          );
          final b = Float64List.fromList(
            List<double>.generate(bRows * bCols, (i) => ((i % 5) - 2) * 0.5),
          );
          final c = Float64List(m * n)..fillRange(0, m * n, 1.5);
          check(
            BlasDart.dgemm(
              transA: transA,
              transB: transB,
              m: m,
              n: n,
              k: k,
              alpha: 1.0,
              a: a,
              aOffset: 0,
              lda: aCols,
              b: b,
              bOffset: 0,
              ldb: bCols,
              beta: 0.5,
              c: c,
              cOffset: 0,
              ldc: n,
            ),
          ).isTrue;
          // Spot-check (0, 0) and (m-1, n-1)
          var ref00 = 0.5 * 1.5;
          var refLast = 0.5 * 1.5;
          for (var p = 0; p < k; p++) {
            final a0 = transA == cblasNoTrans ? a[p] : a[p * aCols];
            final b0 = transB == cblasNoTrans ? b[p * bCols] : b[p];
            ref00 += a0 * b0;
            final aLast = transA == cblasNoTrans
                ? a[(m - 1) * aCols + p]
                : a[p * aCols + (m - 1)];
            final bLast = transB == cblasNoTrans
                ? b[p * bCols + (n - 1)]
                : b[(n - 1) * bCols + p];
            refLast += aLast * bLast;
          }
          check(c[0]).isCloseTo(ref00, 1e-10);
          check(c[(m - 1) * n + (n - 1)]).isCloseTo(refLast, 1e-10);

          final c32 = Float32List(m * n)..fillRange(0, m * n, 1.5);
          check(
            BlasDart.sgemm(
              transA: transA,
              transB: transB,
              m: m,
              n: n,
              k: k,
              alpha: 1.0,
              a: Float32List.fromList(a),
              aOffset: 0,
              lda: aCols,
              b: Float32List.fromList(b),
              bOffset: 0,
              ldb: bCols,
              beta: 0.5,
              c: c32,
              cOffset: 0,
              ldc: n,
            ),
          ).isTrue;
          check(c32[0]).isCloseTo(ref00, 1e-4);
          check(c32[(m - 1) * n + (n - 1)]).isCloseTo(refLast, 1e-4);
        }
      }
    });

    test('dsyrk and ssyrk with k=0 and beta!=0 scale matrix c', () {
      final c64 = Float64List.fromList([2.0, 3.0, 4.0, 5.0]);
      check(
        BlasDart.dsyrk(
          uplo: cblasUpper,
          trans: cblasNoTrans,
          n: 2,
          k: 0,
          alpha: 1.0,
          a: Float64List(0),
          aOffset: 0,
          lda: 2,
          beta: 2.0,
          c: c64,
          cOffset: 0,
          ldc: 2,
        ),
      ).isTrue;
      check(c64[0]).equals(4.0);
      check(c64[1]).equals(6.0);
      check(c64[2]).equals(6.0);
      check(c64[3]).equals(10.0);

      final c32 = Float32List.fromList([2.0, 3.0, 4.0, 5.0]);
      check(
        BlasDart.ssyrk(
          uplo: cblasLower,
          trans: cblasNoTrans,
          n: 2,
          k: 0,
          alpha: 1.0,
          a: Float32List(0),
          aOffset: 0,
          lda: 2,
          beta: 0.0,
          c: c32,
          cOffset: 0,
          ldc: 2,
        ),
      ).isTrue;
      check(c32).deepEquals([0.0, 0.0, 0.0, 0.0]);
    });

    test('dsymm beta scaling and strsm alpha=0 zeroing', () {
      final c = Float64List.fromList([1.0, 2.0, 3.0, 4.0]);
      check(
        BlasDart.dsymm(
          side: cblasLeft,
          uplo: cblasUpper,
          m: 2,
          n: 2,
          alpha: 0.0,
          a: Float64List(4),
          aOffset: 0,
          lda: 2,
          b: Float64List(4),
          bOffset: 0,
          ldb: 2,
          beta: 2.0,
          c: c,
          cOffset: 0,
          ldc: 2,
        ),
      ).isTrue;
      check(c).deepEquals([2.0, 4.0, 6.0, 8.0]);

      final b32 = Float32List.fromList([1.0, 2.0, 3.0, 4.0]);
      check(
        BlasDart.strsm(
          side: cblasLeft,
          uplo: cblasUpper,
          transA: cblasNoTrans,
          diag: cblasNonUnit,
          m: 2,
          n: 2,
          alpha: 0.0,
          a: Float32List(4),
          aOffset: 0,
          lda: 2,
          b: b32,
          bOffset: 0,
          ldb: 2,
        ),
      ).isTrue;
      check(b32).deepEquals([0.0, 0.0, 0.0, 0.0]);
    });
  });
}
