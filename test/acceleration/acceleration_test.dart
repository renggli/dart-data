import 'dart:typed_data';

import 'package:checks/checks.dart';
import 'package:data/acceleration.dart';
import 'package:test/test.dart';

void main() {
  group('AccelerationMode', () {
    tearDown(() {
      AccelerationManager.mode = AccelerationMode.auto;
    });

    test('default mode is auto', () {
      check(AccelerationManager.mode).equals(AccelerationMode.auto);
      check(AccelerationManager.isEnabled).isTrue();
    });

    test('mode switching updates isEnabled property', () {
      AccelerationManager.mode = AccelerationMode.dart;
      check(AccelerationManager.isEnabled).isFalse();
      check(AccelerationManager.isAccelerated).isFalse();

      AccelerationManager.mode = AccelerationMode.accelerated;
      check(AccelerationManager.isEnabled).isTrue();

      AccelerationManager.mode = AccelerationMode.auto;
      check(AccelerationManager.isEnabled).isTrue();
    });

    test('isEnabled setter updates mode', () {
      AccelerationManager.isEnabled = false;
      check(AccelerationManager.mode).equals(AccelerationMode.dart);

      AccelerationManager.isEnabled = true;
      check(AccelerationManager.mode).equals(AccelerationMode.auto);
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

    test(
      'AccelerationMode.accelerated executes on native or throws StateError',
      () {
        AccelerationManager.mode = AccelerationMode.accelerated;

        if (!AccelerationManager.isNativeAvailable) {
          // When native BLAS is unavailable (e.g. web or unsupported OS), must throw StateError
          final x = Float64List.fromList([1.0, 2.0]);
          final y = Float64List.fromList([3.0, 4.0]);
          check(() => AccelerationManager.ddot(n: 2, x: x, y: y))
              .throws<StateError>();
        } else {
          // Native is available: must succeed using native BLAS
          final x = Float64List.fromList([1.0, 2.0]);
          final y = Float64List.fromList([3.0, 4.0]);
          final dot = AccelerationManager.ddot(n: 2, x: x, y: y);
          check(dot).isNotNull();
          check(dot!).isCloseTo(11.0, 1e-9);
        }
      },
    );

    test('HardwareManager alias refers to AccelerationManager', () {
      check(HardwareManager.mode).equals(AccelerationManager.mode);
      HardwareManager.isEnabled = false;
      check(AccelerationManager.mode).equals(AccelerationMode.dart);
      HardwareManager.isEnabled = true;
      check(AccelerationManager.mode).equals(AccelerationMode.auto);
    });
  });
}
