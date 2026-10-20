import 'package:checks/checks.dart';
import 'package:data/linear.dart';
import 'package:data/stats.dart';
import 'package:data/type.dart';
import 'package:test/test.dart';

void main() {
  group('chi-squared', () {
    test('chi-squared goodness-of-fit test', () {
      // Fair 6-sided die expected: 20 per side (120 rolls total)
      final fairRolls = [19, 21, 20, 18, 22, 20];
      final resFair = chiSquaredTest(fairRolls);
      check(resFair.isSignificant).isFalse();
      check(resFair.pValue).isGreaterThan(0.9);

      // Explicit expected with scaling and ddof
      final exp = [20, 20, 20, 20, 20, 20];
      final resExp = chiSquaredTest(fairRolls, expected: exp, ddof: 1);
      check(resExp.degreesOfFreedom).equals(4.0);

      // Biased die
      final biasedRolls = [5, 5, 10, 10, 30, 60];
      final resBiased = chiSquaredTest(biasedRolls);
      check(resBiased.isSignificant).isTrue();
      check(resBiased.pValue).isLessThan(1e-5);

      // Errors
      check(() => chiSquaredTest([5])).throws<ArgumentError>();
      check(() => chiSquaredTest([5, 5], expected: [1, 2, 3]))
          .throws<ArgumentError>();
      check(() => chiSquaredTest([5, 5], expected: [0, 5]))
          .throws<ArgumentError>();
      check(() => chiSquaredTest([5, 5], ddof: 2)).throws<ArgumentError>();
    });

    test('chi-squared test of independence on contingency table', () {
      // 2x2 contingency table
      //           Success  Failure
      // Group A:    20       30
      // Group B:    40       10
      final table = Matrix<int>.fromRows([
        [20, 30],
        [40, 10],
      ], type: DataType.int32);

      final res = chiSquaredContingency(table);
      check(res.isSignificant).isTrue();
      check(res.degreesOfFreedom).equals(1.0);
      check(res.pValue).isLessThan(0.001);

      // Error
      final badTable = Matrix<int>.fromRows([
        [10, 20],
      ], type: DataType.int32);
      check(() => chiSquaredContingency(badTable)).throws<ArgumentError>();
    });
  });
}
