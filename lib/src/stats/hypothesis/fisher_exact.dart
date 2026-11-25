import 'dart:math';

import '../../linear/matrix.dart';
import '../distributions/discrete/hypergeometric.dart';
import 'hypothesis_test_result.dart';
import 'utils.dart';

/// Fisher's exact test for 2x2 contingency tables.
///
/// Tests the null hypothesis that the row and column classifications are
/// independent using exact hypergeometric tail probabilities over the 2x2
/// integer count matrix `[[a, b], [c, d]]`.
///
/// The reported [HypothesisTestResult.statistic] is the sample odds ratio
/// `(a * d) / (b * c)`.
///
/// Throws [ArgumentError] if [table] is not 2x2, contains negative counts, or
/// if [alpha] is outside `(0, 1)`.
HypothesisTestResult fisherExactTest(
  Matrix<int> table, {
  AlternativeHypothesis alternative = AlternativeHypothesis.twoSided,
  double alpha = 0.05,
}) {
  validateAlpha(alpha);
  if (table.rowCount != 2 || table.colCount != 2) {
    throw ArgumentError.value(
      table,
      'table',
      'Fisher exact test requires a 2x2 contingency table',
    );
  }
  final a = table.getUnchecked(0, 0);
  final b = table.getUnchecked(0, 1);
  final c = table.getUnchecked(1, 0);
  final d = table.getUnchecked(1, 1);

  if (a < 0 || b < 0 || c < 0 || d < 0) {
    throw ArgumentError('Table entries must be non-negative integers');
  }

  final r1 = a + b;
  final c1 = a + c;
  final n = r1 + c + d;

  if (n == 0) {
    return HypothesisTestResult(
      testName: "Fisher's Exact Test",
      statistic: double.nan,
      pValue: double.nan,
      alpha: alpha,
      alternative: alternative,
    );
  }

  final double oddsRatio;
  if (b == 0 || c == 0) {
    oddsRatio = (a == 0 || d == 0) ? double.nan : double.infinity;
  } else {
    oddsRatio = (a.toDouble() * d) / (b.toDouble() * c);
  }

  final dist = HypergeometricDistribution(n, r1, c1);
  final double pValue;
  switch (alternative) {
    case AlternativeHypothesis.less:
      pValue = dist.cumulativeProbability(a).clamp(0.0, 1.0);
    case AlternativeHypothesis.greater:
      pValue = dist.survival(a - 1).clamp(0.0, 1.0);
    case AlternativeHypothesis.twoSided:
      final observedLogProb = dist.logProbability(a);
      final threshold = observedLogProb + 1e-12;
      var sum = 0.0;
      for (var k = dist.lowerBound; k <= dist.upperBound; k++) {
        final logP = dist.logProbability(k);
        if (logP <= threshold) {
          sum += exp(logP);
        }
      }
      pValue = sum.clamp(0.0, 1.0);
  }

  return HypothesisTestResult(
    testName: "Fisher's Exact Test",
    statistic: oddsRatio,
    pValue: pValue,
    alpha: alpha,
    alternative: alternative,
  );
}
