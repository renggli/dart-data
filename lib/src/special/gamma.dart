import 'dart:math';

/// Returns an approximation of the gamma function.
///
/// See https://en.wikipedia.org/wiki/Gamma_function for details.
///
/// This uses a Lanczos approximation:
/// ```dart
/// print(gamma(5));  // 24.0
/// ```
double gamma(num x) {
  const lanczosG = 7;
  const lanczosCoeffs = [
    0.99999999999980993,
    676.5203681218851,
    -1259.1392167224028,
    771.32342877765313,
    -176.61502916214059,
    12.507343278686905,
    -0.13857109526572012,
    9.9843695780195716e-6,
    1.5056327351493116e-7,
  ];
  if (x < 0.5) {
    if (x.roundToDouble() == x) {
      return double.nan;
    } else {
      return pi / (sin(pi * x) * gamma(1 - x));
    }
  } else if (x > 100.0) {
    return exp(gammaLn(x));
  } else {
    final xAdj = x - 1.0;
    var y = lanczosCoeffs[0];
    for (var i = 1; i < lanczosG + 2; i++) {
      y += lanczosCoeffs[i] / (xAdj + i);
    }
    final tVal = xAdj + lanczosG + 0.5;
    return sqrt(2.0 * pi) * pow(tVal, xAdj + 0.5) * exp(-tVal) * y;
  }
}

/// Returns the natural logarithm of the gamma function.
double gammaLn(num x) {
  const lanczosG = 607 / 128;
  const lanczosCoeffs = [
    0.99999999999999709182,
    57.156235665862923517,
    -59.597960355475491248,
    14.136097974741747174,
    -0.49191381609762019978,
    0.33994649984811888699e-4,
    0.46523628927048575665e-4,
    -0.98374475304879564677e-4,
    0.15808870322491248884e-3,
    -0.21026444172410488319e-3,
    0.21743961811521264320e-3,
    -0.16431810653676389022e-3,
    0.84418223983852743293e-4,
    -0.26190838401581408670e-4,
    0.36899182659531622704e-5,
  ];
  if (x <= 0.0) {
    return double.nan;
  }
  var y = lanczosCoeffs[0];
  for (var i = lanczosCoeffs.length - 1; i > 0; --i) {
    y += lanczosCoeffs[i] / (x + i);
  }
  final tVal = x + lanczosG + 0.5;
  return 0.5 * log(2.0 * pi) + (x + 0.5) * log(tVal) - tVal + log(y) - log(x);
}

/// Returns the lower incomplete gamma function $\gamma(a, x)$.
double gammap(num a, num x) => lowRegGamma(a, x) * gamma(a);

/// Returns the inverse of the lower regularized incomplete gamma function.
double gammapInv(num probability, num a) {
  const epsilon = 1.0e-8;
  final a1 = a - 1.0;
  final gln = gammaLn(a);
  var x = 0.0;
  var afac = 0.0;
  var lna1 = 0.0;

  if (probability >= 1.0) {
    return max(100, a + 100 * sqrt(a));
  } else if (probability <= 0) {
    return 0.0;
  } else if (a > 1.0) {
    lna1 = log(a1);
    afac = exp(a1 * (lna1 - 1.0) - gln);
    final pp = probability < 0.5 ? probability : 1.0 - probability;
    final tVal = sqrt(-2 * log(pp));
    x =
        (2.30753 + tVal * 0.27061) / (1.0 + tVal * (0.99229 + tVal * 0.04481)) -
        tVal;
    if (probability < 0.5) {
      x = -x;
    }
    x = max(
      1.0e-3,
      a * pow(1.0 - 1.0 / (9.0 * a) - x / (3.0 * sqrt(a)), 3).toDouble(),
    );
  } else {
    final tVal = 1.0 - a * (0.253 + a * 0.12);
    if (probability < tVal) {
      x = pow(probability / tVal, 1.0 / a).toDouble();
    } else {
      x = 1.0 - log(1.0 - (probability - tVal) / (1.0 - tVal));
    }
  }
  for (var j = 0; j < 12; j++) {
    if (x <= 0.0) {
      return 0.0;
    }
    final err = lowRegGamma(a, x) - probability;
    var step = a > 1.0
        ? afac * exp(-(x - a1) + a1 * (log(x) - lna1))
        : exp(-x + a1 * log(x) - gln);
    final uVal = err / step;
    step = uVal / (1.0 - 0.5 * min(1.0, uVal * ((a - 1.0) / x - 1.0)));
    x -= step;
    if (x <= 0.0) {
      x = 0.5 * (x + step);
    }
    if (step.abs() < epsilon * x) {
      break;
    }
  }
  return x;
}

/// Returns the lower regularized incomplete gamma function $P(a, x)$.
double lowRegGamma(num a, num x) {
  if (x < 0 || a <= 0) {
    return double.nan;
  }
  final aln = gammaLn(a);
  var ap = a;
  var sum = 1.0 / a;
  var del = sum;
  var b = x + 1.0 - a;
  var cVal = 1.0 / 1.0e-30;
  var dVal = 1.0 / b;
  var hVal = dVal;
  final maxIter = (log(a >= 1 ? a : 1.0 / a) * 8.5 + a * 0.4 + 17).ceil();
  if (x < a + 1) {
    for (var i = 1; i <= maxIter; i++) {
      sum += del *= x / ++ap;
    }
    return sum * exp(-x + a * log(x) - aln);
  }
  for (var i = 1; i <= maxIter; i++) {
    final an = -i * (i - a);
    b += 2.0;
    dVal = an * dVal + b;
    if (dVal.abs() < 1.0e-30) dVal = 1.0e-30;
    cVal = b + an / cVal;
    if (cVal.abs() < 1.0e-30) cVal = 1.0e-30;
    dVal = 1.0 / dVal;
    final delStep = dVal * cVal;
    hVal *= delStep;
    if ((delStep - 1.0).abs() < 1.0e-15) {
      break;
    }
  }
  return 1.0 - hVal * exp(-x + a * log(x) - aln);
}

/// Returns the factorial based on the [gamma] function.
///
/// ```dart
/// print(factorial(5));  // 120.0
/// ```
double factorial(num value) => value < 0.0 ? double.nan : gamma(1.0 + value);

/// Returns the logarithm of the factorial based on the [gammaLn] function.
double factorialLn(num value) =>
    value < 0.0 ? double.nan : gammaLn(1.0 + value);

/// Returns the combinations based on the [gamma] function.
///
/// ```dart
/// print(combination(5, 2));  // 10.0
/// ```
double combination(num total, num choose) =>
    factorial(total) / factorial(choose) / factorial(total - choose);

/// Returns the logarithm of the combinations based on the [gammaLn] function.
double combinationLn(num total, num choose) =>
    factorialLn(total) - factorialLn(choose) - factorialLn(total - choose);

/// Returns the permutations based on the [gamma] function.
///
/// ```dart
/// print(permutation(5, 2));  // 20.0
/// ```
double permutation(num total, num count) =>
    factorial(total) / factorial(total - count);

/// Returns the logarithm of the permutations based on the [gammaLn] function.
double permutationLn(num total, num count) =>
    factorialLn(total) - factorialLn(total - count);
