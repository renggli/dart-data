import '../distributions/continuous/f.dart';
import 'hypothesis_test_result.dart';
import 'utils.dart';

/// One-way Analysis of Variance (ANOVA) test across multiple independent
/// [groups].
///
/// Tests the null hypothesis that all group means are equal against the
/// alternative that at least one group mean differs. Populates
/// [HypothesisTestResult.degreesOfFreedom] with the between-group degrees of
/// freedom (`k - 1`) and [HypothesisTestResult.denominatorDegreesOfFreedom]
/// with the within-group degrees of freedom (`N - k`).
///
/// Throws [ArgumentError] if fewer than 2 groups are provided, any group is
/// empty, total observations equal the number of groups (`N <= k`), or [alpha]
/// is outside `(0, 1)`. Returns `NaN` statistic and p-value if any observation
/// is non-finite.
HypothesisTestResult oneWayAnova(
  List<Iterable<num>> groups, {
  double alpha = 0.05,
}) {
  validateAlpha(alpha);
  final numGroups = groups.length;
  if (numGroups < 2) {
    throw ArgumentError('At least 2 groups required for ANOVA');
  }

  final groupCounts = List<int>.filled(numGroups, 0);
  final groupMeans = List<double>.filled(numGroups, 0.0);
  var totalN = 0;
  var grandMean = 0.0;
  var ssw = 0.0;
  var hasNonFinite = false;

  // Single pass per group using Welford updates for group mean, within-group SS,
  // and parallel grand mean update without storing intermediate lists.
  for (var g = 0; g < numGroups; g++) {
    var gCount = 0;
    var gMean = 0.0;
    var gM2 = 0.0;
    for (final val in groups[g]) {
      final d = val.toDouble();
      if (!d.isFinite) {
        hasNonFinite = true;
      }
      gCount++;
      final delta = d - gMean;
      gMean += delta / gCount;
      gM2 += delta * (d - gMean);
    }
    if (gCount == 0) {
      throw ArgumentError('Groups cannot be empty');
    }
    groupCounts[g] = gCount;
    groupMeans[g] = gMean;
    ssw += gM2;
    totalN += gCount;
    grandMean += (gMean - grandMean) * (gCount / totalN);
  }

  final df1 = (numGroups - 1).toDouble();
  final df2 = (totalN - numGroups).toDouble();
  if (df2 <= 0.0) {
    throw ArgumentError('Not enough observations across groups');
  }
  if (hasNonFinite) {
    return HypothesisTestResult(
      testName: 'One-Way ANOVA',
      statistic: double.nan,
      pValue: double.nan,
      degreesOfFreedom: df1,
      denominatorDegreesOfFreedom: df2,
      alpha: alpha,
    );
  }

  var ssb = 0.0;
  for (var g = 0; g < numGroups; g++) {
    final diff = groupMeans[g] - grandMean;
    ssb += groupCounts[g] * diff * diff;
  }

  final msb = ssb / df1;
  final msw = ssw / df2;
  final double fStat;
  final double pValue;
  if (msw <= 0.0) {
    if (msb > 0.0) {
      fStat = double.infinity;
      pValue = 0.0;
    } else {
      fStat = 0.0;
      pValue = 1.0;
    }
  } else {
    fStat = msb / msw;
    pValue = FDistribution(df1, df2).survival(fStat).clamp(0.0, 1.0);
  }

  return HypothesisTestResult(
    testName: 'One-Way ANOVA',
    statistic: fStat,
    pValue: pValue,
    degreesOfFreedom: df1,
    denominatorDegreesOfFreedom: df2,
    alpha: alpha,
  );
}
