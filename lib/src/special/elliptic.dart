import 'dart:math';

/// Returns the complete elliptic integral of the first kind $K(k)$.
///
/// Defined for $-1 \le k \le 1$.
///
/// See https://en.wikipedia.org/wiki/Elliptic_integral for details.
double ellipticK(num k) {
  if (k.isNaN || k.abs() > 1.0) {
    return double.nan;
  }
  final kd = k.toDouble();
  if (kd.abs() == 1.0) {
    return double.infinity;
  }
  if (kd == 0.0) {
    return pi / 2.0;
  }
  var a = 1.0;
  var b = sqrt(1.0 - kd * kd);
  for (var i = 0; i < 20; i++) {
    final aNext = 0.5 * (a + b);
    final bNext = sqrt(a * b);
    if ((a - b).abs() < 1.0e-15 * a) {
      a = aNext;
      break;
    }
    a = aNext;
    b = bNext;
  }
  return pi / (2.0 * a);
}

/// Returns the complete elliptic integral of the second kind $E(k)$.
///
/// Defined for $-1 \le k \le 1$.
///
/// See https://en.wikipedia.org/wiki/Elliptic_integral for details.
double ellipticE(num k) {
  if (k.isNaN || k.abs() > 1.0) {
    return double.nan;
  }
  final kd = k.toDouble();
  if (kd.abs() == 1.0) {
    return 1.0;
  }
  if (kd == 0.0) {
    return pi / 2.0;
  }
  var a = 1.0;
  var b = sqrt(1.0 - kd * kd);
  var sum = 0.5 * kd * kd;
  var power = 1.0;
  for (var i = 0; i < 20; i++) {
    final aNext = 0.5 * (a + b);
    final bNext = sqrt(a * b);
    final c = a - aNext;
    sum += power * c * c;
    power *= 2.0;
    if ((a - b).abs() < 1.0e-15 * a) {
      a = aNext;
      break;
    }
    a = aNext;
    b = bNext;
  }
  return (pi / (2.0 * a)) * (1.0 - sum);
}
