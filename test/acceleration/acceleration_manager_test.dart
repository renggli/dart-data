import 'package:checks/checks.dart';
import 'package:data/acceleration.dart';
import 'package:test/test.dart';

void main() {
  group('AccelerationManager status & configuration', () {
    test('default execution mode is auto', () {
      check(AccelerationManager.mode).equals(AccelerationMode.auto);
    });

    test('mode mutation affects isAccelerated', () {
      final prev = AccelerationManager.mode;
      try {
        AccelerationManager.mode = AccelerationMode.dart;
        check(AccelerationManager.isAccelerated).isFalse();

        AccelerationManager.mode = AccelerationMode.auto;
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

    test('error hierarchy formatting', () {
      final unavail = AccelerationUnavailableError('vForce');
      check(unavail).isA<AccelerationUnavailableError>();
      check(unavail.feature).equals('vForce');
      check(unavail.toString())
          .contains('Native vForce acceleration is unavailable');

      final failed = AccelerationFailedError('dgemm');
      check(failed).isA<AccelerationFailedError>();
      check(failed.operation).equals('dgemm');
      check(failed.toString()).contains('Native dgemm execution failed');
    });
  });
}
