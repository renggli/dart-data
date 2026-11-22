import 'dart:math';

import 'package:more/number.dart' show Complex;

import 'erf.dart';
import 'utils.dart';

/// Returns the Fresnel sine integral `S(x) = ∫_0^x sin(π/2 * t^2) dt`.
///
/// See https://en.wikipedia.org/wiki/Fresnel_integral for details.
double fresnelS(num x) => _fresnelPair(x).s;

/// Returns the complex Fresnel sine integral `S(z) = ∫_0^z sin(π/2 * t^2) dt`.
///
/// See https://en.wikipedia.org/wiki/Fresnel_integral for details.
Complex fresnelSComplex(Complex z) => _fresnelPairComplex(z).s;

/// Returns the Fresnel cosine integral `C(x) = ∫_0^x cos(π/2 * t^2) dt`.
///
/// See https://en.wikipedia.org/wiki/Fresnel_integral for details.
double fresnelC(num x) => _fresnelPair(x).c;

/// Returns the complex Fresnel cosine integral `C(z) = ∫_0^z cos(π/2 * t^2) dt`.
///
/// See https://en.wikipedia.org/wiki/Fresnel_integral for details.
Complex fresnelCComplex(Complex z) => _fresnelPairComplex(z).c;

({double c, double s}) _fresnelPair(num x) {
  if (x.isNaN) return (c: double.nan, s: double.nan);
  final xd = x.toDouble();
  if (xd == 0.0) return (c: 0.0, s: 0.0);
  if (xd == double.infinity) return (c: 0.5, s: 0.5);
  if (xd == double.negativeInfinity) return (c: -0.5, s: -0.5);

  final sign = xd < 0.0 ? -1.0 : 1.0;
  final ax = xd.abs();

  if (ax < 1.5) {
    final pix2 = 0.5 * pi * ax * ax;
    final pix2Sq = pix2 * pix2;

    var cSum = ax;
    var cTerm = ax;
    for (var n = 1; n <= 40; n++) {
      cTerm *= -pix2Sq / ((2 * n - 1) * (2 * n));
      final add = cTerm / (4 * n + 1);
      cSum += add;
      if (add.abs() <= 1e-16 * cSum.abs()) break;
    }

    var sTerm = ax * pix2;
    var sSum = sTerm / 3.0;
    for (var n = 1; n <= 40; n++) {
      sTerm *= -pix2Sq / ((2 * n) * (2 * n + 1));
      final add = sTerm / (4 * n + 3);
      sSum += add;
      if (add.abs() <= 1e-16 * sSum.abs()) break;
    }

    return (c: sign * cSum, s: sign * sSum);
  }

  // Lentz continued fraction for auxiliary functions f, g
  final pix2 = pi * ax * ax;
  final h = lentzCFComplex(
    Complex(1.0, -pix2),
    (int k) {
      final n = 2 * k - 1;
      return Complex(-n * (n + 1).toDouble());
    },
    (int k) => Complex(1.0 + 4.0 * k, -pix2),
    maxIter: 99,
  );

  final xh = h * ax;
  final g = xh.a.toDouble();
  final f = xh.b.toDouble();
  final arg = 0.5 * pix2;
  final sinArg = sin(arg);
  final cosArg = cos(arg);

  final cVal = 0.5 + f * sinArg - g * cosArg;
  final sVal = 0.5 - f * cosArg - g * sinArg;
  return (c: sign * cVal, s: sign * sVal);
}

({Complex c, Complex s}) _fresnelPairComplex(Complex z) {
  if (z.isNaN) {
    return (c: Complex.nan, s: Complex.nan);
  }
  if (z.a == 0.0 && z.b == 0.0) return (c: Complex.zero, s: Complex.zero);

  if (z.abs() < 2.0) {
    final pix2 = const Complex(0.5 * pi) * z * z;
    final pix2Sq = pix2 * pix2;

    var cSum = z;
    var cTerm = z;
    for (var n = 1; n <= 40; n++) {
      cTerm *= -pix2Sq / Complex((2 * n - 1) * (2 * n));
      final add = cTerm / Complex(4 * n + 1);
      cSum += add;
      if (add.abs() <= 1e-16 * cSum.abs()) break;
    }

    var sTerm = z * pix2;
    var sSum = sTerm / const Complex(3.0);
    for (var n = 1; n <= 40; n++) {
      sTerm *= -pix2Sq / Complex((2 * n) * (2 * n + 1));
      final add = sTerm / Complex(4 * n + 3);
      sSum += add;
      if (add.abs() <= 1e-16 * sSum.abs()) break;
    }

    return (c: cSum, s: sSum);
  }

  final scale = Complex(0.5 * sqrt(pi));
  final wMinus = erfComplex(scale * const Complex(1.0, -1.0) * z);
  final wPlus = erfComplex(scale * const Complex(1.0, 1.0) * z);
  final termA = const Complex(1.0, 1.0) * wMinus;
  final termB = const Complex(1.0, -1.0) * wPlus;
  return (
    c: (termA + termB) / const Complex(4.0),
    s: (termA - termB) / const Complex(0.0, 4.0),
  );
}
