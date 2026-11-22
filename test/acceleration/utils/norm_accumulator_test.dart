import 'package:checks/checks.dart';
import 'package:data/src/acceleration/utils/norm_accumulator.dart';
import 'package:test/test.dart';

void main() {
  group('ScaledNormAccumulator', () {
    test('computes Euclidean norm of standard values', () {
      final acc = ScaledNormAccumulator()
        ..add(3.0)
        ..add(-4.0);
      check(acc.norm).isCloseTo(5.0, 1e-14);
    });

    test('returns zero for empty or all-zero inputs', () {
      final empty = ScaledNormAccumulator();
      check(empty.norm).equals(0.0);
      final zeros = ScaledNormAccumulator()
        ..add(0.0)
        ..add(-0.0);
      check(zeros.norm).equals(0.0);
    });

    test('avoids overflow on huge magnitudes and underflow on tiny ones', () {
      final huge = ScaledNormAccumulator()
        ..add(3e200)
        ..add(4e200);
      check(huge.norm).isCloseTo(5e200, 1e186);

      final tiny = ScaledNormAccumulator()
        ..add(3e-200)
        ..add(4e-200);
      check(tiny.norm).isCloseTo(5e-200, 1e-214);
    });

    test('propagates infinity and NaN', () {
      final infAcc = ScaledNormAccumulator()
        ..add(1.0)
        ..add(double.negativeInfinity)
        ..add(2.0);
      check(infAcc.norm).equals(double.infinity);

      final nanAcc = ScaledNormAccumulator()
        ..add(double.infinity)
        ..add(double.nan);
      check(nanAcc.norm).isNaN;
    });
  });
}
