import 'package:more/printer.dart' show ObjectPrinter, ToStringPrinter;

/// Alternative hypothesis direction for statistical tests.
enum AlternativeHypothesis {
  /// Two-sided test ($H_1: \theta \ne \theta_0$).
  twoSided,

  /// One-sided test where the true parameter is less than the null
  /// ($H_1: \theta < \theta_0$).
  less,

  /// One-sided test where the true parameter is greater than the null
  /// ($H_1: \theta > \theta_0$).
  greater,
}

/// Result of a hypothesis test.
class HypothesisTestResult with ToStringPrinter {
  /// Creates a [HypothesisTestResult] summarizing a statistical test.
  const new({
    required this.testName,
    required this.statistic,
    required this.pValue,
    this.degreesOfFreedom,
    this.confidenceInterval,
    this.alpha = 0.05,
    this.alternative = AlternativeHypothesis.twoSided,
  });

  /// Name of the statistical test.
  final String testName;

  /// Computed test statistic (e.g. t, F, chi-squared, U).
  final double statistic;

  /// Probability of observing a test statistic as extreme as the computed value
  /// under $H_0$.
  final double pValue;

  /// Degrees of freedom associated with the test, if applicable.
  final double? degreesOfFreedom;

  /// Confidence interval for the parameter of interest at $(1 - \alpha)$, if
  /// applicable.
  final ({double lower, double upper})? confidenceInterval;

  /// Significance level threshold.
  final double alpha;

  /// Direction of the alternative hypothesis.
  final AlternativeHypothesis alternative;

  /// Whether the null hypothesis is rejected at the chosen [alpha] significance
  /// level.
  bool get isSignificant => pValue < alpha;

  @override
  ObjectPrinter get toStringPrinter => super.toStringPrinter
    ..addValue(testName, name: 'test')
    ..addValue(statistic, name: 'statistic')
    ..addValue(pValue, name: 'pValue')
    ..addValue(degreesOfFreedom, name: 'df')
    ..addValue(confidenceInterval, name: 'ci')
    ..addValue(isSignificant, name: 'significant');
}
