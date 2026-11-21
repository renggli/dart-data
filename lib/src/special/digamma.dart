import 'dart:math';

import 'package:more/number.dart' show Complex;

/// Returns the digamma function (also known as the psi function), which is the
/// logarithmic derivative of the gamma function:
/// $\psi(x) = \Gamma'(x)/\Gamma(x)$.
///
/// Conceptually, digamma calculates the rate of change of the logarithm of the
/// gamma function at any point. At $x=1$, it equals $-\gamma$ (the negative
/// Euler-Mascheroni constant $\approx -0.5772$). Formally, this calculates the
/// logarithmic derivative
/// $\psi(x) = \frac{d}{dx}\ln\Gamma(x) = \frac{\Gamma'(x)}{\Gamma(x)}$,
/// evaluated using harmonic recurrence and asymptotic Bernoulli expansion.
///
/// See https://en.wikipedia.org/wiki/Digamma_function for details.
///
/// ```dart
/// final val = digamma(1.0); // ~ -0.5772156649
/// ```
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
  final invVal = 1.0 / value;
  final r2 = invVal * invVal;
  final r4 = r2 * r2;
  final r6 = r4 * r2;
  final r8 = r6 * r2;
  final r10 = r8 * r2;
  final result =
      log(value) -
      0.5 * invVal -
      (1.0 / 12.0) * r2 +
      (1.0 / 120.0) * r4 -
      (1.0 / 252.0) * r6 +
      (1.0 / 240.0) * r8 -
      (5.0 / 660.0) * r10;
  return result - shift;
}

/// Returns the complex digamma function $\psi(z) = \Gamma'(z) / \Gamma(z)$.
Complex digammaComplex(Complex z) {
  if (z.a.isNaN || z.b.isNaN) return const Complex(double.nan, double.nan);
  if (z.b == 0.0 && z.a <= 0.0 && z.a == z.a.roundToDouble()) {
    return const Complex(double.nan, double.nan);
  }
  if (z.a < 0.5) {
    final piZ = const Complex(pi) * z;
    return digammaComplex(Complex.one - z) -
        const Complex(pi) * (piZ.cos() / piZ.sin());
  }
  var shift = Complex.zero;
  var cur = z;
  while (cur.abs() < 8.0) {
    shift += Complex.one / cur;
    cur += Complex.one;
  }
  final invVal = Complex.one / cur;
  final r2 = invVal * invVal;
  final r4 = r2 * r2;
  final r6 = r4 * r2;
  final r8 = r6 * r2;
  final r10 = r8 * r2;
  final result =
      cur.log() -
      const Complex(0.5) * invVal -
      const Complex(1.0 / 12.0) * r2 +
      const Complex(1.0 / 120.0) * r4 -
      const Complex(1.0 / 252.0) * r6 +
      const Complex(1.0 / 240.0) * r8 -
      const Complex(5.0 / 660.0) * r10;
  return result - shift;
}

/// Returns the polygamma function of order [m], which is the $(m+1)$-th
/// derivative of the logarithm of the gamma function:
/// $\psi^{(m)}(x) = \frac{d^{m+1}}{dx^{m+1}} \ln \Gamma(x)$.
///
/// For $m = 0$, this equals [digamma]. For $m = 1$, this is the trigamma
/// function $\psi_1(x) = \psi'(x)$.
double polygamma(int m, num x) {
  if (m < 0) {
    throw ArgumentError.value(m, 'm', 'Order must be non-negative');
  }
  if (m == 0) return digamma(x);
  if (m == 1) return _trigamma(x);
  if (x.isNaN) return double.nan;
  if (x.isInfinite) {
    return x.isNegative ? double.nan : 0.0;
  }
  var value = x.toDouble();
  if (value <= 0.0) {
    if (value.roundToDouble() == value) {
      return double.nan;
    }
    final refl = polygamma(m, 1.0 - value);
    final signM = m.isEven ? 1.0 : -1.0;
    final term = pow(pi, m + 1) * _cotDerivative(m, value);
    return signM * refl - term;
  }
  var mFact = 1.0;
  for (var i = 1; i <= m; i++) {
    mFact *= i;
  }
  final mMinus1Fact = mFact / m;
  final sign = m.isOdd ? 1.0 : -1.0;
  final shiftSign = m.isEven ? -1.0 : 1.0;

  var shift = 0.0;
  while (value < 8.0) {
    shift += shiftSign * mFact / pow(value, m + 1);
    value += 1.0;
  }

  final invVal = 1.0 / value;
  var asymptotic =
      mMinus1Fact * pow(invVal, m) + 0.5 * mFact * pow(invVal, m + 1);

  const bCoeffs = [
    1.0 / 12.0,
    -1.0 / 720.0,
    1.0 / 30240.0,
    -1.0 / 1209600.0,
    1.0 / 47900160.0,
    -691.0 / 1307674368000.0,
    1.0 / 74724249600.0,
  ];

  for (var k = 1; k <= bCoeffs.length; k++) {
    var factor = 1.0;
    for (var j = 1; j <= 2 * k + m - 1; j++) {
      factor *= j;
    }
    final term = bCoeffs[k - 1] * factor * pow(invVal, 2 * k + m);
    asymptotic += term;
    if (term.abs() < 1e-15 * asymptotic.abs()) break;
  }

  return sign * asymptotic + shift;
}

/// Returns the complex polygamma function of order [m],
/// $\psi^{(m)}(z) = \frac{d^{m+1}}{dz^{m+1}} \ln \Gamma(z)$.
Complex polygammaComplex(int m, Complex z) {
  if (m < 0) {
    throw ArgumentError.value(m, 'm', 'Order must be non-negative');
  }
  if (m == 0) return digammaComplex(z);
  if (z.a.isNaN || z.b.isNaN) return const Complex(double.nan, double.nan);
  if (z.b == 0.0 && z.a <= 0.0 && z.a == z.a.roundToDouble()) {
    return const Complex(double.nan, double.nan);
  }
  if (z.a < 0.5) {
    final refl = polygammaComplex(m, Complex.one - z);
    final signM = m.isEven ? 1.0 : -1.0;
    final term =
        Complex(pow(pi, m + 1).toDouble()) * _cotDerivativeComplex(m, z);
    return Complex(signM) * refl - term;
  }
  var mFact = 1.0;
  for (var i = 1; i <= m; i++) {
    mFact *= i;
  }
  final mMinus1Fact = mFact / m;
  final sign = m.isOdd ? 1.0 : -1.0;
  final shiftSign = m.isEven ? -1.0 : 1.0;

  var shift = Complex.zero;
  var cur = z;
  while (cur.abs() < 8.0) {
    shift += Complex(shiftSign * mFact) / cur.pow(m + 1);
    cur += Complex.one;
  }

  final invVal = Complex.one / cur;
  var asymptotic =
      Complex(mMinus1Fact) * invVal.pow(m) +
      Complex(0.5 * mFact) * invVal.pow(m + 1);

  const bCoeffs = [
    1.0 / 12.0,
    -1.0 / 720.0,
    1.0 / 30240.0,
    -1.0 / 1209600.0,
    1.0 / 47900160.0,
    -691.0 / 1307674368000.0,
    1.0 / 74724249600.0,
  ];

  for (var k = 1; k <= bCoeffs.length; k++) {
    var factor = 1.0;
    for (var j = 1; j <= 2 * k + m - 1; j++) {
      factor *= j;
    }
    final term = Complex(bCoeffs[k - 1] * factor) * invVal.pow(2 * k + m);
    asymptotic += term;
    if (term.abs() < 1e-15 * asymptotic.abs()) break;
  }

  return Complex(sign) * asymptotic + shift;
}

double _trigamma(num x) {
  if (x.isNaN) return double.nan;
  if (x.isInfinite) {
    return x.isNegative ? double.nan : 0.0;
  }
  var value = x.toDouble();
  if (value <= 0.0) {
    if (value.roundToDouble() == value) {
      return double.nan;
    }
    final sinVal = sin(pi * value);
    return pi * pi / (sinVal * sinVal) - _trigamma(1.0 - value);
  }
  var shift = 0.0;
  while (value < 8.0) {
    shift += 1.0 / (value * value);
    value += 1.0;
  }
  final invVal = 1.0 / value;
  final r2 = invVal * invVal;
  final r3 = r2 * invVal;
  final r5 = r3 * r2;
  final r7 = r5 * r2;
  final r9 = r7 * r2;
  final r11 = r9 * r2;
  final result =
      invVal +
      0.5 * r2 +
      (1.0 / 6.0) * r3 -
      (1.0 / 30.0) * r5 +
      (1.0 / 42.0) * r7 -
      (1.0 / 30.0) * r9 +
      (5.0 / 66.0) * r11;
  return result + shift;
}

double _cotDerivative(int m, double x) {
  final rem = x - x.floorToDouble();
  final px = pi * rem;
  final sinVal = sin(px);
  final cosVal = cos(px);
  final t = cosVal / sinVal;

  var poly = <double>[0.0, 1.0]; // P_0(t) = t
  for (var k = 0; k < m; k++) {
    final next = List<double>.filled(k + 3, 0.0);
    for (var j = 1; j < poly.length; j++) {
      final c = poly[j];
      if (c != 0.0) {
        final d = j * c;
        next[j - 1] -= d;
        next[j + 1] -= d;
      }
    }
    poly = next;
  }

  var val = 0.0;
  for (var i = poly.length - 1; i >= 0; i--) {
    val = val * t + poly[i];
  }
  return val;
}

Complex _cotDerivativeComplex(int m, Complex z) {
  final px = const Complex(pi) * z;
  final t = px.cos() / px.sin();

  var poly = <double>[0.0, 1.0];
  for (var k = 0; k < m; k++) {
    final next = List<double>.filled(k + 3, 0.0);
    for (var j = 1; j < poly.length; j++) {
      final c = poly[j];
      if (c != 0.0) {
        final d = j * c;
        next[j - 1] -= d;
        next[j + 1] -= d;
      }
    }
    poly = next;
  }

  var val = Complex.zero;
  for (var i = poly.length - 1; i >= 0; i--) {
    val = val * t + Complex(poly[i]);
  }
  return val;
}
