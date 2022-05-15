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
    return exp(gammaLn(x));
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
double gammaLn(num x) {
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
  if (x <= 0.0) {
    return double.nan;
  }
  var y = p[0];
  for (var i = p.length - 1; i > 0; --i) {
    y += p[i] / (x + i);
  }
  final t = x + g + 0.5;
  return 0.5 * log(2.0 * pi) + (x + 0.5) * log(t) - t + log(y) - log(x);
}

// Returns the lower incomplete gamma function.
double gammap(num a, num x) => lowRegGamma(a, x) * gamma(a);

// Returns the inverse of the lower regularized incomplete gamma function.
double gammapInv(num p, num a) {
  final a1 = a - 1.0;
  final epsilon = 1.0e-8;
  var gln = gammaLn(a);
  var x = 0.0;
  var afac = 0.0;
  var lna1 = 0.0;

  if (p >= 1.0) {
    return max(100, a + 100 * sqrt(a));
  } else if (p <= 0) {
    return 0.0;
  } else if (a > 1.0) {
    lna1 = log(a1);
    afac = exp(a1 * (lna1 - 1) - gln);
    final pp = p < 0.5 ? p : 1 - p;
    final t = sqrt(-2 * log(pp));
    x = (2.30753 + t * 0.27061) / (1.0 + t * (0.99229 + t * 0.04481)) - t;
    if (p < 0.5) {
      x = -x;
    }
    x = max(1.0e-3,
        a * pow(1.0 - 1.0 / (9.0 * a) - x / (3.0 * sqrt(a)), 3.0).toDouble());
  } else {
    final t = 1.0 - a * (0.253 + a * 0.12);
    if (p < t) {
      x = pow(p / t, 1.0 / a).toDouble();
    } else {
      x = 1.0 - log(1 - (p - t) / (1 - t));
    }
  }
  for (var j = 0; j < 12; j++) {
    if (x <= 0.0) {
      return 0.0;
    }
    final err = lowRegGamma(a, x) - p;
    var t = a > 1.0
        ? afac * exp(-(x - a1) + a1 * (log(x) - lna1))
        : exp(-x + a1 * log(x) - gln);
    final u = err / t;
    x -= (t = u / (1.0 - 0.5 * min(1.0, u * ((a - 1.0) / x - 1.0))));
    if (x <= 0.0) {
      x = 0.5 * (x + t);
    }
    if (t.abs() < epsilon * x) {
      break;
    }
  }
  return x;
}

// Returns the lower regularized incomplete gamma function.
double lowRegGamma(num a, num x) {
  var aln = gammaLn(a);
  var ap = a;
  var sum = 1.0 / a;
  var del = sum;
  var b = x + 1 - a;
  var c = 1 / 1.0e-30;
  var d = 1 / b;
  var h = d;
  final itmax = (log(a >= 1 ? a : 1 / a) * 8.5 + a * 0.4 + 17).ceil();
  if (x < 0 || a <= 0) {
    return double.nan;
  } else if (x < a + 1) {
    for (var i = 1; i <= itmax; i++) {
      sum += del *= x / ++ap;
    }
    return sum * exp(-x + a * log(x) - aln);
  }
  for (var i = 1; i <= itmax; i++) {
    final an = -i * (i - a);
    b += 2;
    d = an * d + b;
    c = b + an / c;
    d = 1 / d;
    h *= d * c;
  }
  return 1.0 - h * exp(-x + a * log(x) - (aln));
}

/// Returns the factorial based on the [gamma] function.
double factorial(num n) => n < 0.0 ? double.nan : gamma(1.0 + n);

/// Returns the logarithm of the factorial based on the [gammaLn] function.
double factorialLn(num n) => n < 0.0 ? double.nan : gammaLn(1.0 + n);

/// Returns the combinations based on the [gamma] function.
double combination(num n, num k) =>
    factorial(n) / factorial(k) / factorial(n - k);

/// Returns the logarithm of the combinations based on the [gammaLn] function.
double combinationLn(num n, num k) =>
    factorialLn(n) - factorialLn(k) - factorialLn(n - k);

/// Returns the permutations based on the [gamma] function.
double permutation(num n, num m) => factorial(n) / factorial(n - m);

/// Returns the logarithm of the permutations based on the [gammaLn] function.
double permutationLn(num n, num m) => factorialLn(n) - factorialLn(n - m);
