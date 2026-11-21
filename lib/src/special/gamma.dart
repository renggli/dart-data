import 'dart:math';

import 'package:more/number.dart' show Complex;

import 'exp_integral.dart';

/// Returns an approximation of the gamma function $\Gamma(x)$.
///
/// Conceptually, the gamma function is a continuous extension of the factorial
/// function: $\Gamma(n) = (n - 1)!$ for any positive integer $n$ (for example,
/// $\Gamma(5) = 4! = 24$). Formally, this calculates the Euler integral of the
/// second kind $\Gamma(x) = \int_0^\infty t^{x-1} e^{-t} dt$ for $x > 0$,
/// extended analytically across $\mathbb{R} \setminus \{0, -1, -2, \dots\}$ via
/// reflection and Lanczos series.
///
/// See https://en.wikipedia.org/wiki/Gamma_function for details.
///
/// ```dart
/// final val = gamma(5); // 24.0
/// ```
double gamma(num x) {
  if (x.isNaN) return double.nan;
  if (x == double.infinity) return double.infinity;
  if (x == double.negativeInfinity) return double.nan;
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

/// Returns the complex gamma function $\Gamma(z)$ via Lanczos approximation
/// and Euler reflection.
Complex gammaComplex(Complex z) {
  if (z.a.isNaN || z.b.isNaN) return const Complex(double.nan, double.nan);
  if (z.b == 0.0 && z.a <= 0.0 && z.a == z.a.roundToDouble()) {
    return const Complex(double.nan, double.nan);
  }
  if (z.a < 0.5) {
    final piZ = const Complex(pi) * z;
    return const Complex(pi) / (piZ.sin() * gammaComplex(Complex.one - z));
  }
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
  final zAdj = z - Complex.one;
  var y = Complex(lanczosCoeffs[0]);
  for (var i = 1; i < lanczosG + 2; i++) {
    y += Complex(lanczosCoeffs[i]) / (zAdj + Complex(i));
  }
  final tVal = zAdj + const Complex(lanczosG + 0.5);
  return Complex(sqrt(2.0 * pi)) *
      tVal.pow(zAdj + const Complex(0.5)) *
      (-tVal).exp() *
      y;
}

/// Returns the natural logarithm of the gamma function $\ln \Gamma(x)$.
///
/// Conceptually, calculating $\ln(\Gamma(x))$ enables operations on very large
/// factorials and combinations without causing floating-point overflow.
/// Formally, this directly evaluates $\ln \Gamma(x)$ via Lanczos expansion,
/// preserving numerical precision and dynamic range.
///
/// ```dart
/// final logVal = gammaLn(5); // ~ 3.17805383
/// ```
double gammaLn(num x) {
  if (x.isNaN) return double.nan;
  if (x == double.infinity) return double.infinity;
  if (x <= 0.0) return double.nan;
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
  var y = lanczosCoeffs[0];
  for (var i = lanczosCoeffs.length - 1; i > 0; --i) {
    y += lanczosCoeffs[i] / (x + i);
  }
  final tVal = x + lanczosG + 0.5;
  return 0.5 * log(2.0 * pi) + (x + 0.5) * log(tVal) - tVal + log(y) - log(x);
}

/// Returns the complex log-gamma function $\ln \Gamma(z)$ via Lanczos
/// approximation and Euler reflection.
Complex gammaLnComplex(Complex z) {
  if (z.a.isNaN || z.b.isNaN) return const Complex(double.nan, double.nan);
  if (z.b == 0.0 && z.a <= 0.0 && z.a == z.a.roundToDouble()) {
    return const Complex(double.nan, double.nan);
  }
  if (z.a < 0.5) {
    final sinPiZ = (const Complex(pi) * z).sin();
    return Complex(log(pi)) - sinPiZ.log() - gammaLnComplex(Complex.one - z);
  }
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
  var y = Complex(lanczosCoeffs[0]);
  for (var i = lanczosCoeffs.length - 1; i > 0; --i) {
    y += Complex(lanczosCoeffs[i]) / (z + Complex(i));
  }
  final tVal = z + const Complex(lanczosG + 0.5);
  return Complex(0.5 * log(2.0 * pi)) +
      (z + const Complex(0.5)) * tVal.log() -
      tVal +
      y.log() -
      z.log();
}

/// Returns the upper regularized incomplete gamma function $Q(a, x) = 1 - P(a, x)$.
///
/// Follows standard numerical conventions (e.g. SciPy `gammaincc` and Numerical
/// Recipes $Q(a, x) = \frac{\Gamma(a, x)}{\Gamma(a)}$).
double gammaQ(num a, num x) {
  if (x.isNaN || a.isNaN || x < 0 || a <= 0) {
    return double.nan;
  }
  if (x == double.infinity) {
    return 0.0;
  }
  if (a == double.infinity) {
    return 1.0;
  }
  if (x == 0.0) {
    return 1.0;
  }
  final aln = gammaLn(a);
  if (x < a + 1.0) {
    return 1.0 - gammaP(a, x);
  }
  var b = x + 1.0 - a;
  var cVal = 1.0 / 1.0e-30;
  var dVal = 1.0 / b;
  var hVal = dVal;
  final sumAX = (a + x).toDouble();
  final maxIter = sumAX.isFinite
      ? max(200, min(100000, sumAX.ceil() * 2))
      : 200;
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
  return hVal * exp(-x + a * log(x) - aln);
}

/// Returns the inverse of the lower regularized incomplete gamma function.
double gammaPInv(num probability, num a) {
  if (probability.isNaN ||
      a.isNaN ||
      probability < 0.0 ||
      probability > 1.0 ||
      a <= 0.0 ||
      a.isInfinite) {
    return double.nan;
  }
  if (probability == 0.0) {
    return 0.0;
  }
  if (probability == 1.0) {
    return double.infinity;
  }
  const epsilon = 1.0e-14;
  final a1 = a - 1.0;
  final gln = gammaLn(a);
  var x = 0.0;
  var afac = 0.0;
  var lna1 = 0.0;

  if (a > 1.0) {
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
  var xMin = 0.0;
  var xMax = double.infinity;
  if (x <= 0.0 || x.isNaN) {
    x = 1.0;
  }
  for (var j = 0; j < 60; j++) {
    if (x <= xMin || x >= xMax) {
      x = xMax.isFinite ? 0.5 * (xMin + xMax) : (xMin > 0.0 ? xMin * 2.0 : 1.0);
    }
    final curProb = gammaP(a, x);
    final err = curProb - probability;
    if (err > 0) {
      if (x < xMax) xMax = x;
    } else {
      if (x > xMin) xMin = x;
    }
    if (err.abs() <= 1.0e-15 ||
        (xMax.isFinite && (xMax - xMin) <= epsilon * x)) {
      break;
    }
    final tVal = a > 1.0
        ? afac * exp(-(x - a1) + a1 * (log(x) - lna1))
        : exp(-x + a1 * log(x) - gln);
    if (tVal <= 0.0 || !tVal.isFinite) {
      x = xMax.isFinite ? 0.5 * (xMin + xMax) : (xMin > 0.0 ? xMin * 2.0 : 1.0);
      continue;
    }
    final uVal = err / tVal;
    final denom = 1.0 - 0.5 * min(1.0, uVal * ((a - 1.0) / x - 1.0));
    if (denom <= 0.0 || denom.isNaN) {
      x = xMax.isFinite ? 0.5 * (xMin + xMax) : (xMin > 0.0 ? xMin * 2.0 : 1.0);
      continue;
    }
    final step = uVal / denom;
    final nextX = x - step;
    if (nextX <= xMin || nextX >= xMax || nextX.isNaN) {
      x = xMax.isFinite ? 0.5 * (xMin + xMax) : (xMin > 0.0 ? xMin * 2.0 : 1.0);
    } else {
      final change = (x - nextX).abs();
      x = nextX;
      if (change < epsilon * x) {
        break;
      }
    }
  }
  return x;
}

/// Returns the inverse of the upper regularized incomplete gamma function
/// $x = Q^{-1}(a, q)$ such that $Q(a, x) = q$.
double gammaQInv(num probability, num a) {
  if (probability.isNaN ||
      a.isNaN ||
      probability < 0.0 ||
      probability > 1.0 ||
      a <= 0.0 ||
      a.isInfinite) {
    return double.nan;
  }
  if (probability == 0.0) {
    return double.infinity;
  }
  if (probability == 1.0) {
    return 0.0;
  }
  if (probability > 0.25) {
    return gammaPInv(1.0 - probability, a);
  }
  final ad = a.toDouble();
  final qd = probability.toDouble();
  const epsilon = 1.0e-14;
  final gln = gammaLn(ad);
  final a1 = ad - 1.0;
  final lna1 = log(a1 > 0 ? a1 : 1.0);
  final afac = exp(a1 * (lna1 - 1.0) - gln);

  var x = gammaPInv(1.0 - qd, ad);
  var xMin = 0.0;
  var xMax = double.infinity;
  if (x <= 0.0 || !x.isFinite) {
    x = ad > 1.0 ? ad + sqrt(ad) : 1.0;
  }
  for (var j = 0; j < 60; j++) {
    if (x <= xMin || x >= xMax) {
      x = xMax.isFinite ? 0.5 * (xMin + xMax) : (xMin > 0.0 ? xMin * 2.0 : 1.0);
    }
    final curQ = gammaQ(ad, x);
    final err = curQ - qd;
    if (err > 0) {
      if (x > xMin) xMin = x;
    } else {
      if (x < xMax) xMax = x;
    }
    if (err.abs() <= 1.0e-15 ||
        (xMax.isFinite && (xMax - xMin) <= epsilon * x)) {
      break;
    }
    final tVal = ad > 1.0
        ? afac * exp(-(x - a1) + a1 * (log(x) - lna1))
        : exp(-x + a1 * log(x) - gln);
    if (tVal <= 0.0 || !tVal.isFinite) {
      x = xMax.isFinite ? 0.5 * (xMin + xMax) : (xMin > 0.0 ? xMin * 2.0 : 1.0);
      continue;
    }
    final uVal = err / tVal;
    final denom = 1.0 + 0.5 * max(-1.0, uVal * ((ad - 1.0) / x - 1.0));
    if (denom <= 0.0 || denom.isNaN) {
      x = xMax.isFinite ? 0.5 * (xMin + xMax) : (xMin > 0.0 ? xMin * 2.0 : 1.0);
      continue;
    }
    final step = uVal / denom;
    final nextX = x + step;
    if (nextX <= xMin || nextX >= xMax || nextX.isNaN) {
      x = xMax.isFinite ? 0.5 * (xMin + xMax) : (xMin > 0.0 ? xMin * 2.0 : 1.0);
    } else {
      final change = (x - nextX).abs();
      x = nextX;
      if (change < epsilon * x) {
        break;
      }
    }
  }
  return x;
}

/// Returns the lower regularized incomplete gamma function $P(a, x)$.
///
/// Follows standard numerical conventions (e.g. SciPy `gammainc` and Numerical
/// Recipes $P(a, x) = \frac{\gamma(a, x)}{\Gamma(a)}$).
double gammaP(num a, num x) {
  if (x.isNaN || a.isNaN || x < 0 || a <= 0) {
    return double.nan;
  }
  if (x == double.infinity) {
    return 1.0;
  }
  if (a == double.infinity) {
    return 0.0;
  }
  if (x == 0.0) {
    return 0.0;
  }
  if (x >= a + 1.0) {
    return 1.0 - gammaQ(a, x);
  }
  final aln = gammaLn(a);
  var ap = a;
  var sum = 1.0 / a;
  var del = sum;
  final sumAX = (a + x).toDouble();
  final maxIter = sumAX.isFinite
      ? max(200, min(100000, sumAX.ceil() * 2))
      : 200;
  for (var i = 1; i <= maxIter; i++) {
    del *= x / ++ap;
    sum += del;
    if (del.abs() < sum.abs() * 1.0e-15) {
      break;
    }
  }
  return sum * exp(-x + a * log(x) - aln);
}

/// Returns the factorial based on the [gamma] function.
///
/// ```dart
/// print(factorial(5));  // 120.0
/// ```
double factorial(num value) =>
    value.isNaN || value < 0.0 ? double.nan : gamma(1.0 + value);

/// Returns the complex factorial $z! = \Gamma(z + 1)$.
Complex factorialComplex(Complex z) => gammaComplex(z + Complex.one);

/// Returns the logarithm of the factorial based on the [gammaLn] function.
double factorialLn(num value) =>
    value.isNaN || value < 0.0 ? double.nan : gammaLn(1.0 + value);

/// Returns the combinations based on the [gamma] function.
///
/// ```dart
/// print(binomial(5, 2));  // 10.0
/// ```
double binomial(num total, num choose) {
  if (total.isNaN || choose.isNaN) {
    return double.nan;
  }
  if (choose < 0 || choose > total) {
    return 0.0;
  }
  if (choose == 0) {
    return 1.0;
  }
  if (total.isInfinite) {
    if (choose.isInfinite || choose.floorToDouble() != choose) {
      return double.nan;
    }
    return double.infinity;
  }
  if (choose == total) {
    return 1.0;
  }
  var k = choose;
  if (k > total - k) {
    k = total - k;
  }
  final isTotalInt = total.isFinite && total.roundToDouble() == total;
  final isChooseInt = k.isFinite && k.roundToDouble() == k;
  if (isTotalInt && isChooseInt && k <= 1000) {
    final totalInt = total.toInt();
    final kInt = k.toInt();
    const maxSafe = 9007199254740991; // 2^53 - 1, exact across VM and Web
    var res = 1;
    var canUseInt = true;
    for (var i = 1; i <= kInt; i++) {
      final term = totalInt - i + 1;
      final g = term.gcd(i);
      final numPart = term ~/ g;
      final denPart = i ~/ g;
      res = res ~/ denPart;
      if (res > maxSafe ~/ numPart) {
        canUseInt = false;
        break;
      }
      res *= numPart;
    }
    if (canUseInt) {
      return res.toDouble();
    }
    var bigRes = BigInt.one;
    final totalBig = BigInt.from(total);
    for (var i = 1; i <= kInt; i++) {
      bigRes = (bigRes * (totalBig - BigInt.from(kInt - i))) ~/ BigInt.from(i);
    }
    return bigRes.toDouble();
  }
  return exp(binomialLn(total, choose));
}

/// Returns the complex binomial coefficient $\binom{n}{k} = \frac{\Gamma(n + 1)}{\Gamma(k + 1)\Gamma(n - k + 1)}$.
Complex binomialComplex(Complex n, Complex k) {
  if (n.a.isNaN || n.b.isNaN || k.a.isNaN || k.b.isNaN) {
    return const Complex(double.nan, double.nan);
  }
  if (k == Complex.zero) return Complex.one;
  if (k.b == 0.0 && k.a == k.a.roundToDouble()) {
    final kInt = k.a.toInt();
    if (kInt < 0) return Complex.zero;
    if (kInt <= 20) {
      var res = Complex.one;
      for (var i = 0; i < kInt; i++) {
        res = res * (n - Complex(i)) / Complex(i + 1);
      }
      return res;
    }
  }
  return (gammaLnComplex(n + Complex.one) -
          gammaLnComplex(k + Complex.one) -
          gammaLnComplex(n - k + Complex.one))
      .exp();
}

/// Returns the logarithm of the combinations based on the [gammaLn] function.
double binomialLn(num total, num choose) =>
    factorialLn(total) - factorialLn(choose) - factorialLn(total - choose);

/// Returns the permutations based on the [gamma] function.
///
/// ```dart
/// print(permutation(5, 2));  // 20.0
/// ```
double permutation(num total, num count) {
  if (total.isNaN || count.isNaN) {
    return double.nan;
  }
  if (count < 0 || count > total) {
    return 0.0;
  }
  if (count == 0) {
    return 1.0;
  }
  if (total.isInfinite) {
    return count.isInfinite ? double.nan : double.infinity;
  }
  final isTotalInt = total.isFinite && total.roundToDouble() == total;
  final isCountInt = count.isFinite && count.roundToDouble() == count;
  if (isTotalInt && isCountInt && count <= 1000) {
    final totalInt = total.toInt();
    final countInt = count.toInt();
    const maxSafe = 9007199254740991; // 2^53 - 1, exact across VM and Web
    var res = 1;
    var canUseInt = true;
    for (var i = 0; i < countInt; i++) {
      final term = totalInt - i;
      if (res > maxSafe ~/ term) {
        canUseInt = false;
        break;
      }
      res *= term;
    }
    if (canUseInt) {
      return res.toDouble();
    }
    var bigRes = BigInt.one;
    final totalBig = BigInt.from(total);
    for (var i = 0; i < countInt; i++) {
      bigRes *= totalBig - BigInt.from(i);
    }
    return bigRes.toDouble();
  }
  return exp(permutationLn(total, count));
}

/// Returns the logarithm of the permutations based on the [gammaLn] function.
double permutationLn(num total, num count) =>
    factorialLn(total) - factorialLn(total - count);

/// Returns the upper incomplete gamma function $\Gamma(s, x) = \int_x^\infty t^{s-1} e^{-t}\,dt$.
double upperGamma(num s, num x) {
  if (s.isNaN || x.isNaN || x < 0.0) return double.nan;
  final sd = s.toDouble();
  final xd = x.toDouble();
  if (xd == double.infinity) return 0.0;
  if (xd == 0.0) return sd > 0.0 ? gamma(sd) : double.nan;
  if (sd > 0.0) return gamma(sd) * gammaQ(sd, xd);
  if (sd == 0.0) return -expIntegral(-xd);
  return (upperGamma(sd + 1.0, xd) - pow(xd, sd) * exp(-xd)) / sd;
}

/// Returns the complex upper incomplete gamma function $\Gamma(s, z) = \int_z^\infty t^{s-1} e^{-t}\,dt$.
Complex upperGammaComplex(Complex s, Complex z) {
  if (s.a.isNaN || s.b.isNaN || z.a.isNaN || z.b.isNaN) {
    return const Complex(double.nan, double.nan);
  }
  if (z.a == 0.0 && z.b == 0.0) {
    return s.a > 0.0 ? gammaComplex(s) : const Complex(double.nan, double.nan);
  }
  if (z.abs() >= s.abs() + 1.0 && z.a > -z.b.abs()) {
    const tiny = 1.0e-30;
    var b = z + Complex.one - s;
    var c = const Complex(1.0 / tiny);
    var d = b.abs() < tiny ? const Complex(1.0 / tiny) : Complex.one / b;
    var h = d;
    for (var k = 1; k <= 200; k++) {
      final a = Complex(-k) * (Complex(k) - s);
      b += const Complex(2.0);
      d = a * d + b;
      if (d.abs() < tiny) d = const Complex(tiny);
      c = b + a / c;
      if (c.abs() < tiny) c = const Complex(tiny);
      d = Complex.one / d;
      final delta = d * c;
      h *= delta;
      if ((delta - Complex.one).abs() < 1.0e-15) break;
    }
    return z.pow(s) * (-z).exp() * h;
  }
  return gammaComplex(s) - lowerGammaComplex(s, z);
}

/// Returns the lower incomplete gamma function $\gamma(s, x) = \int_0^x t^{s-1} e^{-t}\,dt$.
double lowerGamma(num s, num x) {
  if (s.isNaN || x.isNaN || x < 0.0) return double.nan;
  final sd = s.toDouble();
  final xd = x.toDouble();
  if (xd == 0.0) return sd > 0.0 ? 0.0 : double.nan;
  if (xd == double.infinity) return sd > 0.0 ? gamma(sd) : double.nan;
  if (sd > 0.0) return gamma(sd) * gammaP(sd, xd);
  return gamma(sd) - upperGamma(sd, xd);
}

/// Returns the complex lower incomplete gamma function $\gamma(s, z) = \int_0^z t^{s-1} e^{-t}\,dt$.
Complex lowerGammaComplex(Complex s, Complex z) {
  if (s.a.isNaN || s.b.isNaN || z.a.isNaN || z.b.isNaN) {
    return const Complex(double.nan, double.nan);
  }
  if (z.a == 0.0 && z.b == 0.0) {
    return s.a > 0.0 ? Complex.zero : const Complex(double.nan, double.nan);
  }
  if (s.b == 0.0 && s.a <= 0.0 && s.a == s.a.roundToDouble()) {
    return const Complex(double.nan, double.nan);
  }
  if (z.abs() >= s.abs() + 1.0 && z.a > -z.b.abs()) {
    return gammaComplex(s) - upperGammaComplex(s, z);
  }
  var ap = s;
  var del = Complex.one / s;
  var sum = del;
  for (var n = 1; n <= 120; n++) {
    ap += Complex.one;
    del *= z / ap;
    sum += del;
    if (del.abs() <= 1.0e-15 * sum.abs()) break;
  }
  return z.pow(s) * (-z).exp() * sum;
}
