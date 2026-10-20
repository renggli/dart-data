import '../descriptive.dart';
import '../distributions/continuous/chi_squared.dart';
import 'hypothesis_test_result.dart';

/// Jarque-Bera goodness-of-fit test for sample normality.
///
/// Tests the null hypothesis that [sample] is drawn from a normal distribution
/// by matching sample skewness $S$ and kurtosis $K$ against normal baselines
/// ($S = 0, K = 3$).
HypothesisTestResult jarqueBeraTest(
  Iterable<num> sample, {
  double alpha = 0.05,
}) {
  final list = sample.map((val) => val.toDouble()).toList();
  final n = list.length;
  if (n < 4) {
    throw ArgumentError('Jarque-Bera test requires at least 4 observations');
  }

  final s = skewness(list, bias: true);
  final k = kurtosis(list, excess: true, bias: true);
  final jb = (n / 6.0) * (s * s + 0.25 * k * k);

  const dist = ChiSquaredDistribution(2.0);
  final pValue = dist.survival(jb).clamp(0.0, 1.0);

  return HypothesisTestResult(
    testName: 'Jarque-Bera Normality Test',
    statistic: jb,
    pValue: pValue,
    degreesOfFreedom: 2.0,
    alpha: alpha,
  );
}
