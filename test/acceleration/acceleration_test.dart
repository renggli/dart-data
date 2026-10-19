import 'dart:typed_data';

import 'package:checks/checks.dart';
import 'package:data/acceleration.dart';
import 'package:test/test.dart';

import 'test_utils.dart';

void main() {
  group('AccelerationMode', () {
    tearDown(() {
      AccelerationManager.mode = AccelerationMode.auto;
    });

    test('default mode is auto', () {
      check(AccelerationManager.mode).equals(AccelerationMode.auto);
    });

    test('mode switching updates isAccelerated property', () {
      AccelerationManager.mode = AccelerationMode.dart;
      check(AccelerationManager.isAccelerated).isFalse();

      AccelerationManager.mode = AccelerationMode.accelerated;
      check(AccelerationManager.isAccelerated).equals(
        AccelerationManager.isBlasAvailable ||
            AccelerationManager.isVdspAvailable,
      );

      AccelerationManager.mode = AccelerationMode.auto;
      check(AccelerationManager.isAccelerated).equals(
        AccelerationManager.isBlasAvailable ||
            AccelerationManager.isVdspAvailable,
      );
    });

    test('AccelerationMode.dart forces pure Dart software path', () {
      AccelerationManager.mode = AccelerationMode.dart;

      final a = Float64List.fromList([1.0, 2.0, 3.0, 4.0]);
      final b = Float64List.fromList([5.0, 6.0, 7.0, 8.0]);
      final c = Float64List(4);

      final success = AccelerationManager.dgemm(
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
      // [1*5 + 2*7, 1*6 + 2*8, 3*5 + 4*7, 3*6 + 4*8] = [19, 22, 43, 50]
      check(c[0]).isCloseTo(19.0, 1e-9);
      check(c[1]).isCloseTo(22.0, 1e-9);
      check(c[2]).isCloseTo(43.0, 1e-9);
      check(c[3]).isCloseTo(50.0, 1e-9);
    });

    test('AccelerationMode.accelerated executes on native or throws AccelerationUnavailableError', () {
      AccelerationManager.mode = AccelerationMode.accelerated;

      if (!AccelerationManager.isBlasAvailable) {
        // When native BLAS is unavailable (e.g. web or unsupported OS), must
        // throw AccelerationUnavailableError
        final x = Float64List.fromList([1.0, 2.0]);
        final y = Float64List.fromList([3.0, 4.0]);
        check(() => AccelerationManager.ddot(n: 2, x: x, y: y))
            .throws<AccelerationUnavailableError>();
      } else {
        // Native is available: must succeed using native BLAS
        final x = Float64List.fromList([1.0, 2.0]);
        final y = Float64List.fromList([3.0, 4.0]);
        final dot = AccelerationManager.ddot(n: 2, x: x, y: y);
        check(dot).isNotNull();
        check(dot!).isCloseTo(11.0, 1e-9);
      }
    });
  });

  group('AccelerationError subclasses', () {
    test('AccelerationUnavailableError creates expected error and fields', () {
      final error = AccelerationError.unavailable('LAPACK');
      check(error).isA<AccelerationUnavailableError>();
      check(error).isA<AccelerationError>();
      check((error as AccelerationUnavailableError).feature).equals('LAPACK');
      check(error.message).equals('Native LAPACK acceleration is unavailable.');
    });

    test('AccelerationFailedError creates expected error and fields', () {
      final error = AccelerationError.failed('dgemm');
      check(error).isA<AccelerationFailedError>();
      check(error).isA<AccelerationError>();
      check((error as AccelerationFailedError).operation).equals('dgemm');
      check(error.message).equals('Native dgemm execution failed.');
    });
  });

  group('accelerationTest helper', () {
    accelerationTest('ddot executes across all modes', () {
      final x = Float64List.fromList([1.0, 2.0]);
      final y = Float64List.fromList([3.0, 4.0]);
      final dot = AccelerationManager.ddot(n: 2, x: x, y: y);
      check(dot).isNotNull();
      check(dot!).isCloseTo(11.0, 1e-9);
    });

    accelerationTest(
      'throws AccelerationUnavailableError when acceleration is not supported',
      () {
        if (AccelerationManager.mode == AccelerationMode.accelerated) {
          throw AccelerationError.unavailable('test');
        }
      },
      isSupported: false,
    );
  });
}
