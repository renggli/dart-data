import 'dart:math';

import 'digamma.dart';
import 'gamma.dart';

/// Returns the confluent hypergeometric function $_1F_1(a; b; z)$ (also known
/// as Kummer's function $M(a, b, z)$).
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
  if (zd.isInfinite) {
    return double.nan;
  }
  final isANonPosInt = ad.isFinite && ad <= 0.0 && ad.roundToDouble() == ad;
  final isBNonPosInt = bd.isFinite && bd <= 0.0 && bd.roundToDouble() == bd;
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
    // Kummer's first transformation: 1F1(a, b, z) = exp(z) * 1F1(b - a, b, -z)
    return exp(zd) * hypergeometric1F1(bd - ad, bd, -zd);
  }
  var sum = 1.0;
  var term = 1.0;
  for (var stepIdx = 1; stepIdx <= 1500; stepIdx++) {
    term *= (ad + stepIdx - 1) / (bd + stepIdx - 1) * zd / stepIdx;
    sum += term;
    if (term.abs() < 1.0e-15 * sum.abs()) {
      break;
    }
  }
  return sum;
}

/// Returns the Gauss hypergeometric function $_2F_1(a, b; c; z)$.
///
/// Handles transformations for $z < -1$ and $z \approx 1$ to ensure rapid
/// convergence.
///
/// See https://en.wikipedia.org/wiki/Hypergeometric_function for details.
double hypergeometric2F1(num a, num b, num cVal, num z) {
  if (a.isNaN || b.isNaN || cVal.isNaN || z.isNaN) {
    return double.nan;
  }
  final ad = a.toDouble();
  final bd = b.toDouble();
  final cd = cVal.toDouble();
  final zd = z.toDouble();
  final isANonPosInt = ad.isFinite && ad <= 0.0 && ad.roundToDouble() == ad;
  final isBNonPosInt = bd.isFinite && bd <= 0.0 && bd.roundToDouble() == bd;
  final isCNonPosInt = cd.isFinite && cd <= 0.0 && cd.roundToDouble() == cd;
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
  if (zd < -0.5) {
    final wVal = zd / (zd - 1.0);
    return pow(1.0 - zd, -ad) * hypergeometric2F1(ad, cd - bd, cd, wVal);
  }
  if (zd == 1.0) {
    final diff = cd - ad - bd;
    if (diff <= 0.0) {
      return double.infinity;
    }
    if (_isNonPosInt(cd - ad) || _isNonPosInt(cd - bd)) {
      return 0.0;
    }
    return gamma(cd) * gamma(diff) / (gamma(cd - ad) * gamma(cd - bd));
  }
  if (zd >= 0.9) {
    final diff = cd - ad - bd;
    if (diff.isFinite && diff.roundToDouble() == diff) {
      final m = diff.round();
      if (m < 0) {
        return pow(1.0 - zd, diff) *
            hypergeometric2F1(cd - ad, cd - bd, cd, zd);
      }
      return _hypergeometric2F1Logarithmic(ad, bd, cd, m, zd);
    }
    final term1 = (_isNonPosInt(cd - ad) || _isNonPosInt(cd - bd))
        ? 0.0
        : gamma(cd) *
              gamma(diff) /
              (gamma(cd - ad) * gamma(cd - bd)) *
              hypergeometric2F1(ad, bd, ad + bd - cd + 1.0, 1.0 - zd);
    final term2 =
        gamma(cd) *
        gamma(-diff) /
        (gamma(ad) * gamma(bd)) *
        pow(1.0 - zd, diff) *
        hypergeometric2F1(cd - ad, cd - bd, cd - ad - bd + 1.0, 1.0 - zd);
    return term1 + term2;
  }
  return _hypergeometric2F1Direct(ad, bd, cd, zd);
}

bool _isNonPosInt(double x) => x.isFinite && x <= 0.0 && x.roundToDouble() == x;

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
    final finitePrefactor = (a + m > 0 && b + m > 0 && cVal > 0)
        ? exp(gammaLn(m) + gammaLn(cVal) - gammaLn(a + m) - gammaLn(b + m))
        : gamma(m) * gamma(cVal) / (gamma(a + m) * gamma(b + m));
    finiteSum = finitePrefactor * poly;
  }
  final gammaRatio = (a > 0 && b > 0 && cVal > 0)
      ? exp(gammaLn(cVal) - gammaLn(a) - gammaLn(b))
      : gamma(cVal) / (gamma(a) * gamma(b));
  final infPrefactor = (m.isEven ? -1.0 : 1.0) * gammaRatio * pow(oneMinusZ, m);
  final lnOneMinusZ = log(oneMinusZ);
  var coeff = 1.0 / factorial(m);
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

double _hypergeometric2F1Direct(double a, double b, double cVal, double z) {
  var sum = 1.0;
  var term = 1.0;
  for (var stepIdx = 1; stepIdx <= 2000; stepIdx++) {
    term *=
        (a + stepIdx - 1) *
        (b + stepIdx - 1) /
        (cVal + stepIdx - 1) *
        z /
        stepIdx;
    sum += term;
    if (term.abs() < 1.0e-15 * sum.abs()) {
      break;
    }
  }
  return sum;
}
