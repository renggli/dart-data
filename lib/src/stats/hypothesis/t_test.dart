import 'dart:math' as math;

import '../distributions/continuous/student_t.dart';
import 'hypothesis_test_result.dart';
import 'utils.dart';

/// One-sample Student's t-test for the null hypothesis that the population mean
/// equals [mu0].
///
/// Computes `t = (x_bar - mu0) / (s / sqrt(n))` and evaluates p-values and
/// confidence intervals under `StudentDistribution(n - 1)` in a single Welford
/// pass.
///
/// Throws [ArgumentError] if [sample] has fewer than 2 elements, [mu0] is not
/// finite, or [alpha] is outside `(0, 1)`. Returns `NaN` statistic and p-value
/// if any observation is non-finite.
///
/// ```dart
/// final res = tTestOneSample([10.0, 11.0, 9.5, 10.5, 10.2], mu0: 10.0);
/// ```
HypothesisTestResult tTestOneSample(
  Iterable<num> sample, {
  double mu0 = 0.0,
  AlternativeHypothesis alternative = AlternativeHypothesis.twoSided,
  double alpha = 0.05,
}) {
  validateAlpha(alpha);
  if (!mu0.isFinite) {
    throw ArgumentError.value(mu0, 'mu0', 'Hypothesized mean must be finite');
  }
  final stats = _welfordPass(sample);
  if (stats.count < 2) {
    throw ArgumentError('Sample must contain at least 2 observations');
  }
  final dof = (stats.count - 1).toDouble();
  if (stats.hasNonFinite) {
    return HypothesisTestResult(
      testName: 'One-Sample t-test',
      statistic: double.nan,
      pValue: double.nan,
      degreesOfFreedom: double.nan,
      alpha: alpha,
      alternative: alternative,
    );
  }

  final se = stats.scale * math.sqrt((stats.m2Scaled / dof) / stats.count);
  return _buildTResult(
    testName: 'One-Sample t-test',
    estimate: stats.mean,
    diff: stats.mean - mu0,
    se: se,
    dof: dof,
    alpha: alpha,
    alternative: alternative,
  );
}

/// Two-sample independent t-test for difference in means between [sample1] and
/// [sample2] against hypothesized difference [mu0] (`H0: mu1 - mu2 = mu0`).
///
/// If [equalVariance] is `true`, uses pooled-variance Student's t-test. If
/// `false` (default), uses Welch's t-test with Satterthwaite degrees of
/// freedom.
///
/// Throws [ArgumentError] if either sample has fewer than 2 observations, [mu0]
/// is not finite, or [alpha] is outside `(0, 1)`. Returns `NaN` statistic and
/// p-value if any observation is non-finite.
///
/// ```dart
/// final res = tTestTwoSample([1.0, 2.0, 3.0], [4.0, 5.0, 6.0]);
/// ```
HypothesisTestResult tTestTwoSample(
  Iterable<num> sample1,
  Iterable<num> sample2, {
  double mu0 = 0.0,
  bool equalVariance = false,
  AlternativeHypothesis alternative = AlternativeHypothesis.twoSided,
  double alpha = 0.05,
}) {
  validateAlpha(alpha);
  if (!mu0.isFinite) {
    throw ArgumentError.value(
      mu0,
      'mu0',
      'Hypothesized difference must be finite',
    );
  }
  final testName = equalVariance
      ? "Student's Two-Sample t-test"
      : "Welch's Two-Sample t-test";

  final s1 = _welfordPass(sample1);
  final s2 = _welfordPass(sample2);
  if (s1.count < 2 || s2.count < 2) {
    throw ArgumentError('Both samples must contain at least 2 observations');
  }
  if (s1.hasNonFinite || s2.hasNonFinite) {
    return HypothesisTestResult(
      testName: testName,
      statistic: double.nan,
      pValue: double.nan,
      degreesOfFreedom: double.nan,
      alpha: alpha,
      alternative: alternative,
    );
  }

  final n1 = s1.count;
  final n2 = s2.count;
  final se1 = s1.scale * math.sqrt((s1.m2Scaled / (n1 - 1.0)) / n1);
  final se2 = s2.scale * math.sqrt((s2.m2Scaled / (n2 - 1.0)) / n2);

  final double se;
  final double dof;
  if (equalVariance) {
    final maxScale = math.max(s1.scale, s2.scale);
    if (maxScale <= 0.0) {
      se = 0.0;
    } else {
      final f1 = s1.scale / maxScale;
      final f2 = s2.scale / maxScale;
      final pooledScaled =
          (f1 * f1 * s1.m2Scaled + f2 * f2 * s2.m2Scaled) / (n1 + n2 - 2.0);
      se = maxScale * math.sqrt(pooledScaled * (1.0 / n1 + 1.0 / n2));
    }
    dof = (n1 + n2 - 2).toDouble();
  } else {
    final maxSe = math.max(se1, se2);
    if (maxSe <= 0.0) {
      se = 0.0;
      dof = (n1 + n2 - 2).toDouble();
    } else {
      final u1 = se1 / maxSe;
      final u2 = se2 / maxSe;
      final r1 = u1 * u1;
      final r2 = u2 * u2;
      se = maxSe * math.sqrt(r1 + r2);
      final sumR = r1 + r2;
      final den = (r1 * r1) / (n1 - 1.0) + (r2 * r2) / (n2 - 1.0);
      dof = (sumR * sumR) / den;
    }
  }

  final rawDiff = s1.mean - s2.mean;
  return _buildTResult(
    testName: testName,
    estimate: rawDiff,
    diff: rawDiff - mu0,
    se: se,
    dof: dof,
    alpha: alpha,
    alternative: alternative,
  );
}

/// Paired Student's t-test for the mean difference between dependent samples
/// [sample1] and [sample2] against [mu0] (`H0: mean(x - y) = mu0`).
///
/// Throws [ArgumentError] if samples differ in length, have fewer than 2 pairs,
/// [mu0] is not finite, or [alpha] is outside `(0, 1)`.
HypothesisTestResult tTestPaired(
  Iterable<num> sample1,
  Iterable<num> sample2, {
  double mu0 = 0.0,
  AlternativeHypothesis alternative = AlternativeHypothesis.twoSided,
  double alpha = 0.05,
}) {
  validateAlpha(alpha);
  if (!mu0.isFinite) {
    throw ArgumentError.value(
      mu0,
      'mu0',
      'Hypothesized mean difference must be finite',
    );
  }
  final iter1 = sample1.iterator;
  final iter2 = sample2.iterator;
  final diffs = <double>[];
  while (iter1.moveNext()) {
    if (!iter2.moveNext()) {
      throw ArgumentError('Paired samples must have equal length');
    }
    diffs.add(iter1.current.toDouble() - iter2.current.toDouble());
  }
  if (iter2.moveNext()) {
    throw ArgumentError('Paired samples must have equal length');
  }
  final res = tTestOneSample(
    diffs,
    mu0: mu0,
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

({int count, double mean, double scale, double m2Scaled, bool hasNonFinite})
_welfordPass(Iterable<num> sample) {
  var count = 0;
  var scale = 0.0;
  var meanScaled = 0.0;
  var m2Scaled = 0.0;
  var hasNonFinite = false;
  for (final val in sample) {
    final v = val.toDouble();
    count++;
    if (!v.isFinite) {
      hasNonFinite = true;
      continue;
    }
    final av = v.abs();
    if (av > scale) {
      if (scale > 0.0) {
        final ratio = scale / av;
        meanScaled *= ratio;
        m2Scaled *= ratio * ratio;
      }
      scale = av;
    }
    final sv = scale > 0.0 ? v / scale : 0.0;
    final delta = sv - meanScaled;
    meanScaled += delta / count;
    m2Scaled += delta * (sv - meanScaled);
  }
  return (
    count: count,
    mean: meanScaled * scale,
    scale: scale,
    m2Scaled: m2Scaled,
    hasNonFinite: hasNonFinite,
  );
}

HypothesisTestResult _buildTResult({
  required String testName,
  required double estimate,
  required double diff,
  required double se,
  required double dof,
  required double alpha,
  required AlternativeHypothesis alternative,
}) {
  final dist = StudentDistribution(dof);
  final double tStat;
  final double pValue;
  if (se <= 0.0) {
    if (diff == 0.0) {
      tStat = 0.0;
      pValue = 1.0;
    } else {
      tStat = diff > 0.0 ? double.infinity : double.negativeInfinity;
      pValue = switch (alternative) {
        AlternativeHypothesis.twoSided => 0.0,
        AlternativeHypothesis.less => diff < 0.0 ? 0.0 : 1.0,
        AlternativeHypothesis.greater => diff > 0.0 ? 0.0 : 1.0,
      };
    }
  } else {
    tStat = diff / se;
    pValue = switch (alternative) {
      AlternativeHypothesis.twoSided =>
        (2.0 * dist.survival(tStat.abs())).clamp(0.0, 1.0),
      AlternativeHypothesis.less =>
        dist.cumulativeProbability(tStat).clamp(0.0, 1.0),
      AlternativeHypothesis.greater => dist.survival(tStat).clamp(0.0, 1.0),
    };
  }

  final ci = switch (alternative) {
    AlternativeHypothesis.twoSided => () {
      final tCrit = dist.inverseSurvival(alpha / 2.0);
      return (lower: estimate - tCrit * se, upper: estimate + tCrit * se);
    }(),
    AlternativeHypothesis.less => () {
      final tCrit = dist.inverseSurvival(alpha);
      return (lower: double.negativeInfinity, upper: estimate + tCrit * se);
    }(),
    AlternativeHypothesis.greater => () {
      final tCrit = dist.inverseSurvival(alpha);
      return (lower: estimate - tCrit * se, upper: double.infinity);
    }(),
  };

  return HypothesisTestResult(
    testName: testName,
    statistic: tStat,
    pValue: pValue,
    degreesOfFreedom: dof,
    confidenceInterval: ci,
    alpha: alpha,
    alternative: alternative,
  );
}
