import 'dart:math';

import 'package:more/number.dart' show Complex;

import 'gamma.dart';
import 'utils.dart';

/// Returns the digamma function `ψ(x) = Γ'(x) / Γ(x)`.
///
/// Logarithmic derivative of the gamma function; at `x = 1` it equals `-γ`
/// (`≈ -0.5772156649015329`). Evaluated using harmonic recurrence shifted to
/// `x >= 10` and a 14th-order Bernoulli asymptotic expansion.
///
/// Returns `double.nan` at non-positive integers, `-∞`, and `NaN`, and
/// `double.infinity` at `+∞`.
///
/// See https://en.wikipedia.org/wiki/Digamma_function for details.
///
/// ```dart
/// final val = digamma(1.0); // ~ -0.5772156649015329
/// ```
double digamma(num x) {
  if (x.isNaN) return double.nan;
  if (x.isInfinite) {
    return x.isNegative ? double.nan : double.infinity;
  }
  var value = x.toDouble();
  if (value <= 0.0) {
    final frac = value - value.floorToDouble();
    if (frac == 0.0) {
      return double.nan;
    }
    final cotTerm = frac == 0.5 ? 0.0 : pi * cos(pi * frac) / sin(pi * frac);
    return digamma(1.0 - value) - cotTerm;
  }
  var shift = 0.0;
  while (value < 10.0) {
    shift += 1.0 / value;
    value += 1.0;
  }
  final invVal = 1.0 / value;
  final r2 = invVal * invVal;
  final r4 = r2 * r2;
  final r6 = r4 * r2;
  final r8 = r6 * r2;
  final r10 = r8 * r2;
  final r12 = r10 * r2;
  final r14 = r12 * r2;
  final result =
      log(value) -
      0.5 * invVal -
      (1.0 / 12.0) * r2 +
      (1.0 / 120.0) * r4 -
      (1.0 / 252.0) * r6 +
      (1.0 / 240.0) * r8 -
      (5.0 / 660.0) * r10 +
      (691.0 / 32760.0) * r12 -
      (1.0 / 12.0) * r14;
  return result - shift;
}

/// Returns the complex digamma function `ψ(z) = Γ'(z) / Γ(z)`.
///
/// See https://en.wikipedia.org/wiki/Digamma_function for details.
Complex digammaComplex(Complex z) {
  if (z.isNaN) return Complex.nan;
  if (z.b == 0.0 && z.a == double.infinity) {
    return const Complex(double.infinity);
  }
  if (!z.a.isFinite || !z.b.isFinite) return Complex.nan;
  if (z.b == 0.0 && z.a <= 0.0 && z.a == z.a.roundToDouble()) {
    return Complex.nan;
  }
  if (z.a < 0.5) {
    return digammaComplex(Complex.one - z) -
        const Complex(pi) * cotPiComplex(z);
  }
  var shift = Complex.zero;
  var cur = z;
  while (cur.abs() < 10.0) {
    shift += cur.reciprocal();
    cur += 1;
  }
  final invVal = cur.reciprocal();
  final r2 = invVal.square();
  final r4 = r2.square();
  final r6 = r4 * r2;
  final r8 = r6 * r2;
  final r10 = r8 * r2;
  final r12 = r10 * r2;
  final r14 = r12 * r2;
  final result =
      cur.log() -
      const Complex(0.5) * invVal -
      const Complex(1.0 / 12.0) * r2 +
      const Complex(1.0 / 120.0) * r4 -
      const Complex(1.0 / 252.0) * r6 +
      const Complex(1.0 / 240.0) * r8 -
      const Complex(5.0 / 660.0) * r10 +
      const Complex(691.0 / 32760.0) * r12 -
      const Complex(1.0 / 12.0) * r14;
  return result - shift;
}

/// Returns the polygamma function of order [m],
/// `ψ^(m)(x) = d^(m+1)/dx^(m+1) ln(Γ(x))`.
///
/// For `m == 0`, this equals [digamma]. For `m == 1`, this is the trigamma
/// function `ψ'(x)`. Throws an [ArgumentError] if `m < 0`. Returns `double.nan`
/// at non-positive integers, `-∞`, and `NaN`, and `0.0` for `x = +∞` (`m >= 1`).
///
/// See https://en.wikipedia.org/wiki/Polygamma_function for details.
double polygamma(int m, num x) {
  if (m < 0) {
    throw ArgumentError.value(m, 'm', 'Order must be non-negative');
  }
  if (m == 0) return digamma(x);
  if (m == 1) return _trigamma(x);
  if (x.isNaN) return double.nan;
  if (x.isInfinite) {
    return x.isNegative ? double.nan : 0.0;
  }
  var value = x.toDouble();
  if (value <= 0.0) {
    final frac = value - value.floorToDouble();
    if (frac == 0.0) {
      return double.nan;
    }
    final refl = polygamma(m, 1.0 - value);
    final signM = m.isEven ? 1.0 : -1.0;
    final term = pow(pi, m + 1) * _cotDerivative(m, frac);
    return signM * refl - term;
  }

  final threshold = max(10.0, 1.5 * m + 4.0);
  final sign = m.isOdd ? 1.0 : -1.0;
  final shiftSign = m.isEven ? -1.0 : 1.0;
  final useLog = m > 150;
  final logMFact = useLog ? gammaLn(m + 1.0) : 0.0;
  var mFact = 1.0;
  if (!useLog) {
    for (var i = 2; i <= m; i++) {
      mFact *= i;
    }
  }

  var shift = 0.0;
  while (value < threshold) {
    shift += useLog
        ? shiftSign * exp(logMFact - (m + 1) * log(value))
        : shiftSign * mFact / pow(value, m + 1);
    value += 1.0;
  }

  final invVal = 1.0 / value;
  final invVal2 = invVal * invVal;
  final mMinus1FactOverInv = useLog
      ? exp(gammaLn(m.toDouble()) + m * log(invVal))
      : (mFact / m) * pow(invVal, m);
  final mFactOverInv = useLog
      ? exp(logMFact + (m + 1) * log(invVal))
      : mFact * pow(invVal, m + 1);
  var termFactor = mMinus1FactOverInv;
  var asymptotic = mMinus1FactOverInv + 0.5 * mFactOverInv;

  for (var k = 1; k <= _polygammaBernoulliCoeffs.length; k++) {
    final a = 2 * k + m - 2;
    termFactor *= (a * (a + 1)) * invVal2;
    final term = _polygammaBernoulliCoeffs[k - 1] * termFactor;
    asymptotic += term;
    if (term.abs() < 1e-15 * asymptotic.abs()) break;
  }

  return sign * asymptotic + shift;
}

/// Returns the complex polygamma function of order [m],
/// `ψ^(m)(z) = d^(m+1)/dz^(m+1) ln(Γ(z))`.
///
/// Throws an [ArgumentError] if `m < 0`.
///
/// See https://en.wikipedia.org/wiki/Polygamma_function for details.
Complex polygammaComplex(int m, Complex z) {
  if (m < 0) {
    throw ArgumentError.value(m, 'm', 'Order must be non-negative');
  }
  if (m == 0) return digammaComplex(z);
  if (z.isNaN || !z.a.isFinite || !z.b.isFinite) return Complex.nan;
  if (z.b == 0.0 && z.a <= 0.0 && z.a == z.a.roundToDouble()) {
    return Complex.nan;
  }
  if (z.a < 0.5) {
    final refl = polygammaComplex(m, Complex.one - z);
    final signM = m.isEven ? 1.0 : -1.0;
    final term =
        Complex(pow(pi, m + 1).toDouble()) * _cotDerivativeComplex(m, z);
    return Complex(signM) * refl - term;
  }

  final threshold = max(10.0, 1.5 * m + 4.0);
  final sign = m.isOdd ? 1.0 : -1.0;
  final shiftSign = m.isEven ? -1.0 : 1.0;
  var mFact = 1.0;
  for (var i = 2; i <= m; i++) {
    mFact *= i;
  }
  final mMinus1Fact = mFact / m;

  var shift = Complex.zero;
  var cur = z;
  while (cur.abs() < threshold) {
    shift += Complex(shiftSign * mFact) / cur.pow(m + 1);
    cur += 1;
  }

  final invVal = cur.reciprocal();
  final invVal2 = invVal.square();
  final mMinus1Term = Complex(mMinus1Fact) * invVal.pow(m);
  var termFactor = mMinus1Term;
  var asymptotic = mMinus1Term + Complex(0.5 * mFact) * invVal.pow(m + 1);

  for (var k = 1; k <= _polygammaBernoulliCoeffs.length; k++) {
    final a = 2 * k + m - 2;
    termFactor *= Complex((a * (a + 1)).toDouble()) * invVal2;
    final term = termFactor * _polygammaBernoulliCoeffs[k - 1];
    asymptotic += term;
    if (term.abs() < 1e-15 * asymptotic.abs()) break;
  }

  return Complex(sign) * asymptotic + shift;
}

double _trigamma(num x) {
  if (x.isNaN) return double.nan;
  if (x.isInfinite) {
    return x.isNegative ? double.nan : 0.0;
  }
  var value = x.toDouble();
  if (value <= 0.0) {
    final frac = value - value.floorToDouble();
    if (frac == 0.0) {
      return double.nan;
    }
    final sinVal = sin(pi * frac);
    return pi * pi / (sinVal * sinVal) - _trigamma(1.0 - value);
  }
  var shift = 0.0;
  while (value < 10.0) {
    shift += 1.0 / (value * value);
    value += 1.0;
  }
  final invVal = 1.0 / value;
  final r2 = invVal * invVal;
  final r3 = r2 * invVal;
  final r5 = r3 * r2;
  final r7 = r5 * r2;
  final r9 = r7 * r2;
  final r11 = r9 * r2;
  final r13 = r11 * r2;
  final r15 = r13 * r2;
  final result =
      invVal +
      0.5 * r2 +
      (1.0 / 6.0) * r3 -
      (1.0 / 30.0) * r5 +
      (1.0 / 42.0) * r7 -
      (1.0 / 30.0) * r9 +
      (5.0 / 66.0) * r11 -
      (691.0 / 2730.0) * r13 +
      (7.0 / 6.0) * r15;
  return result + shift;
}

List<double> _cotDerivativePoly(int m) {
  var poly = <double>[0.0, 1.0]; // P_0(t) = t
  for (var k = 0; k < m; k++) {
    final next = List<double>.filled(k + 3, 0.0);
    for (var j = 1; j < poly.length; j++) {
      final c = poly[j];
      if (c != 0.0) {
        final d = j * c;
        next[j - 1] -= d;
        next[j + 1] -= d;
      }
    }
    poly = next;
  }
  return poly;
}

double _cotDerivative(int m, double frac) {
  final px = pi * frac;
  final t = frac == 0.5 ? 0.0 : cos(px) / sin(px);
  final poly = _cotDerivativePoly(m);
  var val = 0.0;
  for (var i = poly.length - 1; i >= 0; i--) {
    val = val * t + poly[i];
  }
  return val;
}

Complex _cotDerivativeComplex(int m, Complex z) {
  final t = cotPiComplex(z);
  final poly = _cotDerivativePoly(m);
  var val = Complex.zero;
  for (var i = poly.length - 1; i >= 0; i--) {
    val = val * t + poly[i];
  }
  return val;
}

/// Bernoulli-derived asymptotic coefficients `B_{2k} / (2k)!` for `k = 1..10`.
const List<double> _polygammaBernoulliCoeffs = [
  1.0 / 12.0,
  -1.0 / 720.0,
  1.0 / 30240.0,
  -1.0 / 1209600.0,
  1.0 / 47900160.0,
  -691.0 / 1307674368000.0,
  1.0 / 74724249600.0,
  -3617.0 / 10670622842880000.0,
  43867.0 / 5109094217170944000.0,
  -174611.0 / 802857662698291200000.0,
];
