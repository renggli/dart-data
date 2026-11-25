import 'dart:math';

import 'package:more/number.dart' show Complex;

import 'gamma.dart';
import 'utils.dart';

/// Returns the exponential integral `Ei(x) = -PV ∫_{-x}^∞ exp(-t) / t dt`.
///
/// Defined for real `x != 0`, with `Ei(0) = -∞`, `Ei(-∞) = 0`, and
/// `Ei(+∞) = +∞`.
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
    for (var k = 1; k <= 60; k++) {
      final next = term * k / xd;
      if (next > term) break;
      term = next;
      sum += term;
      if (term <= 1e-16 * sum) break;
    }
    if (xd > 700.0) {
      final halfExp = exp(0.5 * xd);
      return halfExp * (halfExp / xd * sum);
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
  if (z.b == 0.0) {
    return Complex(expIntegral(z.a.toDouble()));
  }
  if (!z.a.isFinite || !z.b.isFinite) return Complex.nan;
  final absZ = z.abs();
  if (absZ < 4.0 || (z.a > 0.0 && z.b.abs() < 2.0 && absZ <= 40.0)) {
    var sum = z.log() + eulerMascheroni;
    var term = z;
    for (var k = 1; k <= 200; k++) {
      final add = term / k.toDouble();
      sum += add;
      if (add.abs() <= 1e-16 * sum.abs()) break;
      term *= z / (k + 1).toDouble();
    }
    return sum;
  }
  if (z.a > 40.0 && z.b.abs() < 2.0) {
    var sum = Complex.one;
    var term = Complex.one;
    for (var k = 1; k <= 60; k++) {
      final next = term * Complex(k.toDouble()) / z;
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

/// Returns the generalized exponential integral
/// `E_n(x) = ∫_1^∞ exp(-x * t) / t^n dt`.
///
/// See https://en.wikipedia.org/wiki/Exponential_integral for details.
double expIntegralE(num n, num x) {
  if (n.isNaN || x.isNaN) return double.nan;
  final nd = n.toDouble();
  final xd = x.toDouble();
  if (xd == double.infinity) return nd.isFinite ? 0.0 : double.nan;
  if (nd == double.infinity) {
    return xd >= 0.0 && xd.isFinite ? 0.0 : double.nan;
  }
  if (!nd.isFinite || !xd.isFinite) return double.nan;
  if (nd == 0.0) return exp(-xd) / xd;
  if (xd == 0.0) return nd > 1.0 ? 1.0 / (nd - 1.0) : double.infinity;
  if (xd < 0.0) {
    final z = expIntegralEComplex(Complex(nd), Complex(xd));
    return z.b.abs() <= 1e-12 * max(1.0, z.a.abs())
        ? z.a.toDouble()
        : double.nan;
  }
  if (xd > 1.0 && nd > 0.0) {
    return _expIntegralECf(nd, xd);
  }
  if (nd > 0.0 && nd.roundToDouble() == nd && nd <= 10000.0) {
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
///
/// See https://en.wikipedia.org/wiki/Exponential_integral for details.
Complex expIntegralEComplex(Complex n, Complex z) {
  if (n.isNaN || z.isNaN || !n.a.isFinite || !n.b.isFinite) {
    return Complex.nan;
  }
  if (!z.a.isFinite || !z.b.isFinite) return Complex.nan;
  if (n == Complex.zero) return (-z).exp() / z;
  if (z == Complex.zero) {
    return n.a > 1.0 ? Complex.one / (n - 1.0) : const Complex(double.infinity);
  }
  if (z.abs() > 1.0 && z.a > -0.5 * z.b.abs() && n.a > 0.0) {
    return _expIntegralECfComplex(n, z);
  }
  if (n.b == 0.0 &&
      n.a >= 1.0 &&
      n.a.roundToDouble() == n.a &&
      n.a <= 10000.0) {
    final k = n.a.toInt();
    var e = expIntegralE1Complex(z);
    final ez = (-z).exp();
    for (var m = 1; m < k; m++) {
      e = (ez - z * e) / m.toDouble();
    }
    return e;
  }
  return z.pow(n - 1.0) * upperGammaComplex(Complex.one - n, z);
}

/// Returns the logarithmic integral `li(x) = PV ∫_0^x dt / ln(t) = Ei(ln(x))`.
///
/// Defined for `x >= 0`, with `li(0) = 0`, `li(1) = -∞`, and `li(+∞) = +∞`.
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
Complex logIntegralComplex(Complex z) {
  if (z.isNaN) return Complex.nan;
  if (z == Complex.zero) return Complex.zero;
  if (z == Complex.one) return const Complex(double.negativeInfinity);
  if (z.b == 0.0 && z.a == double.infinity) {
    return const Complex(double.infinity);
  }
  if (!z.a.isFinite || !z.b.isFinite) return Complex.nan;
  return expIntegralComplex(z.log());
}

/// Package-internal helper computing `E_1(z)` via power series, negative-axis
/// asymptotic series, or modified Lentz continued fraction.
Complex expIntegralE1Complex(Complex z) {
  if (z.isNaN) return Complex.nan;
  if (!z.a.isFinite || !z.b.isFinite) return Complex.nan;
  if (z == Complex.zero) return const Complex(double.infinity);
  final absZ = z.abs();
  if (absZ < 4.0 || (z.a < 0.0 && z.b.abs() < 2.0 && absZ <= 40.0)) {
    var sum = -const Complex(eulerMascheroni) - z.log();
    var term = Complex.one;
    for (var k = 1; k <= 200; k++) {
      term *= -z / k.toDouble();
      final add = -term / k.toDouble();
      sum += add;
      if (add.abs() <= 1e-16 * sum.abs()) break;
    }
    return sum;
  }
  if (z.a < -40.0 && z.b.abs() < 2.0) {
    final branch = z.b >= 0.0
        ? const Complex(0.0, -pi)
        : const Complex(0.0, pi);
    return -expIntegralComplex(-z) + branch;
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
  final h = lentzCF(
    t + 1.0,
    (i) => -i * i.toDouble(),
    (i) => t + 1.0 + 2.0 * i,
  );
  return exp(-t) * h;
}

double _expIntegralECf(double n, double x) {
  final h = lentzCF(x + n, (i) => -i * (n - 1.0 + i), (i) => x + n + 2.0 * i);
  return exp(-x) * h;
}

Complex _expIntegralECfComplex(Complex n, Complex z) {
  final h = lentzCFComplex(
    z + n,
    (i) => Complex(-i.toDouble()) * (n - 1.0 + i.toDouble()),
    (i) => z + n + Complex(2.0 * i),
  );
  return (-z).exp() * h;
}
