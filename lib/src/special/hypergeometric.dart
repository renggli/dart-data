import 'dart:math';

import 'gamma.dart';

/// Returns the confluent hypergeometric function $_1F_1(a; b; z)$ (also known
/// as Kummer's function $M(a, b, z)$).
///
/// See https://en.wikipedia.org/wiki/Confluent_hypergeometric_function for details.
double hypergeometric1F1(num a, num b, num z) {
  if (a.isNaN || b.isNaN || z.isNaN || b == 0.0) {
    return double.nan;
  }
  if (b <= 0.0 && b.roundToDouble() == b) {
    return double.nan;
  }
  if (z == 0.0) return 1.0;
  var sum = 1.0;
  var term = 1.0;
  final ad = a.toDouble();
  final bd = b.toDouble();
  final zd = z.toDouble();
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
/// Handles transformations for $z < -1$ and $z \approx 1$ to ensure
/// rapid convergence.
///
/// See https://en.wikipedia.org/wiki/Hypergeometric_function for details.
double hypergeometric2F1(num a, num b, num cVal, num z) {
  if (a.isNaN || b.isNaN || cVal.isNaN || z.isNaN || cVal == 0.0) {
    return double.nan;
  }
  if (cVal <= 0.0 && cVal.roundToDouble() == cVal) {
    return double.nan;
  }
  if (z == 0.0) return 1.0;
  final ad = a.toDouble();
  final bd = b.toDouble();
  final cd = cVal.toDouble();
  final zd = z.toDouble();
  if (zd > 1.0) {
    return double.nan;
  }
  if (zd <= -1.0) {
    final wVal = zd / (zd - 1.0);
    return pow(1.0 - zd, -ad) * hypergeometric2F1(ad, cd - bd, cd, wVal);
  }
  if (zd == 1.0) {
    final diff = cd - ad - bd;
    if (diff <= 0.0) {
      return double.infinity;
    }
    return gamma(cd) * gamma(diff) / (gamma(cd - ad) * gamma(cd - bd));
  }
  if (zd >= 0.9) {
    final diff = cd - ad - bd;
    if (diff.roundToDouble() == diff) {
      return _hypergeometric2F1Direct(ad, bd, cd, zd);
    }
    final term1 =
        gamma(cd) *
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
