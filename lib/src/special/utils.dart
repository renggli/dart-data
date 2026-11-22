import 'package:more/number.dart' show Complex;

/// Euler-Mascheroni constant γ ≈ 0.5772156649015329.
const double eulerMascheroni = 0.5772156649015328606;

/// Reciprocal square root of π: 1 / √π.
const double invSqrtPi = 0.56418958354775628695;

/// Square root of π: √π.
const double sqrtPi = 1.7724538509055160273;

/// Reciprocal of Euler's number: 1 / e.
const double invE = 0.3678794411714423216;

/// Small underflow guard for modified Lentz continued-fraction iterations.
const double tinyDouble = 1e-30;

/// Maximum exact 53-bit integer across Dart VM and Web (`2^53 - 1`).
const int maxSafeInt = 9007199254740991;

/// Lanczos parameter `g = 7` for 9-term gamma approximation.
const double lanczosG = 7.0;

/// Lanczos coefficients for `g = 7` (9 terms).
const List<double> lanczosCoeffs = [
  0.99999999999980993,
  676.5203681218851,
  -1259.1392167224028,
  771.32342877765313,
  -176.61502916214059,
  12.507343278686905,
  -0.13857109526572012,
  9.9843695780195716e-6,
  1.5056327351493116e-7,
];

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
