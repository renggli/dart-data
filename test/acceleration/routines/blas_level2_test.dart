import 'dart:typed_data';

import 'package:checks/checks.dart';
import 'package:data/acceleration.dart';
import 'package:test/test.dart';

import '../test_utils.dart';

void main() {
  group('BlasLevel2 Routines', () {
    accelerationTest('dgemv general matrix-vector multiply', () {
      final a = Float64List.fromList([1.0, 2.0, 3.0, 4.0]);
      final x = Float64List.fromList([1.0, 2.0]);
      final y = Float64List(2);

      final ok = AccelerationManager.dgemv(
        m: 2,
        n: 2,
        alpha: 1.0,
        a: a,
        lda: 2,
        x: x,
        incX: 1,
        beta: 0.0,
        y: y,
        incY: 1,
      );
      check(ok).isTrue();
      // [1*1 + 2*2, 3*1 + 4*2] = [5, 11]
      check(y[0]).isCloseTo(5.0, 1e-10);
      check(y[1]).isCloseTo(11.0, 1e-10);
    }, isSupported: AccelerationManager.isBlasAvailable);

    accelerationTest('dgemv transpose', () {
      final a = Float64List.fromList([1.0, 2.0, 3.0, 4.0]);
      final x = Float64List.fromList([1.0, 2.0]);
      final y = Float64List(2);

      final ok = AccelerationManager.dgemv(
        transA: cblasTrans,
        m: 2,
        n: 2,
        alpha: 1.0,
        a: a,
        lda: 2,
        x: x,
        incX: 1,
        beta: 0.0,
        y: y,
        incY: 1,
      );
      check(ok).isTrue();
      // [1*1 + 3*2, 2*1 + 4*2] = [7, 10]
      check(y[0]).isCloseTo(7.0, 1e-10);
      check(y[1]).isCloseTo(10.0, 1e-10);
    }, isSupported: AccelerationManager.isBlasAvailable);

    accelerationTest('sgemv single-precision matrix-vector multiply', () {
      final a = Float32List.fromList([2.0, 0.0, 0.0, 3.0]);
      final x = Float32List.fromList([4.0, 5.0]);
      final y = Float32List(2);

      final ok = AccelerationManager.sgemv(
        m: 2,
        n: 2,
        alpha: 1.0,
        a: a,
        lda: 2,
        x: x,
        incX: 1,
        beta: 0.0,
        y: y,
        incY: 1,
      );
      check(ok).isTrue();
      check(y[0]).isCloseTo(8.0, 1e-5);
      check(y[1]).isCloseTo(15.0, 1e-5);
    }, isSupported: AccelerationManager.isBlasAvailable);

    accelerationTest('dsyr2 rank-2 symmetric update', () {
      final a = Float64List(4);
      final x = Float64List.fromList([1.0, 2.0]);
      final y = Float64List.fromList([3.0, 4.0]);

      final ok = AccelerationManager.dsyr2(
        uplo: cblasUpper,
        n: 2,
        alpha: 1.0,
        x: x,
        y: y,
        a: a,
        lda: 2,
      );
      check(ok).isTrue();
      // A_ij += alpha * (x_i y_j + y_i x_j)
      // A_00 = 1*(1*3 + 3*1) = 6
      // A_01 = 1*(1*4 + 3*2) = 10
      // A_11 = 1*(2*4 + 4*2) = 16
      check(a[0]).isCloseTo(6.0, 1e-10);
      check(a[1]).isCloseTo(10.0, 1e-10);
      check(a[3]).isCloseTo(16.0, 1e-10);
    }, isSupported: AccelerationManager.isBlasAvailable);

    accelerationTest('ssyr2 single-precision rank-2 update', () {
      final a = Float32List(4);
      final x = Float32List.fromList([1.0, 2.0]);
      final y = Float32List.fromList([3.0, 4.0]);

      final ok = AccelerationManager.ssyr2(
        uplo: cblasUpper,
        n: 2,
        alpha: 1.0,
        x: x,
        y: y,
        a: a,
        lda: 2,
      );
      check(ok).isTrue();
      check(a[0]).isCloseTo(6.0, 1e-5);
      check(a[1]).isCloseTo(10.0, 1e-5);
      check(a[3]).isCloseTo(16.0, 1e-5);
    }, isSupported: AccelerationManager.isBlasAvailable);

    accelerationTest('dtrmv triangular matrix-vector multiply', () {
      final a = Float64List.fromList([2.0, 3.0, 0.0, 4.0]);
      final x = Float64List.fromList([5.0, 7.0]);

      final ok = AccelerationManager.dtrmv(
        uplo: cblasUpper,
        n: 2,
        a: a,
        lda: 2,
        x: x,
      );
      check(ok).isTrue();
      // Upper: [2*5 + 3*7, 4*7] = [31, 28]
      check(x[0]).isCloseTo(31.0, 1e-10);
      check(x[1]).isCloseTo(28.0, 1e-10);
    }, isSupported: AccelerationManager.isBlasAvailable);

    accelerationTest(
      'strmv single-precision triangular matrix-vector multiply',
      () {
        final a = Float32List.fromList([2.0, 3.0, 0.0, 4.0]);
        final x = Float32List.fromList([5.0, 7.0]);

        final ok = AccelerationManager.strmv(
          uplo: cblasUpper,
          n: 2,
          a: a,
          lda: 2,
          x: x,
        );
        check(ok).isTrue();
        check(x[0]).isCloseTo(31.0, 1e-5);
        check(x[1]).isCloseTo(28.0, 1e-5);
      },
      isSupported: AccelerationManager.isBlasAvailable,
    );
  });
}
