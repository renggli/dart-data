import '../distributions/continuous/chi_squared.dart';
import 'hypothesis_test_result.dart';
import 'utils.dart';

/// Kruskal-Wallis H-test (one-way ANOVA on ranks) across multiple independent
/// [groups].
///
/// Tests the null hypothesis that the population medians of all [groups] are
/// equal without assuming normality, applying exact tie correction to the
/// chi-squared approximation with `k - 1` degrees of freedom.
///
/// Throws [ArgumentError] if fewer than 2 groups are given, any group is
/// empty, total observations are fewer than 2, or [alpha] is outside `(0, 1)`.
/// Returns `NaN` statistic and p-value if any observation is `NaN`.
HypothesisTestResult kruskalWallisTest(
  List<Iterable<num>> groups, {
  double alpha = 0.05,
}) {
  validateAlpha(alpha);
  final numGroups = groups.length;
  if (numGroups < 2) {
    throw ArgumentError('At least 2 groups required for Kruskal-Wallis test');
  }

  final combined = <double>[];
  final groupSizes = List<int>.filled(numGroups, 0);
  var hasNan = false;
  for (var g = 0; g < numGroups; g++) {
    var count = 0;
    for (final val in groups[g]) {
      final d = val.toDouble();
      if (d.isNaN) hasNan = true;
      combined.add(d);
      count++;
    }
    if (count == 0) {
      throw ArgumentError('Groups cannot be empty');
    }
    groupSizes[g] = count;
  }

  final df = (numGroups - 1).toDouble();
  if (hasNan) {
    return HypothesisTestResult(
      testName: 'Kruskal-Wallis H Test',
      statistic: double.nan,
      pValue: double.nan,
      degreesOfFreedom: df,
      alpha: alpha,
    );
  }

  final totalN = combined.length;
  final ranked = rankDataWithTies(combined);
  final nDouble = totalN.toDouble();
  final denom = nDouble * nDouble * nDouble - nDouble;
  final tieCorrectionFactor = 1.0 - ranked.tieCorrectionSum / denom;

  if (tieCorrectionFactor <= 0.0) {
    return HypothesisTestResult(
      testName: 'Kruskal-Wallis H Test',
      statistic: 0.0,
      pValue: 1.0,
      degreesOfFreedom: df,
      alpha: alpha,
    );
  }

  var rankSqOverN = 0.0;
  var offset = 0;
  for (var g = 0; g < numGroups; g++) {
    final ni = groupSizes[g];
    var rSum = 0.0;
    for (var i = 0; i < ni; i++) {
      rSum += ranked.ranks[offset + i];
    }
    rankSqOverN += (rSum * rSum) / ni;
    offset += ni;
  }

  final rawH =
      (12.0 / (nDouble * (nDouble + 1.0))) * rankSqOverN -
      3.0 * (nDouble + 1.0);
  final hStat = (rawH / tieCorrectionFactor).clamp(0.0, double.infinity);
  final pValue = ChiSquaredDistribution(df).survival(hStat).clamp(0.0, 1.0);

  return HypothesisTestResult(
    testName: 'Kruskal-Wallis H Test',
    statistic: hStat,
    pValue: pValue,
    degreesOfFreedom: df,
    alpha: alpha,
  );
}
