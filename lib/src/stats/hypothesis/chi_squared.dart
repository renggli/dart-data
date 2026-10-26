import '../../linear/matrix.dart';
import '../descriptive.dart';
import '../distributions/continuous/chi_squared.dart';
import 'hypothesis_test_result.dart';

/// Chi-squared goodness-of-fit test.
///
/// Compares [observed] frequencies against [expected] frequencies.
HypothesisTestResult chiSquaredTest(
  Iterable<num> observed, {
  Iterable<num>? expected,
  int ddof = 0,
  double alpha = 0.05,
}) {
  final obs = observed.map((val) => val.toDouble()).toList();
  final numCategories = obs.length;
  if (numCategories < 2) {
    throw ArgumentError('At least 2 observed categories required');
  }

  final obsSum = obs.sum();
  final List<double> exp;

  if (expected == null) {
    final uniformExp = obsSum / numCategories;
    exp = List<double>.filled(numCategories, uniformExp);
  } else {
    exp = expected.map((val) => val.toDouble()).toList();
    if (exp.length != numCategories) {
      throw ArgumentError('Expected length must match observed length');
    }
    final expSum = exp.sum();
    if ((expSum - obsSum).abs() > 1e-7 && expSum > 0.0) {
      final factor = obsSum / expSum;
      for (var i = 0; i < numCategories; i++) {
        exp[i] *= factor;
      }
    }
  }

  var chi2 = 0.0;
  for (var i = 0; i < numCategories; i++) {
    if (exp[i] <= 0.0) {
      throw ArgumentError('Expected counts must be positive');
    }
    final diff = obs[i] - exp[i];
    chi2 += (diff * diff) / exp[i];
  }

  final dof = (numCategories - 1 - ddof).toDouble();
  if (dof <= 0.0) {
    throw ArgumentError('Degrees of freedom must be positive');
  }

  final dist = ChiSquaredDistribution(dof);
  final pValue = dist.survival(chi2).clamp(0.0, 1.0);

  return HypothesisTestResult(
    testName: 'Chi-Squared Goodness-of-Fit Test',
    statistic: chi2,
    pValue: pValue,
    degreesOfFreedom: dof,
    alpha: alpha,
  );
}

/// Chi-squared test of independence for contingency [table].
HypothesisTestResult chiSquaredContingency(
  Matrix<num> table, {
  double alpha = 0.05,
}) {
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
      final val = table.get(i, j).toDouble();
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

  var chi2 = 0.0;
  for (var i = 0; i < rowCount; i++) {
    for (var j = 0; j < colCount; j++) {
      final expected = (rowSums[i] * colSums[j]) / total;
      final observed = table.get(i, j).toDouble();
      final diff = observed - expected;
      chi2 += (diff * diff) / expected;
    }
  }

  final dof = ((rowCount - 1) * (colCount - 1)).toDouble();
  final dist = ChiSquaredDistribution(dof);
  final pValue = dist.survival(chi2).clamp(0.0, 1.0);

  return HypothesisTestResult(
    testName: 'Chi-Squared Test of Independence',
    statistic: chi2,
    pValue: pValue,
    degreesOfFreedom: dof,
    alpha: alpha,
  );
}
