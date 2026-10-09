import 'package:checks/checks.dart';
import 'package:data/linear.dart';
import 'package:data/stats.dart';
import 'package:data/type.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('hypothesis testing', () {
    test('one-sample t-test', () {
      final sample = [10.2, 9.8, 10.1, 10.5, 9.9, 10.0, 10.3, 9.7];
      final resNullTrue = tTestOneSample(sample, mu0: 10.0);
      check(resNullTrue.isSignificant).isFalse();
      check(resNullTrue.pValue).isGreaterThan(0.5);
      check(resNullTrue.confidenceInterval).isNotNull();
      final (lower, upper) = resNullTrue.confidenceInterval!;
      check(lower).isLessThan(10.0);
      check(upper).isGreaterThan(10.0);

      final resNullFalse = tTestOneSample(sample, mu0: 15.0);
      check(resNullFalse.isSignificant).isTrue();
      check(resNullFalse.pValue).isLessThan(1e-5);
      check(resNullFalse.toString()).contains('test');

      // Alternative directions
      final resLess = tTestOneSample(
        sample,
        mu0: 15.0,
        alternative: AlternativeHypothesis.less,
      );
      check(resLess.isSignificant).isTrue();
      check(resLess.pValue).isLessThan(1e-5);

      final resGreater = tTestOneSample(
        sample,
        mu0: 5.0,
        alternative: AlternativeHypothesis.greater,
      );
      check(resGreater.isSignificant).isTrue();
      check(resGreater.pValue).isLessThan(1e-5);

      // Errors
      check(() => tTestOneSample([1.0])).throws<ArgumentError>();
    });

    test('two-sample t-test (Student and Welch)', () {
      final groupA = [12.0, 14.0, 13.0, 15.0, 14.0];
      final groupB = [18.0, 19.0, 17.0, 20.0, 18.5];

      final resStudent = tTestTwoSample(groupA, groupB, equalVariance: true);
      check(resStudent.isSignificant).isTrue();
      check(resStudent.pValue).isLessThan(0.001);

      final resWelch = tTestTwoSample(groupA, groupB, equalVariance: false);
      check(resWelch.isSignificant).isTrue();
      check(resWelch.pValue).isLessThan(0.001);

      final resLess = tTestTwoSample(
        groupA,
        groupB,
        alternative: AlternativeHypothesis.less,
      );
      check(resLess.pValue).isLessThan(0.001);

      final resGreater = tTestTwoSample(
        groupA,
        groupB,
        alternative: AlternativeHypothesis.greater,
      );
      check(resGreater.pValue).isGreaterThan(0.9);

      // Errors
      check(() => tTestTwoSample([1.0], groupB)).throws<ArgumentError>();
      check(() => tTestTwoSample(groupA, [1.0])).throws<ArgumentError>();
    });

    test('paired t-test', () {
      final before = [120.0, 125.0, 130.0, 128.0, 122.0];
      final after = [115.0, 118.0, 121.0, 120.0, 116.0];

      final res = tTestPaired(before, after);
      check(res.isSignificant).isTrue();
      check(res.pValue).isLessThan(0.01);
      check(res.statistic).isGreaterThan(0.0);

      final resGreater = tTestPaired(
        before,
        after,
        alternative: AlternativeHypothesis.greater,
      );
      check(resGreater.pValue).isLessThan(0.01);

      final resLess = tTestPaired(
        before,
        after,
        alternative: AlternativeHypothesis.less,
      );
      check(resLess.pValue).isGreaterThan(0.99);

      // Errors
      check(() => tTestPaired([1.0], after)).throws<ArgumentError>();
      check(() => tTestPaired([1.0, 2.0], [1.0, 2.0, 3.0]))
          .throws<ArgumentError>();
    });

    test('one-way ANOVA', () {
      // 3 groups with clearly separated means
      final g1 = [1.0, 2.0, 3.0, 2.5, 1.5];
      final g2 = [10.0, 11.0, 9.5, 10.5, 11.2];
      final g3 = [20.0, 19.5, 21.0, 20.5, 19.8];

      final res = oneWayAnova([g1, g2, g3]);
      check(res.isSignificant).isTrue();
      check(res.pValue).isLessThan(1e-6);
      check(res.statistic).isGreaterThan(100.0);

      // Errors
      check(() => oneWayAnova([g1])).throws<ArgumentError>();
      check(() => oneWayAnova([g1, <double>[]])).throws<ArgumentError>();
      check(
        () => oneWayAnova([
          [1.0],
          [2.0],
        ]),
      ).throws<ArgumentError>();
    });

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

    test('Mann-Whitney U test', () {
      final x = [1.0, 2.0, 3.0, 4.0, 5.0];
      final y = [6.0, 7.0, 8.0, 9.0, 10.0];

      final res = mannWhitneyUTest(x, y);
      check(res.statistic).isCloseTo(0.0, 1e-10);
      check(res.isSignificant).isTrue();
      check(res.pValue).isLessThan(0.05);

      final resLess = mannWhitneyUTest(
        x,
        y,
        alternative: AlternativeHypothesis.less,
      );
      check(resLess.pValue).isLessThan(0.05);

      final resGreater = mannWhitneyUTest(
        x,
        y,
        alternative: AlternativeHypothesis.greater,
      );
      check(resGreater.pValue).isGreaterThan(0.9);

      // Errors
      check(() => mannWhitneyUTest(<double>[], y)).throws<ArgumentError>();
      check(() => mannWhitneyUTest(x, <double>[])).throws<ArgumentError>();
    });
  });
}
