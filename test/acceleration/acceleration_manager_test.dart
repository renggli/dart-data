import 'package:checks/checks.dart';
import 'package:data/acceleration.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('AccelerationManager status & configuration', () {
    test('default execution mode is auto', () {
      check(AccelerationManager.mode).equals(AccelerationMode.auto);
    });

    test('mode mutation affects isAccelerated', () {
      final prev = AccelerationManager.mode;
      try {
        AccelerationManager.mode = AccelerationMode.dart;
        check(AccelerationManager.isAccelerated).isFalse;

        AccelerationManager.mode = AccelerationMode.auto;
        check(AccelerationManager.isAccelerated).equals(
          Blas.isAvailable ||
              Lapack.isAvailable ||
              Fft.isAvailable ||
              Vforce.isAvailable,
        );

        AccelerationManager.mode = AccelerationMode.accelerated;
        check(AccelerationManager.isAccelerated).equals(
          Blas.isAvailable ||
              Lapack.isAvailable ||
              Fft.isAvailable ||
              Vforce.isAvailable,
        );
      } finally {
        AccelerationManager.mode = prev;
      }
    });

    test('error hierarchy formatting and exhaustive sealed dispatch', () {
      final unavail = AccelerationUnavailableError('vForce');
      check(unavail).isA<AccelerationUnavailableError>();
      check(unavail.feature).equals('vForce');
      check(unavail.toString())
          .contains('Native vForce acceleration is unavailable');

      final unavailFactory = AccelerationError.unavailable('BLAS');
      check(unavailFactory).isA<AccelerationUnavailableError>();
      check((unavailFactory as AccelerationUnavailableError).feature)
          .equals('BLAS');

      final failed = AccelerationFailedError('dgemm');
      check(failed).isA<AccelerationFailedError>();
      check(failed.operation).equals('dgemm');
      check(failed.toString()).contains('Native dgemm execution failed');

      final failedFactory = AccelerationError.failed('dgesv');
      check(failedFactory).isA<AccelerationFailedError>();
      check((failedFactory as AccelerationFailedError).operation)
          .equals('dgesv');

      String describe(AccelerationError err) => switch (err) {
        AccelerationUnavailableError(:final feature) => 'unavailable:$feature',
        AccelerationFailedError(:final operation) => 'failed:$operation',
      };
      check(describe(unavail)).equals('unavailable:vForce');
      check(describe(failed)).equals('failed:dgemm');
    });
  });
}
