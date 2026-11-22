import 'dart:math';

import 'package:more/number.dart' show Complex;

import 'exp_integral.dart';
import 'utils.dart';

/// Returns an approximation of the gamma function `Γ(x)`.
///
/// Extends the factorial to non-integer values: `Γ(n) = (n - 1)!` for any
/// positive integer `n`. Calculated via the Euler integral of the second kind
/// `Γ(x) = ∫_0^∞ t^(x-1) * exp(-t) dt` for `x > 0`, extended analytically
/// across `R \ {0, -1, -2, ...}` via Euler reflection and Lanczos series.
///
/// See https://en.wikipedia.org/wiki/Gamma_function for details.
///
/// ```dart
/// final val = gamma(5); // 24.0
/// ```
double gamma(num x) {
  if (x.isNaN || x == double.negativeInfinity) return double.nan;
  if (x == double.infinity) return double.infinity;
  if (x < 0.5) {
    if (x.roundToDouble() == x) return double.nan;
    return pi / (sin(pi * x) * gamma(1 - x));
  }
  if (x > 100.0) return exp(gammaLn(x));

  final xAdj = x - 1.0;
  var y = lanczosCoeffs[0];
  for (var i = 1; i < lanczosCoeffs.length; i++) {
    y += lanczosCoeffs[i] / (xAdj + i);
  }
  final tVal = xAdj + lanczosG + 0.5;
  return sqrt(2.0 * pi) * pow(tVal, xAdj + 0.5) * exp(-tVal) * y;
}

/// Returns the complex gamma function `Γ(z)` via Lanczos approximation and
/// Euler reflection.
///
/// See https://en.wikipedia.org/wiki/Gamma_function for details.
Complex gammaComplex(Complex z) {
  if (z.isNaN) return Complex.nan;
  if (z.b == 0.0 && z.a <= 0.0 && z.a == z.a.roundToDouble()) {
    return Complex.nan;
  }
  if (z.a < 0.5) {
    final piZ = const Complex(pi) * z;
    return const Complex(pi) / (piZ.sin() * gammaComplex(Complex.one - z));
  }
  if (z.a > 100.0 || z.b.abs() > 100.0) {
    return gammaLnComplex(z).exp();
  }
  final zAdj = z - 1;
  var y = Complex(lanczosCoeffs[0]);
  for (var i = 1; i < lanczosCoeffs.length; i++) {
    y += Complex(lanczosCoeffs[i]) / (zAdj + i);
  }
  final tVal = zAdj + (lanczosG + 0.5);
  return tVal.pow(zAdj + 0.5) * (-tVal).exp() * y * sqrt(2.0 * pi);
}

/// Returns the natural logarithm of the gamma function `ln(Γ(x))`.
///
/// Evaluates `ln(Γ(x))` directly via Lanczos expansion to preserve numerical
/// precision and avoid floating-point overflow for large arguments.
///
/// See https://en.wikipedia.org/wiki/Gamma_function for details.
///
/// ```dart
/// final logVal = gammaLn(5); // ~ 3.17805383
/// ```
double gammaLn(num x) {
  if (x.isNaN) return double.nan;
  if (x == double.infinity) return double.infinity;
  if (x <= 0.0) return double.nan;
  var y = _lanczosLnCoeffs[0];
  for (var i = _lanczosLnCoeffs.length - 1; i > 0; --i) {
    y += _lanczosLnCoeffs[i] / (x + i);
  }
  final tVal = x + _lanczosLnG + 0.5;
  return _halfLog2Pi + (x + 0.5) * log(tVal) - tVal + log(y) - log(x);
}

/// Returns the complex log-gamma function `ln(Γ(z))` via Lanczos approximation
/// and Euler reflection.
///
/// See https://en.wikipedia.org/wiki/Gamma_function for details.
Complex gammaLnComplex(Complex z) {
  if (z.isNaN) return Complex.nan;
  if (z.b == 0.0 && z.a <= 0.0 && z.a == z.a.roundToDouble()) {
    return Complex.nan;
  }
  if (z.a < 0.5) {
    final sinPiZ = (const Complex(pi) * z).sin();
    return Complex(log(pi)) - sinPiZ.log() - gammaLnComplex(Complex.one - z);
  }
  var y = Complex(_lanczosLnCoeffs[0]);
  for (var i = _lanczosLnCoeffs.length - 1; i > 0; --i) {
    y += Complex(_lanczosLnCoeffs[i]) / (z + i);
  }
  final tVal = z + const Complex(_lanczosLnG + 0.5);
  return const Complex(_halfLog2Pi) +
      (z + const Complex(0.5)) * tVal.log() -
      tVal +
      y.log() -
      z.log();
}

/// Returns the upper regularized incomplete gamma function `Q(a, x) = 1 - P(a, x)`.
///
/// Defined as `Q(a, x) = Γ(a, x) / Γ(a)`.
///
/// See https://en.wikipedia.org/wiki/Incomplete_gamma_function for details.
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
  final ad = a.toDouble();
  final a1 = ad - 1.0;
  final gln = gammaLn(ad);
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
  return _gammaInvHalley(
    x,
    ad,
    a1,
    lna1,
    afac,
    gln,
    (curX) => gammaP(ad, curX) - probability,
  );
}

/// Returns the inverse of the upper regularized incomplete gamma function
/// `x = Q^-1(a, q)` such that `Q(a, x) = q`.
///
/// See https://en.wikipedia.org/wiki/Incomplete_gamma_function for details.
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
  final gln = gammaLn(ad);
  final a1 = ad - 1.0;
  final lna1 = log(a1 > 0 ? a1 : 1.0);
  final afac = exp(a1 * (lna1 - 1.0) - gln);

  var x = gammaPInv(1.0 - qd, ad);
  if (x <= 0.0 || !x.isFinite) {
    x = ad > 1.0 ? ad + sqrt(ad) : 1.0;
  }
  return _gammaInvHalley(
    x,
    ad,
    a1,
    lna1,
    afac,
    gln,
    (curX) => qd - gammaQ(ad, curX),
  );
}

/// Returns the lower regularized incomplete gamma function `P(a, x)`.
///
/// Defined as `P(a, x) = γ(a, x) / Γ(a)`.
///
/// See https://en.wikipedia.org/wiki/Incomplete_gamma_function for details.
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

/// Returns the upper incomplete gamma function `Γ(s, x) = ∫_x^∞ t^(s-1) * exp(-t) dt`.
///
/// See https://en.wikipedia.org/wiki/Incomplete_gamma_function for details.
double upperGamma(num s, num x) {
  if (s.isNaN || x.isNaN || x < 0.0) return double.nan;
  final sd = s.toDouble();
  final xd = x.toDouble();
  if (xd == double.infinity) return 0.0;
  if (xd == 0.0) return sd > 0.0 ? gamma(sd) : double.nan;
  if (sd > 0.0) {
    final q = gammaQ(sd, xd);
    if (sd > 150.0) {
      return q == 0.0 ? 0.0 : exp(gammaLn(sd) + log(q));
    }
    return gamma(sd) * q;
  }
  if (sd == 0.0) return -expIntegral(-xd);
  return (upperGamma(sd + 1.0, xd) - pow(xd, sd) * exp(-xd)) / sd;
}

/// Returns the complex upper incomplete gamma function `Γ(s, z) = ∫_z^∞ t^(s-1) * exp(-t) dt`.
///
/// See https://en.wikipedia.org/wiki/Incomplete_gamma_function for details.
Complex upperGammaComplex(Complex s, Complex z) {
  if (s.isNaN || z.isNaN) return Complex.nan;
  if (z == Complex.zero) return s.a > 0.0 ? gammaComplex(s) : Complex.nan;
  if (s == Complex.zero) return expIntegralE1Complex(z);
  if (z.abs() >= s.abs() + 1.0 && z.a > -z.b.abs()) {
    final h = lentzCFComplex(
      z + 1.0 - s,
      (k) => Complex(-k) * (Complex(k) - s),
      (k) => z + 1.0 - s + 2.0 * k,
    );
    return z.pow(s) * (-z).exp() * h;
  }
  if (s.b == 0.0 && s.a < 0.0 && s.a == s.a.roundToDouble()) {
    return (upperGammaComplex(s + Complex.one, z) - z.pow(s) * (-z).exp()) / s;
  }
  return gammaComplex(s) - lowerGammaComplex(s, z);
}

/// Returns the lower incomplete gamma function `γ(s, x) = ∫_0^x t^(s-1) * exp(-t) dt`.
///
/// See https://en.wikipedia.org/wiki/Incomplete_gamma_function for details.
double lowerGamma(num s, num x) {
  if (s.isNaN || x.isNaN || x < 0.0) return double.nan;
  final sd = s.toDouble();
  final xd = x.toDouble();
  if (xd == 0.0) return sd > 0.0 ? 0.0 : double.nan;
  if (xd == double.infinity) return sd > 0.0 ? gamma(sd) : double.nan;
  if (sd > 0.0) return gamma(sd) * gammaP(sd, xd);
  return gamma(sd) - upperGamma(sd, xd);
}

/// Returns the complex lower incomplete gamma function `γ(s, z) = ∫_0^z t^(s-1) * exp(-t) dt`.
///
/// See https://en.wikipedia.org/wiki/Incomplete_gamma_function for details.
Complex lowerGammaComplex(Complex s, Complex z) {
  if (s.isNaN || z.isNaN) return Complex.nan;
  if (z == Complex.zero) return s.a > 0.0 ? Complex.zero : Complex.nan;
  if (s.b == 0.0 && s.a <= 0.0 && s.a == s.a.roundToDouble()) {
    return Complex.nan;
  }
  if (z.abs() >= s.abs() + 1.0 && z.a > -z.b.abs()) {
    return gammaComplex(s) - upperGammaComplex(s, z);
  }
  var ap = s;
  var del = s.reciprocal();
  var sum = del;
  for (var n = 1; n <= 120; n++) {
    ap += 1;
    del *= z / ap;
    sum += del;
    if (del.abs() <= 1.0e-15 * sum.abs()) break;
  }
  return z.pow(s) * (-z).exp() * sum;
}

double _gammaInvHalley(
  double initialX,
  double a,
  double a1,
  double lna1,
  double afac,
  double gln,
  double Function(double x) signedError,
) {
  const epsilon = 1.0e-14;
  var x = initialX <= 0.0 || initialX.isNaN ? 1.0 : initialX;
  var xMin = 0.0;
  var xMax = double.infinity;
  for (var j = 0; j < 60; j++) {
    if (x <= xMin || x >= xMax) {
      x = xMax.isFinite ? 0.5 * (xMin + xMax) : (xMin > 0.0 ? xMin * 2.0 : 1.0);
    }
    final err = signedError(x);
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
    final denom = 1.0 - 0.5 * min(1.0, uVal * (a1 / x - 1.0));
    if (denom <= 0.0 || denom.isNaN) {
      x = xMax.isFinite ? 0.5 * (xMin + xMax) : (xMin > 0.0 ? xMin * 2.0 : 1.0);
      continue;
    }
    final nextX = x - uVal / denom;
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

/// `0.5 * ln(2 * pi)` for log-gamma Lanczos normalization.
const double _halfLog2Pi = 0.91893853320467274178;

/// High-precision Lanczos parameter `g = 607 / 128` for `gammaLn`.
const double _lanczosLnG = 607 / 128;

/// High-precision Lanczos coefficients for `g = 607 / 128` (15 terms).
const List<double> _lanczosLnCoeffs = [
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
