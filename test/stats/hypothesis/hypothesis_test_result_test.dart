import 'package:checks/checks.dart';
import 'package:data/src/stats/hypothesis/hypothesis_test_result.dart';
import 'package:test/test.dart';

void main() {
  group('HypothesisTestResult', () {
    test('properties, significance check, and toString', () {
      const result = HypothesisTestResult(
        testName: 't-test',
        statistic: 2.34,
        pValue: 0.025,
        degreesOfFreedom: 18.0,
        confidenceInterval: (lower: 1.1, upper: 3.5),
        alpha: 0.05,
        alternative: AlternativeHypothesis.twoSided,
      );

      check(result.testName).equals('t-test');
      check(result.statistic).equals(2.34);
      check(result.pValue).equals(0.025);
      check(result.degreesOfFreedom).equals(18.0);
      check(result.confidenceInterval?.lower).equals(1.1);
      check(result.confidenceInterval?.upper).equals(3.5);
      check(result.isSignificant).isTrue();
      check(result.toString()).contains('HypothesisTestResult');
    });

    test('non-significant result', () {
      const result = HypothesisTestResult(
        testName: 'z-test',
        statistic: 1.2,
        pValue: 0.23,
      );
      check(result.isSignificant).isFalse();
      check(result.degreesOfFreedom).isNull();
      check(result.confidenceInterval).isNull();
    });
  });
}
