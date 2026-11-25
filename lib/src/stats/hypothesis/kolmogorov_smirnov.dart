import 'dart:math' as math;
import 'dart:typed_data';

import '../../special/binomial.dart';
import '../../special/gamma.dart';
import '../distributions/continuous.dart';
import '../distributions/continuous/degenerate.dart';
import 'hypothesis_test_result.dart';
import 'utils.dart';

/// One-sample Kolmogorov-Smirnov test comparing [sample] against a theoretical
/// continuous [distribution].
///
/// Tests whether [sample] is drawn from [distribution] under the chosen
/// [alternative] hypothesis (`twoSided`: supremum `max(D+, D-)`, `greater`:
/// `D+ = max(F_n(x) - F(x))`, `less`: `D- = max(F(x) - F_n(x))`). Uses
/// exact probabilities for `n <= 100` and Kolmogorov-Smirnov asymptotics for
/// larger samples.
///
/// Throws [ArgumentError] if [sample] is empty, [distribution] is
/// [DegenerateDistribution], or [alpha] is outside `(0, 1)`. Returns `NaN`
/// statistic and p-value if any observation is `NaN`.
HypothesisTestResult kolmogorovSmirnovTest(
  Iterable<num> sample,
  ContinuousDistribution distribution, {
  AlternativeHypothesis alternative = AlternativeHypothesis.twoSided,
  double alpha = 0.05,
}) {
  validateAlpha(alpha);
  if (distribution is DegenerateDistribution) {
    throw ArgumentError.value(
      distribution,
      'distribution',
      'Kolmogorov-Smirnov test requires a continuous distribution',
    );
  }
  final list = <double>[];
  var hasNan = false;
  for (final val in sample) {
    final d = val.toDouble();
    if (d.isNaN) hasNan = true;
    list.add(d);
  }
  final n = list.length;
  if (n == 0) {
    throw ArgumentError('Sample cannot be empty');
  }
  if (hasNan) {
    return HypothesisTestResult(
      testName: 'One-Sample Kolmogorov-Smirnov Test',
      statistic: double.nan,
      pValue: double.nan,
      alpha: alpha,
      alternative: alternative,
    );
  }
  list.sort();

  var dPlus = 0.0;
  var dMinus = 0.0;
  for (var i = 0; i < n; i++) {
    final cdfVal = distribution.cumulativeProbability(list[i]);
    if (cdfVal.isNaN) {
      return HypothesisTestResult(
        testName: 'One-Sample Kolmogorov-Smirnov Test',
        statistic: double.nan,
        pValue: double.nan,
        alpha: alpha,
        alternative: alternative,
      );
    }
    final dp = (i + 1.0) / n - cdfVal;
    if (dp > dPlus) dPlus = dp;
    final dm = cdfVal - i.toDouble() / n;
    if (dm > dMinus) dMinus = dm;
  }

  final dStat = switch (alternative) {
    AlternativeHypothesis.twoSided => math.max(dPlus, dMinus),
    AlternativeHypothesis.greater => dPlus,
    AlternativeHypothesis.less => dMinus,
  };

  final double pValue;
  if (alternative == AlternativeHypothesis.twoSided) {
    pValue = n <= 100
        ? (1.0 - _kolmogorovExactCdf(dStat, n)).clamp(0.0, 1.0)
        : _kolmogorovAsymptoticPValue(dStat, n.toDouble());
  } else {
    pValue = n <= 100
        ? _smirnovOneSidedExactPValue(dStat, n)
        : _kolmogorovOneSidedAsymptoticPValue(dStat, n.toDouble());
  }

  return HypothesisTestResult(
    testName: 'One-Sample Kolmogorov-Smirnov Test',
    statistic: dStat,
    pValue: pValue,
    alpha: alpha,
    alternative: alternative,
  );
}

/// Two-sample Kolmogorov-Smirnov test comparing two empirical samples
/// [sample1] and [sample2].
///
/// Tests whether both samples come from the same continuous distribution under
/// the chosen [alternative] hypothesis (`twoSided`: `max(D+, D-)`, `greater`:
/// `max(F1(x) - F2(x))`, `less`: `max(F2(x) - F1(x))`). Computes exact
/// lattice-path p-values when neither sample has ties and `n1 * n2 <= 10000`,
/// falling back to the two-sample asymptotic approximation otherwise.
///
/// Throws [ArgumentError] if either sample is empty or [alpha] is outside
/// `(0, 1)`. Returns `NaN` statistic and p-value if any observation is `NaN`.
HypothesisTestResult kolmogorovSmirnovTwoSample(
  Iterable<num> sample1,
  Iterable<num> sample2, {
  AlternativeHypothesis alternative = AlternativeHypothesis.twoSided,
  double alpha = 0.05,
}) {
  validateAlpha(alpha);
  final list1 = <double>[];
  var hasNan = false;
  for (final val in sample1) {
    final d = val.toDouble();
    if (d.isNaN) hasNan = true;
    list1.add(d);
  }
  final list2 = <double>[];
  for (final val in sample2) {
    final d = val.toDouble();
    if (d.isNaN) hasNan = true;
    list2.add(d);
  }
  final n1 = list1.length;
  final n2 = list2.length;
  if (n1 == 0 || n2 == 0) {
    throw ArgumentError('Samples cannot be empty');
  }
  if (hasNan) {
    return HypothesisTestResult(
      testName: 'Two-Sample Kolmogorov-Smirnov Test',
      statistic: double.nan,
      pValue: double.nan,
      alpha: alpha,
      alternative: alternative,
    );
  }

  list1.sort();
  list2.sort();

  var i = 0;
  var j = 0;
  var dPlus = 0.0;
  var dMinus = 0.0;
  var hasTies = false;
  var prevVal = double.nan;

  while (i < n1 || j < n2) {
    final double x;
    if (i < n1 && j < n2) {
      x = math.min(list1[i], list2[j]);
    } else if (i < n1) {
      x = list1[i];
    } else {
      x = list2[j];
    }
    if (x == prevVal) hasTies = true;
    prevVal = x;

    var stepCount = 0;
    while (i < n1 && list1[i] <= x) {
      i++;
      stepCount++;
    }
    while (j < n2 && list2[j] <= x) {
      j++;
      stepCount++;
    }
    if (stepCount > 1) hasTies = true;

    final diff = (i / n1) - (j / n2);
    if (diff > dPlus) dPlus = diff;
    if (-diff > dMinus) dMinus = -diff;
  }

  final dStat = switch (alternative) {
    AlternativeHypothesis.twoSided => math.max(dPlus, dMinus),
    AlternativeHypothesis.greater => dPlus,
    AlternativeHypothesis.less => dMinus,
  };

  final double pValue;
  if (!hasTies && n1 * n2 <= 10000) {
    pValue = _twoSampleExactPValue(dStat, n1, n2, alternative);
  } else {
    final ne = (n1.toDouble() * n2) / (n1 + n2);
    pValue = alternative == AlternativeHypothesis.twoSided
        ? _kolmogorovAsymptoticPValue(dStat, ne)
        : _kolmogorovOneSidedAsymptoticPValue(dStat, ne);
  }

  return HypothesisTestResult(
    testName: 'Two-Sample Kolmogorov-Smirnov Test',
    statistic: dStat,
    pValue: pValue,
    alpha: alpha,
    alternative: alternative,
  );
}

double _kolmogorovAsymptoticPValue(double d, double n) {
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

double _kolmogorovOneSidedAsymptoticPValue(double d, double n) {
  if (d <= 0.0) return 1.0;
  final arg = 2.0 * n * d * d;
  if (arg >= 700.0) return 0.0;
  return math.exp(-arg).clamp(0.0, 1.0);
}

double _smirnovOneSidedExactPValue(double d, int n) {
  if (d <= 0.0) return 1.0;
  if (d >= 1.0) return 0.0;
  final maxJ = (n * (1.0 - d)).floor();
  final logD = math.log(d);
  var sum = 0.0;
  for (var j = 0; j <= maxJ; j++) {
    final p1 = 1.0 - d - j / n;
    final p2 = d + j / n;
    if (p1 <= 0.0) continue;
    final logTerm =
        logD +
        binomialLn(n, j) +
        (n - j) * math.log(p1) +
        (j - 1) * math.log(p2);
    if (logTerm > -745.0) {
      sum += math.exp(logTerm);
    }
  }
  return sum.clamp(0.0, 1.0);
}

/// Exact cumulative distribution function `P(D_n < d)` of the two-sided
/// one-sample Kolmogorov statistic using Marsaglia-Tsang-Wang (2003) /
/// Carvalho (2015) lower-Hessenberg transition recurrence.
double _kolmogorovExactCdf(double d, int n) {
  if (d <= 0.5 / n) return 0.0;
  if (d >= 1.0) return 1.0;

  final k = (n * d).ceil();
  final m = 2 * k - 1;
  final h = k.toDouble() - n * d;

  // Precompute reciprocal factorials 1 / r! via gammaLn to avoid overflow above 170!.
  final invFact = Float64List(m + 1);
  invFact[0] = 1.0;
  for (var r = 1; r <= m; r++) {
    invFact[r] = math.exp(-gammaLn(r + 1.0));
  }

  final hMat = Float64List(m * m);
  for (var i = 0; i < m; i++) {
    final rowOff = i * m;
    for (var j = 0; j <= math.min(i + 1, m - 1); j++) {
      hMat[rowOff + j] = invFact[i - j + 1];
    }
  }

  final hPowers = Float64List(m + 1);
  hPowers[0] = 1.0;
  for (var i = 1; i <= m; i++) {
    hPowers[i] = hPowers[i - 1] * h;
  }

  for (var i = 0; i < m; i++) {
    hMat[i * m] -= hPowers[i + 1] * invFact[i + 1];
    hMat[(m - 1) * m + i] -= hPowers[m - i] * invFact[m - i];
  }
  if (2.0 * h - 1.0 > 0.0) {
    hMat[(m - 1) * m] += math.pow(2.0 * h - 1.0, m.toDouble()) * invFact[m];
  }

  var v = Float64List(m);
  var vNext = Float64List(m);
  v[k - 1] = 1.0;
  for (var t = 1; t <= n; t++) {
    final scale = t / n;
    for (var j = 0; j < m; j++) {
      var s = 0.0;
      final startI = j > 0 ? j - 1 : 0;
      for (var i = startI; i < m; i++) {
        s += v[i] * hMat[i * m + j];
      }
      vNext[j] = s * scale;
    }
    final tmp = v;
    v = vNext;
    vNext = tmp;
  }

  return v[k - 1].clamp(0.0, 1.0);
}

double _twoSampleExactPValue(
  double dStat,
  int n1,
  int n2,
  AlternativeHypothesis alternative,
) {
  if (dStat <= 0.0) return 1.0;
  if (dStat >= 1.0) {
    final totalPaths = math.exp(binomialLn(n1 + n2, n1));
    if (alternative == AlternativeHypothesis.twoSided) {
      return (2.0 / totalPaths).clamp(0.0, 1.0);
    }
    return (1.0 / totalPaths).clamp(0.0, 1.0);
  }

  const tol = 1e-12;
  final thresh = dStat - tol;
  bool allowed(int i, int j) {
    final diff = (i / n1) - (j / n2);
    return switch (alternative) {
      AlternativeHypothesis.twoSided => diff.abs() < thresh,
      AlternativeHypothesis.greater => diff < thresh,
      AlternativeHypothesis.less => -diff < thresh,
    };
  }

  var dp = Float64List(n2 + 1);
  dp[0] = 1.0;
  for (var j = 1; j <= n2; j++) {
    if (!allowed(0, j)) break;
    dp[j] = dp[j - 1] * (n2 - j + 1) / (n1 + n2 - j + 1);
  }

  for (var i = 1; i <= n1; i++) {
    final next = Float64List(n2 + 1);
    for (var j = 0; j <= n2; j++) {
      if (!allowed(i, j)) continue;
      final rem = (n1 + n2 - i - j + 1).toDouble();
      var p = dp[j] * (n1 - i + 1) / rem;
      if (j > 0) {
        p += next[j - 1] * (n2 - j + 1) / rem;
      }
      next[j] = p;
    }
    dp = next;
  }

  return (1.0 - dp[n2]).clamp(0.0, 1.0);
}
