import '../distributions/continuous/chi_squared.dart';
import 'hypothesis_test_result.dart';
import 'utils.dart';

/// Jarque-Bera goodness-of-fit test for sample normality.
///
/// Evaluates `JB = (n / 6) * (S^2 + (K - 3)^2 / 4)` comparing biased sample
/// skewness `S` and excess kurtosis `K - 3` against a chi-squared distribution
/// with 2 degrees of freedom.
///
/// Throws [ArgumentError] if fewer than 4 observations are provided or [alpha]
/// is outside `(0, 1)`. Returns `NaN` statistic and p-value if any observation
/// is non-finite or sample variance is zero.
HypothesisTestResult jarqueBeraTest(
  Iterable<num> sample, {
  double alpha = 0.05,
}) {
  validateAlpha(alpha);
  final list = <double>[];
  var meanVal = 0.0;
  var hasNonFinite = false;
  for (final val in sample) {
    final v = val.toDouble();
    if (!v.isFinite) hasNonFinite = true;
    list.add(v);
    meanVal += (v - meanVal) / list.length;
  }
  final n = list.length;
  if (n < 4) {
    throw ArgumentError('Jarque-Bera test requires at least 4 observations');
  }
  if (hasNonFinite) {
    return HypothesisTestResult(
      testName: 'Jarque-Bera Normality Test',
      statistic: double.nan,
      pValue: double.nan,
      degreesOfFreedom: 2.0,
      alpha: alpha,
    );
  }

  var maxAbsDiff = 0.0;
  for (var i = 0; i < n; i++) {
    final ad = (list[i] - meanVal).abs();
    if (ad > maxAbsDiff) maxAbsDiff = ad;
  }
  if (maxAbsDiff == 0.0 || !maxAbsDiff.isFinite) {
    return HypothesisTestResult(
      testName: 'Jarque-Bera Normality Test',
      statistic: double.nan,
      pValue: double.nan,
      degreesOfFreedom: 2.0,
      alpha: alpha,
    );
  }

  final invScale = 1.0 / maxAbsDiff;
  var m2 = 0.0;
  var m3 = 0.0;
  var m4 = 0.0;
  for (var i = 0; i < n; i++) {
    final d = (list[i] - meanVal) * invScale;
    final d2 = d * d;
    m2 += d2;
    m3 += d2 * d;
    m4 += d2 * d2;
  }
  m2 /= n;
  m3 /= n;
  m4 /= n;

  final s2 = (m3 * m3) / (m2 * m2 * m2);
  final excessK = m4 / (m2 * m2) - 3.0;
  final jb = (n / 6.0) * (s2 + 0.25 * excessK * excessK);
  final pValue = ChiSquaredDistribution(2.0).survival(jb).clamp(0.0, 1.0);

  return HypothesisTestResult(
    testName: 'Jarque-Bera Normality Test',
    statistic: jb,
    pValue: pValue,
    degreesOfFreedom: 2.0,
    alpha: alpha,
  );
}
