import 'dart:math';

import '../../special/gamma.dart';
import 'hypothesis_test_result.dart';

/// Fisher's exact test for 2x2 contingency tables.
///
/// Tests the null hypothesis that classification categories are independent.
/// The input [table] must be a 2x2 matrix or list-of-lists of non-negative
/// integers:
/// `[[a, b], [c, d]]`
///
/// The computed [HypothesisTestResult.statistic] is the sample odds ratio
/// $\frac{a \cdot d}{b \cdot c}$.
HypothesisTestResult fisherExactTest(
  List<List<int>> table, {
  AlternativeHypothesis alternative = AlternativeHypothesis.twoSided,
  double alpha = 0.05,
}) {
  if (table.length != 2 || table[0].length != 2 || table[1].length != 2) {
    throw ArgumentError.value(
      table,
      'table',
      'Fisher exact test requires a 2x2 contingency table',
    );
  }

  final a = table[0][0];
  final b = table[0][1];
  final c = table[1][0];
  final d = table[1][1];

  if (a < 0 || b < 0 || c < 0 || d < 0) {
    throw ArgumentError('Table entries must be non-negative integers');
  }

  final r1 = a + b;
  final r2 = c + d;
  final c1 = a + c;
  final n = r1 + r2;

  if (n == 0) {
    return HypothesisTestResult(
      testName: "Fisher's Exact Test",
      statistic: double.nan,
      pValue: double.nan,
      alpha: alpha,
      alternative: alternative,
    );
  }

  // Odds ratio: (a * d) / (b * c)
  final double oddsRatio;
  if (b * c == 0) {
    oddsRatio = (a * d == 0) ? double.nan : double.infinity;
  } else {
    oddsRatio = (a.toDouble() * d) / (b.toDouble() * c);
  }

  // Hypergeometric probability log-function for cell A = k:
  // P(A = k) = C(r1, k) * C(r2, c1 - k) / C(n, c1)
  final logTotalComb = combinationLn(n, c1);
  double logHypergeometricProb(int k) {
    final k2 = c1 - k;
    if (k < 0 || k > r1 || k2 < 0 || k2 > r2) return double.negativeInfinity;
    return combinationLn(r1, k) + combinationLn(r2, k2) - logTotalComb;
  }

  final minK = max(0, c1 - r2);
  final maxK = min(r1, c1);

  final observedLogProb = logHypergeometricProb(a);
  final observedProb = exp(observedLogProb);

  var pValue = 0.0;
  for (var k = minK; k <= maxK; k++) {
    final logP = logHypergeometricProb(k);
    final pK = exp(logP);

    switch (alternative) {
      case AlternativeHypothesis.twoSided:
        // Sum probabilities of tables less than or equally likely as observed
        if (pK <= observedProb * (1.0 + 1e-12)) {
          pValue += pK;
        }
      case AlternativeHypothesis.less:
        if (k <= a) {
          pValue += pK;
        }
      case AlternativeHypothesis.greater:
        if (k >= a) {
          pValue += pK;
        }
    }
  }

  pValue = pValue.clamp(0.0, 1.0);

  return HypothesisTestResult(
    testName: "Fisher's Exact Test",
    statistic: oddsRatio,
    pValue: pValue,
    alpha: alpha,
    alternative: alternative,
  );
}
