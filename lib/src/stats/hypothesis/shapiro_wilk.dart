import 'dart:math';

import '../descriptive.dart';
import '../distributions/continuous/normal.dart';
import 'hypothesis_test_result.dart';

/// Shapiro-Wilk test for sample normality.
///
/// Tests the null hypothesis that [sample] is drawn from a normally distributed
/// population. Computes the test statistic $W$ and the corresponding $p$-value
/// using Royston's standard approximation for sample sizes $3 \le n \le 5000$.
///
/// Returns a [HypothesisTestResult] containing the $W$ test statistic and $p$-value.
HypothesisTestResult shapiroWilkTest(
  Iterable<num> sample, {
  double alpha = 0.05,
}) {
  final list = <double>[];
  for (final x in sample) {
    final val = x.toDouble();
    if (val.isNaN) {
      return HypothesisTestResult(
        testName: 'Shapiro-Wilk Normality Test',
        statistic: double.nan,
        pValue: double.nan,
        alpha: alpha,
      );
    }
    list.add(val);
  }

  final n = list.length;
  if (n < 3) {
    throw ArgumentError.value(
      n,
      'sample',
      'Shapiro-Wilk test requires at least 3 observations',
    );
  }
  if (n > 5000) {
    throw ArgumentError.value(
      n,
      'sample',
      'Shapiro-Wilk test is recommended for sample sizes up to 5000',
    );
  }

  list.sort();
  final meanVal = mean(list);
  var ssTot = 0.0;
  for (final x in list) {
    final diff = x - meanVal;
    ssTot += diff * diff;
  }

  if (ssTot == 0.0) {
    return HypothesisTestResult(
      testName: 'Shapiro-Wilk Normality Test',
      statistic: double.nan,
      pValue: double.nan,
      degreesOfFreedom: n.toDouble(),
      alpha: alpha,
    );
  }

  // Expected standard normal order statistics (Blom's approximation)
  const norm = NormalDistribution.standard();
  final m = List<double>.generate(n, (i) {
    final p = (i + 1 - 0.375) / (n + 0.25);
    return norm.inverseCumulativeProbability(p);
  });

  var mNormSq = 0.0;
  for (final val in m) {
    mNormSq += val * val;
  }
  final mNorm = sqrt(mNormSq);

  // Weights vector a
  final a = List<double>.filled(n, 0.0);
  if (n == 3) {
    a[0] = -1.0 / sqrt(2.0);
    a[1] = 0.0;
    a[2] = 1.0 / sqrt(2.0);
  } else {
    for (var i = 0; i < n; i++) {
      a[i] = m[i] / mNorm;
    }
  }

  // W test statistic
  var sumA = 0.0;
  for (var i = 0; i < n; i++) {
    sumA += a[i] * list[i];
  }
  final w = ((sumA * sumA) / ssTot).clamp(0.0, 1.0);

  // p-value calculation via Royston's normalizing transformation
  final double pValue;
  if (n == 3) {
    const piConst = pi;
    final pVal = (6.0 / piConst) * (asin(sqrt(w)) - asin(sqrt(0.75)));
    pValue = pVal.clamp(0.0, 1.0);
  } else {
    final y = log(1.0 - w);
    final logN = log(n.toDouble());
    final double mu;
    final double sigma;

    if (n <= 11) {
      mu = -2.273 + 0.459 * logN;
      sigma = exp(0.544 - 0.3997 * logN);
    } else {
      mu =
          -1.5861 -
          0.31082 * logN -
          0.083751 * logN * logN +
          0.0038915 * logN * logN * logN;
      sigma = exp(-0.4803 - 0.082676 * logN + 0.0030302 * logN * logN);
    }

    final z = (y - mu) / sigma;
    pValue = norm.survival(z).clamp(0.0, 1.0);
  }

  return HypothesisTestResult(
    testName: 'Shapiro-Wilk Normality Test',
    statistic: w,
    pValue: pValue,
    degreesOfFreedom: n.toDouble(),
    alpha: alpha,
  );
}
