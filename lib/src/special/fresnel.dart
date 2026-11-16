import 'dart:math';

import 'package:more/number.dart' show Complex;

/// Returns the Fresnel sine integral `S(x) = ∫_0^x sin(π/2 * t^2) dt`.
double fresnelS(num x) => _fresnelPair(x).s;

/// Returns the Fresnel cosine integral `C(x) = ∫_0^x cos(π/2 * t^2) dt`.
double fresnelC(num x) => _fresnelPair(x).c;

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
  const tiny = 1e-30;
  var b = Complex(1.0, -pix2);
  var c = const Complex(1.0 / tiny);
  var d = const Complex(1.0) / b;
  var h = d;
  var n = -1.0;
  for (var k = 2; k <= 100; k++) {
    n += 2.0;
    final a = -n * (n + 1.0);
    b = b + const Complex(4.0);
    d = Complex(a) * d + b;
    if (d.abs() < tiny) d = const Complex(tiny);
    c = b + Complex(a) / c;
    if (c.abs() < tiny) c = const Complex(tiny);
    d = const Complex(1.0) / d;
    final del = d * c;
    h = h * del;
    if ((del - const Complex(1.0)).abs() <= 1e-15) break;
  }

  final xh = h * Complex(ax);
  final g = xh.a.toDouble();
  final f = xh.b.toDouble();
  final arg = 0.5 * pix2;
  final sinArg = sin(arg);
  final cosArg = cos(arg);

  final cVal = 0.5 + f * sinArg - g * cosArg;
  final sVal = 0.5 - f * cosArg - g * sinArg;
  return (c: sign * cVal, s: sign * sVal);
}
