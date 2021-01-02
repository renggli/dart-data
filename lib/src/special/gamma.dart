import 'dart:math';

/// Returns an approximation of the gamma function, for details see
/// https://en.wikipedia.org/wiki/Gamma_function.
///
/// This uses a Lanczos approximation from
/// https://en.wikipedia.org/wiki/Lanczos_approximation.
double gamma(num x) {
  const g = 7;
  const p = [
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
    return exp(logGamma(x));
  } else {
    x -= 1.0;
    var y = p[0];
    for (var i = 1; i < g + 2; i++) {
      y += p[i] / (x + i);
    }
    final t = x + g + 0.5;
    return sqrt(2.0 * pi) * pow(t, x + 0.5) * exp(-t) * y;
  }
}

/// Returns the natural logarithm of the gamma function.
double logGamma(num x) {
  const g = 607 / 128;
  const p = [
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
  if (x <= 0) {
    return double.nan;
  }
  var y = p[0];
  for (var i = p.length - 1; i > 0; --i) {
    y += p[i] / (x + i);
  }
  final t = x + g + 0.5;
  return 0.5 * log(2.0 * pi) + (x + 0.5) * log(t) - t + log(y) - log(x);
}

/// Beta function based on the [gamma] function.
double beta(num x, num y) =>
    x <= 0 || y <= 0 ? double.nan : gamma(x) * gamma(y) / gamma(x + y);

/// Logarithm of the beta function based on the [logGamma] function.
double logBeta(num x, num y) =>
    x <= 0 || y <= 0 ? double.nan : logGamma(x) + logGamma(y) - logGamma(x + y);

/// Factorial based on the [gamma] function.
double factorial(num n) => n < 0 ? double.nan : gamma(n + 1.0);

/// Logarithm of the factorial based on the [logGamma] function.
double logFactorial(num n) => n < 0 ? double.nan : logGamma(n + 1.0);

/// Combinations based on the [gamma] function.
double combination(num n, num k) =>
    factorial(n) / factorial(k) / factorial(n - k);

/// Logarithm of the combinations based on the [logGamma] function.
double logCombination(num n, num k) =>
    logFactorial(n) - logFactorial(k) - logFactorial(n - k);
