import 'dart:math' as math;

import 'package:more/number.dart' show Complex;

import 'zeta.dart';

/// Returns the real-valued polylogarithm `Li_s(z) = ∑_{k=1}^∞ z^k / k^s`.
///
/// Defined on R for `z <= 1` (and `z < 1` when `s <= 1`).
/// Returns `double.nan` on the branch cut `z > 1`.
///
/// See https://en.wikipedia.org/wiki/Polylogarithm for details.
double polylog(num s, num z) {
  if (s.isNaN || z.isNaN) return double.nan;
  final sd = s.toDouble();
  final zd = z.toDouble();
  if (zd > 1.0) return double.nan;
  if (zd == 0.0) return 0.0;
  if (sd == 1.0) {
    if (zd == 1.0) return double.infinity;
    return -math.log(1.0 - zd);
  }
  if (sd == 0.0) {
    return zd == 1.0 ? double.infinity : zd / (1.0 - zd);
  }
  if (sd == -1.0) {
    return zd == 1.0 ? double.infinity : zd / ((1.0 - zd) * (1.0 - zd));
  }
  if (zd == 1.0) {
    return sd > 1.0 ? zeta(sd) : double.infinity;
  }
  final res = polylogComplex(Complex(sd), Complex(zd));
  return res.a.toDouble();
}

/// Returns the complex-valued polylogarithm `Li_s(z)`.
///
/// See https://en.wikipedia.org/wiki/Polylogarithm for details.
Complex polylogComplex(Complex s, Complex z) {
  if (z.a == 0.0 && z.b == 0.0) return Complex.zero;

  if (s.b == 0.0) {
    final sr = s.a.toDouble();
    if (sr == 1.0) return -(Complex.one - z).log();
    if (sr == 0.0) return z / (Complex.one - z);
    if (sr == -1.0) {
      final omz = Complex.one - z;
      return z / (omz * omz);
    }
    if (z.a == 1.0 && z.b == 0.0) {
      return sr > 1.0 ? Complex(zeta(sr)) : const Complex(double.infinity);
    }
    if (z.a == -1.0 && z.b == 0.0 && sr > 1.0) {
      return Complex(-(1.0 - math.pow(2.0, 1.0 - sr)) * zeta(sr));
    }
  }

  final absZ = z.abs();
  if (absZ <= 0.95 && (z - Complex.one).abs() >= 0.4) {
    return _polylogSeries(s, z, maxTerms: 600);
  }

  if (s.b == 0.0 && s.a == s.a.roundToDouble() && s.a >= 2 && s.a <= 12) {
    final n = s.a.toInt();
    if ((z - Complex.one).abs() < 0.4) {
      return _polylogLogExpansion(n, z);
    }
    if (absZ > 1.05) {
      return _polylogInversion(n, z);
    }
    return _polylogSeries(s, z, maxTerms: 2000);
  }

  // Fallback for general s with |z| < 1
  if (absZ < 1.0) {
    return _polylogSeries(s, z, maxTerms: 1000);
  }
  return Complex.nan;
}

Complex _polylogSeries(Complex s, Complex z, {int maxTerms = 200}) {
  var sum = Complex.zero;
  var zk = z;
  for (var k = 1; k <= maxTerms; k++) {
    final term = zk / Complex(k.toDouble()).pow(s);
    sum = sum + term;
    if (term.abs() <= 1e-15 * math.max(1e-30, sum.abs())) break;
    zk = zk * z;
  }
  return sum;
}

Complex _polylogInversion(int n, Complex z) {
  final inv = polylogComplex(Complex(n.toDouble()), z.reciprocal());
  final sign = n.isEven ? -1.0 : 1.0;
  final logNegZ = (-z).log();

  var polySum = Complex.zero;
  var fact2k = 1.0;
  var twoPiIPow = Complex.one;
  final twoPiISq =
      const Complex(0.0, 2.0 * math.pi) * const Complex(0.0, 2.0 * math.pi);

  for (var k = 0; 2 * k <= n; k++) {
    final rem = n - 2 * k;
    var factRem = 1.0;
    for (var j = 2; j <= rem; j++) {
      factRem *= j;
    }
    final bernoulliShift = k == 0
        ? 1.0
        : (math.pow(2.0, 1 - 2 * k) - 1.0) * _bernoulliEven[k];
    final coeff = twoPiIPow * Complex(bernoulliShift / (fact2k * factRem));
    final logPow = rem == 0
        ? Complex.one
        : logNegZ.pow(Complex(rem.toDouble()));
    polySum = polySum + coeff * logPow;

    twoPiIPow = twoPiIPow * twoPiISq;
    fact2k *= (2 * k + 1) * (2 * k + 2);
  }

  return Complex(sign) * inv - polySum;
}

Complex _polylogLogExpansion(int n, Complex z) {
  final mu = z.log();
  var harmonic = 0.0;
  var factNMinus1 = 1.0;
  for (var j = 1; j < n; j++) {
    harmonic += 1.0 / j;
    factNMinus1 *= j;
  }
  final singularTerm =
      mu.pow(Complex((n - 1).toDouble())) *
      Complex(1.0 / factNMinus1) *
      (Complex(harmonic) - (-mu).log());

  var sum = singularTerm;
  var muPow = Complex.one;
  var factK = 1.0;
  for (var k = 0; k <= 60; k++) {
    if (k != n - 1) {
      final zVal = zeta((n - k).toDouble());
      final term = muPow * Complex(zVal / factK);
      sum = sum + term;
      if (k > n && term.abs() <= 1e-15 * math.max(1e-30, sum.abs())) break;
    }
    muPow = muPow * mu;
    factK *= k + 1;
  }
  return sum;
}

/// Even Bernoulli numbers `B_0, B_2, ..., B_12`.
const List<double> _bernoulliEven = [
  1.0,
  1.0 / 6.0,
  -1.0 / 30.0,
  1.0 / 42.0,
  -1.0 / 30.0,
  5.0 / 66.0,
  -691.0 / 2730.0,
];
