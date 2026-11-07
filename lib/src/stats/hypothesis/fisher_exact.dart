import 'dart:math';

import '../../linear/matrix.dart';
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
  Object table, {
  AlternativeHypothesis alternative = AlternativeHypothesis.twoSided,
  double alpha = 0.05,
}) {
  final int a, b, c, d;
  if (table is Matrix<num>) {
    if (table.rowCount != 2 || table.colCount != 2) {
      throw ArgumentError.value(
        table,
        'table',
        'Fisher exact test requires a 2x2 contingency table',
      );
    }
    a = table.get(0, 0).round();
    b = table.get(0, 1).round();
    c = table.get(1, 0).round();
    d = table.get(1, 1).round();
  } else if (table is Iterable) {
    final rows = table.toList();
    if (rows.length != 2) {
      throw ArgumentError.value(
        table,
        'table',
        'Fisher exact test requires a 2x2 contingency table',
      );
    }
    final r0 = rows[0];
    final r1 = rows[1];
    if (r0 is! Iterable || r1 is! Iterable) {
      throw ArgumentError.value(
        table,
        'table',
        'Fisher exact test requires a 2x2 contingency table',
      );
    }
    final row0 = r0.toList();
    final row1 = r1.toList();
    if (row0.length != 2 || row1.length != 2) {
      throw ArgumentError.value(
        table,
        'table',
        'Fisher exact test requires a 2x2 contingency table',
      );
    }
    if (row0[0] is! num ||
        row0[1] is! num ||
        row1[0] is! num ||
        row1[1] is! num) {
      throw ArgumentError.value(
        table,
        'table',
        'Table entries must be non-negative integers',
      );
    }
    a = (row0[0] as num).round();
    b = (row0[1] as num).round();
    c = (row1[0] as num).round();
    d = (row1[1] as num).round();
  } else {
    throw ArgumentError.value(
      table,
      'table',
      'Fisher exact test requires a 2x2 contingency table',
    );
  }

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
