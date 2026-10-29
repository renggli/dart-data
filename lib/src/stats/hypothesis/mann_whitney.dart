import 'dart:math' as math;

import '../descriptive.dart';
import '../distributions/continuous/normal.dart';
import 'hypothesis_test_result.dart';

/// Mann-Whitney U test (Wilcoxon rank-sum test) for two independent groups [x]
/// and [y].
///
/// Computes the rank-sum statistic $U$ and calculates the asymptotic p-value
/// using the normal approximation with tie correction and optional
/// [continuityCorrection] (defaults to `true`).
HypothesisTestResult mannWhitneyUTest(
  Iterable<num> x,
  Iterable<num> y, {
  AlternativeHypothesis alternative = AlternativeHypothesis.twoSided,
  double alpha = 0.05,
  bool continuityCorrection = true,
}) {
  final xList = x.map((val) => val.toDouble()).toList();
  final yList = y.map((val) => val.toDouble()).toList();
  final n1 = xList.length;
  final n2 = yList.length;
  if (n1 == 0 || n2 == 0) {
    throw ArgumentError('Groups cannot be empty');
  }

  for (var i = 0; i < n1; i++) {
    if (xList[i].isNaN) {
      return HypothesisTestResult(
        testName: 'Mann-Whitney U Test',
        statistic: double.nan,
        pValue: double.nan,
        alpha: alpha,
      );
    }
  }
  for (var i = 0; i < n2; i++) {
    if (yList[i].isNaN) {
      return HypothesisTestResult(
        testName: 'Mann-Whitney U Test',
        statistic: double.nan,
        pValue: double.nan,
        alpha: alpha,
      );
    }
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

  final n = n1 + n2;
  final muU = (n1 * n2) / 2.0;

  // Tie correction
  final tieCounts = <double, int>{};
  for (final val in combined) {
    tieCounts[val] = (tieCounts[val] ?? 0) + 1;
  }
  var tieTerm = 0.0;
  for (final count in tieCounts.values) {
    if (count > 1) {
      tieTerm += count * count * count - count;
    }
  }

  final tieCorrection = tieTerm / (n * (n - 1.0));
  final varU = (n1 * n2 / 12.0) * (n + 1.0 - tieCorrection);
  if (varU <= 0.0) {
    return HypothesisTestResult(
      testName: 'Mann-Whitney U Test',
      statistic: uStat,
      pValue: 1.0,
      alpha: alpha,
      alternative: alternative,
    );
  }

  final sigmaU = math.sqrt(varU);
  const normal = NormalDistribution.standard();

  final double pValue;
  switch (alternative) {
    case AlternativeHypothesis.twoSided:
      final diff = (u1 - muU).abs();
      final adjustedDiff = continuityCorrection
          ? math.max(0.0, diff - 0.5)
          : diff;
      final z = adjustedDiff / sigmaU;
      pValue = (2.0 * normal.survival(z)).clamp(0.0, 1.0);
    case AlternativeHypothesis.less:
      final diff = u1 - muU;
      final adjustedDiff = continuityCorrection ? diff + 0.5 : diff;
      final z = adjustedDiff / sigmaU;
      pValue = normal.cumulativeProbability(z).clamp(0.0, 1.0);
    case AlternativeHypothesis.greater:
      final diff = u1 - muU;
      final adjustedDiff = continuityCorrection ? diff - 0.5 : diff;
      final z = adjustedDiff / sigmaU;
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
