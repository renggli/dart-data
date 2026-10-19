import 'dart:typed_data';

import 'package:checks/checks.dart';
import 'package:data/acceleration.dart';
import 'package:data/linear.dart';
import 'package:data/type.dart';
import 'package:test/test.dart';

import '../test_utils.dart';

void main() {
  group('CBLAS / LAPACK multi-RHS dgesv', () {
    accelerationTest(
      'multi-RHS solve (N = 4, nrhs = 3) compared against pure Dart LU solve',
      () {
        final aMat = Matrix<double>.fromRows([
          [2.0, 1.0, 0.0, 0.0],
          [1.0, 2.0, 1.0, 0.0],
          [0.0, 1.0, 2.0, 1.0],
          [0.0, 0.0, 1.0, 2.0],
        ], type: DataType.float64);

        final bMat = Matrix<double>.fromRows([
          [4.0, 5.0, 6.0],
          [4.0, 4.0, 4.0],
          [3.0, 0.0, 4.0],
          [5.0, -2.0, 5.0],
        ], type: DataType.float64);

        // Solve using pure Dart LU
        final lu = aMat.lu;
        check(lu.isNonsingular).isTrue();
        final xLu = lu.solve(bMat);

        // Verify analytical solution:
        // X = [
        //   [1.0,  2.0, 3.0],
        //   [2.0,  1.0, 0.0],
        //   [-1.0, 0.0, 1.0],
        //   [3.0, -1.0, 2.0],
        // ]
        check(xLu.get(0, 0)).isCloseTo(1.0, 1e-9);
        check(xLu.get(0, 1)).isCloseTo(2.0, 1e-9);
        check(xLu.get(0, 2)).isCloseTo(3.0, 1e-9);
        check(xLu.get(1, 0)).isCloseTo(2.0, 1e-9);
        check(xLu.get(1, 1)).isCloseTo(1.0, 1e-9);
        check(xLu.get(1, 2)).isCloseTo(0.0, 1e-9);
        check(xLu.get(2, 0)).isCloseTo(-1.0, 1e-9);
        check(xLu.get(2, 1)).isCloseTo(0.0, 1e-9);
        check(xLu.get(2, 2)).isCloseTo(1.0, 1e-9);
        check(xLu.get(3, 0)).isCloseTo(3.0, 1e-9);
        check(xLu.get(3, 1)).isCloseTo(-1.0, 1e-9);
        check(xLu.get(3, 2)).isCloseTo(2.0, 1e-9);

        // Solve using AccelerationManager
        final a = Float64List.fromList(aMat.tensor.data);
        final b = Float64List.fromList(bMat.tensor.data);
        final ok = AccelerationManager.dgesv(
          n: 4,
          nrhs: 3,
          a: a,
          lda: 4,
          b: b,
          ldb: 3,
        );
        check(ok).isTrue();
        for (var r = 0; r < 4; r++) {
          for (var c = 0; c < 3; c++) {
            check(b[r * 3 + c]).isCloseTo(xLu.get(r, c), 1e-9);
          }
        }
      },
      isSupported: AccelerationManager.isBlasAvailable,
    );

    test('multi-RHS solve with nrhs > N (N = 3, nrhs = 4)', () {
      final aMat = Matrix<double>.fromRows([
        [3.0, 1.0, 2.0],
        [1.0, 4.0, 1.0],
        [2.0, 2.0, 5.0],
      ], type: DataType.float64);

      final bMat = Matrix<double>.fromRows([
        [1.0, 0.0, 2.0, 3.0],
        [0.0, 1.0, -1.0, 2.0],
        [2.0, 1.0, 0.0, -1.0],
      ], type: DataType.float64);

      final lu = aMat.lu;
      check(lu.isNonsingular).isTrue();
      final xLu = lu.solve(bMat);

      final aCopy = Float64List.fromList(aMat.tensor.data);
      final bCopy = Float64List.fromList(bMat.tensor.data);
      final ok = AccelerationManager.dgesv(
        n: 3,
        nrhs: 4,
        a: aCopy,
        lda: 3,
        b: bCopy,
        ldb: 4,
      );
      check(ok).isTrue();
      for (var r = 0; r < 3; r++) {
        for (var c = 0; c < 4; c++) {
          check(bCopy[r * 4 + c]).isCloseTo(xLu.get(r, c), 1e-9);
        }
      }
    });

    accelerationTest('multi-RHS solve with buffer offsets and padding (aOffset, bOffset, ldb > nrhs)', () {
      final aMat = Matrix<double>.fromRows([
        [4.0, 1.0, 0.0],
        [1.0, 5.0, 2.0],
        [0.0, 2.0, 6.0],
      ], type: DataType.float64);

      final bMat = Matrix<double>.fromRows([
        [1.0, 2.0],
        [3.0, 4.0],
        [5.0, 6.0],
      ], type: DataType.float64);

      final lu = aMat.lu;
      final xLu = lu.solve(bMat);

      const aOffset = 3;
      final aBuffer = Float64List(aOffset + 3 * 3 + 2);
      aBuffer.setRange(aOffset, aOffset + 9, aMat.tensor.data);

      const bOffset = 2;
      const ldb = 4; // ldb > nrhs (stride 4 with 2 active columns)
      final bBuffer = Float64List(bOffset + 3 * ldb + 3);
      for (var r = 0; r < 3; r++) {
        bBuffer[bOffset + r * ldb + 0] = bMat.get(r, 0);
        bBuffer[bOffset + r * ldb + 1] = bMat.get(r, 1);
        bBuffer[bOffset + r * ldb + 2] = -999.0; // padding guard
        bBuffer[bOffset + r * ldb + 3] = -999.0; // padding guard
      }

      final aCopy = Float64List.fromList(aBuffer);
      final bCopy = Float64List.fromList(bBuffer);

      final ok = AccelerationManager.dgesv(
        n: 3,
        nrhs: 2,
        a: aCopy,
        aOffset: aOffset,
        lda: 3,
        b: bCopy,
        bOffset: bOffset,
        ldb: ldb,
      );
      check(ok).isTrue();
      for (var r = 0; r < 3; r++) {
        check(bCopy[bOffset + r * ldb + 0]).isCloseTo(xLu.get(r, 0), 1e-9);
        check(bCopy[bOffset + r * ldb + 1]).isCloseTo(xLu.get(r, 1), 1e-9);
      }
    });

    accelerationTest(
      'multi-RHS singular matrix fails gracefully without corrupting b',
      () {
        final aSingular = Float64List.fromList([
          1.0,
          2.0,
          3.0,
          2.0,
          4.0,
          6.0,
          0.0,
          0.0,
          0.0,
        ]);
        final bOriginal = Float64List.fromList([1.0, 2.0, 3.0, 4.0, 5.0, 6.0]);

        final aCopy = Float64List.fromList(aSingular);
        final bCopy = Float64List.fromList(bOriginal);

        final ok = AccelerationManager.dgesv(
          n: 3,
          nrhs: 2,
          a: aCopy,
          lda: 3,
          b: bCopy,
          ldb: 2,
        );
        check(ok).isFalse();
        check(bCopy).deepEquals(bOriginal);
      },
      isSupported: AccelerationManager.isBlasAvailable,
    );

    accelerationTest('single-RHS (nrhs = 1) compatibility preserved', () {
      final a = Float64List.fromList([2.0, 1.0, 1.0, 3.0]);
      final b = Float64List.fromList([4.0, 7.0]);

      final aCopy = Float64List.fromList(a);
      final bCopy = Float64List.fromList(b);

      final ok = AccelerationManager.dgesv(
        n: 2,
        nrhs: 1,
        a: aCopy,
        lda: 2,
        b: bCopy,
        ldb: 1,
      );
      check(ok).isTrue();
      check(bCopy[0]).isCloseTo(1.0, 1e-9);
      check(bCopy[1]).isCloseTo(2.0, 1e-9);
    });

    accelerationTest('single-RHS (nrhs = 1) with ldb > 1 (strided column)', () {
      final a = Float64List.fromList([2.0, 1.0, 1.0, 3.0]);
      // b has 2 rows and ldb = 3. Active column is col 0: [4.0, 7.0]^T.
      // Padding / other columns should not be corrupted.
      final b = Float64List.fromList([4.0, 111.0, 222.0, 7.0, 333.0, 444.0]);

      final aCopy = Float64List.fromList(a);
      final bCopy = Float64List.fromList(b);

      final ok = AccelerationManager.dgesv(
        n: 2,
        nrhs: 1,
        a: aCopy,
        lda: 2,
        b: bCopy,
        ldb: 3,
      );
      check(ok).isTrue();
      check(bCopy[0]).isCloseTo(1.0, 1e-9);
      check(bCopy[1]).equals(111.0); // padding guard
      check(bCopy[2]).equals(222.0); // padding guard
      check(bCopy[3]).isCloseTo(2.0, 1e-9);
      check(bCopy[4]).equals(333.0); // padding guard
      check(bCopy[5]).equals(444.0); // padding guard
    });

    test('multi-RHS solve with NativeBuffer backing', () {
      if (!NativeBuffer.isSupported || !NativeBuffer.isActive) return;

      final aMat = Matrix<double>.fromRows([
        [2.0, 1.0],
        [1.0, 3.0],
      ], type: DataType.float64);

      final bNative = NativeBuffer<double>(4, type: DataType.float64);
      bNative.data[0] = 4.0;
      bNative.data[1] = 5.0;
      bNative.data[2] = 7.0;
      bNative.data[3] = 10.0;

      final aCopy = Float64List.fromList(aMat.tensor.data);
      final ok = AccelerationManager.dgesv(
        n: 2,
        nrhs: 2,
        a: aCopy,
        lda: 2,
        b: bNative.data as Float64List,
        ldb: 2,
      );
      check(ok).isTrue();
      check(bNative.data[0]).isCloseTo(1.0, 1e-9);
      check(bNative.data[1]).isCloseTo(1.0, 1e-9);
      check(bNative.data[2]).isCloseTo(2.0, 1e-9);
      check(bNative.data[3]).isCloseTo(3.0, 1e-9);
      bNative.dispose();
    });

    test('single-RHS contiguous in-place solve with NativeBuffer backing', () {
      if (!NativeBuffer.isSupported || !NativeBuffer.isActive) return;

      final a = Float64List.fromList([2.0, 1.0, 1.0, 3.0]);
      final bNative = NativeBuffer<double>(2, type: DataType.float64);
      bNative.data[0] = 4.0;
      bNative.data[1] = 7.0;

      final ok = AccelerationManager.dgesv(
        n: 2,
        nrhs: 1,
        a: a,
        lda: 2,
        b: bNative.data as Float64List,
        ldb: 1,
      );
      check(ok).isTrue();
      check(bNative.data[0]).isCloseTo(1.0, 1e-9);
      check(bNative.data[1]).isCloseTo(2.0, 1e-9);
      bNative.dispose();
    });

    test('parameter validation and dimension bounds', () {
      final a = Float64List(4);
      final b = Float64List(4);

      // lda < n
      check(
        AccelerationManager.dgesv(n: 2, nrhs: 1, a: a, lda: 1, b: b, ldb: 1),
      ).isFalse();

      // ldb < nrhs
      check(
        AccelerationManager.dgesv(n: 2, nrhs: 2, a: a, lda: 2, b: b, ldb: 1),
      ).isFalse();

      // buffer too short
      final shortA = Float64List(2);
      check(
        AccelerationManager.dgesv(
          n: 2,
          nrhs: 1,
          a: shortA,
          lda: 2,
          b: b,
          ldb: 1,
        ),
      ).isFalse();

      final shortB = Float64List(1);
      check(
        AccelerationManager.dgesv(
          n: 2,
          nrhs: 1,
          a: a,
          lda: 2,
          b: shortB,
          ldb: 1,
        ),
      ).isFalse();

      // n = 0 or nrhs = 0
      check(
        AccelerationManager.dgesv(n: 0, nrhs: 1, a: a, lda: 2, b: b, ldb: 1),
      ).isTrue();
      check(
        AccelerationManager.dgesv(n: 2, nrhs: 0, a: a, lda: 2, b: b, ldb: 1),
      ).isTrue();
    });
  });

  group('CBLAS dtrmv and strmv', () {
    test('dtrmv upper, lower, trans, and unit options', () {
      final a = Float64List.fromList([2.0, 3.0, 0.0, 4.0]);

      // Upper, noTrans, nonUnit: [2*5 + 3*7, 4*7] = [31, 28]
      final x1 = Float64List.fromList([5.0, 7.0]);
      check(
        AccelerationManager.dtrmv(
          uplo: cblasUpper,
          trans: cblasNoTrans,
          diag: cblasNonUnit,
          n: 2,
          a: a,
          lda: 2,
          x: x1,
        ),
      ).isTrue();
      check(x1[0]).isCloseTo(31.0, 1e-9);
      check(x1[1]).isCloseTo(28.0, 1e-9);

      // Upper, trans, nonUnit: A^T * x = [2*5 + 0*7, 3*5 + 4*7] = [10, 43]
      final x2 = Float64List.fromList([5.0, 7.0]);
      check(
        AccelerationManager.dtrmv(
          uplo: cblasUpper,
          trans: cblasTrans,
          diag: cblasNonUnit,
          n: 2,
          a: a,
          lda: 2,
          x: x2,
        ),
      ).isTrue();
      check(x2[0]).isCloseTo(10.0, 1e-9);
      check(x2[1]).isCloseTo(43.0, 1e-9);

      // Upper, noTrans, unit: diag treated as 1 -> [1*5 + 3*7, 1*7] = [26, 7]
      final x3 = Float64List.fromList([5.0, 7.0]);
      check(
        AccelerationManager.dtrmv(
          uplo: cblasUpper,
          trans: cblasNoTrans,
          diag: cblasUnit,
          n: 2,
          a: a,
          lda: 2,
          x: x3,
        ),
      ).isTrue();
      check(x3[0]).isCloseTo(26.0, 1e-9);
      check(x3[1]).isCloseTo(7.0, 1e-9);

      // Lower, noTrans, nonUnit with lower triangular matrix
      final aLower = Float64List.fromList([2.0, 0.0, 3.0, 4.0]);
      final x4 = Float64List.fromList([5.0, 7.0]);
      check(
        AccelerationManager.dtrmv(
          uplo: cblasLower,
          trans: cblasNoTrans,
          diag: cblasNonUnit,
          n: 2,
          a: aLower,
          lda: 2,
          x: x4,
        ),
      ).isTrue();
      check(x4[0]).isCloseTo(10.0, 1e-9);
      check(x4[1]).isCloseTo(43.0, 1e-9);
    });

    test('strmv single-precision calculation', () {
      final a = Float32List.fromList([2.0, 3.0, 0.0, 4.0]);
      final x = Float32List.fromList([5.0, 7.0]);
      check(
        AccelerationManager.strmv(
          uplo: cblasUpper,
          trans: cblasNoTrans,
          diag: cblasNonUnit,
          n: 2,
          a: a,
          lda: 2,
          x: x,
        ),
      ).isTrue();
      check(x[0]).isCloseTo(31.0, 1e-5);
      check(x[1]).isCloseTo(28.0, 1e-5);
    });

    accelerationTest('dtrmv hardware acceleration vs fallback consistency', () {
      final a = Float64List.fromList([
        3.0,
        -1.0,
        2.0,
        0.0,
        4.0,
        5.0,
        0.0,
        0.0,
        6.0,
      ]);
      final x = Float64List.fromList([2.0, 4.0, 3.0]);

      check(
        AccelerationManager.dtrmv(
          uplo: cblasUpper,
          trans: cblasNoTrans,
          diag: cblasNonUnit,
          n: 3,
          a: a,
          lda: 3,
          x: x,
        ),
      ).isTrue();

      check(x[0]).isCloseTo(8.0, 1e-9);
      check(x[1]).isCloseTo(31.0, 1e-9);
      check(x[2]).isCloseTo(18.0, 1e-9);
    }, isSupported: AccelerationManager.isBlasAvailable);

    test('dtrmv validation bounds', () {
      final a = Float64List(4);
      final x = Float64List(2);

      check(AccelerationManager.dtrmv(n: 2, a: a, lda: 1, x: x)).isFalse();
      check(AccelerationManager.dtrmv(n: 2, a: a, lda: 2, x: x, incX: 0))
          .isFalse();
      check(AccelerationManager.dtrmv(n: 0, a: a, lda: 2, x: x)).isTrue();
    });
  });

  group('CBLAS dsymm and ssymm', () {
    test('dsymm side left and right with alpha and beta scaling', () {
      // A = [ [2, 1], [1, 3] ]
      final a = Float64List.fromList([2.0, 1.0, 1.0, 3.0]);
      // B = [ [1, 2], [3, 4] ]
      final b = Float64List.fromList([1.0, 2.0, 3.0, 4.0]);

      // Side left: C = 1.0 * A * B + 0.0 * C = [ [5, 8], [10, 14] ]
      final cLeft = Float64List(4);
      check(
        AccelerationManager.dsymm(
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
          c: cLeft,
          ldc: 2,
        ),
      ).isTrue();
      check(cLeft[0]).isCloseTo(5.0, 1e-9);
      check(cLeft[1]).isCloseTo(8.0, 1e-9);
      check(cLeft[2]).isCloseTo(10.0, 1e-9);
      check(cLeft[3]).isCloseTo(14.0, 1e-9);

      // Side right: C = 1.0 * B * A + 0.0 * C = [ [4, 7], [10, 15] ]
      final cRight = Float64List(4);
      check(
        AccelerationManager.dsymm(
          side: cblasRight,
          uplo: cblasUpper,
          m: 2,
          n: 2,
          alpha: 1.0,
          a: a,
          lda: 2,
          b: b,
          ldb: 2,
          beta: 0.0,
          c: cRight,
          ldc: 2,
        ),
      ).isTrue();
      check(cRight[0]).isCloseTo(4.0, 1e-9);
      check(cRight[1]).isCloseTo(7.0, 1e-9);
      check(cRight[2]).isCloseTo(10.0, 1e-9);
      check(cRight[3]).isCloseTo(15.0, 1e-9);
    });

    test('ssymm single-precision calculation', () {
      final a = Float32List.fromList([2.0, 1.0, 1.0, 3.0]);
      final b = Float32List.fromList([1.0, 2.0, 3.0, 4.0]);
      final c = Float32List(4);
      check(
        AccelerationManager.ssymm(
          side: cblasLeft,
          uplo: cblasUpper,
          m: 2,
          n: 2,
          alpha: 2.0,
          a: a,
          lda: 2,
          b: b,
          ldb: 2,
          beta: 0.0,
          c: c,
          ldc: 2,
        ),
      ).isTrue();
      check(c[0]).isCloseTo(10.0, 1e-5);
      check(c[1]).isCloseTo(16.0, 1e-5);
      check(c[2]).isCloseTo(20.0, 1e-5);
      check(c[3]).isCloseTo(28.0, 1e-5);
    });

    accelerationTest('dsymm hardware acceleration vs fallback consistency', () {
      final a = Float64List.fromList([
        5.0,
        2.0,
        -1.0,
        2.0,
        4.0,
        3.0,
        -1.0,
        3.0,
        6.0,
      ]);
      final b = Float64List.fromList([1.0, 2.0, 3.0, 4.0, 5.0, 6.0]);
      final c = Float64List(6);

      check(
        AccelerationManager.dsymm(
          side: cblasLeft,
          uplo: cblasUpper,
          m: 3,
          n: 2,
          alpha: 1.5,
          a: a,
          lda: 3,
          b: b,
          ldb: 2,
          beta: 0.0,
          c: c,
          ldc: 2,
        ),
      ).isTrue();

      check(c[0]).isCloseTo(9.0, 1e-9);
      check(c[1]).isCloseTo(18.0, 1e-9);
      check(c[2]).isCloseTo(43.5, 1e-9);
      check(c[3]).isCloseTo(57.0, 1e-9);
      check(c[4]).isCloseTo(57.0, 1e-9);
      check(c[5]).isCloseTo(69.0, 1e-9);
    }, isSupported: AccelerationManager.isBlasAvailable);

    test('dsymm validation bounds', () {
      final a = Float64List(4);
      final b = Float64List(4);
      final c = Float64List(4);

      check(
        AccelerationManager.dsymm(
          side: cblasLeft,
          m: 2,
          n: 2,
          alpha: 1.0,
          a: a,
          lda: 1,
          b: b,
          ldb: 2,
          beta: 0.0,
          c: c,
          ldc: 2,
        ),
      ).isFalse();
      check(
        AccelerationManager.dsymm(
          side: cblasLeft,
          m: 0,
          n: 2,
          alpha: 1.0,
          a: a,
          lda: 2,
          b: b,
          ldb: 2,
          beta: 0.0,
          c: c,
          ldc: 2,
        ),
      ).isTrue();
    });
  });

  group('CBLAS dtrmm and strmm', () {
    test('dtrmm side left and right in-place triangular matrix multiply', () {
      // A = [ [2, 3], [0, 4] ]
      final a = Float64List.fromList([2.0, 3.0, 0.0, 4.0]);

      // Left: B = 1.0 * A * B = [ [11, 16], [12, 16] ]
      final bLeft = Float64List.fromList([1.0, 2.0, 3.0, 4.0]);
      check(
        AccelerationManager.dtrmm(
          side: cblasLeft,
          uplo: cblasUpper,
          transA: cblasNoTrans,
          diag: cblasNonUnit,
          m: 2,
          n: 2,
          alpha: 1.0,
          a: a,
          lda: 2,
          b: bLeft,
          ldb: 2,
        ),
      ).isTrue();
      check(bLeft[0]).isCloseTo(11.0, 1e-9);
      check(bLeft[1]).isCloseTo(16.0, 1e-9);
      check(bLeft[2]).isCloseTo(12.0, 1e-9);
      check(bLeft[3]).isCloseTo(16.0, 1e-9);

      // Left, trans: B = 1.0 * A^T * B = [ [2, 4], [15, 22] ]
      final bLeftTrans = Float64List.fromList([1.0, 2.0, 3.0, 4.0]);
      check(
        AccelerationManager.dtrmm(
          side: cblasLeft,
          uplo: cblasUpper,
          transA: cblasTrans,
          diag: cblasNonUnit,
          m: 2,
          n: 2,
          alpha: 1.0,
          a: a,
          lda: 2,
          b: bLeftTrans,
          ldb: 2,
        ),
      ).isTrue();
      check(bLeftTrans[0]).isCloseTo(2.0, 1e-9);
      check(bLeftTrans[1]).isCloseTo(4.0, 1e-9);
      check(bLeftTrans[2]).isCloseTo(15.0, 1e-9);
      check(bLeftTrans[3]).isCloseTo(22.0, 1e-9);

      // Right: B = 1.0 * B * A = [ [2, 11], [6, 25] ]
      final bRight = Float64List.fromList([1.0, 2.0, 3.0, 4.0]);
      check(
        AccelerationManager.dtrmm(
          side: cblasRight,
          uplo: cblasUpper,
          transA: cblasNoTrans,
          diag: cblasNonUnit,
          m: 2,
          n: 2,
          alpha: 1.0,
          a: a,
          lda: 2,
          b: bRight,
          ldb: 2,
        ),
      ).isTrue();
      check(bRight[0]).isCloseTo(2.0, 1e-9);
      check(bRight[1]).isCloseTo(11.0, 1e-9);
      check(bRight[2]).isCloseTo(6.0, 1e-9);
      check(bRight[3]).isCloseTo(25.0, 1e-9);
    });

    test('strmm single-precision calculation', () {
      final a = Float32List.fromList([2.0, 3.0, 0.0, 4.0]);
      final b = Float32List.fromList([1.0, 2.0, 3.0, 4.0]);
      check(
        AccelerationManager.strmm(
          side: cblasLeft,
          uplo: cblasUpper,
          transA: cblasNoTrans,
          diag: cblasNonUnit,
          m: 2,
          n: 2,
          alpha: 2.0,
          a: a,
          lda: 2,
          b: b,
          ldb: 2,
        ),
      ).isTrue();
      check(b[0]).isCloseTo(22.0, 1e-5);
      check(b[1]).isCloseTo(32.0, 1e-5);
      check(b[2]).isCloseTo(24.0, 1e-5);
      check(b[3]).isCloseTo(32.0, 1e-5);
    });

    accelerationTest('dtrmm hardware acceleration vs fallback consistency', () {
      final a = Float64List.fromList([
        2.0,
        1.0,
        -1.0,
        0.0,
        3.0,
        2.0,
        0.0,
        0.0,
        4.0,
      ]);
      final b = Float64List.fromList([1.0, 2.0, 3.0, 4.0, 5.0, 6.0]);

      check(
        AccelerationManager.dtrmm(
          side: cblasLeft,
          uplo: cblasUpper,
          transA: cblasNoTrans,
          diag: cblasNonUnit,
          m: 3,
          n: 2,
          alpha: 1.0,
          a: a,
          lda: 3,
          b: b,
          ldb: 2,
        ),
      ).isTrue();

      check(b[0]).isCloseTo(0.0, 1e-9);
      check(b[1]).isCloseTo(2.0, 1e-9);
      check(b[2]).isCloseTo(19.0, 1e-9);
      check(b[3]).isCloseTo(24.0, 1e-9);
      check(b[4]).isCloseTo(20.0, 1e-9);
      check(b[5]).isCloseTo(24.0, 1e-9);
    }, isSupported: AccelerationManager.isBlasAvailable);

    test('dtrmm validation bounds', () {
      final a = Float64List(4);
      final b = Float64List(4);

      check(
        AccelerationManager.dtrmm(
          side: cblasLeft,
          m: 2,
          n: 2,
          alpha: 1.0,
          a: a,
          lda: 1,
          b: b,
          ldb: 2,
        ),
      ).isFalse();
      check(
        AccelerationManager.dtrmm(
          side: cblasLeft,
          m: 0,
          n: 2,
          alpha: 1.0,
          a: a,
          lda: 2,
          b: b,
          ldb: 2,
        ),
      ).isTrue();
    });
  });

  group('LAPACK dsyev and ssyev', () {
    test('dsyev 2x2 eigenvalue and orthonormal eigenvector solve', () {
      final a = Float64List.fromList([2.0, 1.0, 1.0, 2.0]);
      final w = Float64List(2);

      check(
        AccelerationManager.dsyev(
          jobz: 'V',
          uplo: cblasUpper,
          n: 2,
          a: a,
          lda: 2,
          w: w,
        ),
      ).isTrue();

      // Eigenvalues in ascending order: [1.0, 3.0]
      check(w[0]).isCloseTo(1.0, 1e-9);
      check(w[1]).isCloseTo(3.0, 1e-9);

      // Eigenvectors in columns of a: V^T * V = I
      final v00 = a[0];
      final v10 = a[2];
      final v01 = a[1];
      final v11 = a[3];

      check(v00 * v00 + v10 * v10).isCloseTo(1.0, 1e-9);
      check(v01 * v01 + v11 * v11).isCloseTo(1.0, 1e-9);
      check(v00 * v01 + v10 * v11).isCloseTo(0.0, 1e-9);

      // Verify A * v_i = lambda_i * v_i
      final origA = [2.0, 1.0, 1.0, 2.0];
      // A * v0
      final av0_0 = origA[0] * v00 + origA[1] * v10;
      final av0_1 = origA[2] * v00 + origA[3] * v10;
      check(av0_0).isCloseTo(w[0] * v00, 1e-9);
      check(av0_1).isCloseTo(w[0] * v10, 1e-9);

      // A * v1
      final av1_0 = origA[0] * v01 + origA[1] * v11;
      final av1_1 = origA[2] * v01 + origA[3] * v11;
      check(av1_0).isCloseTo(w[1] * v01, 1e-9);
      check(av1_1).isCloseTo(w[1] * v11, 1e-9);
    });

    accelerationTest('dsyev 3x3 hardware vs fallback consistency', () {
      final a = Float64List.fromList([
        4.0,
        1.0,
        -2.0,
        1.0,
        2.0,
        0.0,
        -2.0,
        0.0,
        3.0,
      ]);
      final w = Float64List(3);

      check(
        AccelerationManager.dsyev(
          jobz: 'V',
          uplo: cblasUpper,
          n: 3,
          a: a,
          lda: 3,
          w: w,
        ),
      ).isTrue();

      check(w[0] <= w[1]).isTrue();
      check(w[1] <= w[2]).isTrue();
      check(w[0] + w[1] + w[2]).isCloseTo(9.0, 1e-8);

      // Check orthonormality of eigenvector matrix
      for (var i = 0; i < 3; i++) {
        for (var j = 0; j < 3; j++) {
          var dot = 0.0;
          for (var r = 0; r < 3; r++) {
            dot += a[r * 3 + i] * a[r * 3 + j];
          }
          check(dot).isCloseTo(i == j ? 1.0 : 0.0, 1e-8);
        }
      }
    }, isSupported: AccelerationManager.isBlasAvailable);

    test('ssyev single-precision calculation', () {
      final a = Float32List.fromList([2.0, 1.0, 1.0, 2.0]);
      final w = Float32List(2);

      check(
        AccelerationManager.ssyev(
          jobz: 'V',
          uplo: cblasUpper,
          n: 2,
          a: a,
          lda: 2,
          w: w,
        ),
      ).isTrue();

      check(w[0]).isCloseTo(1.0, 1e-4);
      check(w[1]).isCloseTo(3.0, 1e-4);
    });

    test('dsyev validation and edge cases', () {
      final a = Float64List(4);
      final w = Float64List(2);

      check(AccelerationManager.dsyev(n: 2, a: a, lda: 1, w: w)).isFalse();
      check(AccelerationManager.dsyev(n: 0, a: a, lda: 2, w: w)).isTrue();

      // 1x1 matrix
      final a1 = Float64List.fromList([42.0]);
      final w1 = Float64List(1);
      check(AccelerationManager.dsyev(n: 1, a: a1, lda: 1, w: w1)).isTrue();
      check(w1[0]).equals(42.0);
      check(a1[0]).equals(1.0);
    });

    accelerationTest(
      'dtrmv with row padding (lda > n) and strided incX > 1',
      () {
        final a = Float64List.fromList([2.0, 3.0, -999.0, 0.0, 4.0]);
        final x = Float64List.fromList([5.0, -888.0, 7.0, -888.0, -888.0]);

        final xCopy = Float64List.fromList(x);
        final aCopy = Float64List.fromList(a);
        check(
          AccelerationManager.dtrmv(
            uplo: cblasUpper,
            trans: cblasNoTrans,
            diag: cblasNonUnit,
            n: 2,
            a: aCopy,
            lda: 3,
            x: xCopy,
            incX: 2,
          ),
        ).isTrue();
        check(xCopy[0]).isCloseTo(31.0, 1e-9);
        check(xCopy[1]).equals(-888.0);
        check(xCopy[2]).isCloseTo(28.0, 1e-9);
        check(xCopy[3]).equals(-888.0);
        check(aCopy[2]).equals(-999.0);
      },
    );

    accelerationTest(
      'dsymm with buffer padding and offsets (lda > m, ldb > n, ldc > n)',
      () {
        final a = Float64List.fromList([2.0, 1.0, -777.0, 1.0, 3.0]);
        final b = Float64List.fromList([1.0, 2.0, -888.0, 3.0, 4.0]);

        final c = Float64List.fromList([0.0, 0.0, -999.0, 0.0, 0.0]);
        check(
          AccelerationManager.dsymm(
            side: cblasLeft,
            uplo: cblasUpper,
            m: 2,
            n: 2,
            alpha: 1.0,
            a: a,
            lda: 3,
            b: b,
            ldb: 3,
            beta: 0.0,
            c: c,
            ldc: 3,
          ),
        ).isTrue();
        check(c[0]).isCloseTo(5.0, 1e-9);
        check(c[1]).isCloseTo(8.0, 1e-9);
        check(c[2]).equals(-999.0);
        check(c[3]).isCloseTo(10.0, 1e-9);
        check(c[4]).isCloseTo(14.0, 1e-9);
      },
    );

    accelerationTest('dtrmm with buffer padding (lda > m, ldb > n)', () {
      final a = Float64List.fromList([2.0, 3.0, -777.0, 0.0, 4.0]);
      final b = Float64List.fromList([1.0, 2.0, -888.0, 3.0, 4.0]);
      check(
        AccelerationManager.dtrmm(
          side: cblasLeft,
          uplo: cblasUpper,
          transA: cblasNoTrans,
          diag: cblasNonUnit,
          m: 2,
          n: 2,
          alpha: 1.0,
          a: a,
          lda: 3,
          b: b,
          ldb: 3,
        ),
      ).isTrue();
      check(b[0]).isCloseTo(11.0, 1e-9);
      check(b[1]).isCloseTo(16.0, 1e-9);
      check(b[2]).equals(-888.0);
      check(b[3]).isCloseTo(12.0, 1e-9);
      check(b[4]).isCloseTo(16.0, 1e-9);
    });

    test('dsyev with jobz = N (eigenvalues only) and lowercase jobz = v', () {
      final origA = [2.0, 1.0, 1.0, 2.0];
      final aN = Float64List.fromList(origA);
      final wN = Float64List(2);
      check(
        AccelerationManager.dsyev(
          jobz: 'N',
          uplo: cblasUpper,
          n: 2,
          a: aN,
          lda: 2,
          w: wN,
        ),
      ).isTrue();
      check(wN[0]).isCloseTo(1.0, 1e-9);
      check(wN[1]).isCloseTo(3.0, 1e-9);

      final aV = Float64List.fromList(origA);
      final wV = Float64List(2);
      check(
        AccelerationManager.dsyev(
          jobz: 'v',
          uplo: cblasUpper,
          n: 2,
          a: aV,
          lda: 2,
          w: wV,
        ),
      ).isTrue();
      check(wV[0]).isCloseTo(1.0, 1e-9);
      check(wV[1]).isCloseTo(3.0, 1e-9);
      check(aV[0] * aV[0] + aV[2] * aV[2]).isCloseTo(1.0, 1e-9);
      check(aV[1] * aV[1] + aV[3] * aV[3]).isCloseTo(1.0, 1e-9);
    });

    test('validation of invalid options on dtrmv, dsymm, dtrmm, dsyev', () {
      final a = Float64List(4);
      final b = Float64List(4);
      final c = Float64List(4);
      final w = Float64List(2);

      check(AccelerationManager.dtrmv(uplo: 999, n: 2, a: a, lda: 2, x: b))
          .isFalse();
      check(AccelerationManager.dtrmv(trans: 999, n: 2, a: a, lda: 2, x: b))
          .isFalse();
      check(AccelerationManager.dtrmv(diag: 999, n: 2, a: a, lda: 2, x: b))
          .isFalse();

      check(
        AccelerationManager.dsymm(
          side: 999,
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
        ),
      ).isFalse();
      check(
        AccelerationManager.dsymm(
          uplo: 999,
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
        ),
      ).isFalse();

      check(
        AccelerationManager.dtrmm(
          side: 999,
          m: 2,
          n: 2,
          alpha: 1.0,
          a: a,
          lda: 2,
          b: b,
          ldb: 2,
        ),
      ).isFalse();
      check(
        AccelerationManager.dtrmm(
          transA: 999,
          m: 2,
          n: 2,
          alpha: 1.0,
          a: a,
          lda: 2,
          b: b,
          ldb: 2,
        ),
      ).isFalse();

      check(
        AccelerationManager.dsyev(jobz: 'INVALID', n: 2, a: a, lda: 2, w: w),
      ).isFalse();
      check(AccelerationManager.dsyev(uplo: 999, n: 2, a: a, lda: 2, w: w))
          .isFalse();
    });
  });
}
