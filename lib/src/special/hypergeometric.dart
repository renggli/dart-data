import 'dart:math';

import 'package:more/number.dart' show Complex;

import 'digamma.dart';
import 'gamma.dart';

/// Returns the confluent hypergeometric function `1F1(a; b; z)` (also known
/// as Kummer's function `M(a, b, z)`).
///
/// Defined as `∑_{n=0}^∞ ((a)_n / (b)_n) * z^n / n!`. Returns `double.nan`
/// when [b] is a non-positive integer not preceded by a terminating negative
/// integer [a], or when any argument is `NaN` or non-finite.
///
/// See https://en.wikipedia.org/wiki/Confluent_hypergeometric_function for
/// details.
double hypergeometric1F1(num a, num b, num z) {
  if (a.isNaN || b.isNaN || z.isNaN) {
    return double.nan;
  }
  final ad = a.toDouble();
  final bd = b.toDouble();
  final zd = z.toDouble();
  if (!ad.isFinite || !bd.isFinite || !zd.isFinite) {
    return double.nan;
  }
  final isANonPosInt = _isNonPosInt(ad);
  final isBNonPosInt = _isNonPosInt(bd);
  if (isANonPosInt) {
    final n = (-ad).round();
    if (isBNonPosInt && (-bd).round() < n) {
      return double.nan;
    }
    if (zd == 0.0 || n == 0) return 1.0;
    var sum = 1.0;
    var term = 1.0;
    for (var stepIdx = 1; stepIdx <= n; stepIdx++) {
      term *= (ad + stepIdx - 1) / (bd + stepIdx - 1) * zd / stepIdx;
      sum += term;
    }
    return sum;
  }
  if (isBNonPosInt) {
    return double.nan;
  }
  if (zd == 0.0) return 1.0;
  if (zd < 0.0) {
    if (zd < -100.0) {
      final bMinusA = bd - ad;
      if (_isNonPosInt(bMinusA)) {
        if (zd <= -710.0) return 0.0;
        return exp(zd) * hypergeometric1F1(bMinusA, bd, -zd);
      }
      final invNegZ = 1.0 / (-zd);
      var term = 1.0;
      var sum = 1.0;
      for (var n = 1; n <= 100; n++) {
        final next =
            term * (ad + n - 1) * (1.0 + ad - bd + n - 1) * invNegZ / n;
        if (n > 2 && next.abs() >= term.abs()) break;
        term = next;
        sum += term;
        if (term.abs() < 1e-15 * sum.abs()) break;
      }
      final numG = logAbsGammaWithSign(bd);
      final denG = logAbsGammaWithSign(bMinusA);
      if (numG.sign == 0 || denG.sign == 0) return double.nan;
      final logPref = numG.logAbs - denG.logAbs - ad * log(-zd);
      final sign = numG.sign * denG.sign;
      return sign * exp(logPref) * sum;
    }
    return exp(zd) * hypergeometric1F1(bd - ad, bd, -zd);
  }
  var sum = 1.0;
  var term = 1.0;
  for (var stepIdx = 1; stepIdx <= 1500; stepIdx++) {
    term *= (ad + stepIdx - 1) / (bd + stepIdx - 1) * zd / stepIdx;
    sum += term;
    if (!sum.isFinite) break;
    if (term.abs() < 1.0e-15 * sum.abs()) {
      break;
    }
  }
  return sum;
}

/// Returns the complex confluent hypergeometric function `1F1(a; b; z)`.
///
/// See https://en.wikipedia.org/wiki/Confluent_hypergeometric_function for
/// details.
Complex hypergeometric1F1Complex(Complex a, Complex b, Complex z) {
  if (a.isNaN || b.isNaN || z.isNaN) return Complex.nan;
  if (!a.a.isFinite ||
      !a.b.isFinite ||
      !b.a.isFinite ||
      !b.b.isFinite ||
      !z.a.isFinite ||
      !z.b.isFinite) {
    return Complex.nan;
  }
  final isANonPosInt = _isComplexNonPosInt(a);
  final isBNonPosInt = _isComplexNonPosInt(b);
  if (isANonPosInt) {
    final n = (-a.a).round();
    if (isBNonPosInt && (-b.a).round() < n) {
      return Complex.nan;
    }
    if ((z.a == 0.0 && z.b == 0.0) || n == 0) return Complex.one;
    var sum = Complex.one;
    var term = Complex.one;
    for (var k = 1; k <= n; k++) {
      term *=
          (a + Complex((k - 1).toDouble())) /
          (b + Complex((k - 1).toDouble())) *
          z /
          Complex(k.toDouble());
      sum += term;
    }
    return sum;
  }
  if (isBNonPosInt) {
    return Complex.nan;
  }
  if (z.a == 0.0 && z.b == 0.0) return Complex.one;
  if (z.a < 0.0) {
    return z.exp() * hypergeometric1F1Complex(b - a, b, -z);
  }
  var sum = Complex.one;
  var term = Complex.one;
  for (var k = 1; k <= 1500; k++) {
    term *=
        (a + Complex((k - 1).toDouble())) /
        (b + Complex((k - 1).toDouble())) *
        z /
        Complex(k.toDouble());
    sum += term;
    if (!sum.a.isFinite || !sum.b.isFinite) break;
    if (term.abs() < 1e-15 * sum.abs()) break;
  }
  return sum;
}

/// Returns the Gauss hypergeometric function `2F1(a, b; c; z)`.
///
/// Defined for `z <= 1` (and for all real `z` when terminating as a polynomial
/// in `z`). Uses Pfaff and Euler transformations near `z < -0.5` and `z ≈ 1`
/// to preserve convergence and numerical stability.
///
/// See https://en.wikipedia.org/wiki/Hypergeometric_function for details.
double hypergeometric2F1(num a, num b, num c, num z) {
  if (a.isNaN || b.isNaN || c.isNaN || z.isNaN) {
    return double.nan;
  }
  var ad = a.toDouble();
  var bd = b.toDouble();
  final cd = c.toDouble();
  final zd = z.toDouble();
  if (!ad.isFinite || !bd.isFinite || !cd.isFinite) {
    return double.nan;
  }
  final isANonPosInt = _isNonPosInt(ad);
  final isBNonPosInt = _isNonPosInt(bd);
  final isCNonPosInt = _isNonPosInt(cd);
  if (isANonPosInt || isBNonPosInt) {
    final int n;
    if (isANonPosInt && isBNonPosInt) {
      n = min((-ad).round(), (-bd).round());
    } else if (isANonPosInt) {
      n = (-ad).round();
    } else {
      n = (-bd).round();
    }
    if (isCNonPosInt && (-cd).round() < n) {
      return double.nan;
    }
    if (zd == 0.0 || n == 0) return 1.0;
    var sum = 1.0;
    var term = 1.0;
    for (var stepIdx = 1; stepIdx <= n; stepIdx++) {
      term *=
          (ad + stepIdx - 1) *
          (bd + stepIdx - 1) /
          (cd + stepIdx - 1) *
          zd /
          stepIdx;
      sum += term;
    }
    return sum;
  }
  if (isCNonPosInt) {
    return double.nan;
  }
  if (zd == 0.0) return 1.0;
  if (zd > 1.0) {
    return double.nan;
  }
  if (ad > bd) {
    final tmp = ad;
    ad = bd;
    bd = tmp;
  }
  if (zd < -0.5) {
    if (zd == double.negativeInfinity) {
      if (ad > 0.0) return 0.0;
      if (ad == bd) {
        if (_isNonPosInt(cd - ad)) return 0.0;
        final gC = logAbsGammaWithSign(cd);
        final gA = logAbsGammaWithSign(ad);
        final gCA = logAbsGammaWithSign(cd - ad);
        final sign = gC.sign * gA.sign * gCA.sign;
        return sign * double.infinity;
      }
      final f1 = hypergeometric2F1(ad, cd - bd, cd, 1.0);
      if (f1.isNaN) return double.nan;
      if (f1 == 0.0) return 0.0;
      return f1 > 0.0 ? double.infinity : double.negativeInfinity;
    }
    final wVal = zd / (zd - 1.0);
    return pow(1.0 - zd, -ad) * hypergeometric2F1(ad, cd - bd, cd, wVal);
  }
  if (zd == 1.0) {
    final diff = cd - ad - bd;
    if (diff <= 0.0) {
      final gC = logAbsGammaWithSign(cd);
      final gA = logAbsGammaWithSign(ad);
      final gB = logAbsGammaWithSign(bd);
      final sign = gC.sign * gA.sign * gB.sign;
      return sign == 0 ? double.nan : sign * double.infinity;
    }
    if (_isNonPosInt(cd - ad) || _isNonPosInt(cd - bd)) {
      return 0.0;
    }
    return _gammaRatio4(cd, diff, cd - ad, cd - bd);
  }
  if (zd >= 0.9) {
    final diff = cd - ad - bd;
    final roundedDiff = diff.roundToDouble();
    if (diff.isFinite && (diff - roundedDiff).abs() <= 1e-10) {
      final m = roundedDiff.round();
      if (m < 0) {
        return pow(1.0 - zd, roundedDiff) *
            hypergeometric2F1(cd - ad, cd - bd, cd, zd);
      }
      return _hypergeometric2F1Logarithmic(ad, bd, cd, m, zd);
    }
    final term1 = (_isNonPosInt(cd - ad) || _isNonPosInt(cd - bd))
        ? 0.0
        : _gammaRatio4(cd, diff, cd - ad, cd - bd) *
              hypergeometric2F1(ad, bd, ad + bd - cd + 1.0, 1.0 - zd);
    final term2 =
        _gammaRatio4(cd, -diff, ad, bd) *
        pow(1.0 - zd, diff) *
        hypergeometric2F1(cd - ad, cd - bd, cd - ad - bd + 1.0, 1.0 - zd);
    return term1 + term2;
  }
  return _hypergeometric2F1Direct(ad, bd, cd, zd);
}

/// Returns the complex Gauss hypergeometric function `2F1(a, b; c; z)`.
///
/// See https://en.wikipedia.org/wiki/Hypergeometric_function for details.
Complex hypergeometric2F1Complex(Complex a, Complex b, Complex c, Complex z) {
  if (a.isNaN || b.isNaN || c.isNaN || z.isNaN) return Complex.nan;
  if (!a.a.isFinite ||
      !a.b.isFinite ||
      !b.a.isFinite ||
      !b.b.isFinite ||
      !c.a.isFinite ||
      !c.b.isFinite ||
      !z.a.isFinite ||
      !z.b.isFinite) {
    return Complex.nan;
  }
  final isANonPosInt = _isComplexNonPosInt(a);
  final isBNonPosInt = _isComplexNonPosInt(b);
  final isCNonPosInt = _isComplexNonPosInt(c);
  if (isANonPosInt || isBNonPosInt) {
    final int n;
    if (isANonPosInt && isBNonPosInt) {
      n = min((-a.a).round(), (-b.a).round());
    } else if (isANonPosInt) {
      n = (-a.a).round();
    } else {
      n = (-b.a).round();
    }
    if (isCNonPosInt && (-c.a).round() < n) {
      return Complex.nan;
    }
    if ((z.a == 0.0 && z.b == 0.0) || n == 0) return Complex.one;
    var sum = Complex.one;
    var term = Complex.one;
    for (var k = 1; k <= n; k++) {
      term *=
          (a + Complex((k - 1).toDouble())) *
          (b + Complex((k - 1).toDouble())) /
          (c + Complex((k - 1).toDouble())) *
          z /
          Complex(k.toDouble());
      sum += term;
    }
    return sum;
  }
  if (isCNonPosInt) {
    return Complex.nan;
  }
  z = _normalizeZero(z);
  if (z.a == 0.0 && z.b == 0.0) return Complex.one;
  if (z.abs() >= 0.8) {
    final w = _normalizeZero(z / (z - Complex.one));
    if (w.abs() < 0.8) {
      return _normalizeZero(Complex.one - z).pow(-a) *
          hypergeometric2F1Complex(a, c - b, c, w);
    }
    final oneMinusZ = _normalizeZero(Complex.one - z);
    if (oneMinusZ.abs() < 0.8) {
      final diff = c - a - b;
      if (_isNearRealInt(diff)) {
        final m = diff.a.round();
        if (m < 0) {
          return oneMinusZ.pow(Complex(m.toDouble())) *
              hypergeometric2F1Complex(c - a, c - b, c, z);
        }
        return _hypergeometric2F1LogarithmicComplex(a, b, c, m, oneMinusZ);
      }
      final t1 = (_isComplexNonPosInt(c - a) || _isComplexNonPosInt(c - b))
          ? Complex.zero
          : gammaComplex(c) *
                gammaComplex(diff) /
                (gammaComplex(c - a) * gammaComplex(c - b)) *
                hypergeometric2F1Complex(
                  a,
                  b,
                  a + b - c + Complex.one,
                  oneMinusZ,
                );
      final t2 = (_isComplexNonPosInt(a) || _isComplexNonPosInt(b))
          ? Complex.zero
          : gammaComplex(c) *
                gammaComplex(-diff) /
                (gammaComplex(a) * gammaComplex(b)) *
                oneMinusZ.pow(diff) *
                hypergeometric2F1Complex(
                  c - a,
                  c - b,
                  c - a - b + Complex.one,
                  oneMinusZ,
                );
      return t1 + t2;
    }
    if (z.abs() > 1.25) {
      final abDiff = a - b;
      if (_isNearRealInt(abDiff)) {
        return _hypergeometric2F1InvLogarithmicComplex(a, b, c, z);
      }
      final invZ = _normalizeZero(z.reciprocal());
      final negZ = _normalizeZero(-z);
      final t1 = (_isComplexNonPosInt(b) || _isComplexNonPosInt(c - a))
          ? Complex.zero
          : gammaComplex(c) *
                gammaComplex(-abDiff) /
                (gammaComplex(b) * gammaComplex(c - a)) *
                negZ.pow(-a) *
                hypergeometric2F1Complex(
                  a,
                  a - c + Complex.one,
                  abDiff + Complex.one,
                  invZ,
                );
      final t2 = (_isComplexNonPosInt(a) || _isComplexNonPosInt(c - b))
          ? Complex.zero
          : gammaComplex(c) *
                gammaComplex(abDiff) /
                (gammaComplex(a) * gammaComplex(c - b)) *
                negZ.pow(-b) *
                hypergeometric2F1Complex(
                  b,
                  b - c + Complex.one,
                  -abDiff + Complex.one,
                  invZ,
                );
      return t1 + t2;
    }
    return _hypergeometric2F1OdeTaylorComplex(a, b, c, z);
  }
  var sum = Complex.one;
  var term = Complex.one;
  for (var k = 1; k <= 1500; k++) {
    term *=
        (a + Complex((k - 1).toDouble())) *
        (b + Complex((k - 1).toDouble())) /
        (c + Complex((k - 1).toDouble())) *
        z /
        Complex(k.toDouble());
    sum += term;
    if (term.abs() < 1e-15 * sum.abs()) break;
  }
  return sum;
}

/// Evaluates the generalized hypergeometric function `pFq(a; b; z)`.
///
/// See https://en.wikipedia.org/wiki/Generalized_hypergeometric_function for
/// details.
double hypergeometricPFQ(List<num> a, List<num> b, num z) {
  if (z.isNaN || a.any((v) => v.isNaN) || b.any((v) => v.isNaN)) {
    return double.nan;
  }
  if (a.isEmpty && b.isEmpty) return exp(z.toDouble());
  if (a.length == 1 && b.isEmpty) {
    return pow(1.0 - z.toDouble(), -a[0].toDouble()).toDouble();
  }
  if (a.length == 2 && b.length == 1) {
    return hypergeometric2F1(a[0], a[1], b[0], z);
  }
  if (a.length == 1 && b.length == 1) {
    return hypergeometric1F1(a[0], b[0], z);
  }

  var minTermDegree = -1;
  for (final ai in a) {
    final ad = ai.toDouble();
    if (_isNonPosInt(ad)) {
      final deg = (-ad).round();
      if (minTermDegree < 0 || deg < minTermDegree) minTermDegree = deg;
    }
  }
  for (final bj in b) {
    final bd = bj.toDouble();
    if (_isNonPosInt(bd)) {
      final poleDeg = (-bd).round();
      if (minTermDegree < 0 || poleDeg < minTermDegree) {
        return double.nan;
      }
    }
  }

  final zd = z.toDouble();
  if (zd == 0.0) return 1.0;
  var sum = 1.0;
  var term = 1.0;
  for (var k = 0; k < 400; k++) {
    var numProd = 1.0;
    for (final ai in a) {
      numProd *= ai.toDouble() + k;
    }
    if (numProd == 0.0) break;
    var denProd = (k + 1).toDouble();
    for (final bj in b) {
      final denom = bj.toDouble() + k;
      if (denom == 0.0) return double.nan;
      denProd *= denom;
    }
    term *= numProd * zd / denProd;
    sum += term;
    if (term.abs() <= 1e-15 * sum.abs()) break;
  }
  return sum;
}

/// Evaluates the complex generalized hypergeometric function `pFq(a; b; z)`.
///
/// See https://en.wikipedia.org/wiki/Generalized_hypergeometric_function for
/// details.
Complex hypergeometricPFQComplex(List<Complex> a, List<Complex> b, Complex z) {
  if (z.isNaN || a.any((v) => v.isNaN) || b.any((v) => v.isNaN)) {
    return Complex.nan;
  }
  if (a.isEmpty && b.isEmpty) return z.exp();
  if (a.length == 1 && b.isEmpty) return (Complex.one - z).pow(-a[0]);
  if (a.length == 2 && b.length == 1) {
    return hypergeometric2F1Complex(a[0], a[1], b[0], z);
  }
  if (a.length == 1 && b.length == 1) {
    return hypergeometric1F1Complex(a[0], b[0], z);
  }

  var minTermDegree = -1;
  for (final ai in a) {
    if (_isComplexNonPosInt(ai)) {
      final deg = (-ai.a).round();
      if (minTermDegree < 0 || deg < minTermDegree) minTermDegree = deg;
    }
  }
  for (final bj in b) {
    if (_isComplexNonPosInt(bj)) {
      final poleDeg = (-bj.a).round();
      if (minTermDegree < 0 || poleDeg < minTermDegree) {
        return Complex.nan;
      }
    }
  }

  if (z == Complex.zero) return Complex.one;
  var sum = Complex.one;
  var term = Complex.one;
  for (var k = 0; k < 400; k++) {
    var numProd = Complex.one;
    for (final ai in a) {
      numProd *= ai + k.toDouble();
    }
    if (numProd == Complex.zero) break;
    var denProd = Complex((k + 1).toDouble());
    for (final bj in b) {
      final denom = bj + k.toDouble();
      if (denom == Complex.zero) return Complex.nan;
      denProd *= denom;
    }
    term *= numProd * z / denProd;
    sum += term;
    if (term.abs() <= 1e-15 * sum.abs()) break;
  }
  return sum;
}

bool _isNonPosInt(double x) => x.isFinite && x <= 0.0 && x.roundToDouble() == x;

bool _isComplexNonPosInt(Complex z) =>
    z.b == 0.0 && z.a.isFinite && z.a <= 0.0 && z.a == z.a.roundToDouble();

double _gammaRatio4(double n1, double n2, double d1, double d2) {
  final gN1 = logAbsGammaWithSign(n1);
  final gN2 = logAbsGammaWithSign(n2);
  final gD1 = logAbsGammaWithSign(d1);
  final gD2 = logAbsGammaWithSign(d2);
  if (gN1.sign == 0 || gN2.sign == 0) return double.nan;
  if (gD1.sign == 0 || gD2.sign == 0) return 0.0;
  final logVal = gN1.logAbs + gN2.logAbs - gD1.logAbs - gD2.logAbs;
  final sign = gN1.sign * gN2.sign * gD1.sign * gD2.sign;
  return logVal > 709.782712893384
      ? sign * double.infinity
      : sign * exp(logVal);
}

double _hypergeometric2F1Logarithmic(
  double a,
  double b,
  double cVal,
  int m,
  double z,
) {
  final oneMinusZ = 1.0 - z;
  var finiteSum = 0.0;
  if (m > 0) {
    var poly = 1.0;
    var term = 1.0;
    for (var n = 1; n < m; n++) {
      term *= (a + n - 1) * (b + n - 1) / (n * (n - m)) * oneMinusZ;
      poly += term;
    }
    finiteSum = _gammaRatio4(m.toDouble(), cVal, a + m, b + m) * poly;
  }
  if (_isNonPosInt(a + m) || _isNonPosInt(b + m)) {
    return finiteSum;
  }
  final gC = logAbsGammaWithSign(cVal);
  final gA = logAbsGammaWithSign(a);
  final gB = logAbsGammaWithSign(b);
  if (gC.sign == 0) return double.nan;
  if (gA.sign == 0 || gB.sign == 0) return finiteSum;
  final gammaRatio =
      gC.sign * gA.sign * gB.sign * exp(gC.logAbs - gA.logAbs - gB.logAbs);
  final infPrefactor = (m.isEven ? -1.0 : 1.0) * gammaRatio * pow(oneMinusZ, m);
  final lnOneMinusZ = log(oneMinusZ);
  var coeff = exp(-gammaLn(m + 1.0));
  var psiN1 = digamma(1.0);
  var psiNM1 = digamma(m + 1.0);
  var psiA = digamma(a + m);
  var psiB = digamma(b + m);
  var infSum = coeff * (lnOneMinusZ - psiN1 - psiNM1 + psiA + psiB);
  for (var n = 0; n < 2000; n++) {
    final n1 = n + 1;
    final nm1 = n + m + 1;
    final amn = a + m + n;
    final bmn = b + m + n;
    coeff *= amn * bmn / (n1 * nm1) * oneMinusZ;
    psiN1 += 1.0 / n1;
    psiNM1 += 1.0 / nm1;
    psiA += 1.0 / amn;
    psiB += 1.0 / bmn;
    final term = coeff * (lnOneMinusZ - psiN1 - psiNM1 + psiA + psiB);
    infSum += term;
    if (term.abs() < 1.0e-15 * infSum.abs()) {
      break;
    }
  }
  return finiteSum + infPrefactor * infSum;
}

Complex _hypergeometric2F1LogarithmicComplex(
  Complex a,
  Complex b,
  Complex c,
  int m,
  Complex oneMinusZ,
) {
  var finiteSum = Complex.zero;
  if (m > 0) {
    var poly = Complex.one;
    var term = Complex.one;
    for (var n = 1; n < m; n++) {
      term *=
          (a + Complex((n - 1).toDouble())) *
          (b + Complex((n - 1).toDouble())) /
          Complex((n * (n - m)).toDouble()) *
          oneMinusZ;
      poly += term;
    }
    final pre =
        (gammaLnComplex(Complex(m.toDouble())) +
                gammaLnComplex(c) -
                gammaLnComplex(a + m.toDouble()) -
                gammaLnComplex(b + m.toDouble()))
            .exp();
    finiteSum = pre * poly;
  }
  if ((_isNearRealInt(a + m.toDouble()) && (a.a + m).round() <= 0) ||
      (_isNearRealInt(b + m.toDouble()) && (b.a + m).round() <= 0)) {
    return finiteSum;
  }
  final gammaRatio = gammaComplex(c) / (gammaComplex(a) * gammaComplex(b));
  final infPrefactor =
      Complex(m.isEven ? -1.0 : 1.0) *
      gammaRatio *
      oneMinusZ.pow(Complex(m.toDouble()));
  final lnOneMinusZ = oneMinusZ.log();
  var coeff = Complex(exp(-gammaLn(m + 1.0)));
  var psiN1 = Complex(digamma(1.0));
  var psiNM1 = Complex(digamma(m + 1.0));
  var psiA = digammaComplex(a + m.toDouble());
  var psiB = digammaComplex(b + m.toDouble());
  var infSum = coeff * (lnOneMinusZ - psiN1 - psiNM1 + psiA + psiB);
  for (var n = 0; n < 2000; n++) {
    final n1 = n + 1;
    final nm1 = n + m + 1;
    final amn = a + (m + n).toDouble();
    final bmn = b + (m + n).toDouble();
    coeff *= amn * bmn / Complex((n1 * nm1).toDouble()) * oneMinusZ;
    psiN1 += 1.0 / n1;
    psiNM1 += 1.0 / nm1;
    psiA += amn.reciprocal();
    psiB += bmn.reciprocal();
    final term = coeff * (lnOneMinusZ - psiN1 - psiNM1 + psiA + psiB);
    infSum += term;
    if (term.abs() < 1e-15 * infSum.abs()) break;
  }
  return finiteSum + infPrefactor * infSum;
}

Complex _normalizeZero(Complex z) =>
    Complex(z.a == 0.0 ? 0.0 : z.a, z.b == 0.0 ? 0.0 : z.b);

bool _isNearRealInt(Complex z, [double tol = 1e-10]) =>
    z.b.abs() <= tol &&
    z.a.isFinite &&
    (z.a - z.a.roundToDouble()).abs() <= tol;

Complex _hypergeometric2F1InvLogarithmicComplex(
  Complex a,
  Complex b,
  Complex c,
  Complex z,
) {
  final rawDiff = (b - a).a.round();
  if (rawDiff < 0) {
    return _hypergeometric2F1InvLogarithmicComplex(b, a, c, z);
  }
  final m = rawDiff;
  final bVal = a + Complex(m.toDouble());
  final ca = c - a;
  final cb = c - bVal;
  if (_isNearRealInt(cb) && cb.a.round() <= 0) {
    final q = cb.a.round();
    final caArg = (_isNearRealInt(ca) && ca.a.round() <= 0)
        ? Complex(ca.a.roundToDouble())
        : ca;
    return _normalizeZero(Complex.one - z).pow(c - a - b) *
        hypergeometric2F1Complex(caArg, Complex(q.toDouble()), c, z);
  }
  if (_isNearRealInt(ca) && ca.a.round() <= 0) {
    final q = ca.a.round();
    return _normalizeZero(Complex.one - z).pow(c - a - b) *
        hypergeometric2F1Complex(Complex(q.toDouble()), cb, c, z);
  }

  final invZ = _normalizeZero(z.reciprocal());
  final negZ = _normalizeZero(-z);
  final invNegZ = _normalizeZero(negZ.reciprocal());

  var finiteSum = Complex.zero;
  if (m > 0) {
    var poly = Complex.one;
    var term = Complex.one;
    for (var k = 0; k < m - 1; k++) {
      term *=
          (a + k.toDouble()) *
          (Complex.one + a - c + k.toDouble()) /
          Complex(((k + 1) * (m - 1 - k)).toDouble()) *
          invNegZ;
      poly += term;
    }
    final pre =
        (gammaLnComplex(Complex(m.toDouble())) +
                gammaLnComplex(c) -
                gammaLnComplex(bVal) -
                gammaLnComplex(ca))
            .exp() *
        negZ.pow(-a);
    finiteSum = pre * poly;
  }

  final lnNegZ = negZ.log();
  final signM = Complex(m.isEven ? 1.0 : -1.0);
  final negZPowNegB = negZ.pow(-bVal);

  var infSum = Complex.zero;
  if (_isNearRealInt(cb) && cb.a.round() >= 1) {
    final kInt = cb.a.round();
    var coeff =
        signM *
        (gammaLnComplex(c) -
                gammaLnComplex(a) -
                gammaLnComplex(bVal) -
                gammaLnComplex(Complex(kInt.toDouble())) -
                gammaLnComplex(Complex((m + 1).toDouble())))
            .exp() *
        negZPowNegB;
    var h =
        lnNegZ +
        Complex(digamma(m + 1.0) + digamma(1.0) - digamma(kInt.toDouble())) -
        digammaComplex(bVal);
    for (var j = 0; j < kInt; j++) {
      infSum += coeff * h;
      if (j + 1 < kInt) {
        coeff *=
            (bVal + j.toDouble()) *
            Complex((1 - kInt + j).toDouble()) /
            Complex(((m + j + 1) * (j + 1)).toDouble()) *
            invZ;
        h +=
            Complex(1.0 / (m + j + 1) + 1.0 / (j + 1) - 1.0 / (1 - kInt + j)) -
            (bVal + j.toDouble()).reciprocal();
      }
    }
    var tailTerm =
        signM *
        (gammaLnComplex(c) +
                gammaLnComplex(bVal + kInt.toDouble()) -
                gammaLnComplex(a) -
                gammaLnComplex(bVal) -
                gammaLnComplex(Complex((m + kInt + 1).toDouble())) -
                gammaLnComplex(Complex((kInt + 1).toDouble())))
            .exp() *
        negZ.pow(-bVal - kInt.toDouble());
    for (var j = kInt; j < kInt + 2000; j++) {
      infSum += tailTerm;
      tailTerm *=
          Complex((j - kInt + 1).toDouble()) *
          (bVal + j.toDouble()) /
          Complex(((m + j + 1) * (j + 1)).toDouble()) *
          invZ;
      if (tailTerm.abs() <= 1e-15 * infSum.abs()) break;
    }
    return finiteSum + infSum;
  }

  var coeff =
      signM *
      (gammaLnComplex(c) -
              gammaLnComplex(a) -
              gammaLnComplex(bVal) -
              gammaLnComplex(cb) -
              gammaLnComplex(Complex((m + 1).toDouble())))
          .exp() *
      negZPowNegB;
  var h =
      lnNegZ +
      Complex(digamma(m + 1.0) + digamma(1.0)) -
      digammaComplex(bVal) -
      digammaComplex(cb);
  infSum = coeff * h;
  for (var j = 0; j < 2000; j++) {
    coeff *=
        (bVal + j.toDouble()) *
        (Complex.one - cb + j.toDouble()) /
        Complex(((m + j + 1) * (j + 1)).toDouble()) *
        invZ;
    h +=
        Complex(1.0 / (m + j + 1) + 1.0 / (j + 1)) -
        (bVal + j.toDouble()).reciprocal() -
        (Complex.one - cb + j.toDouble()).reciprocal();
    final term = coeff * h;
    infSum += term;
    if (term.abs() <= 1e-15 * infSum.abs()) break;
  }
  return finiteSum + infSum;
}

Complex _hypergeometric2F1OdeTaylorComplex(
  Complex a,
  Complex b,
  Complex c,
  Complex z,
) {
  final z0 = Complex(0.5, z.b >= 0.0 ? 0.5 : -0.5);
  var f = hypergeometric2F1Complex(a, b, c, z0);
  if (f.isNaN) return Complex.nan;
  var df =
      (a * b / c) *
      hypergeometric2F1Complex(
        a + Complex.one,
        b + Complex.one,
        c + Complex.one,
        z0,
      );
  if (df.isNaN) return Complex.nan;

  final totalDist = (z - z0).abs();
  final steps = totalDist == 0.0 ? 1 : (totalDist / 0.3).ceil().clamp(1, 6);
  final dz = (z - z0) / steps.toDouble();
  var curZ = z0;
  final abSum1 = a + b + Complex.one;

  for (var s = 0; s < steps; s++) {
    var c0 = f;
    var c1 = df;
    var sumF = c0 + c1 * dz;
    var sumDf = c1;
    var dzPow = dz;
    final p0 = curZ * (Complex.one - curZ);
    final q0 = c - abSum1 * curZ;
    final twoZMinus1 = const Complex(2.0) * curZ - Complex.one;
    var smallCount = 0;

    for (var n = 0; n < 120; n++) {
      final cNext =
          ((twoZMinus1 * n.toDouble() - q0) * (n + 1).toDouble() * c1 +
              (a + n.toDouble()) * (b + n.toDouble()) * c0) /
          (p0 * ((n + 1) * (n + 2)).toDouble());
      final termDf = cNext * (n + 2).toDouble() * dzPow;
      dzPow *= dz;
      final termF = cNext * dzPow;
      sumF += termF;
      sumDf += termDf;
      c0 = c1;
      c1 = cNext;
      if (termF.abs() <= 1e-16 * sumF.abs() &&
          termDf.abs() <= 1e-16 * sumDf.abs()) {
        smallCount++;
        if (smallCount >= 2 && n >= 6) break;
      } else {
        smallCount = 0;
      }
    }
    f = sumF;
    df = sumDf;
    curZ += dz;
  }
  return f;
}

double _hypergeometric2F1Direct(double a, double b, double c, double z) {
  var sum = 1.0;
  var term = 1.0;
  for (var stepIdx = 1; stepIdx <= 2000; stepIdx++) {
    term *=
        (a + stepIdx - 1) * (b + stepIdx - 1) / (c + stepIdx - 1) * z / stepIdx;
    sum += term;
    if (term.abs() < 1.0e-15 * sum.abs()) {
      break;
    }
  }
  return sum;
}
