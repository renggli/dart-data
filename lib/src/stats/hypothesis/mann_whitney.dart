import 'dart:math' as math;
import 'dart:typed_data';

import '../../special/binomial.dart';
import '../distributions/continuous/normal.dart';
import 'hypothesis_test_result.dart';
import 'utils.dart';

/// Mann-Whitney U test (Wilcoxon rank-sum test) for two independent groups
/// [x] and [y].
///
/// Computes the rank-sum statistic `U`. When [exact] is `true`, or when
/// [exact] is omitted for small untied samples (`n1 * n2 <= 400` and
/// `n1 + n2 <= 50`), computes the exact permutation p-value via dynamic
/// programming. Otherwise uses the tie-corrected normal approximation with
/// optional [continuityCorrection] (defaults to `true`).
///
/// Throws [ArgumentError] if either group is empty, [alpha] is outside
/// `(0, 1)`, or `exact: true` is requested when ties are present. Returns
/// `NaN` statistic and p-value if any observation is `NaN`.
HypothesisTestResult mannWhitneyUTest(
  Iterable<num> x,
  Iterable<num> y, {
  AlternativeHypothesis alternative = AlternativeHypothesis.twoSided,
  double alpha = 0.05,
  bool continuityCorrection = true,
  bool? exact,
}) {
  validateAlpha(alpha);
  final xList = <double>[];
  var hasNan = false;
  for (final val in x) {
    final d = val.toDouble();
    if (d.isNaN) hasNan = true;
    xList.add(d);
  }
  final yList = <double>[];
  for (final val in y) {
    final d = val.toDouble();
    if (d.isNaN) hasNan = true;
    yList.add(d);
  }
  final n1 = xList.length;
  final n2 = yList.length;
  if (n1 == 0 || n2 == 0) {
    throw ArgumentError('Groups cannot be empty');
  }
  if (hasNan) {
    return HypothesisTestResult(
      testName: 'Mann-Whitney U Test',
      statistic: double.nan,
      pValue: double.nan,
      alpha: alpha,
      alternative: alternative,
    );
  }

  final combined = [...xList, ...yList];
  final ranked = rankDataWithTies(combined);
  if (exact == true) {
    if (ranked.hasTies) {
      throw ArgumentError(
        'Exact Mann-Whitney U p-value requires untied samples',
      );
    }
    if (n1 + n2 > 50) {
      throw ArgumentError(
        'Exact Mann-Whitney U p-value requires total sample size <= 50',
      );
    }
  }

  var rankSum1 = 0.0;
  for (var i = 0; i < n1; i++) {
    rankSum1 += ranked.ranks[i];
  }

  final u1 = rankSum1 - 0.5 * n1 * (n1 + 1.0);
  final n1n2 = n1.toDouble() * n2;
  final u2 = n1n2 - u1;
  final uStat = switch (alternative) {
    AlternativeHypothesis.twoSided => math.min(u1, u2),
    AlternativeHypothesis.less || AlternativeHypothesis.greater => u1,
  };

  final useExact =
      exact ?? (!ranked.hasTies && n1 * n2 <= 400 && n1 + n2 <= 50);
  if (useExact && n1 + n2 <= 50) {
    final pValue = _exactMannWhitneyPValue(u1.round(), n1, n2, alternative);
    return HypothesisTestResult(
      testName: 'Mann-Whitney U Test',
      statistic: uStat,
      pValue: pValue,
      alpha: alpha,
      alternative: alternative,
    );
  }

  final n = (n1 + n2).toDouble();
  final muU = 0.5 * n1n2;
  final tieCorrection = ranked.tieCorrectionSum / (n * (n - 1.0));
  final varU = (n1n2 / 12.0) * (n + 1.0 - tieCorrection);
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
      pValue = (2.0 * normal.survival(adjustedDiff / sigmaU)).clamp(0.0, 1.0);
    case AlternativeHypothesis.less:
      final diff = u1 - muU;
      final adjustedDiff = continuityCorrection ? diff + 0.5 : diff;
      pValue = normal
          .cumulativeProbability(adjustedDiff / sigmaU)
          .clamp(0.0, 1.0);
    case AlternativeHypothesis.greater:
      final diff = u1 - muU;
      final adjustedDiff = continuityCorrection ? diff - 0.5 : diff;
      pValue = normal.survival(adjustedDiff / sigmaU).clamp(0.0, 1.0);
  }

  return HypothesisTestResult(
    testName: 'Mann-Whitney U Test',
    statistic: uStat,
    pValue: pValue,
    alpha: alpha,
    alternative: alternative,
  );
}

double _exactMannWhitneyPValue(
  int u1,
  int n1,
  int n2,
  AlternativeHypothesis alternative,
) {
  final maxU = n1 * n2;
  final target = switch (alternative) {
    AlternativeHypothesis.twoSided => math.min(u1, maxU - u1),
    AlternativeHypothesis.less => u1,
    AlternativeHypothesis.greater => maxU - u1,
  };
  if (target < 0) return 0.0;
  if (target >= maxU) return 1.0;

  final cdfProb = _mannWhitneyLowerCdf(target, n1, n2);
  return alternative == AlternativeHypothesis.twoSided
      ? (2.0 * cdfProb).clamp(0.0, 1.0)
      : cdfProb.clamp(0.0, 1.0);
}

double _mannWhitneyLowerCdf(int target, int n1, int n2) {
  // Recurrence: c(i, j, u) = c(i - 1, j, u - j) + c(i, j - 1, u).
  final uCap = math.min(target, n1 * n2);
  final stride = uCap + 1;
  var prev = List<Float64List>.generate(n1 + 1, (_) => Float64List(stride));
  for (var i = 0; i <= n1; i++) {
    prev[i][0] = 1.0;
  }
  for (var j = 1; j <= n2; j++) {
    final curr = List<Float64List>.generate(n1 + 1, (_) => Float64List(stride));
    curr[0][0] = 1.0;
    for (var i = 1; i <= n1; i++) {
      final ci = curr[i];
      final cim1 = curr[i - 1];
      final pi = prev[i];
      final limit = math.min(uCap, i * j);
      for (var u = 0; u <= limit; u++) {
        var ways = pi[u];
        if (u >= j) ways += cim1[u - j];
        ci[u] = ways;
      }
    }
    prev = curr;
  }

  var sum = 0.0;
  final finalRow = prev[n1];
  for (var u = 0; u <= uCap; u++) {
    sum += finalRow[u];
  }
  final total = math.exp(binomialLn(n1 + n2, n1));
  return sum / total;
}
