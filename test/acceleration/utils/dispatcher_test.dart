import 'package:checks/checks.dart';
import 'package:data/acceleration.dart';
import 'package:data/src/acceleration/utils/dispatcher.dart';
import 'package:test/test.dart';

void main() {
  group('Dispatcher', () {
    final originalMode = AccelerationManager.mode;
    tearDown(() => AccelerationManager.mode = originalMode);

    test('executeAccelerated in dart mode uses fallback', () {
      AccelerationManager.mode = AccelerationMode.dart;
      var accelCalled = false;
      var fallbackCalled = false;

      final res = executeAccelerated<int>(
        feature: 'Test',
        operation: 'op',
        isAvailable: true,
        accelerate: () {
          accelCalled = true;
          return 42;
        },
        fallback: () {
          fallbackCalled = true;
          return 100;
        },
      );

      check(res).equals(100);
      check(accelCalled).isFalse();
      check(fallbackCalled).isTrue();
    });

    test('executeAccelerated in accelerated mode throws when unavailable', () {
      AccelerationManager.mode = AccelerationMode.accelerated;
      check(
        () => executeAccelerated<int>(
          feature: 'TestFeature',
          operation: 'op',
          isAvailable: false,
          accelerate: () => 42,
          fallback: () => 100,
        ),
      ).throws<AccelerationError>();
    });

    test('executeAccelerated in accelerated mode throws when accelerate returns null', () {
      AccelerationManager.mode = AccelerationMode.accelerated;
      check(
        () => executeAccelerated<int>(
          feature: 'TestFeature',
          operation: 'op',
          isAvailable: true,
          accelerate: () => null,
          fallback: () => 100,
        ),
      ).throws<AccelerationError>();
    });

    test(
      'executeAccelerated in accelerated mode returns result when successful',
      () {
        AccelerationManager.mode = AccelerationMode.accelerated;
        final res = executeAccelerated<int>(
          feature: 'TestFeature',
          operation: 'op',
          isAvailable: true,
          accelerate: () => 42,
          fallback: () => 100,
        );
        check(res).equals(42);
      },
    );

    test(
      'executeAccelerated in auto mode falls back when accelerate returns null',
      () {
        AccelerationManager.mode = AccelerationMode.auto;
        final res = executeAccelerated<int>(
          feature: 'TestFeature',
          operation: 'op',
          isAvailable: true,
          accelerate: () => null,
          fallback: () => 999,
        );
        check(res).equals(999);
      },
    );

    test('executeAcceleratedOperation dispatches boolean operation', () {
      AccelerationManager.mode = AccelerationMode.dart;
      final res = executeAcceleratedOperation(
        feature: 'Test',
        operation: 'op',
        isAvailable: true,
        accelerate: () => true,
        fallback: () => false,
      );
      check(res).isFalse();
    });

    test('executeAcceleratedVoid executes void operation', () {
      AccelerationManager.mode = AccelerationMode.dart;
      var ranFallback = false;
      executeAcceleratedVoid(
        feature: 'Test',
        operation: 'op',
        isAvailable: true,
        accelerate: () => true,
        fallback: () {
          ranFallback = true;
        },
      );
      check(ranFallback).isTrue();

      AccelerationManager.mode = AccelerationMode.accelerated;
      check(
        () => executeAcceleratedOperation(
          feature: 'Test',
          operation: 'op',
          isAvailable: false,
          accelerate: () => true,
          fallback: () => false,
        ),
      ).throws<AccelerationError>();
      check(
        () => executeAcceleratedOperation(
          feature: 'Test',
          operation: 'op',
          isAvailable: true,
          accelerate: () => false,
          fallback: () => false,
        ),
      ).throws<AccelerationError>();
      check(
        () => executeAcceleratedVoid(
          feature: 'Test',
          operation: 'op',
          isAvailable: false,
          accelerate: () => true,
          fallback: () {},
        ),
      ).throws<AccelerationError>();
      check(
        () => executeAcceleratedVoid(
          feature: 'Test',
          operation: 'op',
          isAvailable: true,
          accelerate: () => false,
          fallback: () {},
        ),
      ).throws<AccelerationError>();
    });
  });
}
