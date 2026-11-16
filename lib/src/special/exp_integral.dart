import 'dart:math';

import 'package:more/number.dart' show Complex;

/// Returns the exponential integral $\operatorname{Ei}(x) = -\operatorname{PV}\int_{-x}^\infty \frac{e^{-t}}{t}\,dt$.
///
/// Defined for real $x \ne 0$, with $\operatorname{Ei}(0) = -\infty$.
double expIntegralEi(num x) {
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

/// Returns the logarithmic integral $\operatorname{li}(x) = \int_0^x \frac{dt}{\ln t} = \operatorname{Ei}(\ln x)$.
///
/// Defined for $x \ge 0$, with $\operatorname{li}(0) = 0$ and $\operatorname{li}(1) = -\infty$.
double logIntegralLi(num x) {
  if (x.isNaN || x < 0.0) return double.nan;
  final xd = x.toDouble();
  if (xd == 0.0) return 0.0;
  if (xd == 1.0) return double.negativeInfinity;
  if (xd == double.infinity) return double.infinity;
  return expIntegralEi(log(xd));
}

/// Returns the sine integral $\operatorname{Si}(x) = \int_0^x \frac{\sin t}{t}\,dt$.
double sinIntegralSi(num x) {
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

/// Returns the cosine integral $\operatorname{Ci}(x) = \gamma + \ln x + \int_0^x \frac{\cos t - 1}{t}\,dt$.
///
/// Defined for $x > 0$, with $\operatorname{Ci}(0) = -\infty$.
double cosIntegralCi(num x) {
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

/// Returns the hyperbolic sine integral $\operatorname{Shi}(x) = \int_0^x \frac{\sinh t}{t}\,dt$.
double sinhIntegralShi(num x) {
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

  return sign * 0.5 * (expIntegralEi(ax) - expIntegralEi(-ax));
}

/// Returns the hyperbolic cosine integral $\operatorname{Chi}(x) = \gamma + \ln x + \int_0^x \frac{\cosh t - 1}{t}\,dt$.
///
/// Defined for $x > 0$, with $\operatorname{Chi}(0) = -\infty$.
double coshIntegralChi(num x) {
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

  return 0.5 * (expIntegralEi(xd) + expIntegralEi(-xd));
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
