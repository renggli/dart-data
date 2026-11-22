import 'dart:math';

import 'package:more/number.dart' show Complex;

import 'gamma.dart';
import 'utils.dart';

/// Returns the exponential integral `Ei(x) = -PV ∫_{-x}^∞ exp(-t) / t dt`.
///
/// Defined for real `x != 0`, with `Ei(0) = -∞`.
///
/// See https://en.wikipedia.org/wiki/Exponential_integral for details.
double expIntegral(num x) {
  if (x.isNaN) return double.nan;
  final xd = x.toDouble();
  if (xd == 0.0) return double.negativeInfinity;
  if (xd == double.infinity) return double.infinity;
  if (xd == double.negativeInfinity) return 0.0;

  if (xd > 0.0) {
    if (xd <= 40.0) {
      var sum = eulerMascheroni + log(xd);
      var term = xd;
      for (var k = 1; k <= 200; k++) {
        final add = term / k;
        sum += add;
        if (add.abs() <= 1e-16 * sum.abs()) break;
        term *= xd / (k + 1);
      }
      return sum;
    }
    var sum = 1.0;
    var term = 1.0;
    for (var k = 1; k <= 40; k++) {
      final next = term * k / xd;
      if (next > term) break;
      term = next;
      sum += term;
      if (term <= 1e-16 * sum) break;
    }
    return exp(xd) / xd * sum;
  }
  return -_expIntegralE1(-xd);
}

/// Returns the complex exponential integral `Ei(z)`.
///
/// See https://en.wikipedia.org/wiki/Exponential_integral for details.
Complex expIntegralComplex(Complex z) {
  if (z.isNaN) return Complex.nan;
  if (z == Complex.zero) return const Complex(double.negativeInfinity);
  if (z.b == 0.0) return Complex(expIntegral(z.a.toDouble()));
  final absZ = z.abs();
  if (absZ < 4.0 || (z.a > 0.0 && absZ <= 30.0)) {
    var sum = z.log() + eulerMascheroni;
    var term = z;
    for (var k = 1; k <= 200; k++) {
      final add = term / k;
      sum += add;
      if (add.abs() <= 1e-16 * sum.abs()) break;
      term *= z / (k + 1);
    }
    return sum;
  }
  if (z.a > 30.0 && z.b.abs() < 0.5 * z.a) {
    var sum = Complex.one;
    var term = Complex.one;
    for (var k = 1; k <= 40; k++) {
      final next = term * Complex(k) / z;
      if (next.abs() > term.abs()) break;
      term = next;
      sum += term;
      if (term.abs() <= 1e-16 * sum.abs()) break;
    }
    return z.exp() / z * sum;
  }
  final branch = z.b > 0.0 ? const Complex(0.0, pi) : const Complex(0.0, -pi);
  return -expIntegralE1Complex(-z) + branch;
}

/// Returns the logarithmic integral `li(x) = ∫_0^x dt / ln(t) = Ei(ln(x))`.
///
/// Defined for `x >= 0`, with `li(0) = 0` and `li(1) = -∞`.
///
/// See https://en.wikipedia.org/wiki/Logarithmic_integral_function for details.
double logIntegral(num x) {
  if (x.isNaN || x < 0.0) return double.nan;
  final xd = x.toDouble();
  if (xd == 0.0) return 0.0;
  if (xd == 1.0) return double.negativeInfinity;
  if (xd == double.infinity) return double.infinity;
  return expIntegral(log(xd));
}

/// Returns the complex logarithmic integral `li(z) = Ei(ln(z))`.
///
/// See https://en.wikipedia.org/wiki/Logarithmic_integral_function for details.
Complex logIntegralComplex(Complex z) => expIntegralComplex(z.log());

/// Package-internal helper computing `E_1(z)` via power series or modified
/// Lentz continued fraction.
Complex expIntegralE1Complex(Complex z) {
  if (z.isNaN) return Complex.nan;
  if (z == Complex.zero) return const Complex(double.infinity);
  final absZ = z.abs();
  if (absZ < 4.0 || (z.a < 0.0 && z.b.abs() < 2.0 && absZ <= 30.0)) {
    var sum = -const Complex(eulerMascheroni) - z.log();
    var term = Complex.one;
    for (var k = 1; k <= 200; k++) {
      term *= -z / k;
      final add = -term / k;
      sum += add;
      if (add.abs() <= 1e-16 * sum.abs()) break;
    }
    return sum;
  }
  final h = lentzCFComplex(
    z + 1.0,
    (i) => Complex(-i * i.toDouble()),
    (i) => z + 1.0 + 2.0 * i,
  );
  return (-z).exp() * h;
}

double _expIntegralE1(double t) {
  if (t <= 1.0) {
    var sum = -eulerMascheroni - log(t);
    var term = 1.0;
    for (var k = 1; k <= 100; k++) {
      term *= -t / k;
      final add = -term / k;
      sum += add;
      if (add.abs() <= 1e-16 * sum.abs()) break;
    }
    return sum;
  }
  var b = t + 1.0;
  var c = 1.0 / tinyDouble;
  var d = 1.0 / b;
  var h = d;
  for (var i = 1; i <= 200; i++) {
    final a = -i * i.toDouble();
    b += 2.0;
    d = a * d + b;
    if (d.abs() < tinyDouble) d = tinyDouble;
    c = b + a / c;
    if (c.abs() < tinyDouble) c = tinyDouble;
    d = 1.0 / d;
    final del = d * c;
    h *= del;
    if ((del - 1.0).abs() <= 1e-15) break;
  }
  return exp(-t) * h;
}

/// Returns the generalized exponential integral `E_n(x) = ∫_1^∞ e^(-x*t) / t^n dt`.
double expIntegralE(num n, num x) {
  if (n.isNaN || x.isNaN) return double.nan;
  final nd = n.toDouble();
  final xd = x.toDouble();
  if (nd == 0.0) return exp(-xd) / xd;
  if (xd == 0.0) return nd > 1.0 ? 1.0 / (nd - 1.0) : double.infinity;
  if (xd < 0.0) {
    final z = expIntegralEComplex(Complex(nd), Complex(xd));
    return z.b.abs() <= 1e-12 * max(1.0, z.a.abs())
        ? z.a.toDouble()
        : double.nan;
  }
  if (nd > 0.0 && nd.roundToDouble() == nd && nd <= 100.0) {
    final k = nd.toInt();
    var e = _expIntegralE1(xd);
    final ex = exp(-xd);
    for (var m = 1; m < k; m++) {
      e = (ex - xd * e) / m;
    }
    return e;
  }
  final z = expIntegralEComplex(Complex(nd), Complex(xd));
  return z.a.toDouble();
}

/// Returns the complex generalized exponential integral `E_n(z)`.
Complex expIntegralEComplex(Complex n, Complex z) {
  if (n.isNaN || z.isNaN) return Complex.nan;
  if (n == Complex.zero) return (-z).exp() / z;
  if (z == Complex.zero) {
    return n.a > 1.0 ? Complex.one / (n - 1.0) : const Complex(double.infinity);
  }
  if (n.b == 0.0 && n.a >= 1.0 && n.a.roundToDouble() == n.a && n.a <= 100.0) {
    final k = n.a.toInt();
    var e = expIntegralE1Complex(z);
    final ez = (-z).exp();
    for (var m = 1; m < k; m++) {
      e = (ez - z * e) / m;
    }
    return e;
  }
  return z.pow(n - 1.0) * upperGammaComplex(Complex.one - n, z);
}
