import 'dart:math' as math;

import '../distribution.dart';
import 'hypothesis_test_result.dart';

/// One-sample Kolmogorov-Smirnov test comparing [sample] against a theoretical
/// [distribution].
///
/// Tests the null hypothesis that [sample] is drawn from the continuous
/// reference [distribution].
HypothesisTestResult kolmogorovSmirnovTest(
  Iterable<num> sample,
  Distribution<num> distribution, {
  double alpha = 0.05,
}) {
  final list = sample.map((val) => val.toDouble()).toList()..sort();
  final n = list.length;
  if (n == 0) {
    throw ArgumentError('Sample cannot be empty');
  }

  var dPlus = 0.0;
  var dMinus = 0.0;
  for (var i = 0; i < n; i++) {
    final cdfVal = distribution.cumulativeProbability(list[i]);
    final iOverN = (i + 1.0) / n;
    final iMinusOneOverN = i.toDouble() / n;
    final dp = iOverN - cdfVal;
    if (dp > dPlus) dPlus = dp;
    final dm = cdfVal - iMinusOneOverN;
    if (dm > dMinus) dMinus = dm;
  }
  final dStat = math.max(dPlus, dMinus);
  final pValue = _kolmogorovPValue(dStat, n.toDouble());

  return HypothesisTestResult(
    testName: 'One-Sample Kolmogorov-Smirnov Test',
    statistic: dStat,
    pValue: pValue,
    alpha: alpha,
  );
}

/// Two-sample Kolmogorov-Smirnov test comparing two empirical samples [sample1]
/// and [sample2].
///
/// Tests the null hypothesis that both samples are drawn from the same
/// continuous distribution.
HypothesisTestResult kolmogorovSmirnov2Sample(
  Iterable<num> sample1,
  Iterable<num> sample2, {
  double alpha = 0.05,
}) {
  final list1 = sample1.map((val) => val.toDouble()).toList()..sort();
  final list2 = sample2.map((val) => val.toDouble()).toList()..sort();
  final n1 = list1.length;
  final n2 = list2.length;
  if (n1 == 0 || n2 == 0) {
    throw ArgumentError('Samples cannot be empty');
  }

  var i = 0;
  var j = 0;
  var dStat = 0.0;
  while (i < n1 || j < n2) {
    final double x;
    if (i < n1 && j < n2) {
      x = math.min(list1[i], list2[j]);
    } else if (i < n1) {
      x = list1[i];
    } else {
      x = list2[j];
    }
    while (i < n1 && list1[i] <= x) {
      i++;
    }
    while (j < n2 && list2[j] <= x) {
      j++;
    }
    final diff = ((i / n1) - (j / n2)).abs();
    if (diff > dStat) dStat = diff;
  }

  final ne = (n1 * n2) / (n1 + n2);
  final pValue = _kolmogorovPValue(dStat, ne);

  return HypothesisTestResult(
    testName: 'Two-Sample Kolmogorov-Smirnov Test',
    statistic: dStat,
    pValue: pValue,
    alpha: alpha,
  );
}

double _kolmogorovPValue(double d, double n) {
  if (d <= 0.0) return 1.0;
  final sqrtN = math.sqrt(n);
  final lambda = (sqrtN + 0.12 + 0.11 / sqrtN) * d;
  if (lambda <= 0.0) return 1.0;
  if (lambda >= 3.0) return 0.0;

  final lambdaSq = lambda * lambda;
  var sum = 0.0;
  var sign = 1.0;
  for (var k = 1; k <= 100; k++) {
    final term = 2.0 * math.exp(-2.0 * k * k * lambdaSq);
    sum += sign * term;
    if (term < 1e-15) break;
    sign = -sign;
  }
  return sum.clamp(0.0, 1.0);
}
