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
    final u = 1.0 / sqrt(n);
    final a1 = _poly(_c1, u) + m[n - 1] / mNorm;
    if (n > 5) {
      final a2 = _poly(_c2, u) + m[n - 2] / mNorm;
      final fac = sqrt(
        (mNormSq - 2.0 * m[n - 1] * m[n - 1] - 2.0 * m[n - 2] * m[n - 2]) /
            (1.0 - 2.0 * a1 * a1 - 2.0 * a2 * a2),
      );
      a[n - 1] = a1;
      a[0] = -a1;
      a[n - 2] = a2;
      a[1] = -a2;
      for (var i = 2; i < n ~/ 2; i++) {
        final val = m[n - 1 - i] / fac;
        a[n - 1 - i] = val;
        a[i] = -val;
      }
    } else {
      final fac = sqrt(
        (mNormSq - 2.0 * m[n - 1] * m[n - 1]) / (1.0 - 2.0 * a1 * a1),
      );
      a[n - 1] = a1;
      a[0] = -a1;
      for (var i = 1; i < n ~/ 2; i++) {
        final val = m[n - 1 - i] / fac;
        a[n - 1 - i] = val;
        a[i] = -val;
      }
    }
  }

  // W test statistic
  var sumA = 0.0;
  for (var i = 0; i < n; i++) {
    sumA += a[i] * list[i];
  }
  final rawW = (sumA * sumA) / ssTot;
  final w = (1.0 - rawW).abs() <= 1e-12 ? 1.0 : rawW.clamp(0.0, 1.0);

  // p-value calculation via Royston's normalizing transformation
  final double pValue;
  if (n == 3) {
    if (w >= 1.0) {
      pValue = 1.0;
    } else {
      final pVal = (6.0 / pi) * (asin(sqrt(w)) - asin(sqrt(0.75)));
      pValue = pVal.clamp(0.0, 1.0);
    }
  } else if (w >= 1.0) {
    pValue = 1.0;
  } else if (n <= 11) {
    final gamma = _g[0] + _g[1] * n;
    final log1MinusW = log(1.0 - w);
    if (log1MinusW >= gamma) {
      pValue = 0.0;
    } else {
      final y = -log(gamma - log1MinusW);
      final mu = _poly(_c3, n.toDouble());
      final sigma = exp(_poly(_c4, n.toDouble()));
      final z = (y - mu) / sigma;
      pValue = norm.survival(z).clamp(0.0, 1.0);
    }
  } else {
    final y = log(1.0 - w);
    final logN = log(n.toDouble());
    final mu = _poly(_c5, logN);
    final sigma = exp(_poly(_c6, logN));
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

double _poly(List<double> cc, double x) {
  var p = x * cc.last;
  for (var i = cc.length - 2; i >= 1; i--) {
    p = (p + cc[i]) * x;
  }
  return cc[0] + p;
}

const _c1 = [0.0, 0.221157, -0.147981, -2.07119, 4.434685, -2.706056];
const _c2 = [0.0, 0.042981, -0.293762, -1.752461, 5.682633, -3.582633];
const _c3 = [0.544, -0.39978, 0.025054, -0.0006714];
const _c4 = [1.3822, -0.77857, 0.062767, -0.0020322];
const _c5 = [-1.5861, -0.31082, -0.083751, 0.0038915];
const _c6 = [-0.4803, -0.082676, 0.0030302];
const _g = [-2.273, 0.459];
