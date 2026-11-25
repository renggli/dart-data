import 'dart:math';

import 'package:more/number.dart' show Complex;

/// Euler-Mascheroni constant γ ≈ 0.5772156649015329.
const double eulerMascheroni = 0.5772156649015328606;

/// Reciprocal square root of π: `1 / √π`.
const double invSqrtPi = 0.56418958354775628695;

/// Square root of π: `√π`.
const double sqrtPi = 1.7724538509055160273;

/// Reciprocal of Euler's number: `1 / e`.
const double invE = 1.0 / e;

/// Small underflow guard for modified Lentz continued-fraction iterations.
const double tinyDouble = 1e-30;

/// Maximum exact 53-bit integer across Dart VM and Web (`2^53 - 1`).
const int maxSafeInt = 9007199254740991;

/// Evaluates `ln(1 + x)` without catastrophic cancellation for small `|x|`.
double log1p(double x) {
  if (x.isNaN || x < -1.0) return double.nan;
  if (x == -1.0) return double.negativeInfinity;
  if (x == double.infinity) return double.infinity;
  final u = 1.0 + x;
  return u == 1.0 ? x : log(u) * (x / (u - 1.0));
}

/// Evaluates the polynomial `c[0] + c[1]*x + ... + c[n]*x^n` via Horner's
/// method.
double horner(double x, List<double> coeffs) {
  var acc = 0.0;
  for (var i = coeffs.length - 1; i >= 0; i--) {
    acc = acc * x + coeffs[i];
  }
  return acc;
}

/// Evaluates the rational function `horner(x, num) / horner(x, den)`.
double hornerRatio(double x, List<double> num, List<double> den) =>
    horner(x, num) / horner(x, den);

/// Evaluates a real continued fraction `1 / (b0 + a1 / (b1 + a2 / ...))`
/// via the modified Lentz method.
double lentzCF(
  double b0,
  double Function(int k) aFn,
  double Function(int k) bFn, {
  int maxIter = 200,
  double tol = 1e-15,
}) {
  var c = 1.0 / tinyDouble;
  var d = b0.abs() < tinyDouble ? 1.0 / tinyDouble : 1.0 / b0;
  var h = d;
  for (var k = 1; k <= maxIter; k++) {
    final a = aFn(k);
    final b = bFn(k);
    d = a * d + b;
    if (d.abs() < tinyDouble) d = tinyDouble;
    c = b + a / c;
    if (c.abs() < tinyDouble) c = tinyDouble;
    d = 1.0 / d;
    final delta = d * c;
    h *= delta;
    if ((delta - 1.0).abs() <= tol) break;
  }
  return h;
}

/// Evaluates a complex continued fraction `1 / (b0 + a1 / (b1 + a2 / ...))`
/// via the modified Lentz method.
Complex lentzCFComplex(
  Complex b0,
  Complex Function(int k) aFn,
  Complex Function(int k) bFn, {
  int maxIter = 200,
  double tol = 1e-15,
}) {
  var c = const Complex(1.0 / tinyDouble);
  var d = b0.abs() < tinyDouble
      ? const Complex(1.0 / tinyDouble)
      : b0.reciprocal();
  var h = d;
  for (var k = 1; k <= maxIter; k++) {
    final a = aFn(k);
    final b = bFn(k);
    d = a * d + b;
    if (d.abs() < tinyDouble) d = const Complex(tinyDouble);
    c = b + a / c;
    if (c.abs() < tinyDouble) c = const Complex(tinyDouble);
    d = d.reciprocal();
    final delta = d * c;
    h *= delta;
    if ((delta - 1).abs() <= tol) break;
  }
  return h;
}

/// Evaluates `ln(sin(π * z))` without overflow for large `|Im(z)|`.
Complex logSinPiComplex(Complex z) {
  final re = z.a.toDouble();
  final im = z.b.toDouble();
  final r = re - 2.0 * (re / 2.0).roundToDouble();
  if (im > 10.0) {
    var ang = pi * (0.5 - r);
    if (ang > pi) ang -= 2.0 * pi;
    if (ang <= -pi) ang += 2.0 * pi;
    return Complex(pi * im - ln2, ang);
  }
  if (im < -10.0) {
    var ang = pi * (r - 0.5);
    if (ang > pi) ang -= 2.0 * pi;
    if (ang <= -pi) ang += 2.0 * pi;
    return Complex(-pi * im - ln2, ang);
  }
  return Complex(pi * r, pi * im).sin().log();
}

/// Evaluates `cot(π * z)` without overflow for large `|Im(z)|`.
Complex cotPiComplex(Complex z) {
  final re = z.a.toDouble();
  final im = z.b.toDouble();
  if (im > 20.0) return const Complex(0.0, -1.0);
  if (im < -20.0) return const Complex(0.0, 1.0);
  final r = re - re.floorToDouble();
  final px = Complex(pi * r, pi * im);
  return px.cos() / px.sin();
}
