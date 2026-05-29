import 'dart:math';

/// Returns the digamma function (also known as the psi function), which is the
/// logarithmic derivative of the gamma function: $\psi(x) = \Gamma'(x)/\Gamma(x)$.
///
/// See https://en.wikipedia.org/wiki/Digamma_function for details.
double digamma(num x) {
  if (x.isNaN) return double.nan;
  if (x.isInfinite) {
    return x.isNegative ? double.nan : double.infinity;
  }
  var value = x.toDouble();
  if (value <= 0.0) {
    if (value.roundToDouble() == value) {
      return double.nan;
    }
    return digamma(1.0 - value) - pi / tan(pi * value);
  }
  var shift = 0.0;
  while (value < 8.0) {
    shift += 1.0 / value;
    value += 1.0;
  }
  final r = 1.0 / value;
  final r2 = r * r;
  final r4 = r2 * r2;
  final r6 = r4 * r2;
  final r8 = r6 * r2;
  final r10 = r8 * r2;
  final result =
      log(value) -
      0.5 * r -
      (1.0 / 12.0) * r2 +
      (1.0 / 120.0) * r4 -
      (1.0 / 252.0) * r6 +
      (1.0 / 240.0) * r8 -
      (5.0 / 660.0) * r10;
  return result - shift;
}

/// Returns the trigamma function, which is the first derivative of the digamma
/// function: $\psi_1(x) = \psi'(x)$.
///
/// See https://en.wikipedia.org/wiki/Trigamma_function for details.
double trigamma(num x) {
  if (x.isNaN) return double.nan;
  if (x.isInfinite) {
    return 0.0;
  }
  var value = x.toDouble();
  if (value <= 0.0) {
    if (value.roundToDouble() == value) {
      return double.nan;
    }
    final s = sin(pi * value);
    return pi * pi / (s * s) - trigamma(1.0 - value);
  }
  var shift = 0.0;
  while (value < 8.0) {
    shift += 1.0 / (value * value);
    value += 1.0;
  }
  final r = 1.0 / value;
  final r2 = r * r;
  final r3 = r2 * r;
  final r5 = r3 * r2;
  final r7 = r5 * r2;
  final r9 = r7 * r2;
  final r11 = r9 * r2;
  final result =
      r +
      0.5 * r2 +
      (1.0 / 6.0) * r3 -
      (1.0 / 30.0) * r5 +
      (1.0 / 42.0) * r7 -
      (1.0 / 30.0) * r9 +
      (5.0 / 66.0) * r11;
  return result + shift;
}
