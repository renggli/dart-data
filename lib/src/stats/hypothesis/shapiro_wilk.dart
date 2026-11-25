import 'dart:math';

import 'package:more/math.dart' show PolynomialIterableExtension;

import '../distributions/continuous/normal.dart';
import 'hypothesis_test_result.dart';
import 'utils.dart';

/// Shapiro-Wilk test for sample normality.
///
/// Tests the null hypothesis that [sample] is drawn from a normally distributed
/// population using Royston's AS R94 algorithm for sample sizes `3 <= n <= 5000`.
///
/// Throws [ArgumentError] if `sample.length < 3`, `sample.length > 5000`, or
/// [alpha] is outside `(0, 1)`. Returns `NaN` statistic and p-value if any
/// observation is non-finite or all values are identical.
HypothesisTestResult shapiroWilkTest(
  Iterable<num> sample, {
  double alpha = 0.05,
}) {
  validateAlpha(alpha);
  final list = <double>[];
  var hasNonFinite = false;
  for (final x in sample) {
    final val = x.toDouble();
    if (!val.isFinite) hasNonFinite = true;
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
      'Shapiro-Wilk test supports sample sizes up to 5000',
    );
  }
  if (hasNonFinite) {
    return HypothesisTestResult(
      testName: 'Shapiro-Wilk Normality Test',
      statistic: double.nan,
      pValue: double.nan,
      alpha: alpha,
    );
  }

  list.sort();
  // Shift by list[0] for complete translation invariance in sum-of-squares.
  final shift = list[0];
  var shiftedMean = 0.0;
  for (var i = 0; i < n; i++) {
    shiftedMean += list[i] - shift;
  }
  shiftedMean /= n;
  var ssTot = 0.0;
  for (var i = 0; i < n; i++) {
    final diff = (list[i] - shift) - shiftedMean;
    ssTot += diff * diff;
  }

  if (ssTot == 0.0) {
    return HypothesisTestResult(
      testName: 'Shapiro-Wilk Normality Test',
      statistic: double.nan,
      pValue: double.nan,
      alpha: alpha,
    );
  }

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

  final a = List<double>.filled(n, 0.0);
  if (n == 3) {
    a[2] = 1.0 / sqrt(2.0);
    a[0] = -a[2];
  } else {
    final u = 1.0 / sqrt(n);
    final a1 = _c1.polynomial(u).toDouble() + m[n - 1] / mNorm;
    if (n > 5) {
      final a2 = _c2.polynomial(u).toDouble() + m[n - 2] / mNorm;
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

  // Symmetric pairing prevents offset cancellation in numerator sum.
  var sumA = 0.0;
  final half = n ~/ 2;
  for (var i = 0; i < half; i++) {
    sumA += a[n - 1 - i] * (list[n - 1 - i] - list[i]);
  }
  final rawW = (sumA * sumA) / ssTot;
  final w = (1.0 - rawW).abs() <= 1e-12 ? 1.0 : rawW.clamp(0.0, 1.0);

  final double pValue;
  if (w >= 1.0) {
    pValue = 1.0;
  } else if (n == 3) {
    final pVal = (6.0 / pi) * (asin(sqrt(w)) - asin(sqrt(0.75)));
    pValue = pVal.clamp(0.0, 1.0);
  } else if (n <= 11) {
    final gamma = _g[0] + _g[1] * n;
    final log1MinusW = log(1.0 - w);
    if (log1MinusW >= gamma) {
      pValue = 0.0;
    } else {
      final y = -log(gamma - log1MinusW);
      final mu = _c3.polynomial(n.toDouble()).toDouble();
      final sigma = exp(_c4.polynomial(n.toDouble()).toDouble());
      final z = (y - mu) / sigma;
      pValue = norm.survival(z).clamp(0.0, 1.0);
    }
  } else {
    final y = log(1.0 - w);
    final logN = log(n.toDouble());
    final mu = _c5.polynomial(logN).toDouble();
    final sigma = exp(_c6.polynomial(logN).toDouble());
    final z = (y - mu) / sigma;
    pValue = norm.survival(z).clamp(0.0, 1.0);
  }

  return HypothesisTestResult(
    testName: 'Shapiro-Wilk Normality Test',
    statistic: w,
    pValue: pValue,
    alpha: alpha,
  );
}

const _c1 = [0.0, 0.221157, -0.147981, -2.07119, 4.434685, -2.706056];
const _c2 = [0.0, 0.042981, -0.293762, -1.752461, 5.682633, -3.582633];
const _c3 = [0.544, -0.39978, 0.025054, -0.0006714];
const _c4 = [1.3822, -0.77857, 0.062767, -0.0020322];
const _c5 = [-1.5861, -0.31082, -0.083751, 0.0038915];
const _c6 = [-0.4803, -0.082676, 0.0030302];
const _g = [-2.273, 0.459];
