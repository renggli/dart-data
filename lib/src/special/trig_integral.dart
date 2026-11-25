import 'dart:math';

import 'package:more/number.dart' show Complex;

import 'exp_integral.dart';
import 'utils.dart';

/// Returns the sine integral `Si(x) = ∫_0^x sin(t) / t dt`.
///
/// Odd function with `Si(0) = 0` and `Si(±∞) = ±π / 2`.
///
/// See https://en.wikipedia.org/wiki/Trigonometric_integral for details.
double sinIntegral(num x) {
  if (x.isNaN) return double.nan;
  final xd = x.toDouble();
  if (xd == 0.0) return 0.0;
  if (xd == double.infinity) return pi / 2.0;
  if (xd == double.negativeInfinity) return -pi / 2.0;
  final sign = xd < 0.0 ? -1.0 : 1.0;
  final ax = xd.abs();
  if (ax <= 4.0) return sign * _oddIntegralSeries(ax, alternating: true);
  final e1 = expIntegralE1Complex(Complex(0.0, ax));
  return sign * (pi / 2.0 + e1.b);
}

/// Returns the complex sine integral `Si(z) = ∫_0^z sin(t) / t dt`.
///
/// See https://en.wikipedia.org/wiki/Trigonometric_integral for details.
Complex sinIntegralComplex(Complex z) {
  if (z.isNaN) return Complex.nan;
  if (z.b == 0.0) return Complex(sinIntegral(z.a.toDouble()));
  if (!z.a.isFinite || !z.b.isFinite) return Complex.nan;
  if (z.abs() < 4.0) return _oddIntegralSeriesComplex(z, alternating: true);
  if (z.a < 0.0 || (z.a == 0.0 && z.b < 0.0)) {
    return -sinIntegralComplex(-z);
  }
  final iz = Complex.i * z;
  return const Complex(pi / 2.0) +
      (expIntegralE1Complex(iz) - expIntegralE1Complex(-iz)) /
          const Complex(0.0, 2.0);
}

/// Returns the cosine integral `Ci(x) = γ + ln(x) + ∫_0^x (cos(t) - 1) / t dt`.
///
/// Defined for `x >= 0`, with `Ci(0) = -∞`, `Ci(+∞) = 0`, and `double.nan`
/// for `x < 0` or `NaN`.
///
/// See https://en.wikipedia.org/wiki/Trigonometric_integral for details.
double cosIntegral(num x) {
  if (x.isNaN || x < 0.0) return double.nan;
  final xd = x.toDouble();
  if (xd == 0.0) return double.negativeInfinity;
  if (xd == double.infinity) return 0.0;
  if (xd <= 4.0) return _evenIntegralSeries(xd, alternating: true);
  return -expIntegralE1Complex(Complex(0.0, xd)).a.toDouble();
}

/// Returns the complex cosine integral `Ci(z)`.
///
/// See https://en.wikipedia.org/wiki/Trigonometric_integral for details.
Complex cosIntegralComplex(Complex z) {
  if (z.isNaN) return Complex.nan;
  if (z == Complex.zero) return const Complex(double.negativeInfinity);
  if (z.b == 0.0 && z.a == double.infinity) return Complex.zero;
  if (!z.a.isFinite || !z.b.isFinite) return Complex.nan;
  if (z.abs() < 4.0) return _evenIntegralSeriesComplex(z, alternating: true);
  if (z.a < 0.0 || (z.a == 0.0 && z.b < 0.0)) {
    final branch = z.b >= 0.0
        ? const Complex(0.0, pi)
        : const Complex(0.0, -pi);
    return cosIntegralComplex(-z) + branch;
  }
  final iz = Complex.i * z;
  return -const Complex(0.5) *
      (expIntegralE1Complex(iz) + expIntegralE1Complex(-iz));
}

/// Returns the hyperbolic sine integral `Shi(x) = ∫_0^x sinh(t) / t dt`.
///
/// Odd function with `Shi(0) = 0` and `Shi(±∞) = ±∞`.
///
/// See https://en.wikipedia.org/wiki/Trigonometric_integral#Hyperbolic_sine_integral
/// for details.
double sinhIntegral(num x) {
  if (x.isNaN) return double.nan;
  final xd = x.toDouble();
  if (xd == 0.0) return 0.0;
  if (xd.isInfinite) return xd;
  final sign = xd < 0.0 ? -1.0 : 1.0;
  final ax = xd.abs();
  if (ax <= 4.0) return sign * _oddIntegralSeries(ax, alternating: false);
  return sign * 0.5 * (expIntegral(ax) - expIntegral(-ax));
}

/// Returns the complex hyperbolic sine integral `Shi(z) = ∫_0^z sinh(t) / t dt`.
///
/// See https://en.wikipedia.org/wiki/Trigonometric_integral#Hyperbolic_sine_integral
/// for details.
Complex sinhIntegralComplex(Complex z) {
  if (z.isNaN) return Complex.nan;
  if (z.b == 0.0) return Complex(sinhIntegral(z.a.toDouble()));
  if (!z.a.isFinite || !z.b.isFinite) return Complex.nan;
  if (z.abs() < 4.0) return _oddIntegralSeriesComplex(z, alternating: false);
  return const Complex(0.0, -1.0) * sinIntegralComplex(Complex.i * z);
}

/// Returns the hyperbolic cosine integral
/// `Chi(x) = γ + ln(x) + ∫_0^x (cosh(t) - 1) / t dt`.
///
/// Defined for `x >= 0`, with `Chi(0) = -∞`, `Chi(+∞) = +∞`, and `double.nan`
/// for `x < 0` or `NaN`.
///
/// See https://en.wikipedia.org/wiki/Trigonometric_integral#Hyperbolic_cosine_integral
/// for details.
double coshIntegral(num x) {
  if (x.isNaN || x < 0.0) return double.nan;
  final xd = x.toDouble();
  if (xd == 0.0) return double.negativeInfinity;
  if (xd == double.infinity) return double.infinity;
  if (xd <= 4.0) return _evenIntegralSeries(xd, alternating: false);
  return 0.5 * (expIntegral(xd) + expIntegral(-xd));
}

/// Returns the complex hyperbolic cosine integral `Chi(z)`.
///
/// See https://en.wikipedia.org/wiki/Trigonometric_integral#Hyperbolic_cosine_integral
/// for details.
Complex coshIntegralComplex(Complex z) {
  if (z.isNaN) return Complex.nan;
  if (z == Complex.zero) return const Complex(double.negativeInfinity);
  if (z.b == 0.0 && z.a == double.infinity) {
    return const Complex(double.infinity);
  }
  if (!z.a.isFinite || !z.b.isFinite) return Complex.nan;
  if (z.abs() < 4.0) return _evenIntegralSeriesComplex(z, alternating: false);
  final branch = z.b > 0.0
      ? const Complex(0.0, 0.5 * pi)
      : z.b < 0.0
      ? const Complex(0.0, -0.5 * pi)
      : (z.a < 0.0 ? const Complex(0.0, pi) : Complex.zero);
  return const Complex(0.5) * (expIntegralComplex(z) + expIntegralComplex(-z)) +
      branch;
}

double _oddIntegralSeries(double x, {required bool alternating}) {
  final signedX2 = alternating ? -x * x : x * x;
  var sum = x;
  var term = x;
  for (var n = 1; n <= 50; n++) {
    term *= signedX2 / ((2 * n) * (2 * n + 1));
    final add = term / (2 * n + 1);
    sum += add;
    if (add.abs() <= 1e-16 * sum.abs()) break;
  }
  return sum;
}

Complex _oddIntegralSeriesComplex(Complex z, {required bool alternating}) {
  final signedZ2 = alternating ? -z * z : z * z;
  var sum = z;
  var term = z;
  for (var n = 1; n <= 50; n++) {
    term *= signedZ2 / Complex((2 * n) * (2 * n + 1).toDouble());
    final add = term / Complex((2 * n + 1).toDouble());
    sum += add;
    if (add.abs() <= 1e-16 * sum.abs()) break;
  }
  return sum;
}

double _evenIntegralSeries(double x, {required bool alternating}) {
  final signedX2 = alternating ? -x * x : x * x;
  var sum = eulerMascheroni + log(x);
  var term = 1.0;
  for (var n = 1; n <= 50; n++) {
    term *= signedX2 / ((2 * n - 1) * (2 * n));
    final add = term / (2 * n);
    sum += add;
    if (add.abs() <= 1e-16 * sum.abs()) break;
  }
  return sum;
}

Complex _evenIntegralSeriesComplex(Complex z, {required bool alternating}) {
  final signedZ2 = alternating ? -z * z : z * z;
  var sum = const Complex(eulerMascheroni) + z.log();
  var term = Complex.one;
  for (var n = 1; n <= 50; n++) {
    term *= signedZ2 / Complex((2 * n - 1) * (2 * n).toDouble());
    final add = term / Complex((2 * n).toDouble());
    sum += add;
    if (add.abs() <= 1e-16 * sum.abs()) break;
  }
  return sum;
}
