import 'package:meta/meta.dart';
import 'package:more/printer.dart' show ObjectPrinter, ToStringPrinter;

/// Alternative hypothesis direction for statistical tests.
enum AlternativeHypothesis {
  /// Two-sided test (`H1: theta != theta0`).
  twoSided,

  /// One-sided test where the true parameter is less than the null
  /// (`H1: theta < theta0`).
  less,

  /// One-sided test where the true parameter is greater than the null
  /// (`H1: theta > theta0`).
  greater,
}

/// Result of a hypothesis test.
@immutable
class HypothesisTestResult with ToStringPrinter {
  /// Creates a [HypothesisTestResult] summarizing a statistical test.
  const new({
    required this.testName,
    required this.statistic,
    required this.pValue,
    this.degreesOfFreedom,
    this.denominatorDegreesOfFreedom,
    this.confidenceInterval,
    this.alpha = 0.05,
    this.alternative = AlternativeHypothesis.twoSided,
  });

  /// Name of the statistical test.
  final String testName;

  /// Computed test statistic (e.g., `t`, `F`, chi-squared, `U`, `W`).
  final double statistic;

  /// Probability of observing a test statistic at least as extreme as the
  /// computed value under the null hypothesis.
  final double pValue;

  /// Primary or numerator degrees of freedom associated with the test, if
  /// applicable.
  final double? degreesOfFreedom;

  /// Denominator degrees of freedom (e.g., within-group degrees of freedom in
  /// F-tests), if applicable.
  final double? denominatorDegreesOfFreedom;

  /// Confidence interval for the parameter of interest at level `1 - alpha`, if
  /// applicable.
  final ({double lower, double upper})? confidenceInterval;

  /// Significance level threshold in `(0, 1)`.
  final double alpha;

  /// Direction of the alternative hypothesis.
  final AlternativeHypothesis alternative;

  /// Whether the null hypothesis is rejected at the chosen [alpha] significance
  /// level (`pValue < alpha`).
  bool get isSignificant => pValue < alpha;

  @override
  bool operator ==(Object other) =>
      other is HypothesisTestResult &&
      testName == other.testName &&
      statistic == other.statistic &&
      pValue == other.pValue &&
      degreesOfFreedom == other.degreesOfFreedom &&
      denominatorDegreesOfFreedom == other.denominatorDegreesOfFreedom &&
      confidenceInterval == other.confidenceInterval &&
      alpha == other.alpha &&
      alternative == other.alternative;

  @override
  int get hashCode => Object.hash(
    HypothesisTestResult,
    testName,
    statistic,
    pValue,
    degreesOfFreedom,
    denominatorDegreesOfFreedom,
    confidenceInterval,
    alpha,
    alternative,
  );

  @override
  ObjectPrinter get toStringPrinter => super.toStringPrinter
    ..addValue(testName, name: 'test')
    ..addValue(statistic, name: 'statistic')
    ..addValue(pValue, name: 'pValue')
    ..addValue(degreesOfFreedom, name: 'df')
    ..addValue(denominatorDegreesOfFreedom, name: 'df2')
    ..addValue(confidenceInterval, name: 'ci')
    ..addValue(alternative.name, name: 'alternative')
    ..addValue(isSignificant, name: 'significant');
}
