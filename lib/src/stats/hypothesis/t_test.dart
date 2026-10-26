import 'dart:math' as math;

import '../descriptive.dart';
import '../distributions/continuous/student_t.dart';
import 'hypothesis_test_result.dart';

/// One-sample Student's t-test for the null hypothesis that the population mean
/// equals [mu0].
///
/// Conceptually, this tests whether the sample mean differs significantly from
/// a specified hypothesized value $\mu_0$. Formally, this evaluates
/// $H_0: \mu = \mu_0$ using Student's $t$ statistic
/// $t = \frac{\bar{x} - \mu_0}{s / \sqrt{n}} \sim t_{n-1}$.
///
/// ```dart
/// final res = tTestOneSample([10.0, 11.0, 9.5, 10.5, 10.2], mu0: 10.0);
/// // res.pValue, res.isSignificant
/// ```
HypothesisTestResult tTestOneSample(
  Iterable<num> sample, {
  double mu0 = 0.0,
  AlternativeHypothesis alternative = AlternativeHypothesis.twoSided,
  double alpha = 0.05,
}) {
  final list = sample.map((val) => val.toDouble()).toList();
  final count = list.length;
  if (count < 2) {
    throw ArgumentError('Sample must contain at least 2 observations');
  }
  final sampleMean = mean(list);
  final sampleStd = standardDeviation(list);
  final se = sampleStd / math.sqrt(count);
  final diff = sampleMean - mu0;
  final dof = (count - 1).toDouble();
  final dist = StudentDistribution(dof);

  final double tStat;
  final double pValue;
  if (se <= 0.0) {
    if (diff == 0.0) {
      tStat = 0.0;
      pValue = 1.0;
    } else {
      tStat = diff > 0.0 ? double.infinity : double.negativeInfinity;
      switch (alternative) {
        case AlternativeHypothesis.twoSided:
          pValue = 0.0;
        case AlternativeHypothesis.less:
          pValue = diff < 0.0 ? 0.0 : 1.0;
        case AlternativeHypothesis.greater:
          pValue = diff > 0.0 ? 0.0 : 1.0;
      }
    }
  } else {
    tStat = diff / se;
    switch (alternative) {
      case AlternativeHypothesis.twoSided:
        pValue = (2.0 * dist.survival(tStat.abs())).clamp(0.0, 1.0);
      case AlternativeHypothesis.less:
        pValue = dist.cumulativeProbability(tStat).clamp(0.0, 1.0);
      case AlternativeHypothesis.greater:
        pValue = dist.survival(tStat).clamp(0.0, 1.0);
    }
  }

  final ci = switch (alternative) {
    AlternativeHypothesis.twoSided => () {
      final tCrit = dist.inverseCumulativeProbability(1.0 - alpha / 2.0);
      return (lower: sampleMean - tCrit * se, upper: sampleMean + tCrit * se);
    }(),
    AlternativeHypothesis.less => () {
      final tCrit = dist.inverseCumulativeProbability(1.0 - alpha);
      return (lower: double.negativeInfinity, upper: sampleMean + tCrit * se);
    }(),
    AlternativeHypothesis.greater => () {
      final tCrit = dist.inverseCumulativeProbability(1.0 - alpha);
      return (lower: sampleMean - tCrit * se, upper: double.infinity);
    }(),
  };

  return HypothesisTestResult(
    testName: 'One-Sample t-test',
    statistic: tStat,
    pValue: pValue,
    degreesOfFreedom: dof,
    confidenceInterval: ci,
    alpha: alpha,
    alternative: alternative,
  );
}

/// Two-sample independent t-test for difference in means between [sample1] and
/// [sample2].
///
/// Conceptually, this tests whether the difference between the means of two
/// independent groups is statistically significant or could have occurred by
/// chance alone. Formally, this evaluates $H_0: \mu_1 = \mu_2$ using Welch's
/// $t$-test with Satterthwaite-Welch degrees of freedom when [equalVariance] is
/// false, or pooled variance Student's $t$ when [equalVariance] is true.
///
/// ```dart
/// final res = tTestTwoSample([1.0, 2.0, 3.0], [4.0, 5.0, 6.0]);
/// // res.pValue, res.statistic
/// ```
///
/// If [equalVariance] is true, uses standard Student's t-test with pooled
/// variance. If [equalVariance] is false (default), uses Welch's t-test with
/// Satterthwaite degrees of freedom.
HypothesisTestResult tTestTwoSample(
  Iterable<num> sample1,
  Iterable<num> sample2, {
  bool equalVariance = false,
  AlternativeHypothesis alternative = AlternativeHypothesis.twoSided,
  double alpha = 0.05,
}) {
  final list1 = sample1.map((val) => val.toDouble()).toList();
  final list2 = sample2.map((val) => val.toDouble()).toList();
  final n1 = list1.length;
  final n2 = list2.length;
  if (n1 < 2 || n2 < 2) {
    throw ArgumentError('Both samples must contain at least 2 observations');
  }

  final m1 = mean(list1);
  final m2 = mean(list2);
  final v1 = variance(list1);
  final v2 = variance(list2);

  final double se;
  final double dof;

  if (equalVariance) {
    final pooledVar = ((n1 - 1.0) * v1 + (n2 - 1.0) * v2) / (n1 + n2 - 2.0);
    se = math.sqrt(pooledVar * (1.0 / n1 + 1.0 / n2));
    dof = n1 + n2 - 2.0;
  } else {
    final se1Sq = v1 / n1;
    final se2Sq = v2 / n2;
    se = math.sqrt(se1Sq + se2Sq);
    final num = (se1Sq + se2Sq) * (se1Sq + se2Sq);
    final den = (se1Sq * se1Sq) / (n1 - 1.0) + (se2Sq * se2Sq) / (n2 - 1.0);
    dof = den > 0.0 ? num / den : 1.0;
  }

  final diff = m1 - m2;
  final dist = StudentDistribution(dof);

  final double tStat;
  final double pValue;
  if (se <= 0.0) {
    if (diff == 0.0) {
      tStat = 0.0;
      pValue = 1.0;
    } else {
      tStat = diff > 0.0 ? double.infinity : double.negativeInfinity;
      switch (alternative) {
        case AlternativeHypothesis.twoSided:
          pValue = 0.0;
        case AlternativeHypothesis.less:
          pValue = diff < 0.0 ? 0.0 : 1.0;
        case AlternativeHypothesis.greater:
          pValue = diff > 0.0 ? 0.0 : 1.0;
      }
    }
  } else {
    tStat = diff / se;
    switch (alternative) {
      case AlternativeHypothesis.twoSided:
        pValue = (2.0 * dist.survival(tStat.abs())).clamp(0.0, 1.0);
      case AlternativeHypothesis.less:
        pValue = dist.cumulativeProbability(tStat).clamp(0.0, 1.0);
      case AlternativeHypothesis.greater:
        pValue = dist.survival(tStat).clamp(0.0, 1.0);
    }
  }

  final ci = switch (alternative) {
    AlternativeHypothesis.twoSided => () {
      final tCrit = dist.inverseCumulativeProbability(1.0 - alpha / 2.0);
      return (lower: diff - tCrit * se, upper: diff + tCrit * se);
    }(),
    AlternativeHypothesis.less => () {
      final tCrit = dist.inverseCumulativeProbability(1.0 - alpha);
      return (lower: double.negativeInfinity, upper: diff + tCrit * se);
    }(),
    AlternativeHypothesis.greater => () {
      final tCrit = dist.inverseCumulativeProbability(1.0 - alpha);
      return (lower: diff - tCrit * se, upper: double.infinity);
    }(),
  };

  return HypothesisTestResult(
    testName: equalVariance
        ? "Student's Two-Sample t-test"
        : "Welch's Two-Sample t-test",
    statistic: tStat,
    pValue: pValue,
    degreesOfFreedom: dof,
    confidenceInterval: ci,
    alpha: alpha,
    alternative: alternative,
  );
}

/// Paired Student's t-test for dependent samples [sample1] and [sample2].
HypothesisTestResult tTestPaired(
  Iterable<num> sample1,
  Iterable<num> sample2, {
  AlternativeHypothesis alternative = AlternativeHypothesis.twoSided,
  double alpha = 0.05,
}) {
  final list1 = sample1.map((val) => val.toDouble()).toList();
  final list2 = sample2.map((val) => val.toDouble()).toList();
  if (list1.length != list2.length) {
    throw ArgumentError('Paired samples must have equal length');
  }
  final diffs = List<double>.generate(list1.length, (i) => list1[i] - list2[i]);
  final res = tTestOneSample(
    diffs,
    mu0: 0.0,
    alternative: alternative,
    alpha: alpha,
  );
  return HypothesisTestResult(
    testName: 'Paired t-test',
    statistic: res.statistic,
    pValue: res.pValue,
    degreesOfFreedom: res.degreesOfFreedom,
    confidenceInterval: res.confidenceInterval,
    alpha: alpha,
    alternative: alternative,
  );
}
