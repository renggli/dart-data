import 'dart:math' as math;
import 'dart:typed_data';

import '../distributions/continuous/normal.dart';
import 'hypothesis_test_result.dart';
import 'utils.dart';

/// Wilcoxon signed-rank test for paired samples or one-sample median against
/// zero.
///
/// If [y] is provided, tests paired differences `x_i - y_i`; if [y] is
/// omitted, tests `x_i` directly against zero. After removing zero differences,
/// uses exact signed-rank permutation p-values when [exact] is `true`, or when
/// [exact] is omitted for untied samples with `n <= 25`. Otherwise uses the
/// tie-corrected normal approximation with optional [continuityCorrection].
///
/// Throws [ArgumentError] if [x] is empty, paired lengths differ, [alpha] is
/// outside `(0, 1)`, or `exact: true` is requested when tied magnitudes exist.
/// Returns `NaN` statistic and p-value if any observation is `NaN`.
HypothesisTestResult wilcoxonSignedRankTest(
  Iterable<num> x, {
  Iterable<num>? y,
  AlternativeHypothesis alternative = AlternativeHypothesis.twoSided,
  double alpha = 0.05,
  bool continuityCorrection = true,
  bool? exact,
}) {
  validateAlpha(alpha);
  final nonZeroDiffs = <double>[];
  var hasNan = false;
  var totalCount = 0;

  if (y != null) {
    final xIter = x.iterator;
    final yIter = y.iterator;
    while (xIter.moveNext()) {
      if (!yIter.moveNext()) {
        throw ArgumentError('Paired samples must have equal length');
      }
      totalCount++;
      final diff = xIter.current.toDouble() - yIter.current.toDouble();
      if (diff.isNaN) hasNan = true;
      if (diff != 0.0) nonZeroDiffs.add(diff);
    }
    if (yIter.moveNext()) {
      throw ArgumentError('Paired samples must have equal length');
    }
  } else {
    for (final val in x) {
      totalCount++;
      final diff = val.toDouble();
      if (diff.isNaN) hasNan = true;
      if (diff != 0.0) nonZeroDiffs.add(diff);
    }
  }

  if (totalCount == 0) {
    throw ArgumentError('Sample cannot be empty');
  }
  if (hasNan) {
    return HypothesisTestResult(
      testName: 'Wilcoxon Signed-Rank Test',
      statistic: double.nan,
      pValue: double.nan,
      alpha: alpha,
      alternative: alternative,
    );
  }

  final n = nonZeroDiffs.length;
  if (n == 0) {
    return HypothesisTestResult(
      testName: 'Wilcoxon Signed-Rank Test',
      statistic: 0.0,
      pValue: 1.0,
      alpha: alpha,
      alternative: alternative,
    );
  }

  final absDiffs = [for (final d in nonZeroDiffs) d.abs()];
  final ranked = rankDataWithTies(absDiffs);
  if (exact == true) {
    if (ranked.hasTies) {
      throw ArgumentError(
        'Exact Wilcoxon signed-rank p-value requires untied non-zero differences',
      );
    }
    if (n > 50) {
      throw ArgumentError(
        'Exact Wilcoxon signed-rank p-value requires at most 50 non-zero differences',
      );
    }
  }

  var wPlus = 0.0;
  var wMinus = 0.0;
  for (var i = 0; i < n; i++) {
    if (nonZeroDiffs[i] > 0.0) {
      wPlus += ranked.ranks[i];
    } else {
      wMinus += ranked.ranks[i];
    }
  }

  final wStat = switch (alternative) {
    AlternativeHypothesis.twoSided => math.min(wPlus, wMinus),
    AlternativeHypothesis.greater || AlternativeHypothesis.less => wPlus,
  };

  final useExact = exact ?? (!ranked.hasTies && n <= 25);
  if (useExact && n <= 50) {
    final pValue = _exactWilcoxonPValue(wPlus.round(), n, alternative);
    return HypothesisTestResult(
      testName: 'Wilcoxon Signed-Rank Test',
      statistic: wStat,
      pValue: pValue,
      alpha: alpha,
      alternative: alternative,
    );
  }

  final nd = n.toDouble();
  final muW = 0.25 * nd * (nd + 1.0);
  final varW =
      (nd * (nd + 1.0) * (2.0 * nd + 1.0) - 0.5 * ranked.tieCorrectionSum) /
      24.0;
  final sigmaW = varW > 0.0 ? math.sqrt(varW) : 1e-15;

  const normal = NormalDistribution.standard();
  final double pValue;
  switch (alternative) {
    case AlternativeHypothesis.twoSided:
      final diff = (wPlus - muW).abs();
      final adjustedDiff = continuityCorrection
          ? math.max(0.0, diff - 0.5)
          : diff;
      pValue = (2.0 * normal.survival(adjustedDiff / sigmaW)).clamp(0.0, 1.0);
    case AlternativeHypothesis.greater:
      final diff = wPlus - muW;
      final adjustedDiff = continuityCorrection ? diff - 0.5 : diff;
      pValue = normal.survival(adjustedDiff / sigmaW).clamp(0.0, 1.0);
    case AlternativeHypothesis.less:
      final diff = wPlus - muW;
      final adjustedDiff = continuityCorrection ? diff + 0.5 : diff;
      pValue = normal
          .cumulativeProbability(adjustedDiff / sigmaW)
          .clamp(0.0, 1.0);
  }

  return HypothesisTestResult(
    testName: 'Wilcoxon Signed-Rank Test',
    statistic: wStat,
    pValue: pValue,
    alpha: alpha,
    alternative: alternative,
  );
}

double _exactWilcoxonPValue(
  int wPlus,
  int n,
  AlternativeHypothesis alternative,
) {
  final maxSum = n * (n + 1) ~/ 2;
  final dp = Float64List(maxSum + 1);
  dp[0] = 1.0;
  for (var r = 1; r <= n; r++) {
    final limit = r * (r + 1) ~/ 2;
    for (var s = limit; s >= r; s--) {
      dp[s] += dp[s - r];
    }
  }
  final total = math.pow(2.0, n).toDouble();
  final target = switch (alternative) {
    AlternativeHypothesis.twoSided => math.min(wPlus, maxSum - wPlus),
    AlternativeHypothesis.less => wPlus,
    AlternativeHypothesis.greater => maxSum - wPlus,
  };
  var sum = 0.0;
  for (var s = 0; s <= target; s++) {
    sum += dp[s];
  }
  final prob = sum / total;
  return alternative == AlternativeHypothesis.twoSided
      ? (2.0 * prob).clamp(0.0, 1.0)
      : prob.clamp(0.0, 1.0);
}
