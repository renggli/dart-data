import 'dart:math';

import 'package:more/number.dart' show Complex;

import 'gamma.dart';

/// Returns the Riemann zeta function `ζ(s) = ∑_{n=1}^∞ n^(-s)`.
///
/// Analytic continuation of Dirichlet's series across `R \ {1}`, with a simple
/// pole at `s = 1`. Evaluated via Borwein's accelerated alternating series
/// (`n = 21`) for `0 < s <= 25`, direct summation for `s > 25`, and Riemann's
/// functional reflection equation for `s < 0`.
///
/// See https://en.wikipedia.org/wiki/Riemann_zeta_function for details.
///
/// ```dart
/// final val = zeta(2.0); // ~ 1.6449340668 (pi^2 / 6)
/// ```
double zeta(num s) {
  if (s.isNaN) return double.nan;
  final sd = s.toDouble();
  if (sd.isInfinite) return sd > 0.0 ? 1.0 : double.nan;
  if (sd == 1.0) return double.infinity;
  if (sd == 0.0) return -0.5;

  // Trivial zeros at negative even integers.
  if (sd < 0.0 && sd.roundToDouble() == sd && sd.toInt().isEven) {
    return 0.0;
  }

  // Reflection formula for negative s.
  if (sd < 0.0) {
    final oneMinusS = 1.0 - sd;
    // Exact argument reduction mod 4 avoids sin(pi/2 * s) drift for large |s|.
    final sinVal = sin(0.5 * pi * (sd % 4.0));
    if (sinVal == 0.0) return 0.0;
    if (sd < -50.0) {
      final sign = sinVal > 0.0 ? 1.0 : -1.0;
      final logMag =
          sd * ln2 +
          (sd - 1.0) * _lnPi +
          log(sinVal.abs()) +
          gammaLn(oneMinusS) +
          log(zeta(oneMinusS));
      if (logMag > 709.782712893384) {
        return sign * double.infinity;
      }
      return sign * exp(logMag);
    }
    return exp(sd * ln2 + (sd - 1.0) * _lnPi) *
        sinVal *
        gamma(oneMinusS) *
        zeta(oneMinusS);
  }

  // Direct summation for large positive s.
  if (sd > 55.0) return 1.0;
  if (sd > 25.0) {
    return 1.0 +
        exp(-sd * _lnTable[1]) +
        exp(-sd * _lnTable[2]) +
        exp(-sd * _lnTable[3]);
  }

  // Borwein's algorithm with precomputed normalized weights (n = 21).
  var sum = _borweinWeights[0];
  for (var k = 1; k < _borweinN; k++) {
    sum += _borweinWeights[k] * exp(-sd * _lnTable[k]);
  }

  // Accurate 1 - 2^(1 - s) near s = 1 to avoid catastrophic cancellation.
  final u = (1.0 - sd) * ln2;
  final oneMinusTwoPow = u.abs() < 1e-4
      ? -(u * (1.0 + u * (0.5 + u * (_oneSixth + u * _oneTwentyFourth))))
      : 1.0 - exp(u);
  return -sum / oneMinusTwoPow;
}

/// Returns the complex Riemann zeta function `ζ(s)`.
///
/// Uses Borwein's accelerated alternating series (`n = 21`) for `Re(s) >= 0.5`
/// and `|Im(s)| <= 6`, adaptive Euler–Maclaurin summation for larger `|Im(s)|`
/// (avoiding both Borwein's exponential precision loss and spurious poles at
/// `s = 1 + 2πik / ln 2`), conjugate symmetry `ζ(s̄) = ζ(s)̄`, and
/// overflow-safe log-space reflection for `Re(s) < 0.5`.
///
/// See https://en.wikipedia.org/wiki/Riemann_zeta_function for details.
Complex zetaComplex(Complex s) {
  if (s.isNaN) return Complex.nan;
  final sigma = s.a.toDouble();
  final tRaw = s.b.toDouble();

  if (tRaw == 0.0) {
    return Complex(zeta(sigma));
  }

  // Conjugate symmetry: ζ(conj(s)) = conj(ζ(s)); restrict to t > 0.
  if (tRaw < 0.0) {
    return zetaComplex(Complex(sigma, -tRaw)).conjugate();
  }
  final t = tRaw;

  // Reflection formula for Re(s) < 0.5.
  if (sigma < 0.5) {
    final oneMinusS = Complex(1.0 - sigma, -t);
    final zetaReflected = zetaComplex(oneMinusS);
    if (sigma < -50.0 || t > 20.0) {
      // Log-space reflection avoids overflow in sin(pi*s/2) and underflow in Γ(1-s).
      final logSin = _logSinPiHalf(sigma, t);
      final logFactor =
          Complex(sigma * ln2 + (sigma - 1.0) * _lnPi, t * (ln2 + _lnPi)) +
          logSin +
          gammaLnComplex(oneMinusS);
      return logFactor.exp() * zetaReflected;
    }
    final scaleMag = exp(sigma * ln2 + (sigma - 1.0) * _lnPi);
    final scaleAng = t * (ln2 + _lnPi);
    final scale = Complex(scaleMag * cos(scaleAng), scaleMag * sin(scaleAng));
    final sinFactor = Complex(0.5 * pi * (sigma % 4.0), 0.5 * pi * t).sin();
    return scale * sinFactor * gammaComplex(oneMinusS) * zetaReflected;
  }

  if (sigma > 55.0) return Complex.one;

  // Fast unboxed Borwein path for small imaginary parts (well below first
  // spurious denominator zero at t = 2π / ln(2) ≈ 9.0647).
  if (t <= 6.0) {
    var sumRe = _borweinWeights[0];
    var sumIm = 0.0;
    for (var k = 1; k < _borweinN; k++) {
      final lnK = _lnTable[k];
      final mag = _borweinWeights[k] * exp(-sigma * lnK);
      final ang = -t * lnK;
      sumRe += mag * cos(ang);
      sumIm += mag * sin(ang);
    }
    final twoMag = exp((1.0 - sigma) * ln2);
    final twoAng = -t * ln2;
    final denom = Complex(1.0 - twoMag * cos(twoAng), -twoMag * sin(twoAng));
    return Complex(-sumRe, -sumIm) / denom;
  }

  // Adaptive Euler–Maclaurin summation for general complex s (Re(s) >= 0.5).
  return _zetaEulerMaclaurin(sigma, t);
}

/// Returns the Hurwitz zeta function `ζ(s, a) = ∑_{n=0}^∞ (n + a)^(-s)`.
///
/// See https://en.wikipedia.org/wiki/Hurwitz_zeta_function for details.
double hurwitzZeta(num s, num a) {
  if (s.isNaN || a.isNaN) return double.nan;
  final sd = s.toDouble();
  final ad = a.toDouble();
  if (ad == 1.0) return zeta(sd);
  if (sd == 1.0) return double.infinity;
  if (sd == 0.0) return 0.5 - ad;
  if (ad <= 0.0 && ad.roundToDouble() == ad) {
    if (sd > 0.0) return double.nan;
    final m = (-ad).round();
    var sum = zeta(sd);
    for (var j = 1; j <= m; j++) {
      sum += pow(-j.toDouble(), -sd).toDouble();
    }
    return sum;
  }
  final z = hurwitzZetaComplex(Complex(sd), Complex(ad));
  return z.b.abs() <= 1e-12 * max(1.0, z.a.abs()) ? z.a.toDouble() : double.nan;
}

/// Returns the complex Hurwitz zeta function `ζ(s, a)`.
Complex hurwitzZetaComplex(Complex s, Complex a) {
  if (s.isNaN || a.isNaN) return Complex.nan;
  if (a == Complex.one) return zetaComplex(s);
  if (s == Complex.one) return const Complex(double.infinity);
  if (s == Complex.zero) return const Complex(0.5) - a;

  // Shift `a` so Re(a) >= 1 before Euler–Maclaurin summation.
  var sum = Complex.zero;
  var curA = a;
  if (curA.a < 1.0) {
    final shift = (1.0 - curA.a).ceil();
    for (var k = 0; k < shift; k++) {
      final termA = curA + k.toDouble();
      if (termA == Complex.zero) return Complex.nan;
      sum += termA.pow(-s);
    }
    curA += shift.toDouble();
  }

  final m = max(12, (1.15 * s.abs() + 10.0).ceil());
  for (var k = 0; k < m; k++) {
    sum += (curA + k.toDouble()).pow(-s);
  }
  final aM = curA + m.toDouble();
  final aMPowNegS = aM.pow(-s);
  sum += (aM * aMPowNegS) / (s - Complex.one);
  sum += aMPowNegS * 0.5;

  final invAM2 = Complex.one / (aM * aM);
  var coeff = s * aMPowNegS / aM;
  for (var k = 0; k < _eulerMaclaurinCoeffs.length; k++) {
    final term = coeff * _eulerMaclaurinCoeffs[k];
    sum += term;
    if (k >= 2 && term.abs() < 1e-16 * max(1.0, sum.abs())) break;
    final twoK = 2 * k + 1;
    coeff *= (s + twoK.toDouble()) * (s + (twoK + 1).toDouble()) * invAM2;
  }
  return sum;
}

Complex _zetaEulerMaclaurin(double sigma, double t) {
  final s = Complex(sigma, t);
  final sAbs = sqrt(sigma * sigma + t * t);
  final n = max(12, (1.15 * sAbs + 10.0).ceil());

  _ensureLnCache(n);

  var sumRe = 1.0;
  var sumIm = 0.0;
  for (var k = 2; k < n; k++) {
    final lnK = _lnCache[k];
    final mag = exp(-sigma * lnK);
    final ang = -t * lnK;
    sumRe += mag * cos(ang);
    sumIm += mag * sin(ang);
  }

  final lnN = _lnCache[n];
  final nMag = exp(-sigma * lnN);
  final nAng = -t * lnN;
  final nPowNegS = Complex(nMag * cos(nAng), nMag * sin(nAng));

  var total =
      Complex(sumRe, sumIm) +
      (nPowNegS * n.toDouble()) / Complex(sigma - 1.0, t) +
      nPowNegS * 0.5;

  final invN = 1.0 / n;
  final invN2 = invN * invN;
  var coeff = s * nPowNegS * invN;
  for (var k = 0; k < _eulerMaclaurinCoeffs.length; k++) {
    final term = coeff * _eulerMaclaurinCoeffs[k];
    total += term;
    if (k >= 2 && term.abs() < 1e-16 * max(1.0, total.abs())) break;
    final twoK = 2 * k + 1;
    coeff *= Complex(sigma + twoK, t) * Complex(sigma + twoK + 1, t) * invN2;
  }
  return total;
}

Complex _logSinPiHalf(double sigma, double t) {
  if (t > 20.0) {
    // sin(pi/2 * (sigma + i*t)) = (i/2) * exp(pi/2 * t - i*pi/2 * sigma) * (1 - exp(-pi*t + i*pi*sigma))
    // For t > 20, exp(-pi * t) < 5e-28 < double epsilon.
    return Complex(0.5 * pi * t - ln2, 0.5 * pi * (1.0 - sigma));
  }
  return Complex(0.5 * pi * (sigma % 4.0), 0.5 * pi * t).sin().log();
}

void _ensureLnCache(int n) {
  while (_lnCache.length <= n) {
    _lnCache.add(log(_lnCache.length));
  }
}

final List<double> _lnCache = <double>[
  0.0,
  for (var k = 1; k <= 64; k++) log(k),
];

/// Precomputed `B_{2k} / (2k)!` for `k = 1..10`.
const List<double> _eulerMaclaurinCoeffs = <double>[
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

const double _lnPi = 1.1447298858494002;
const double _oneSixth = 1.0 / 6.0;
const double _oneTwentyFourth = 1.0 / 24.0;
const int _borweinN = 21;

/// Precomputed normalized Borwein weights `(-1)^k * (d_k - d_n) / d_n` (`n = 21`).
const List<double> _borweinWeights = <double>[
  -0.9999999999999998,
  0.9999999999998519,
  -0.9999999999781624,
  0.9999999987143826,
  -0.9999999597177504,
  0.9999992231146966,
  -0.9999899374519575,
  0.9999072848495549,
  -0.9993672878471919,
  0.996706126149272,
  -0.9866217239255753,
  0.9568487268841854,
  -0.8878098931650205,
  0.7616281478444542,
  -0.5800332551079779,
  0.3754780885772345,
  -0.1973171370827161,
  0.07981347923428146,
  -0.023113301478846344,
  0.004240127090835221,
  -0.00036870670355088883,
];

/// Precomputed `ln(k + 1)` for `k = 0..20`.
const List<double> _lnTable = <double>[
  0.0,
  0.6931471805599453,
  1.0986122886681098,
  1.3862943611198906,
  1.6094379124341003,
  1.791759469228055,
  1.9459101490553132,
  2.0794415416798357,
  2.1972245773362196,
  2.302585092994046,
  2.3978952727983707,
  2.4849066497880004,
  2.5649493574615367,
  2.6390573296152584,
  2.70805020110221,
  2.772588722239781,
  2.833213344056216,
  2.8903717578961645,
  2.9444389791664403,
  2.995732273553991,
  3.044522437723423,
];
