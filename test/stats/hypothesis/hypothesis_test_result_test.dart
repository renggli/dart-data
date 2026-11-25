import 'package:checks/checks.dart';
import 'package:data/stats.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('HypothesisTestResult', () {
    test('stores properties and evaluates significance threshold', () {
      const result = HypothesisTestResult(
        testName: 'F-test',
        statistic: 4.5,
        pValue: 0.025,
        degreesOfFreedom: 2.0,
        denominatorDegreesOfFreedom: 12.0,
        confidenceInterval: (lower: 1.1, upper: 3.5),
        alpha: 0.05,
        alternative: AlternativeHypothesis.greater,
      );

      check(result.testName).equals('F-test');
      check(result.statistic).equals(4.5);
      check(result.pValue).equals(0.025);
      check(result.degreesOfFreedom).equals(2.0);
      check(result.denominatorDegreesOfFreedom).equals(12.0);
      check(result.confidenceInterval?.lower).equals(1.1);
      check(result.confidenceInterval?.upper).equals(3.5);
      check(result.alternative).equals(AlternativeHypothesis.greater);
      check(result.isSignificant).isTrue;
      check(result.toString()).contains('HypothesisTestResult');
    });

    test('handles non-significant defaults and omitted optional fields', () {
      const result = HypothesisTestResult(
        testName: 'z-test',
        statistic: 1.2,
        pValue: 0.23,
      );
      check(result.isSignificant).isFalse;
      check(result.degreesOfFreedom).isNull;
      check(result.denominatorDegreesOfFreedom).isNull;
      check(result.confidenceInterval).isNull;
      check(result.alpha).equals(0.05);
      check(result.alternative).equals(AlternativeHypothesis.twoSided);
    });

    test('equality and hashCode reflect all fields', () {
      const a = HypothesisTestResult(
        testName: 't-test',
        statistic: 2.0,
        pValue: 0.04,
        degreesOfFreedom: 10.0,
        confidenceInterval: (lower: 0.1, upper: 1.9),
      );
      const b = HypothesisTestResult(
        testName: 't-test',
        statistic: 2.0,
        pValue: 0.04,
        degreesOfFreedom: 10.0,
        confidenceInterval: (lower: 0.1, upper: 1.9),
      );
      const c = HypothesisTestResult(
        testName: 't-test',
        statistic: 2.0,
        pValue: 0.06,
        degreesOfFreedom: 10.0,
        confidenceInterval: (lower: 0.1, upper: 1.9),
      );
      check(a == b).isTrue;
      check(a.hashCode).equals(b.hashCode);
      check(a == c).isFalse;
    });
  });
}
