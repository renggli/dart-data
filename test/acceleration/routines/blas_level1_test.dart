import 'dart:typed_data';

import 'package:checks/checks.dart';
import 'package:data/acceleration.dart';
import 'package:test/test.dart';

import '../test_utils.dart';

void main() {
  group('BlasLevel1 Routines', () {
    accelerationTest('ddot with positive values', () {
      final x = Float64List.fromList([1.0, 2.0, 3.0]);
      final y = Float64List.fromList([4.0, 5.0, 6.0]);
      final dot = AccelerationManager.ddot(n: 3, x: x, y: y);
      check(dot).isNotNull();
      check(dot!).isCloseTo(32.0, 1e-10);
    }, isSupported: AccelerationManager.isBlasAvailable);

    accelerationTest('ddot with offsets and strides', () {
      final x = Float64List.fromList([0.0, 1.0, 0.0, 2.0]);
      final y = Float64List.fromList([0.0, 0.0, 3.0, 0.0, 4.0]);
      final dot = AccelerationManager.ddot(
        n: 2,
        x: x,
        xOffset: 1,
        incX: 2,
        y: y,
        yOffset: 2,
        incY: 2,
      );
      check(dot).isNotNull();
      check(dot!).isCloseTo(1.0 * 3.0 + 2.0 * 4.0, 1e-10);
    }, isSupported: AccelerationManager.isBlasAvailable);

    accelerationTest('sdot with negative values', () {
      final x = Float32List.fromList([1.0, -2.0, 3.0]);
      final y = Float32List.fromList([-4.0, 5.0, -6.0]);
      final dot = AccelerationManager.sdot(n: 3, x: x, y: y);
      check(dot).isNotNull();
      check(dot!).isCloseTo(-4.0 - 10.0 - 18.0, 1e-5);
    }, isSupported: AccelerationManager.isBlasAvailable);

    accelerationTest('dnrm2 Euclidean norm', () {
      final x = Float64List.fromList([3.0, 4.0]);
      final norm = AccelerationManager.dnrm2(n: 2, x: x);
      check(norm).isNotNull();
      check(norm!).isCloseTo(5.0, 1e-10);
    }, isSupported: AccelerationManager.isBlasAvailable);

    accelerationTest('snrm2 Euclidean norm', () {
      final x = Float32List.fromList([1.0, 2.0, 2.0]);
      final norm = AccelerationManager.snrm2(n: 3, x: x);
      check(norm).isNotNull();
      check(norm!).isCloseTo(3.0, 1e-5);
    }, isSupported: AccelerationManager.isBlasAvailable);

    accelerationTest('daxpy vector accumulation y = alpha * x + y', () {
      final x = Float64List.fromList([1.0, 2.0, 3.0]);
      final y = Float64List.fromList([10.0, 20.0, 30.0]);
      final ok = AccelerationManager.daxpy(n: 3, alpha: 2.0, x: x, y: y);
      check(ok).isTrue();
      check(y[0]).isCloseTo(12.0, 1e-10);
      check(y[1]).isCloseTo(24.0, 1e-10);
      check(y[2]).isCloseTo(36.0, 1e-10);
    }, isSupported: AccelerationManager.isBlasAvailable);

    accelerationTest('saxpy single-precision vector accumulation', () {
      final x = Float32List.fromList([1.0, 2.0, 3.0]);
      final y = Float32List.fromList([10.0, 20.0, 30.0]);
      final ok = AccelerationManager.saxpy(n: 3, alpha: 3.0, x: x, y: y);
      check(ok).isTrue();
      check(y[0]).isCloseTo(13.0, 1e-5);
      check(y[1]).isCloseTo(26.0, 1e-5);
      check(y[2]).isCloseTo(39.0, 1e-5);
    }, isSupported: AccelerationManager.isBlasAvailable);

    accelerationTest('dscal vector in-place scaling', () {
      final x = Float64List.fromList([2.0, 4.0, 6.0]);
      final ok = AccelerationManager.dscal(n: 3, alpha: 0.5, x: x);
      check(ok).isTrue();
      check(x[0]).isCloseTo(1.0, 1e-10);
      check(x[1]).isCloseTo(2.0, 1e-10);
      check(x[2]).isCloseTo(3.0, 1e-10);
    }, isSupported: AccelerationManager.isBlasAvailable);

    accelerationTest('sscal single-precision vector in-place scaling', () {
      final x = Float32List.fromList([3.0, 6.0, 9.0]);
      final ok = AccelerationManager.sscal(n: 3, alpha: -2.0, x: x);
      check(ok).isTrue();
      check(x[0]).isCloseTo(-6.0, 1e-5);
      check(x[1]).isCloseTo(-12.0, 1e-5);
      check(x[2]).isCloseTo(-18.0, 1e-5);
    }, isSupported: AccelerationManager.isBlasAvailable);
  });
}
