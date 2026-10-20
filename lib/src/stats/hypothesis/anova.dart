import '../descriptive.dart';
import '../distributions/continuous/f.dart';
import 'hypothesis_test_result.dart';

/// One-way Analysis of Variance (ANOVA) test across multiple independent
/// groups.
HypothesisTestResult oneWayAnova(
  List<Iterable<num>> groups, {
  double alpha = 0.05,
}) {
  final numGroups = groups.length;
  if (numGroups < 2) {
    throw ArgumentError('At least 2 groups required for ANOVA');
  }

  final doubleLists = groups
      .map((group) => group.map((val) => val.toDouble()).toList())
      .toList();
  var totalN = 0;
  var grandSum = 0.0;
  for (final group in doubleLists) {
    if (group.isEmpty) {
      throw ArgumentError('Groups cannot be empty');
    }
    totalN += group.length;
    for (final x in group) {
      grandSum += x;
    }
  }

  final grandMean = grandSum / totalN;
  var ssb = 0.0;
  var ssw = 0.0;

  for (final group in doubleLists) {
    final gMean = mean(group);
    ssb += group.length * (gMean - grandMean) * (gMean - grandMean);
    for (final x in group) {
      final diff = x - gMean;
      ssw += diff * diff;
    }
  }

  final df1 = (numGroups - 1).toDouble();
  final df2 = (totalN - numGroups).toDouble();
  if (df2 <= 0.0) {
    throw ArgumentError('Not enough observations across groups');
  }

  final msb = ssb / df1;
  final msw = ssw / df2;
  final fStat = msw > 0.0 ? msb / msw : 0.0;

  final dist = FDistribution(df1, df2);
  final pValue = dist.survival(fStat).clamp(0.0, 1.0);

  return HypothesisTestResult(
    testName: 'One-Way ANOVA',
    statistic: fStat,
    pValue: pValue,
    degreesOfFreedom: df1,
    alpha: alpha,
  );
}
