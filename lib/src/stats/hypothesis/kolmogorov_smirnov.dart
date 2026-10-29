import 'dart:math' as math;

import '../distribution.dart';
import '../distributions/discrete.dart';
import 'hypothesis_test_result.dart';

/// One-sample Kolmogorov-Smirnov test comparing [sample] against a theoretical
/// [distribution].
///
/// Tests the null hypothesis that [sample] is drawn from the continuous
/// reference [distribution].
///
/// Throws an [ArgumentError] if [sample] is empty or if [distribution] is a
/// [DiscreteDistribution].
HypothesisTestResult kolmogorovSmirnovTest(
  Iterable<num> sample,
  Distribution<num> distribution, {
  double alpha = 0.05,
}) {
  if (distribution is DiscreteDistribution) {
    throw ArgumentError.value(
      distribution,
      'distribution',
      'Kolmogorov-Smirnov test requires a continuous distribution',
    );
  }
  final list = sample.map((val) => val.toDouble()).toList()..sort();
  final n = list.length;
  if (n == 0) {
    throw ArgumentError('Sample cannot be empty');
  }
  for (var i = 0; i < n; i++) {
    if (list[i].isNaN) {
      return HypothesisTestResult(
        testName: 'One-Sample Kolmogorov-Smirnov Test',
        statistic: double.nan,
        pValue: double.nan,
        alpha: alpha,
      );
    }
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
  final pValue = n <= 100
      ? (1.0 - _kolmogorovExactCdf(dStat, n)).clamp(0.0, 1.0)
      : _kolmogorovPValue(dStat, n.toDouble());

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
HypothesisTestResult kolmogorovSmirnovTwoSample(
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
  for (var k = 0; k < n1; k++) {
    if (list1[k].isNaN) {
      return HypothesisTestResult(
        testName: 'Two-Sample Kolmogorov-Smirnov Test',
        statistic: double.nan,
        pValue: double.nan,
        alpha: alpha,
      );
    }
  }
  for (var k = 0; k < n2; k++) {
    if (list2[k].isNaN) {
      return HypothesisTestResult(
        testName: 'Two-Sample Kolmogorov-Smirnov Test',
        statistic: double.nan,
        pValue: double.nan,
        alpha: alpha,
      );
    }
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
  if (lambda >= 6.5) return 0.0;

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

/// Exact cumulative distribution function $P(D_n < d)$ of the one-sample
/// Kolmogorov statistic using the Marsaglia-Tsang-Wang (2003) / Carvalho (2015)
/// transition matrix method.
double _kolmogorovExactCdf(double d, int n) {
  if (d <= 0.5 / n) return 0.0;
  if (d >= 1.0) return 1.0;

  final k = (n * d).ceil();
  final m = 2 * k - 1;
  final h = k.toDouble() - n * d;

  final hMat = List<double>.filled(m * m, 0.0);
  for (var i = 0; i < m; i++) {
    for (var j = 0; j < m; j++) {
      if (i - j + 1 >= 0) {
        hMat[i * m + j] = 1.0;
      }
    }
  }

  for (var i = 0; i < m; i++) {
    hMat[i * m] -= math.pow(h, i + 1.0);
    hMat[(m - 1) * m + i] -= math.pow(h, m - i.toDouble());
  }

  if (2.0 * h - 1.0 > 0.0) {
    hMat[(m - 1) * m] += math.pow(2.0 * h - 1.0, m.toDouble());
  }

  for (var i = 0; i < m; i++) {
    for (var j = 0; j < m; j++) {
      if (i - j + 1 > 0) {
        var fact = 1.0;
        for (var g = 1; g <= i - j + 1; g++) {
          fact *= g;
        }
        hMat[i * m + j] /= fact;
      }
    }
  }

  // Vector multiplication: v_0 = e_{k-1}
  var v = List<double>.filled(m, 0.0);
  v[k - 1] = 1.0;
  for (var t = 1; t <= n; t++) {
    final vNext = List<double>.filled(m, 0.0);
    final scale = t / n;
    for (var j = 0; j < m; j++) {
      var s = 0.0;
      for (var i = 0; i < m; i++) {
        s += v[i] * hMat[i * m + j];
      }
      vNext[j] = s * scale;
    }
    v = vNext;
  }

  return v[k - 1].clamp(0.0, 1.0);
}
