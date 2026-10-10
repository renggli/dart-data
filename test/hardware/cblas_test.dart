import 'dart:typed_data';

import 'package:checks/checks.dart';
import 'package:data/hardware.dart';
import 'package:data/linear.dart';
import 'package:data/type.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('CBLAS / LAPACK multi-RHS dgesv', () {
    test(
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

        // Solve using HardwareManager with fallback (pure Dart _luSolve)
        HardwareManager.isEnabled = false;
        final aFallback = Float64List.fromList(aMat.tensor.data);
        final bFallback = Float64List.fromList(bMat.tensor.data);
        final okFallback = HardwareManager.dgesv(
          n: 4,
          nrhs: 3,
          a: aFallback,
          lda: 4,
          b: bFallback,
          ldb: 3,
        );
        check(okFallback).isTrue();
        for (var r = 0; r < 4; r++) {
          for (var c = 0; c < 3; c++) {
            check(bFallback[r * 3 + c]).isCloseTo(xLu.get(r, c), 1e-9);
          }
        }

        // Solve using HardwareManager with native hardware acceleration enabled
        HardwareManager.isEnabled = true;
        if (HardwareManager.isNativeAvailable) {
          final aHw = Float64List.fromList(aMat.tensor.data);
          final bHw = Float64List.fromList(bMat.tensor.data);
          final okHw = HardwareManager.dgesv(
            n: 4,
            nrhs: 3,
            a: aHw,
            lda: 4,
            b: bHw,
            ldb: 3,
          );
          check(okHw).isTrue();
          for (var r = 0; r < 4; r++) {
            for (var c = 0; c < 3; c++) {
              check(bHw[r * 3 + c]).isCloseTo(xLu.get(r, c), 1e-9);
            }
          }
        }
      },
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

      for (final enableHw in [false, true]) {
        HardwareManager.isEnabled = enableHw;
        if (enableHw && !HardwareManager.isNativeAvailable) continue;

        final aCopy = Float64List.fromList(aMat.tensor.data);
        final bCopy = Float64List.fromList(bMat.tensor.data);
        final ok = HardwareManager.dgesv(
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
      }
      HardwareManager.isEnabled = true;
    });

    test('multi-RHS solve with buffer offsets and padding (aOffset, bOffset, ldb > nrhs)', () {
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

      for (final enableHw in [false, true]) {
        HardwareManager.isEnabled = enableHw;
        if (enableHw && !HardwareManager.isNativeAvailable) continue;

        final aCopy = Float64List.fromList(aBuffer);
        final bCopy = Float64List.fromList(bBuffer);

        final ok = HardwareManager.dgesv(
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
      }
      HardwareManager.isEnabled = true;
    });

    test('multi-RHS singular matrix fails gracefully without corrupting b', () {
      final aSingular = Float64List.fromList([
        1.0,
        2.0,
        3.0,
        4.0,
        5.0,
        6.0,
        0.0,
        0.0,
        0.0,
      ]);
      final bOriginal = Float64List.fromList([1.0, 2.0, 3.0, 4.0, 5.0, 6.0]);

      for (final enableHw in [false, true]) {
        HardwareManager.isEnabled = enableHw;
        if (enableHw && !HardwareManager.isNativeAvailable) continue;

        final aCopy = Float64List.fromList(aSingular);
        final bCopy = Float64List.fromList(bOriginal);

        final ok = HardwareManager.dgesv(
          n: 3,
          nrhs: 2,
          a: aCopy,
          lda: 3,
          b: bCopy,
          ldb: 2,
        );
        check(ok).isFalse();
        check(bCopy).deepEquals(bOriginal);
      }
      HardwareManager.isEnabled = true;
    });

    test('single-RHS (nrhs = 1) compatibility preserved', () {
      final a = Float64List.fromList([2.0, 1.0, 1.0, 3.0]);
      final b = Float64List.fromList([4.0, 7.0]);

      for (final enableHw in [false, true]) {
        HardwareManager.isEnabled = enableHw;
        if (enableHw && !HardwareManager.isNativeAvailable) continue;

        final aCopy = Float64List.fromList(a);
        final bCopy = Float64List.fromList(b);

        final ok = HardwareManager.dgesv(
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
      }
      HardwareManager.isEnabled = true;
    });

    test('single-RHS (nrhs = 1) with ldb > 1 (strided column)', () {
      final a = Float64List.fromList([2.0, 1.0, 1.0, 3.0]);
      // b has 2 rows and ldb = 3. Active column is col 0: [4.0, 7.0]^T.
      // Padding / other columns should not be corrupted.
      final b = Float64List.fromList([4.0, 111.0, 222.0, 7.0, 333.0, 444.0]);

      for (final enableHw in [false, true]) {
        HardwareManager.isEnabled = enableHw;
        if (enableHw && !HardwareManager.isNativeAvailable) continue;

        final aCopy = Float64List.fromList(a);
        final bCopy = Float64List.fromList(b);

        final ok = HardwareManager.dgesv(
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
      }
      HardwareManager.isEnabled = true;
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
      final ok = HardwareManager.dgesv(
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

      final ok = HardwareManager.dgesv(
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
      check(HardwareManager.dgesv(n: 2, nrhs: 1, a: a, lda: 1, b: b, ldb: 1))
          .isFalse();

      // ldb < nrhs
      check(HardwareManager.dgesv(n: 2, nrhs: 2, a: a, lda: 2, b: b, ldb: 1))
          .isFalse();

      // buffer too short
      final shortA = Float64List(2);
      check(
        HardwareManager.dgesv(n: 2, nrhs: 1, a: shortA, lda: 2, b: b, ldb: 1),
      ).isFalse();

      final shortB = Float64List(1);
      check(
        HardwareManager.dgesv(n: 2, nrhs: 1, a: a, lda: 2, b: shortB, ldb: 1),
      ).isFalse();

      // n = 0 or nrhs = 0
      check(HardwareManager.dgesv(n: 0, nrhs: 1, a: a, lda: 2, b: b, ldb: 1))
          .isTrue();
      check(HardwareManager.dgesv(n: 2, nrhs: 0, a: a, lda: 2, b: b, ldb: 1))
          .isTrue();
    });
  });
}
