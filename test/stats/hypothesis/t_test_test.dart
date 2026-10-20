import 'package:checks/checks.dart';
import 'package:data/stats.dart';
import 'package:test/test.dart';

void main() {
  group('t-test', () {
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
  });
}
