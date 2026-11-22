import 'dart:math';

import 'package:more/number.dart' show Complex;

/// Returns the exponential integral `Ei(x) = -PV ∫_{-x}^∞ e^(-t) / t dt`.
///
/// Defined for real `x != 0`, with `Ei(0) = -∞`.
double expIntegral(num x) {
  if (x.isNaN) return double.nan;
  final xd = x.toDouble();
  if (xd == 0.0) return double.negativeInfinity;
  if (xd == double.infinity) return double.infinity;
  if (xd == double.negativeInfinity) return 0.0;

  if (xd > 0.0) {
    if (xd <= 40.0) {
      var sum = _eulerMascheroni + log(xd);
      var term = xd;
      for (var k = 1; k <= 200; k++) {
        final add = term / k;
        sum += add;
        if (add.abs() <= 1e-16 * sum.abs()) break;
        term *= xd / (k + 1);
      }
      return sum;
    } else {
      // Asymptotic expansion: exp(x)/x * sum_{k=0}^N k! / x^k
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
  } else {
    // Ei(x) = -E1(-x) for x < 0
    return -_expIntegralE1(-xd);
  }
}

/// Returns the complex exponential integral $\operatorname{Ei}(z)$.
Complex expIntegralComplex(Complex z) {
  if (z.a.isNaN || z.b.isNaN) return const Complex(double.nan, double.nan);
  if (z.a == 0.0 && z.b == 0.0) return const Complex(double.negativeInfinity);
  if (z.b == 0.0) return Complex(expIntegral(z.a.toDouble()));
  if (z.abs() < 4.0) {
    var sum = const Complex(_eulerMascheroni) + z.log();
    var term = z;
    for (var k = 1; k <= 100; k++) {
      final add = term / Complex(k);
      sum += add;
      if (add.abs() <= 1e-16 * sum.abs()) break;
      term *= z / Complex(k + 1);
    }
    return sum;
  }
  final branch = z.b > 0.0 ? const Complex(0.0, pi) : const Complex(0.0, -pi);
  return -_expIntegralE1Complex(-z) + branch;
}

/// Returns the logarithmic integral `li(x) = ∫_0^x dt / ln(t) = Ei(ln(x))`.
///
/// Defined for `x >= 0`, with `li(0) = 0` and `li(1) = -∞`.
double logIntegral(num x) {
  if (x.isNaN || x < 0.0) return double.nan;
  final xd = x.toDouble();
  if (xd == 0.0) return 0.0;
  if (xd == 1.0) return double.negativeInfinity;
  if (xd == double.infinity) return double.infinity;
  return expIntegral(log(xd));
}

/// Returns the complex logarithmic integral $\operatorname{li}(z) = \operatorname{Ei}(\ln(z))$.
Complex logIntegralComplex(Complex z) => expIntegralComplex(z.log());

/// Returns the sine integral `Si(x) = ∫_0^x sin(t) / t dt`.
double sinIntegral(num x) {
  if (x.isNaN) return double.nan;
  final xd = x.toDouble();
  if (xd == 0.0) return 0.0;
  if (xd == double.infinity) return pi / 2.0;
  if (xd == double.negativeInfinity) return -pi / 2.0;
  final sign = xd < 0.0 ? -1.0 : 1.0;
  final ax = xd.abs();

  if (ax <= 4.0) {
    final x2 = ax * ax;
    var sum = ax;
    var term = ax;
    for (var n = 1; n <= 50; n++) {
      term *= -x2 / ((2 * n) * (2 * n + 1));
      final add = term / (2 * n + 1);
      sum += add;
      if (add.abs() <= 1e-16 * sum.abs()) break;
    }
    return sign * sum;
  }

  final e1 = _expIntegralE1Complex(Complex(0.0, ax));
  return sign * (pi / 2.0 + e1.b);
}

/// Returns the complex sine integral $\operatorname{Si}(z) = \int_0^z \frac{\sin(t)}{t}\,dt$.
Complex sinIntegralComplex(Complex z) {
  if (z.a.isNaN || z.b.isNaN) return const Complex(double.nan, double.nan);
  if (z.a == 0.0 && z.b == 0.0) return Complex.zero;
  if (z.abs() < 4.0) {
    final z2 = z * z;
    var sum = z;
    var term = z;
    for (var n = 1; n <= 50; n++) {
      term *= -z2 / Complex((2 * n) * (2 * n + 1));
      final add = term / Complex(2 * n + 1);
      sum += add;
      if (add.abs() <= 1e-16 * sum.abs()) break;
    }
    return sum;
  }
  if (z.a < 0.0) return -sinIntegralComplex(-z);
  final iz = Complex.i * z;
  final e1Plus = _expIntegralE1Complex(iz);
  final e1Minus = _expIntegralE1Complex(-iz);
  return const Complex(pi / 2.0) + (e1Plus - e1Minus) / const Complex(0.0, 2.0);
}

/// Returns the cosine integral `Ci(x) = γ + ln(x) + ∫_0^x (cos(t) - 1) / t dt`.
///
/// Defined for `x > 0`, with `Ci(0) = -∞`.
double cosIntegral(num x) {
  if (x.isNaN || x < 0.0) return double.nan;
  final xd = x.toDouble();
  if (xd == 0.0) return double.negativeInfinity;
  if (xd == double.infinity) return 0.0;

  if (xd <= 4.0) {
    final x2 = xd * xd;
    var sum = _eulerMascheroni + log(xd);
    var term = 1.0;
    for (var n = 1; n <= 50; n++) {
      term *= -x2 / ((2 * n - 1) * (2 * n));
      final add = term / (2 * n);
      sum += add;
      if (add.abs() <= 1e-16 * sum.abs()) break;
    }
    return sum;
  }

  final e1 = _expIntegralE1Complex(Complex(0.0, xd));
  return -e1.a.toDouble();
}

/// Returns the complex cosine integral $\operatorname{Ci}(z)$.
Complex cosIntegralComplex(Complex z) {
  if (z.a.isNaN || z.b.isNaN) return const Complex(double.nan, double.nan);
  if (z.a == 0.0 && z.b == 0.0) return const Complex(double.negativeInfinity);
  if (z.abs() < 4.0) {
    final z2 = z * z;
    var sum = const Complex(_eulerMascheroni) + z.log();
    var term = Complex.one;
    for (var n = 1; n <= 50; n++) {
      term *= -z2 / Complex((2 * n - 1) * (2 * n));
      final add = term / Complex(2 * n);
      sum += add;
      if (add.abs() <= 1e-16 * sum.abs()) break;
    }
    return sum;
  }
  if (z.a < 0.0) {
    final branch = z.b >= 0.0
        ? const Complex(0.0, pi)
        : const Complex(0.0, -pi);
    return cosIntegralComplex(-z) + branch;
  }
  final iz = Complex.i * z;
  return -const Complex(0.5) *
      (_expIntegralE1Complex(iz) + _expIntegralE1Complex(-iz));
}

/// Returns the hyperbolic sine integral `Shi(x) = ∫_0^x sinh(t) / t dt`.
double sinhIntegral(num x) {
  if (x.isNaN) return double.nan;
  final xd = x.toDouble();
  if (xd == 0.0) return 0.0;
  if (xd.isInfinite) return xd;
  final sign = xd < 0.0 ? -1.0 : 1.0;
  final ax = xd.abs();

  if (ax <= 4.0) {
    final x2 = ax * ax;
    var sum = ax;
    var term = ax;
    for (var n = 1; n <= 50; n++) {
      term *= x2 / ((2 * n) * (2 * n + 1));
      final add = term / (2 * n + 1);
      sum += add;
      if (add.abs() <= 1e-16 * sum.abs()) break;
    }
    return sign * sum;
  }

  return sign * 0.5 * (expIntegral(ax) - expIntegral(-ax));
}

/// Returns the complex hyperbolic sine integral $\operatorname{Shi}(z) = \int_0^z \frac{\sinh(t)}{t}\,dt$.
Complex sinhIntegralComplex(Complex z) {
  if (z.a.isNaN || z.b.isNaN) return const Complex(double.nan, double.nan);
  if (z.a == 0.0 && z.b == 0.0) return Complex.zero;
  if (z.abs() < 4.0) {
    final z2 = z * z;
    var sum = z;
    var term = z;
    for (var n = 1; n <= 50; n++) {
      term *= z2 / Complex((2 * n) * (2 * n + 1));
      final add = term / Complex(2 * n + 1);
      sum += add;
      if (add.abs() <= 1e-16 * sum.abs()) break;
    }
    return sum;
  }
  return const Complex(0.0, -1.0) * sinIntegralComplex(Complex.i * z);
}

/// Returns the hyperbolic cosine integral `Chi(x) = γ + ln(x) + ∫_0^x (cosh(t) - 1) / t dt`.
///
/// Defined for `x > 0`, with `Chi(0) = -∞`.
double coshIntegral(num x) {
  if (x.isNaN || x < 0.0) return double.nan;
  final xd = x.toDouble();
  if (xd == 0.0) return double.negativeInfinity;
  if (xd == double.infinity) return double.infinity;

  if (xd <= 4.0) {
    final x2 = xd * xd;
    var sum = _eulerMascheroni + log(xd);
    var term = 1.0;
    for (var n = 1; n <= 50; n++) {
      term *= x2 / ((2 * n - 1) * (2 * n));
      final add = term / (2 * n);
      sum += add;
      if (add.abs() <= 1e-16 * sum.abs()) break;
    }
    return sum;
  }

  return 0.5 * (expIntegral(xd) + expIntegral(-xd));
}

/// Returns the complex hyperbolic cosine integral $\operatorname{Chi}(z)$.
Complex coshIntegralComplex(Complex z) {
  if (z.a.isNaN || z.b.isNaN) return const Complex(double.nan, double.nan);
  if (z.a == 0.0 && z.b == 0.0) return const Complex(double.negativeInfinity);
  if (z.abs() < 4.0) {
    final z2 = z * z;
    var sum = const Complex(_eulerMascheroni) + z.log();
    var term = Complex.one;
    for (var n = 1; n <= 50; n++) {
      term *= z2 / Complex((2 * n - 1) * (2 * n));
      final add = term / Complex(2 * n);
      sum += add;
      if (add.abs() <= 1e-16 * sum.abs()) break;
    }
    return sum;
  }
  final branch = z.b > 0.0
      ? const Complex(0.0, 0.5 * pi)
      : (z.b < 0.0 ? const Complex(0.0, -0.5 * pi) : Complex.zero);
  return const Complex(0.5) * (expIntegralComplex(z) + expIntegralComplex(-z)) +
      branch;
}

const _eulerMascheroni = 0.57721566490153286060651209008240243;

double _expIntegralE1(double t) {
  if (t <= 1.0) {
    var sum = -_eulerMascheroni - log(t);
    var term = 1.0;
    for (var k = 1; k <= 100; k++) {
      term *= -t / k;
      final add = -term / k;
      sum += add;
      if (add.abs() <= 1e-16 * sum.abs()) break;
    }
    return sum;
  }
  // Lentz continued fraction for E1(t)
  const tiny = 1e-30;
  var b = t + 1.0;
  var c = 1.0 / tiny;
  var d = 1.0 / b;
  var h = d;
  for (var i = 1; i <= 200; i++) {
    final a = -i * i.toDouble();
    b += 2.0;
    d = a * d + b;
    if (d.abs() < tiny) d = tiny;
    c = b + a / c;
    if (c.abs() < tiny) c = tiny;
    d = 1.0 / d;
    final del = d * c;
    h *= del;
    if ((del - 1.0).abs() <= 1e-15) break;
  }
  return exp(-t) * h;
}

Complex _expIntegralE1Complex(Complex z) {
  const tiny = 1e-30;
  var b = z + const Complex(1.0);
  var c = const Complex(1.0 / tiny);
  var d = const Complex(1.0) / b;
  var h = d;
  for (var i = 1; i <= 200; i++) {
    final a = Complex(-i * i.toDouble());
    b = b + const Complex(2.0);
    d = a * d + b;
    if (d.abs() < tiny) d = const Complex(tiny);
    c = b + a / c;
    if (c.abs() < tiny) c = const Complex(tiny);
    d = const Complex(1.0) / d;
    final del = d * c;
    h = h * del;
    if ((del - const Complex(1.0)).abs() <= 1e-15) break;
  }
  return (-z).exp() * h;
}
