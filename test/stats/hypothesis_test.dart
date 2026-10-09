import 'package:data/linear.dart';
import 'package:data/stats.dart';
import 'package:data/type.dart';
import 'package:test/test.dart';

void main() {
  group('hypothesis testing', () {
    test('one-sample t-test', () {
      final sample = [10.2, 9.8, 10.1, 10.5, 9.9, 10.0, 10.3, 9.7];
      final resNullTrue = tTestOneSample(sample, mu0: 10.0);
      expect(resNullTrue.isSignificant, isFalse);
      expect(resNullTrue.pValue, greaterThan(0.5));
      expect(resNullTrue.confidenceInterval, isNotNull);
      final (lower, upper) = resNullTrue.confidenceInterval!;
      expect(lower, lessThan(10.0));
      expect(upper, greaterThan(10.0));

      final resNullFalse = tTestOneSample(sample, mu0: 15.0);
      expect(resNullFalse.isSignificant, isTrue);
      expect(resNullFalse.pValue, lessThan(1e-5));
    });

    test('two-sample t-test (Student and Welch)', () {
      final groupA = [12.0, 14.0, 13.0, 15.0, 14.0];
      final groupB = [18.0, 19.0, 17.0, 20.0, 18.5];

      final resStudent = tTestTwoSample(groupA, groupB, equalVariance: true);
      expect(resStudent.isSignificant, isTrue);
      expect(resStudent.pValue, lessThan(0.001));

      final resWelch = tTestTwoSample(groupA, groupB, equalVariance: false);
      expect(resWelch.isSignificant, isTrue);
      expect(resWelch.pValue, lessThan(0.001));
    });

    test('paired t-test', () {
      final before = [120.0, 125.0, 130.0, 128.0, 122.0];
      final after = [115.0, 118.0, 121.0, 120.0, 116.0];

      final res = tTestPaired(before, after);
      expect(res.isSignificant, isTrue);
      expect(res.pValue, lessThan(0.01));
      expect(res.statistic, greaterThan(0.0));
    });

    test('one-way ANOVA', () {
      // 3 groups with clearly separated means
      final g1 = [1.0, 2.0, 3.0, 2.5, 1.5];
      final g2 = [10.0, 11.0, 9.5, 10.5, 11.2];
      final g3 = [20.0, 19.5, 21.0, 20.5, 19.8];

      final res = oneWayAnova([g1, g2, g3]);
      expect(res.isSignificant, isTrue);
      expect(res.pValue, lessThan(1e-6));
      expect(res.statistic, greaterThan(100.0));
    });

    test('chi-squared goodness-of-fit test', () {
      // Fair 6-sided die expected: 20 per side (120 rolls total)
      final fairRolls = [19, 21, 20, 18, 22, 20];
      final resFair = chiSquaredTest(fairRolls);
      expect(resFair.isSignificant, isFalse);
      expect(resFair.pValue, greaterThan(0.9));

      // Biased die
      final biasedRolls = [5, 5, 10, 10, 30, 60];
      final resBiased = chiSquaredTest(biasedRolls);
      expect(resBiased.isSignificant, isTrue);
      expect(resBiased.pValue, lessThan(1e-5));
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
      expect(res.isSignificant, isTrue);
      expect(res.degreesOfFreedom, 1.0);
      expect(res.pValue, lessThan(0.001));
    });

    test('Mann-Whitney U test', () {
      final x = [1.0, 2.0, 3.0, 4.0, 5.0];
      final y = [6.0, 7.0, 8.0, 9.0, 10.0];

      final res = mannWhitneyUTest(x, y);
      expect(res.statistic, closeTo(0.0, 1e-10));
      expect(res.isSignificant, isTrue);
      expect(res.pValue, lessThan(0.05));
    });
  });
}
