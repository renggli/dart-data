import 'dart:math' as math;

import '../descriptive.dart';
import '../distributions/continuous/normal.dart';
import 'hypothesis_test_result.dart';

/// Mann-Whitney U test (Wilcoxon rank-sum test) for two independent groups [x]
/// and [y].
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
