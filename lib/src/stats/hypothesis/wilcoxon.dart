import 'dart:math' as math;

import '../descriptive.dart';
import '../distributions/continuous/normal.dart';
import 'hypothesis_test_result.dart';

/// Wilcoxon signed-rank test for paired samples or one-sample median against 0.
///
/// If [y] is provided, tests paired differences $x_i - y_i$. If [y] is omitted,
/// tests $x_i$ directly against a symmetric median of 0.
HypothesisTestResult wilcoxonSignedRankTest(
  Iterable<num> x, {
  Iterable<num>? y,
  AlternativeHypothesis alternative = AlternativeHypothesis.twoSided,
  double alpha = 0.05,
}) {
  final xList = x.map((val) => val.toDouble()).toList();
  final List<double> diffs;
  if (y != null) {
    final yList = y.map((val) => val.toDouble()).toList();
    if (xList.length != yList.length) {
      throw ArgumentError('Paired samples must have equal length');
    }
    diffs = List<double>.generate(xList.length, (i) => xList[i] - yList[i]);
  } else {
    diffs = xList;
  }

  for (var i = 0; i < diffs.length; i++) {
    if (diffs[i].isNaN) {
      return HypothesisTestResult(
        testName: 'Wilcoxon Signed-Rank Test',
        statistic: double.nan,
        pValue: double.nan,
        alpha: alpha,
      );
    }
  }

  final nonZeroDiffs = diffs.where((d) => d != 0.0).toList();
  final n = nonZeroDiffs.length;
  if (n == 0) {
    throw ArgumentError('All sample differences are zero');
  }

  final absDiffs = nonZeroDiffs.map((d) => d.abs()).toList();
  final ranks = rankData(absDiffs);

  var wPlus = 0.0;
  var wMinus = 0.0;
  for (var i = 0; i < n; i++) {
    if (nonZeroDiffs[i] > 0.0) {
      wPlus += ranks[i];
    } else {
      wMinus += ranks[i];
    }
  }

  final wStat = switch (alternative) {
    AlternativeHypothesis.twoSided => math.min(wPlus, wMinus),
    AlternativeHypothesis.greater => wPlus,
    AlternativeHypothesis.less => wPlus,
  };

  // Normal approximation with tie correction
  final muW = (n * (n + 1.0)) / 4.0;

  // Tie correction
  final tieCounts = <double, int>{};
  for (final ad in absDiffs) {
    tieCounts[ad] = (tieCounts[ad] ?? 0) + 1;
  }
  var tieTerm = 0.0;
  for (final count in tieCounts.values) {
    if (count > 1) {
      tieTerm += count * count * count - count;
    }
  }

  final varW = (n * (n + 1.0) * (2.0 * n + 1.0) - 0.5 * tieTerm) / 24.0;
  final sigmaW = varW > 0.0 ? math.sqrt(varW) : 1e-15;

  const normal = NormalDistribution.standard();
  final double pValue;
  switch (alternative) {
    case AlternativeHypothesis.twoSided:
      final z = math.max(0.0, (wPlus - muW).abs() - 0.5) / sigmaW;
      pValue = (2.0 * normal.survival(z)).clamp(0.0, 1.0);
    case AlternativeHypothesis.greater:
      final z = (wPlus - muW - 0.5) / sigmaW;
      pValue = normal.survival(z).clamp(0.0, 1.0);
    case AlternativeHypothesis.less:
      final z = (wPlus - muW + 0.5) / sigmaW;
      pValue = normal.cumulativeProbability(z).clamp(0.0, 1.0);
  }

  return HypothesisTestResult(
    testName: 'Wilcoxon Signed-Rank Test',
    statistic: wStat,
    pValue: pValue,
    alpha: alpha,
    alternative: alternative,
  );
}
