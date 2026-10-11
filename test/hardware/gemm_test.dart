import 'dart:math' as math;
import 'dart:typed_data';

import 'package:checks/checks.dart';
import 'package:data/hardware.dart';
import 'package:data/linear.dart';
import 'package:data/src/hardware/pure_dart_gemm.dart';
import 'package:test/test.dart';

void main() {
  group('Pure Dart Cache-Blocked GEMM (Float64)', () {
    test('small matrix multiplication NN (NoTrans, NoTrans)', () {
      final a = Float64List.fromList([1.0, 2.0, 3.0, 4.0]);
      final b = Float64List.fromList([5.0, 6.0, 7.0, 8.0]);
      final c = Float64List(4);

      final success = cacheBlockedGemmFloat64(
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

      check(success).isTrue();
      // [1*5 + 2*7, 1*6 + 2*8] = [19, 22]
      // [3*5 + 4*7, 3*6 + 4*8] = [43, 50]
      check(c[0]).isCloseTo(19.0, 1e-10);
      check(c[1]).isCloseTo(22.0, 1e-10);
      check(c[2]).isCloseTo(43.0, 1e-10);
      check(c[3]).isCloseTo(50.0, 1e-10);
    });

    test('transpose variations (TN, NT, TT)', () {
      // A: 2x3, B: 2x3, C: 3x3 for A^T * B?
      // A is 2x3:
      // [1, 2, 3]
      // [4, 5, 6]
      final a = Float64List.fromList([1.0, 2.0, 3.0, 4.0, 5.0, 6.0]);
      // 1. TN: A is 2x3, transA=cblasTrans means op(A) is 3x2.
      // op(A) (3x2) * b (2x3)? Let's use bTN of shape 2x2:
      final b2x2 = Float64List.fromList([1.0, 2.0, 3.0, 4.0]);
      final cTN = Float64List(6); // 3x2
      cacheBlockedGemmFloat64(
        transA: cblasTrans,
        transB: cblasNoTrans,
        m: 3,
        n: 2,
        k: 2,
        alpha: 1.0,
        a: a,
        lda: 3,
        b: b2x2,
        ldb: 2,
        beta: 0.0,
        c: cTN,
        ldc: 2,
      );
      // op(A) is [[1, 4], [2, 5], [3, 6]]
      // * [[1, 2], [3, 4]]
      // row 0: 1*1 + 4*3 = 13, 1*2 + 4*4 = 18
      // row 1: 2*1 + 5*3 = 17, 2*2 + 5*4 = 24
      // row 2: 3*1 + 6*3 = 21, 3*2 + 6*4 = 30
      check(cTN[0]).isCloseTo(13.0, 1e-10);
      check(cTN[1]).isCloseTo(18.0, 1e-10);
      check(cTN[2]).isCloseTo(17.0, 1e-10);
      check(cTN[3]).isCloseTo(24.0, 1e-10);
      check(cTN[4]).isCloseTo(21.0, 1e-10);
      check(cTN[5]).isCloseTo(30.0, 1e-10);

      // 2. NT: A is 2x3, B is 2x3, transB=cblasTrans means op(B) is 3x2 -> C is
      // 2x2
      final cNT = Float64List(4);
      final b2x3 = Float64List.fromList([7.0, 8.0, 9.0, 1.0, 2.0, 3.0]);
      cacheBlockedGemmFloat64(
        transA: cblasNoTrans,
        transB: cblasTrans,
        m: 2,
        n: 2,
        k: 3,
        alpha: 1.0,
        a: a,
        lda: 3,
        b: b2x3,
        ldb: 3,
        beta: 0.0,
        c: cNT,
        ldc: 2,
      );
      // row 0: 1*7 + 2*8 + 3*9 = 7 + 16 + 27 = 50; 1*1 + 2*2 + 3*3 = 14
      // row 1: 4*7 + 5*8 + 6*9 = 28 + 40 + 54 = 122; 4*1 + 5*2 + 6*3 = 4 + 10 +
      // 18 = 32
      check(cNT[0]).isCloseTo(50.0, 1e-10);
      check(cNT[1]).isCloseTo(14.0, 1e-10);
      check(cNT[2]).isCloseTo(122.0, 1e-10);
      check(cNT[3]).isCloseTo(32.0, 1e-10);

      // 3. TT: op(A) 3x2 * op(B) 2x2 where A is 2x3 and B is 2x2 transposed ->
      // C is 3x2
      final cTT = Float64List(6);
      cacheBlockedGemmFloat64(
        transA: cblasTrans,
        transB: cblasTrans,
        m: 3,
        n: 2,
        k: 2,
        alpha: 1.0,
        a: a,
        lda: 3,
        b: b2x2,
        ldb: 2,
        beta: 0.0,
        c: cTT,
        ldc: 2,
      );
      // op(A) = [[1, 4], [2, 5], [3, 6]]
      // op(B) = [[1, 3], [2, 4]]
      // row 0: 1*1 + 4*2 = 9; 1*3 + 4*4 = 19
      // row 1: 2*1 + 5*2 = 12; 2*3 + 5*4 = 26
      // row 2: 3*1 + 6*2 = 15; 3*3 + 6*4 = 33
      check(cTT[0]).isCloseTo(9.0, 1e-10);
      check(cTT[1]).isCloseTo(19.0, 1e-10);
      check(cTT[2]).isCloseTo(12.0, 1e-10);
      check(cTT[3]).isCloseTo(26.0, 1e-10);
      check(cTT[4]).isCloseTo(15.0, 1e-10);
      check(cTT[5]).isCloseTo(33.0, 1e-10);
    });

    test('alpha and beta scaling', () {
      final a = Float64List.fromList([1.0, 2.0, 3.0, 4.0]);
      final b = Float64List.fromList([5.0, 6.0, 7.0, 8.0]);
      final c = Float64List.fromList([10.0, 10.0, 10.0, 10.0]);

      // c = 2.0 * (a * b) + 0.5 * c
      cacheBlockedGemmFloat64(
        m: 2,
        n: 2,
        k: 2,
        alpha: 2.0,
        a: a,
        lda: 2,
        b: b,
        ldb: 2,
        beta: 0.5,
        c: c,
        ldc: 2,
      );

      // a * b = [19, 22, 43, 50]
      // c = 2.0 * [19, 22, 43, 50] + 0.5 * [10, 10, 10, 10]
      //   = [38 + 5, 44 + 5, 86 + 5, 100 + 5] = [43, 49, 91, 105]
      check(c[0]).isCloseTo(43.0, 1e-10);
      check(c[1]).isCloseTo(49.0, 1e-10);
      check(c[2]).isCloseTo(91.0, 1e-10);
      check(c[3]).isCloseTo(105.0, 1e-10);
    });

    test('multi-block tiled multiplication crossing 32x32 boundary', () {
      final rng = math.Random(42);
      const m = 35;
      const n = 45;
      const k = 33;

      final a = Float64List(m * k);
      final b = Float64List(k * n);
      final cBlocked = Float64List(m * n);
      final cRef = Float64List(m * n);

      for (var i = 0; i < a.length; i++) {
        a[i] = rng.nextDouble() * 2.0 - 1.0;
      }
      for (var i = 0; i < b.length; i++) {
        b[i] = rng.nextDouble() * 2.0 - 1.0;
      }

      // Compute with cache blocked GEMM
      cacheBlockedGemmFloat64(
        m: m,
        n: n,
        k: k,
        alpha: 1.0,
        a: a,
        lda: k,
        b: b,
        ldb: n,
        beta: 0.0,
        c: cBlocked,
        ldc: n,
      );

      // Compute with reference naive 3-loop GEMM
      for (var i = 0; i < m; i++) {
        for (var j = 0; j < n; j++) {
          var sum = 0.0;
          for (var p = 0; p < k; p++) {
            sum += a[i * k + p] * b[p * n + j];
          }
          cRef[i * n + j] = sum;
        }
      }

      // Verify exact equivalence
      for (var i = 0; i < m * n; i++) {
        check(cBlocked[i]).isCloseTo(cRef[i], 1e-9);
      }
    });

    test('zero dimensions and zero alpha edge cases', () {
      final a = Float64List(10);
      final b = Float64List(10);
      final c = Float64List.fromList([1.0, 2.0, 3.0, 4.0]);

      // m = 0
      check(
        cacheBlockedGemmFloat64(
          m: 0,
          n: 2,
          k: 2,
          alpha: 1.0,
          a: a,
          lda: 2,
          b: b,
          ldb: 2,
          beta: 1.0,
          c: c,
          ldc: 2,
        ),
      ).isTrue();

      // k = 0 with beta = 0.0 zeros C
      check(
        cacheBlockedGemmFloat64(
          m: 2,
          n: 2,
          k: 0,
          alpha: 1.0,
          a: a,
          lda: 0,
          b: b,
          ldb: 2,
          beta: 0.0,
          c: c,
          ldc: 2,
        ),
      ).isTrue();
      check(c[0]).equals(0.0);
      check(c[1]).equals(0.0);
      check(c[2]).equals(0.0);
      check(c[3]).equals(0.0);
    });
  });

  group('Pure Dart Cache-Blocked GEMM (Float32)', () {
    test('Float32 matrix multiplication matches reference', () {
      final a = Float32List.fromList([1.0, 2.0, 3.0, 4.0]);
      final b = Float32List.fromList([5.0, 6.0, 7.0, 8.0]);
      final c = Float32List(4);

      cacheBlockedGemmFloat32(
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

      check(c[0]).isCloseTo(19.0, 1e-5);
      check(c[1]).isCloseTo(22.0, 1e-5);
      check(c[2]).isCloseTo(43.0, 1e-5);
      check(c[3]).isCloseTo(50.0, 1e-5);
    });

    test('Float32 multi-block tiling with transpose', () {
      const m = 34;
      const n = 36;
      const k = 35;
      final a = Float32List(m * k);
      final b = Float32List(n * k); // for transB=cblasTrans, b is n x k
      final c = Float32List(m * n);

      for (var i = 0; i < a.length; i++) {
        a[i] = (i % 7).toDouble();
      }
      for (var i = 0; i < b.length; i++) {
        b[i] = (i % 5).toDouble();
      }

      cacheBlockedGemmFloat32(
        transA: cblasNoTrans,
        transB: cblasTrans,
        m: m,
        n: n,
        k: k,
        alpha: 1.0,
        a: a,
        lda: k,
        b: b,
        ldb: k,
        beta: 0.0,
        c: c,
        ldc: n,
      );

      // Verify row 0, col 0: sum_{p=0..k-1} a[0, p] * b[0, p]
      var expected00 = 0.0;
      for (var p = 0; p < k; p++) {
        expected00 += a[p] * b[p];
      }
      check(c[0]).isCloseTo(expected00, 1e-4);
    });
  });

  group('HardwareManager GEMM Routing & Matrix Integration', () {
    test(
      'HardwareManager.dgemm small matrix (N < 64) matches blocked GEMM',
      () {
        final a = Float64List.fromList([2.0, 0.0, 0.0, 3.0]);
        final b = Float64List.fromList([1.0, 4.0, 5.0, 2.0]);
        final c = Float64List(4);

        final success = HardwareManager.dgemm(
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

        check(success).isTrue();
        check(c[0]).isCloseTo(2.0, 1e-10);
        check(c[1]).isCloseTo(8.0, 1e-10);
        check(c[2]).isCloseTo(15.0, 1e-10);
        check(c[3]).isCloseTo(6.0, 1e-10);
      },
    );

    test('Matrix operator * produces consistent output regardless of HardwareManager.isEnabled', () {
      final m1 = Matrix<double>.generate(
        16,
        16,
        (r, c) => (r + c + 1).toDouble(),
      );
      final m2 = Matrix<double>.generate(
        16,
        16,
        (r, c) => (r * c + 1).toDouble(),
      );

      final prev = HardwareManager.isEnabled;
      try {
        HardwareManager.isEnabled = true;
        final resAcc = m1 * m2;

        HardwareManager.isEnabled = false;
        final resPure = m1 * m2;

        for (var r = 0; r < 16; r++) {
          for (var c = 0; c < 16; c++) {
            check(resAcc.getUnchecked(r, c))
                .isCloseTo(resPure.getUnchecked(r, c), 1e-9);
          }
        }
      } finally {
        HardwareManager.isEnabled = prev;
      }
    });

    test('Matrix operator * on 70x70 matrix with HardwareManager enabled vs disabled', () {
      final rng = math.Random(123);
      final m1 = Matrix<double>.generate(70, 70, (r, c) => rng.nextDouble());
      final m2 = Matrix<double>.generate(70, 70, (r, c) => rng.nextDouble());

      final prev = HardwareManager.isEnabled;
      try {
        HardwareManager.isEnabled = true;
        final resAcc = m1 * m2;

        HardwareManager.isEnabled = false;
        final resPure = m1 * m2;

        for (var r = 0; r < 70; r++) {
          for (var c = 0; c < 70; c++) {
            check(resAcc.getUnchecked(r, c))
                .isCloseTo(resPure.getUnchecked(r, c), 1e-8);
          }
        }
      } finally {
        HardwareManager.isEnabled = prev;
      }
    });
  });
}
