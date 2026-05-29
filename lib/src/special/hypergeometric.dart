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
  for (var n = 1; n <= 1500; n++) {
    term *= (ad + n - 1) / (bd + n - 1) * zd / n;
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
double hypergeometric2F1(num a, num b, num c, num z) {
  if (a.isNaN || b.isNaN || c.isNaN || z.isNaN || c == 0.0) {
    return double.nan;
  }
  if (c <= 0.0 && c.roundToDouble() == c) {
    return double.nan;
  }
  if (z == 0.0) return 1.0;
  final ad = a.toDouble();
  final bd = b.toDouble();
  final cd = c.toDouble();
  final zd = z.toDouble();
  if (zd > 1.0) {
    return double.nan;
  }
  if (zd <= -1.0) {
    final w = zd / (zd - 1.0);
    return pow(1.0 - zd, -ad) * hypergeometric2F1(ad, cd - bd, cd, w);
  }
  if (zd == 1.0) {
    final d = cd - ad - bd;
    if (d <= 0.0) {
      return double.infinity;
    }
    return gamma(cd) * gamma(d) / (gamma(cd - ad) * gamma(cd - bd));
  }
  if (zd >= 0.9) {
    final d = cd - ad - bd;
    if (d.roundToDouble() == d) {
      return _hypergeometric2F1Direct(ad, bd, cd, zd);
    }
    final term1 =
        gamma(cd) *
        gamma(d) /
        (gamma(cd - ad) * gamma(cd - bd)) *
        hypergeometric2F1(ad, bd, ad + bd - cd + 1.0, 1.0 - zd);
    final term2 =
        gamma(cd) *
        gamma(-d) /
        (gamma(ad) * gamma(bd)) *
        pow(1.0 - zd, d) *
        hypergeometric2F1(cd - ad, cd - bd, cd - ad - bd + 1.0, 1.0 - zd);
    return term1 + term2;
  }
  return _hypergeometric2F1Direct(ad, bd, cd, zd);
}

// Helper function for direct hypergeometric series summation
double _hypergeometric2F1Direct(double a, double b, double c, double z) {
  var sum = 1.0;
  var term = 1.0;
  for (var n = 1; n <= 2000; n++) {
    term *= (a + n - 1) * (b + n - 1) / (c + n - 1) * z / n;
    sum += term;
    if (term.abs() < 1.0e-15 * sum.abs()) {
      break;
    }
  }
  return sum;
}
