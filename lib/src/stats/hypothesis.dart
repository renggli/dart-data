import 'dart:math' as math;

import 'package:more/printer.dart';

import '../linear/matrix.dart';
import 'descriptive.dart';
import 'distributions/continuous/chi_squared.dart';
import 'distributions/continuous/f.dart';
import 'distributions/continuous/normal.dart';
import 'distributions/continuous/student_t.dart';

/// Alternative hypothesis direction for statistical tests.
enum AlternativeHypothesis {
  /// Two-sided test ($H_1: \theta \ne \theta_0$).
  twoSided,

  /// One-sided test where the true parameter is less than the null ($H_1: \theta < \theta_0$).
  less,

  /// One-sided test where the true parameter is greater than the null ($H_1: \theta > \theta_0$).
  greater,
}

/// Result of a hypothesis test.
class HypothesisTestResult with ToStringPrinter {
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

  /// Probability of observing a test statistic as extreme as the computed value under $H_0$.
  final double pValue;

  /// Degrees of freedom associated with the test, if applicable.
  final double? degreesOfFreedom;

  /// Confidence interval for the parameter of interest at $(1 - \alpha)$, if applicable.
  final (double, double)? confidenceInterval;

  /// Significance level threshold.
  final double alpha;

  /// Direction of the alternative hypothesis.
  final AlternativeHypothesis alternative;

  /// Whether the null hypothesis is rejected at the chosen [alpha] significance level.
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

/// One-sample Student's t-test for the null hypothesis that the population mean equals [mu0].
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
  final tStat = se > 0.0 ? (sampleMean - mu0) / se : 0.0;
  final dof = (count - 1).toDouble();
  final dist = StudentDistribution(dof);

  final double pValue;
  switch (alternative) {
    case AlternativeHypothesis.twoSided:
      pValue = (2.0 * dist.survival(tStat.abs())).clamp(0.0, 1.0);
    case AlternativeHypothesis.less:
      pValue = dist.cumulativeProbability(tStat).clamp(0.0, 1.0);
    case AlternativeHypothesis.greater:
      pValue = dist.survival(tStat).clamp(0.0, 1.0);
  }

  final tCrit = dist.inverseCumulativeProbability(1.0 - alpha / 2.0);
  final ci = (sampleMean - tCrit * se, sampleMean + tCrit * se);

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

/// Two-sample independent t-test for difference in means between [sample1] and [sample2].
///
/// If [equalVariance] is true, uses standard Student's t-test with pooled variance.
/// If [equalVariance] is false (default), uses Welch's t-test with Satterthwaite degrees of freedom.
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
  final tStat = se > 0.0 ? diff / se : 0.0;
  final dist = StudentDistribution(dof);

  final double pValue;
  switch (alternative) {
    case AlternativeHypothesis.twoSided:
      pValue = (2.0 * dist.survival(tStat.abs())).clamp(0.0, 1.0);
    case AlternativeHypothesis.less:
      pValue = dist.cumulativeProbability(tStat).clamp(0.0, 1.0);
    case AlternativeHypothesis.greater:
      pValue = dist.survival(tStat).clamp(0.0, 1.0);
  }

  final tCrit = dist.inverseCumulativeProbability(1.0 - alpha / 2.0);
  final ci = (diff - tCrit * se, diff + tCrit * se);

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

/// One-way Analysis of Variance (ANOVA) test across multiple independent groups.
HypothesisTestResult oneWayAnova(
  List<Iterable<num>> groups, {
  double alpha = 0.05,
}) {
  final numGroups = groups.length;
  if (numGroups < 2) {
    throw ArgumentError('At least 2 groups required for ANOVA');
  }

  final doubleLists = groups
      .map((group) => group.map((val) => val.toDouble()).toList())
      .toList();
  var totalN = 0;
  var grandSum = 0.0;
  for (final group in doubleLists) {
    if (group.isEmpty) {
      throw ArgumentError('Groups cannot be empty');
    }
    totalN += group.length;
    for (final x in group) {
      grandSum += x;
    }
  }

  final grandMean = grandSum / totalN;
  var ssb = 0.0;
  var ssw = 0.0;

  for (final group in doubleLists) {
    final gMean = mean(group);
    ssb += group.length * (gMean - grandMean) * (gMean - grandMean);
    for (final x in group) {
      final diff = x - gMean;
      ssw += diff * diff;
    }
  }

  final df1 = (numGroups - 1).toDouble();
  final df2 = (totalN - numGroups).toDouble();
  if (df2 <= 0.0) {
    throw ArgumentError('Not enough observations across groups');
  }

  final msb = ssb / df1;
  final msw = ssw / df2;
  final fStat = msw > 0.0 ? msb / msw : 0.0;

  final dist = FDistribution(df1, df2);
  final pValue = dist.survival(fStat).clamp(0.0, 1.0);

  return HypothesisTestResult(
    testName: 'One-Way ANOVA',
    statistic: fStat,
    pValue: pValue,
    degreesOfFreedom: df1,
    alpha: alpha,
  );
}

/// Chi-squared goodness-of-fit test.
///
/// Compares [observed] frequencies against [expected] frequencies.
HypothesisTestResult chiSquaredTest(
  Iterable<num> observed, {
  Iterable<num>? expected,
  int ddof = 0,
  double alpha = 0.05,
}) {
  final obs = observed.map((val) => val.toDouble()).toList();
  final numCategories = obs.length;
  if (numCategories < 2) {
    throw ArgumentError('At least 2 observed categories required');
  }

  final obsSum = obs.sum();
  final List<double> exp;

  if (expected == null) {
    final uniformExp = obsSum / numCategories;
    exp = List<double>.filled(numCategories, uniformExp);
  } else {
    exp = expected.map((val) => val.toDouble()).toList();
    if (exp.length != numCategories) {
      throw ArgumentError('Expected length must match observed length');
    }
    final expSum = exp.sum();
    if ((expSum - obsSum).abs() > 1e-7 && expSum > 0.0) {
      final factor = obsSum / expSum;
      for (var i = 0; i < numCategories; i++) {
        exp[i] *= factor;
      }
    }
  }

  var chi2 = 0.0;
  for (var i = 0; i < numCategories; i++) {
    if (exp[i] <= 0.0) {
      throw ArgumentError('Expected counts must be positive');
    }
    final diff = obs[i] - exp[i];
    chi2 += (diff * diff) / exp[i];
  }

  final dof = (numCategories - 1 - ddof).toDouble();
  if (dof <= 0.0) {
    throw ArgumentError('Degrees of freedom must be positive');
  }

  final dist = ChiSquaredDistribution(dof);
  final pValue = dist.survival(chi2).clamp(0.0, 1.0);

  return HypothesisTestResult(
    testName: 'Chi-Squared Goodness-of-Fit Test',
    statistic: chi2,
    pValue: pValue,
    degreesOfFreedom: dof,
    alpha: alpha,
  );
}

/// Chi-squared test of independence for contingency [table].
HypothesisTestResult chiSquaredContingency(
  Matrix<num> table, {
  double alpha = 0.05,
}) {
  final rowCount = table.rowCount;
  final colCount = table.colCount;
  if (rowCount < 2 || colCount < 2) {
    throw ArgumentError('Contingency table must be at least 2x2');
  }

  final rowSums = List<double>.filled(rowCount, 0.0);
  final colSums = List<double>.filled(colCount, 0.0);
  var total = 0.0;

  for (var i = 0; i < rowCount; i++) {
    for (var j = 0; j < colCount; j++) {
      final val = table.get(i, j).toDouble();
      rowSums[i] += val;
      colSums[j] += val;
      total += val;
    }
  }

  var chi2 = 0.0;
  for (var i = 0; i < rowCount; i++) {
    for (var j = 0; j < colCount; j++) {
      final expected = (rowSums[i] * colSums[j]) / total;
      final observed = table.get(i, j).toDouble();
      final diff = observed - expected;
      chi2 += (diff * diff) / expected;
    }
  }

  final dof = ((rowCount - 1) * (colCount - 1)).toDouble();
  final dist = ChiSquaredDistribution(dof);
  final pValue = dist.survival(chi2).clamp(0.0, 1.0);

  return HypothesisTestResult(
    testName: 'Chi-Squared Test of Independence',
    statistic: chi2,
    pValue: pValue,
    degreesOfFreedom: dof,
    alpha: alpha,
  );
}

/// Mann-Whitney U test (Wilcoxon rank-sum test) for two independent groups [x] and [y].
HypothesisTestResult mannWhitneyUTest(
  Iterable<num> x,
  Iterable<num> y, {
  AlternativeHypothesis alternative = AlternativeHypothesis.twoSided,
  double alpha = 0.05,
}) {
  final xList = x.map((val) => val.toDouble()).toList();
  final yList = y.map((val) => val.toDouble()).toList();
  final n1 = xList.length;
  final n2 = yList.length;
  if (n1 == 0 || n2 == 0) {
    throw ArgumentError('Groups cannot be empty');
  }

  final combined = [...xList, ...yList];
  final ranks = rankData(combined);

  var rankSum1 = 0.0;
  for (var i = 0; i < n1; i++) {
    rankSum1 += ranks[i];
  }

  final u1 = rankSum1 - (n1 * (n1 + 1.0)) / 2.0;
  final u2 = (n1 * n2).toDouble() - u1;

  final uStat = switch (alternative) {
    AlternativeHypothesis.twoSided => math.min(u1, u2),
    AlternativeHypothesis.less => u1,
    AlternativeHypothesis.greater => u1,
  };

  // Normal approximation
  final muU = (n1 * n2) / 2.0;
  final sigmaU = math.sqrt((n1 * n2 * (n1 + n2 + 1.0)) / 12.0);

  final z = (uStat - muU) / sigmaU;
  const normal = NormalDistribution.standard();

  final double pValue;
  switch (alternative) {
    case AlternativeHypothesis.twoSided:
      pValue = (2.0 * normal.cumulativeProbability(-z.abs())).clamp(0.0, 1.0);
    case AlternativeHypothesis.less:
      pValue = normal.cumulativeProbability(z).clamp(0.0, 1.0);
    case AlternativeHypothesis.greater:
      pValue = normal.survival(z).clamp(0.0, 1.0);
  }

  return HypothesisTestResult(
    testName: 'Mann-Whitney U Test',
    statistic: uStat,
    pValue: pValue,
    alpha: alpha,
    alternative: alternative,
  );
}
