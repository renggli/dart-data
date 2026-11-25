import 'dart:math' as math;

import '../../linear/matrix.dart';
import '../distributions/continuous/chi_squared.dart';
import 'hypothesis_test_result.dart';
import 'utils.dart';

/// Chi-squared goodness-of-fit test comparing [observed] counts against
/// [expected] counts.
///
/// When [expected] is omitted, assumes a uniform distribution across all
/// categories. When [expected] is provided, scales expected values to match
/// the observed total if they differ beyond relative tolerance `1e-7`. Adjusts
/// degrees of freedom as `categories - 1 - ddof`.
///
/// Throws [ArgumentError] if fewer than 2 categories exist, counts are
/// negative/non-finite, [expected] entries are non-positive or length-mismatched,
/// [ddof] is negative, resulting degrees of freedom are non-positive, or
/// [alpha] is outside `(0, 1)`.
HypothesisTestResult chiSquaredTest(
  Iterable<num> observed, {
  Iterable<num>? expected,
  int ddof = 0,
  double alpha = 0.05,
}) {
  validateAlpha(alpha);
  if (ddof < 0) {
    throw ArgumentError.value(ddof, 'ddof', 'ddof must be non-negative');
  }
  final obs = <double>[];
  var obsSum = 0.0;
  for (final val in observed) {
    final v = val.toDouble();
    if (!v.isFinite || v < 0.0) {
      throw ArgumentError.value(
        val,
        'observed',
        'Observed counts must be non-negative and finite',
      );
    }
    obs.add(v);
    obsSum += v;
  }
  final numCategories = obs.length;
  if (numCategories < 2) {
    throw ArgumentError('At least 2 observed categories required');
  }
  if (obsSum <= 0.0) {
    throw ArgumentError('Observed counts must sum to a positive number');
  }

  final List<double> exp;
  if (expected == null) {
    exp = List<double>.filled(numCategories, obsSum / numCategories);
  } else {
    exp = <double>[];
    var expSum = 0.0;
    for (final val in expected) {
      final v = val.toDouble();
      if (!v.isFinite || v <= 0.0) {
        throw ArgumentError.value(
          val,
          'expected',
          'Expected counts must be positive and finite',
        );
      }
      exp.add(v);
      expSum += v;
    }
    if (exp.length != numCategories) {
      throw ArgumentError('Expected length must match observed length');
    }
    if ((expSum - obsSum).abs() > 1e-7 * obsSum) {
      final factor = obsSum / expSum;
      for (var i = 0; i < numCategories; i++) {
        exp[i] *= factor;
      }
    }
  }

  final dof = (numCategories - 1 - ddof).toDouble();
  if (dof <= 0.0) {
    throw ArgumentError('Degrees of freedom must be positive');
  }

  var chi2 = 0.0;
  for (var i = 0; i < numCategories; i++) {
    final diff = obs[i] - exp[i];
    chi2 += (diff * diff) / exp[i];
  }

  final pValue = ChiSquaredDistribution(dof).survival(chi2).clamp(0.0, 1.0);

  return HypothesisTestResult(
    testName: 'Chi-Squared Goodness-of-Fit Test',
    statistic: chi2,
    pValue: pValue,
    degreesOfFreedom: dof,
    alpha: alpha,
  );
}

/// Chi-squared test of independence for contingency [table].
///
/// For 2x2 contingency tables, setting [continuityCorrection] to `true` applies
/// Yates' continuity correction subtracting `min(0.5, |O - E|)` before squaring.
///
/// Throws [ArgumentError] if dimensions are smaller than 2x2, any entry is
/// negative or non-finite, any row/column marginal sum is zero, or [alpha] is
/// outside `(0, 1)`.
HypothesisTestResult chiSquaredContingency(
  Matrix<num> table, {
  bool continuityCorrection = false,
  double alpha = 0.05,
}) {
  validateAlpha(alpha);
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
      final val = table.getUnchecked(i, j).toDouble();
      if (val < 0.0 || !val.isFinite) {
        throw ArgumentError.value(
          val,
          'table[$i][$j]',
          'Contingency table counts must be non-negative and finite',
        );
      }
      rowSums[i] += val;
      colSums[j] += val;
      total += val;
    }
  }
  if (total <= 0.0) {
    throw ArgumentError('Contingency table total count must be positive');
  }
  for (var i = 0; i < rowCount; i++) {
    if (rowSums[i] <= 0.0) {
      throw ArgumentError('Row $i marginal sum must be positive');
    }
  }
  for (var j = 0; j < colCount; j++) {
    if (colSums[j] <= 0.0) {
      throw ArgumentError('Column $j marginal sum must be positive');
    }
  }

  final applyYates = continuityCorrection && rowCount == 2 && colCount == 2;
  var chi2 = 0.0;
  for (var i = 0; i < rowCount; i++) {
    for (var j = 0; j < colCount; j++) {
      final expected = (rowSums[i] * colSums[j]) / total;
      final observed = table.getUnchecked(i, j).toDouble();
      var absDiff = (observed - expected).abs();
      if (applyYates) {
        absDiff = math.max(0.0, absDiff - 0.5);
      }
      chi2 += (absDiff * absDiff) / expected;
    }
  }

  final dof = ((rowCount - 1) * (colCount - 1)).toDouble();
  final pValue = ChiSquaredDistribution(dof).survival(chi2).clamp(0.0, 1.0);

  return HypothesisTestResult(
    testName: 'Chi-Squared Test of Independence',
    statistic: chi2,
    pValue: pValue,
    degreesOfFreedom: dof,
    alpha: alpha,
  );
}
