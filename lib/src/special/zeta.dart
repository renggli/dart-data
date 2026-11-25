import 'dart:math';

import 'package:more/number.dart' show Complex;

import 'gamma.dart';
import 'utils.dart';

/// Returns the Riemann zeta function `ζ(s) = ∑_{n=1}^∞ n^(-s)`.
///
/// Analytic continuation of Dirichlet's series across `R \ {1}`, with a simple
/// pole at `s = 1` (`ζ(1) = +∞`). Evaluated via Borwein's accelerated
/// alternating series (`n = 21`) for `0 < s <= 25`, direct summation for
/// `s > 25`, and Riemann's functional reflection equation for `s < 0`.
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

  if (sd < 0.0 && sd.roundToDouble() == sd && sd % 2.0 == 0.0) {
    return 0.0;
  }

  if (sd < 0.0) {
    final oneMinusS = 1.0 - sd;
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

  if (sd > 55.0) return 1.0;
  if (sd > 25.0) {
    return 1.0 +
        exp(-sd * _lnTable[1]) +
        exp(-sd * _lnTable[2]) +
        exp(-sd * _lnTable[3]);
  }

  var sum = _borweinWeights[0];
  for (var k = 1; k < _borweinN; k++) {
    sum += _borweinWeights[k] * exp(-sd * _lnTable[k]);
  }

  final u = (1.0 - sd) * ln2;
  final oneMinusTwoPow = u.abs() < 1e-4
      ? -(u * (1.0 + u * (0.5 + u * (_oneSixth + u * _oneTwentyFourth))))
      : 1.0 - exp(u);
  return -sum / oneMinusTwoPow;
}

/// Returns the complex Riemann zeta function `ζ(s)`.
///
/// Uses Borwein's accelerated alternating series (`n = 21`) for `Re(s) >= 0.5`
/// and `|Im(s)| <= 6`, adaptive Euler–Maclaurin summation for larger `|Im(s)|`,
/// conjugate symmetry `ζ(conj(s)) = conj(ζ(s))`, and overflow-safe log-space
/// reflection for `Re(s) < 0.5`.
///
/// See https://en.wikipedia.org/wiki/Riemann_zeta_function for details.
Complex zetaComplex(Complex s) {
  if (s.isNaN) return Complex.nan;
  final sigma = s.a.toDouble();
  final tRaw = s.b.toDouble();

  if (tRaw == 0.0) {
    return Complex(zeta(sigma));
  }
  if (!sigma.isFinite || !tRaw.isFinite) return Complex.nan;

  if (tRaw < 0.0) {
    return zetaComplex(Complex(sigma, -tRaw)).conjugate();
  }
  final t = tRaw;

  if (sigma < 0.5) {
    final oneMinusS = Complex(1.0 - sigma, -t);
    final zetaReflected = zetaComplex(oneMinusS);
    if (sigma < -50.0 || t > 20.0) {
      final logSin = logSinPiComplex(Complex(0.5 * sigma, 0.5 * t));
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

  return _zetaEulerMaclaurin(sigma, t);
}

/// Returns the Hurwitz zeta function `ζ(s, a) = ∑_{n=0}^∞ (n + a)^(-s)`.
///
/// Uses exact Bernoulli polynomial evaluation `-B_{n+1}(a) / (n + 1)` at
/// non-positive integers `s = -n` (`0 <= n <= 50`) to eliminate cancellation,
/// and shifted Euler–Maclaurin summation elsewhere.
///
/// See https://en.wikipedia.org/wiki/Hurwitz_zeta_function for details.
double hurwitzZeta(num s, num a) {
  if (s.isNaN || a.isNaN) return double.nan;
  final sd = s.toDouble();
  final ad = a.toDouble();
  if (!sd.isFinite || !ad.isFinite) {
    if (sd == double.infinity && ad > 0.0 && ad.isFinite) {
      return ad == 1.0 ? 1.0 : (ad < 1.0 ? double.infinity : 0.0);
    }
    if (ad == double.infinity && sd > 1.0 && sd.isFinite) return 0.0;
    return double.nan;
  }
  if (ad == 1.0) return zeta(sd);
  if (sd == 1.0) return double.infinity;
  if (sd <= 0.0 && sd >= -50.0 && sd.roundToDouble() == sd) {
    return _hurwitzBernoulliReal((-sd).round(), ad);
  }
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
///
/// See https://en.wikipedia.org/wiki/Hurwitz_zeta_function for details.
Complex hurwitzZetaComplex(Complex s, Complex a) {
  if (s.isNaN || a.isNaN) return Complex.nan;
  if (!s.a.isFinite || !s.b.isFinite || !a.a.isFinite || !a.b.isFinite) {
    return Complex.nan;
  }
  if (a == Complex.one) return zetaComplex(s);
  if (s == Complex.one) return const Complex(double.infinity);
  if (s.b == 0.0 && s.a <= 0.0 && s.a >= -50.0 && s.a == s.a.roundToDouble()) {
    return _hurwitzBernoulliComplex((-s.a).round(), a);
  }

  var sum = Complex.zero;
  var curA = a;
  if (curA.a < 1.0) {
    final shift = (1.0 - curA.a).ceil();
    for (var k = 0; k < shift; k++) {
      final termA = curA + k.toDouble();
      if (termA == Complex.zero) {
        if (s.a < 0.0) continue;
        return Complex.nan;
      }
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

double _hurwitzBernoulliReal(int n, double a) {
  final m = n + 1;
  final b = _bernoulliNumbers(m);
  var binom = 1.0;
  var sum = b[m];
  var aPow = 1.0;
  for (var j = 1; j <= m; j++) {
    aPow *= a;
    binom = binom * (m - j + 1) / j;
    final bk = b[m - j];
    if (bk != 0.0) {
      sum += binom * bk * aPow;
    }
  }
  return -sum / m;
}

Complex _hurwitzBernoulliComplex(int n, Complex a) {
  final m = n + 1;
  final b = _bernoulliNumbers(m);
  var binom = 1.0;
  var sum = Complex(b[m]);
  var aPow = Complex.one;
  for (var j = 1; j <= m; j++) {
    aPow *= a;
    binom = binom * (m - j + 1) / j;
    final bk = b[m - j];
    if (bk != 0.0) {
      sum += aPow * (binom * bk);
    }
  }
  return -sum / m.toDouble();
}

List<double> _bernoulliNumbers(int maxM) {
  if (_bernoulliCache.length > maxM) return _bernoulliCache;
  while (_bernoulliCache.length <= maxM) {
    final m = _bernoulliCache.length;
    var sum = 0.0;
    var binom = 1.0;
    for (var k = 0; k < m; k++) {
      sum += binom * _bernoulliCache[k];
      binom = binom * (m + 1 - k) / (k + 1);
    }
    _bernoulliCache.add(-sum / (m + 1));
  }
  return _bernoulliCache;
}

Complex _zetaEulerMaclaurin(double sigma, double t) {
  final s = Complex(sigma, t);
  final sAbs = sqrt(sigma * sigma + t * t);
  final n = max(12, (1.15 * sAbs + 10.0).ceil());

  _ensureLnCache(n);

  var sumRe = 1.0;
  var sumIm = 0.0;
  for (var k = 2; k < n; k++) {
    final lnK = k < _lnCache.length ? _lnCache[k] : log(k);
    final mag = exp(-sigma * lnK);
    final ang = -t * lnK;
    sumRe += mag * cos(ang);
    sumIm += mag * sin(ang);
  }

  final lnN = n < _lnCache.length ? _lnCache[n] : log(n);
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

void _ensureLnCache(int n) {
  final limit = min(n, _maxLnCacheSize);
  while (_lnCache.length <= limit) {
    _lnCache.add(log(_lnCache.length));
  }
}

const int _maxLnCacheSize = 4096;

final List<double> _lnCache = <double>[
  0.0,
  for (var k = 1; k <= 64; k++) log(k),
];

final List<double> _bernoulliCache = <double>[1.0];

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
