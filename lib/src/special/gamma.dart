import 'dart:math';

import 'package:more/number.dart' show Complex;

import 'exp_integral.dart';
import 'utils.dart';

/// Returns the gamma function `Γ(x)`.
///
/// Extends the factorial to non-integer values: `Γ(n) = (n - 1)!` for any
/// positive integer `n`. Calculated via exact lookup for integers `1..23`,
/// the 15-term Lanczos approximation for `x >= 0.5`, and Euler's reflection
/// formula `Γ(x) * Γ(1 - x) = π / sin(π * x)` for `x < 0.5`.
///
/// Defined for all real `x` except non-positive integers (`0, -1, -2, ...`),
/// where it returns `double.nan`. Returns `double.infinity` for `x = +∞` or
/// `x > 171.63`, and `double.nan` for `x = -∞` or `double.nan`.
///
/// See https://en.wikipedia.org/wiki/Gamma_function for details.
///
/// ```dart
/// final val = gamma(5); // 24.0
/// ```
double gamma(num x) {
  if (x.isNaN || x == double.negativeInfinity) return double.nan;
  if (x == double.infinity) return double.infinity;
  final xd = x.toDouble();
  if (xd < 0.5) {
    final r = xd - 2.0 * (xd / 2.0).roundToDouble();
    if (r == 0.0 || r.abs() == 1.0) return double.nan;
    final sinVal = sin(pi * r);
    if (xd < -100.0) {
      final sign = sinVal > 0.0 ? 1.0 : -1.0;
      final logMag = log(pi) - log(sinVal.abs()) - gammaLn(1.0 - xd);
      return sign * exp(logMag);
    }
    return pi / (sinVal * gamma(1.0 - xd));
  }
  if (xd <= 23.0 && xd.roundToDouble() == xd) {
    return _smallFactorials[xd.toInt() - 1];
  }
  if (xd > 171.63) return double.infinity;

  var y = _lanczosCoeffs[0];
  for (var i = _lanczosCoeffs.length - 1; i > 0; --i) {
    y += _lanczosCoeffs[i] / (xd + i);
  }
  final tVal = xd + _lanczosG + 0.5;
  if (xd > 140.0) {
    final halfPow = pow(tVal, 0.5 * (xd + 0.5)).toDouble();
    return (halfPow * exp(-tVal)) * (_sqrt2Pi * y / xd) * halfPow;
  }
  return _sqrt2Pi * pow(tVal, xd + 0.5) * exp(-tVal) * y / xd;
}

/// Returns the complex gamma function `Γ(z)` via 15-term Lanczos approximation
/// and Euler reflection.
///
/// Returns `Complex.nan` at non-positive integers or when either component is
/// `NaN` or non-finite (except `+∞ + 0i`, which returns `+∞`).
///
/// See https://en.wikipedia.org/wiki/Gamma_function for details.
Complex gammaComplex(Complex z) {
  if (z.isNaN) return Complex.nan;
  if (z.b == 0.0) return Complex(gamma(z.a.toDouble()));
  if (!z.a.isFinite || !z.b.isFinite) return Complex.nan;
  if (z.a < 0.5) {
    if (z.a < -100.0 || z.b.abs() > 100.0) {
      return gammaLnComplex(z).exp();
    }
    final r = z.a - 2.0 * (z.a / 2.0).roundToDouble();
    final piZ = Complex(pi * r, pi * z.b);
    return const Complex(pi) / (piZ.sin() * gammaComplex(Complex.one - z));
  }
  if (z.a > 100.0 || z.b.abs() > 100.0) {
    return gammaLnComplex(z).exp();
  }
  var y = Complex(_lanczosCoeffs[0]);
  for (var i = _lanczosCoeffs.length - 1; i > 0; --i) {
    y += Complex(_lanczosCoeffs[i]) / (z + i.toDouble());
  }
  final tVal = z + const Complex(_lanczosG + 0.5);
  return const Complex(_sqrt2Pi) *
      tVal.pow(z + const Complex(0.5)) *
      (-tVal).exp() *
      y /
      z;
}

/// Returns the natural logarithm of the gamma function `ln(Γ(x))` for `x > 0`.
///
/// Evaluates `ln(Γ(x))` directly via 15-term Lanczos expansion to preserve
/// numerical precision and avoid floating-point overflow for large arguments.
/// Returns `double.nan` for `x <= 0` or `NaN`, and `double.infinity` for `+∞`.
///
/// See https://en.wikipedia.org/wiki/Gamma_function for details.
///
/// ```dart
/// final logVal = gammaLn(5); // ~ 3.17805383
/// ```
double gammaLn(num x) {
  if (x.isNaN) return double.nan;
  if (x == double.infinity) return double.infinity;
  final xd = x.toDouble();
  if (xd <= 0.0) return double.nan;
  if (xd == 1.0 || xd == 2.0) return 0.0;
  var y = _lanczosCoeffs[0];
  for (var i = _lanczosCoeffs.length - 1; i > 0; --i) {
    y += _lanczosCoeffs[i] / (xd + i);
  }
  final tVal = xd + _lanczosG + 0.5;
  return _halfLog2Pi + (xd + 0.5) * log(tVal) - tVal + log(y) - log(xd);
}

/// Returns the complex log-gamma function `ln(Γ(z))` via 15-term Lanczos
/// approximation and overflow-free Euler reflection.
///
/// See https://en.wikipedia.org/wiki/Gamma_function for details.
Complex gammaLnComplex(Complex z) {
  if (z.isNaN) return Complex.nan;
  if (z.b == 0.0 && z.a == double.infinity) {
    return const Complex(double.infinity);
  }
  if (!z.a.isFinite || !z.b.isFinite) return Complex.nan;
  if (z.b == 0.0 && z.a <= 0.0 && z.a == z.a.roundToDouble()) {
    return Complex.nan;
  }
  if (z.a < 0.5) {
    return const Complex(_lnPi) -
        logSinPiComplex(z) -
        gammaLnComplex(Complex.one - z);
  }
  var y = Complex(_lanczosCoeffs[0]);
  for (var i = _lanczosCoeffs.length - 1; i > 0; --i) {
    y += Complex(_lanczosCoeffs[i]) / (z + i.toDouble());
  }
  final tVal = z + const Complex(_lanczosG + 0.5);
  return const Complex(_halfLog2Pi) +
      (z + const Complex(0.5)) * tVal.log() -
      tVal +
      y.log() -
      z.log();
}

/// Returns the lower regularized incomplete gamma function
/// `P(a, x) = γ(a, x) / Γ(a)`.
///
/// Defined for `a > 0` and `x >= 0`. Returns `double.nan` when `a <= 0`,
/// `x < 0`, either argument is `NaN`, or both `a` and `x` are infinite.
///
/// See https://en.wikipedia.org/wiki/Incomplete_gamma_function for details.
double gammaP(num a, num x) {
  if (x.isNaN || a.isNaN || x < 0 || a <= 0) {
    return double.nan;
  }
  if (a.isInfinite && x.isInfinite) {
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
  final ad = a.toDouble();
  final xd = x.toDouble();
  final aln = gammaLn(ad);
  var ap = ad;
  var sum = 1.0 / ad;
  var del = sum;
  final sumAX = ad + xd;
  final maxIter = sumAX.isFinite
      ? max(200, min(100000, sumAX.ceil() * 2))
      : 200;
  for (var i = 1; i <= maxIter; i++) {
    del *= xd / ++ap;
    sum += del;
    if (del.abs() < sum.abs() * 1.0e-15) {
      break;
    }
  }
  return sum * exp(-xd + ad * log(xd) - aln);
}

/// Returns the upper regularized incomplete gamma function
/// `Q(a, x) = 1 - P(a, x) = Γ(a, x) / Γ(a)`.
///
/// Defined for `a > 0` and `x >= 0`. Returns `double.nan` when `a <= 0`,
/// `x < 0`, either argument is `NaN`, or both `a` and `x` are infinite.
///
/// See https://en.wikipedia.org/wiki/Incomplete_gamma_function for details.
double gammaQ(num a, num x) {
  if (x.isNaN || a.isNaN || x < 0 || a <= 0) {
    return double.nan;
  }
  if (a.isInfinite && x.isInfinite) {
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
  final ad = a.toDouble();
  final xd = x.toDouble();
  if (xd < ad + 1.0) {
    return 1.0 - gammaP(ad, xd);
  }
  final aln = gammaLn(ad);
  var b = xd + 1.0 - ad;
  var cVal = 1.0 / tinyDouble;
  var dVal = b.abs() < tinyDouble ? 1.0 / tinyDouble : 1.0 / b;
  var hVal = dVal;
  final sumAX = ad + xd;
  final maxIter = sumAX.isFinite
      ? max(200, min(100000, sumAX.ceil() * 2))
      : 200;
  for (var i = 1; i <= maxIter; i++) {
    final an = -i * (i - ad);
    b += 2.0;
    dVal = an * dVal + b;
    if (dVal.abs() < tinyDouble) dVal = tinyDouble;
    cVal = b + an / cVal;
    if (cVal.abs() < tinyDouble) cVal = tinyDouble;
    dVal = 1.0 / dVal;
    final delStep = dVal * cVal;
    hVal *= delStep;
    if ((delStep - 1.0).abs() < 1.0e-15) {
      break;
    }
  }
  return hVal * exp(-xd + ad * log(xd) - aln);
}

/// Returns the inverse `x` of the lower regularized incomplete gamma function
/// such that `P(a, x) = p`, for shape `a > 0` and probability `0 <= p <= 1`.
///
/// Returns `0.0` at `p = 0`, `double.infinity` at `p = 1`, and `double.nan`
/// for out-of-domain or non-finite arguments.
///
/// See https://en.wikipedia.org/wiki/Incomplete_gamma_function for details.
double gammaPInv(num a, num p) {
  if (p.isNaN || a.isNaN || p < 0.0 || p > 1.0 || a <= 0.0 || a.isInfinite) {
    return double.nan;
  }
  if (p == 0.0) return 0.0;
  if (p == 1.0) return double.infinity;

  final ad = a.toDouble();
  final pd = p.toDouble();
  final a1 = ad - 1.0;
  final gln = gammaLn(ad);
  var x = 0.0;
  var afac = 0.0;
  var lna1 = 0.0;

  if (ad > 1.0) {
    lna1 = log(a1);
    afac = exp(a1 * (lna1 - 1.0) - gln);
    final pp = pd < 0.5 ? pd : 1.0 - pd;
    final tVal = sqrt(-2.0 * log(pp));
    x =
        (2.30753 + tVal * 0.27061) / (1.0 + tVal * (0.99229 + tVal * 0.04481)) -
        tVal;
    if (pd < 0.5) {
      x = -x;
    }
    x = max(
      1.0e-3,
      ad * pow(1.0 - 1.0 / (9.0 * ad) - x / (3.0 * sqrt(ad)), 3).toDouble(),
    );
  } else {
    final tVal = 1.0 - ad * (0.253 + ad * 0.12);
    if (pd < tVal) {
      x = pow(pd / tVal, 1.0 / ad).toDouble();
    } else {
      x = 1.0 - log(1.0 - (pd - tVal) / (1.0 - tVal));
    }
  }
  return _gammaInvHalley(
    x,
    ad,
    a1,
    lna1,
    afac,
    gln,
    pd,
    (curX) => gammaP(ad, curX) - pd,
  );
}

/// Returns the inverse `x` of the upper regularized incomplete gamma function
/// such that `Q(a, x) = q`, for shape `a > 0` and probability `0 <= q <= 1`.
///
/// Returns `double.infinity` at `q = 0`, `0.0` at `q = 1`, and `double.nan`
/// for out-of-domain or non-finite arguments.
///
/// See https://en.wikipedia.org/wiki/Incomplete_gamma_function for details.
double gammaQInv(num a, num q) {
  if (q.isNaN || a.isNaN || q < 0.0 || q > 1.0 || a <= 0.0 || a.isInfinite) {
    return double.nan;
  }
  if (q == 0.0) return double.infinity;
  if (q == 1.0) return 0.0;
  if (q > 0.25) {
    return gammaPInv(a, 1.0 - q);
  }

  final ad = a.toDouble();
  final qd = q.toDouble();
  final gln = gammaLn(ad);
  final a1 = ad - 1.0;
  final lna1 = a1 > 0.0 ? log(a1) : 0.0;
  final afac = a1 > 0.0 ? exp(a1 * (lna1 - 1.0) - gln) : 0.0;

  final double x;
  if (ad > 1.0) {
    final tVal = sqrt(-2.0 * log(qd));
    final z =
        tVal -
        (2.30753 + tVal * 0.27061) / (1.0 + tVal * (0.99229 + tVal * 0.04481));
    x = max(
      1.0e-3,
      ad * pow(1.0 - 1.0 / (9.0 * ad) + z / (3.0 * sqrt(ad)), 3).toDouble(),
    );
  } else {
    final u = -log(qd) - gln;
    x = max(1.0e-3, u + a1 * log(max(1.0, u)));
  }

  return _gammaInvHalley(
    x,
    ad,
    a1,
    lna1,
    afac,
    gln,
    qd,
    (curX) => qd - gammaQ(ad, curX),
  );
}

/// Returns the lower incomplete gamma function
/// `γ(s, x) = ∫_0^x t^(s-1) * exp(-t) dt`.
///
/// Defined for `x >= 0` and real `s` (excluding non-positive integers when
/// `x > 0`, and `s <= 0` when `x == 0`).
///
/// See https://en.wikipedia.org/wiki/Incomplete_gamma_function for details.
double lowerGamma(num s, num x) {
  if (s.isNaN || x.isNaN || x < 0.0 || !s.isFinite) return double.nan;
  final sd = s.toDouble();
  final xd = x.toDouble();
  if (xd == 0.0) return sd > 0.0 ? 0.0 : double.nan;
  if (xd == double.infinity) return sd > 0.0 ? gamma(sd) : double.nan;
  if (sd > 0.0) {
    final p = gammaP(sd, xd);
    if (sd > 150.0) {
      return p == 0.0 ? 0.0 : exp(gammaLn(sd) + log(p));
    }
    return gamma(sd) * p;
  }
  return gamma(sd) - upperGamma(sd, xd);
}

/// Returns the complex lower incomplete gamma function
/// `γ(s, z) = ∫_0^z t^(s-1) * exp(-t) dt`.
///
/// See https://en.wikipedia.org/wiki/Incomplete_gamma_function for details.
Complex lowerGammaComplex(Complex s, Complex z) {
  if (s.isNaN || z.isNaN || !s.a.isFinite || !s.b.isFinite) {
    return Complex.nan;
  }
  if (!z.a.isFinite || !z.b.isFinite) {
    return Complex.nan;
  }
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
  for (var n = 1; n <= 500; n++) {
    ap += 1;
    del *= z / ap;
    sum += del;
    if (del.abs() <= 1.0e-15 * sum.abs()) break;
  }
  return z.pow(s) * (-z).exp() * sum;
}

/// Returns the upper incomplete gamma function
/// `Γ(s, x) = ∫_x^∞ t^(s-1) * exp(-t) dt`.
///
/// Defined for `x >= 0` and finite real `s` (for `x == 0`, requires `s > 0`).
///
/// See https://en.wikipedia.org/wiki/Incomplete_gamma_function for details.
double upperGamma(num s, num x) {
  if (s.isNaN || x.isNaN || x < 0.0 || !s.isFinite) return double.nan;
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

  final expNegX = exp(-xd);
  if (sd.roundToDouble() == sd && sd >= -1e7) {
    final steps = (-sd).round();
    var sCur = 0.0;
    var gCur = -expIntegral(-xd);
    for (var j = 0; j < steps; j++) {
      sCur -= 1.0;
      gCur = (gCur - pow(xd, sCur) * expNegX) / sCur;
    }
    return gCur;
  }
  final steps = (-sd).floor() + 1;
  var sCur = sd + steps;
  var gCur = upperGamma(sCur, xd);
  for (var j = 0; j < steps; j++) {
    sCur -= 1.0;
    gCur = (gCur - pow(xd, sCur) * expNegX) / sCur;
  }
  return gCur;
}

/// Returns the complex upper incomplete gamma function
/// `Γ(s, z) = ∫_z^∞ t^(s-1) * exp(-t) dt`.
///
/// See https://en.wikipedia.org/wiki/Incomplete_gamma_function for details.
Complex upperGammaComplex(Complex s, Complex z) {
  if (s.isNaN || z.isNaN || !s.a.isFinite || !s.b.isFinite) {
    return Complex.nan;
  }
  if (!z.a.isFinite || !z.b.isFinite) return Complex.nan;
  if (z == Complex.zero) return s.a > 0.0 ? gammaComplex(s) : Complex.nan;
  if (s == Complex.zero) return expIntegralE1Complex(z);
  if (z.abs() >= s.abs() + 1.0 && z.a > -z.b.abs()) {
    final h = lentzCFComplex(
      z + 1.0 - s,
      (k) => Complex(-k.toDouble()) * (Complex(k.toDouble()) - s),
      (k) => z + 1.0 - s + 2.0 * k,
    );
    return z.pow(s) * (-z).exp() * h;
  }
  if (s.b == 0.0 && s.a < 0.0 && s.a >= -1e7 && s.a == s.a.roundToDouble()) {
    final steps = (-s.a).round();
    final expNegZ = (-z).exp();
    var sCur = Complex.zero;
    var gCur = expIntegralE1Complex(z);
    for (var j = 0; j < steps; j++) {
      sCur -= 1;
      gCur = (gCur - z.pow(sCur) * expNegZ) / sCur;
    }
    return gCur;
  }
  return gammaComplex(s) - lowerGammaComplex(s, z);
}

/// Package-internal helper returning `(ln|Γ(x)|, sign(Γ(x)))` for real `x`.
///
/// Returns `sign == 0` and `logAbs == double.infinity` at non-positive integer
/// poles.
({double logAbs, int sign}) logAbsGammaWithSign(double x) {
  if (x.isNaN || x == double.negativeInfinity) {
    return (logAbs: double.nan, sign: 0);
  }
  if (x == double.infinity) {
    return (logAbs: double.infinity, sign: 1);
  }
  if (x > 0.0) {
    return (logAbs: gammaLn(x), sign: 1);
  }
  final r = x - 2.0 * (x / 2.0).roundToDouble();
  if (r == 0.0 || r.abs() == 1.0) {
    return (logAbs: double.infinity, sign: 0);
  }
  final sinVal = sin(pi * r);
  final logAbs = _lnPi - log(sinVal.abs()) - gammaLn(1.0 - x);
  return (logAbs: logAbs, sign: sinVal > 0.0 ? 1 : -1);
}

double _gammaInvHalley(
  double initialX,
  double a,
  double a1,
  double lna1,
  double afac,
  double gln,
  double targetProb,
  double Function(double x) signedError,
) {
  const epsilon = 1.0e-14;
  var x = initialX <= 0.0 || initialX.isNaN ? 1.0 : initialX;
  var xMin = 0.0;
  var xMax = double.infinity;
  final errTol = 1.0e-15 * targetProb;
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
    if (err.abs() <= errTol ||
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

/// `sqrt(2 * pi)` for Lanczos gamma normalization.
const double _sqrt2Pi = 2.5066282746310005024;

/// `0.5 * ln(2 * pi)` for log-gamma Lanczos normalization.
const double _halfLog2Pi = 0.91893853320467274178;

/// `ln(pi)` for reflection formula.
const double _lnPi = 1.14472988584940017414;

/// High-precision Lanczos parameter `g = 607 / 128`.
const double _lanczosG = 607 / 128;

/// Exact IEEE-754 double values of `Γ(n) = (n - 1)!` for `n = 1..23`.
const List<double> _smallFactorials = [
  1.0,
  1.0,
  2.0,
  6.0,
  24.0,
  120.0,
  720.0,
  5040.0,
  40320.0,
  362880.0,
  3628800.0,
  39916800.0,
  479001600.0,
  6227020800.0,
  87178291200.0,
  1307674368000.0,
  20922789888000.0,
  355687428096000.0,
  6402373705728000.0,
  121645100408832000.0,
  2432902008176640000.0,
  51090942171709440000.0,
  1124000727777607680000.0,
];

/// High-precision Lanczos coefficients for `g = 607 / 128` (15 terms).
const List<double> _lanczosCoeffs = [
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
