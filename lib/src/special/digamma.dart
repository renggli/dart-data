import 'dart:math';

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

/// Returns the trigamma function, which is the first derivative of the digamma
/// function: $\psi_1(x) = \psi'(x)$.
///
/// Conceptually, trigamma measures the curvature (second derivative) of
/// $\ln\Gamma(x)$. At $x=1$, it equals $\pi^2 / 6 \approx 1.6449$. Formally,
/// this evaluates the first polygamma function
/// $\psi_1(x) = \frac{d^2}{dx^2}\ln\Gamma(x)$
/// $= \sum_{k=0}^\infty \frac{1}{(x + k)^2}$.
///
/// See https://en.wikipedia.org/wiki/Trigamma_function for details.
///
/// ```dart
/// final val = trigamma(1.0); // ~ 1.6449340668 (pi^2 / 6)
/// ```
double trigamma(num x) {
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
    return pi * pi / (sinVal * sinVal) - trigamma(1.0 - value);
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

/// Returns the polygamma function of order [m], which is the $(m+1)$-th
/// derivative of the logarithm of the gamma function:
/// $\psi^{(m)}(x) = \frac{d^{m+1}}{dx^{m+1}} \ln \Gamma(x)$.
///
/// For $m = 0$, this equals [digamma]. For $m = 1$, this equals [trigamma].
double polygamma(int m, num x) {
  if (m < 0) {
    throw ArgumentError.value(m, 'm', 'Order must be non-negative');
  }
  if (m == 0) return digamma(x);
  if (m == 1) return trigamma(x);
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
