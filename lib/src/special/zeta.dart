import 'dart:math';

import 'gamma.dart';

/// Returns the Riemann zeta function $\zeta(s) = \sum_{n=1}^\infty n^{-s}$.
///
/// Conceptually, the Riemann zeta function sums inverse power series and
/// encodes deep structural information about the distribution of prime
/// numbers. Formally, it provides the analytic continuation of Dirichlet's
/// series across the real line $\mathbb{R} \setminus \{1\}$, with a simple pole
/// at $s = 1$.
///
/// Evaluated via Borwein's fast alternating series expansion for $s > 0$ and
/// Riemann's functional reflection equation for $s < 0$.
///
/// See https://en.wikipedia.org/wiki/Riemann_zeta_function for details.
///
/// ```dart
/// final val = zeta(2.0); // ~ 1.6449340668 (pi^2 / 6)
/// ```
double zeta(num s) {
  if (s.isNaN) return double.nan;
  final sd = s.toDouble();
  if (sd.isInfinite) return sd > 0.0 ? 1.0 : double.nan;
  if (sd == 1.0) return double.infinity;
  if (sd == 0.0) return -0.5;

  // Trivial zeros at negative even integers
  if (sd < 0.0 && sd.roundToDouble() == sd && sd.toInt().isEven) {
    return 0.0;
  }

  // Reflection formula for negative s
  if (sd < 0.0) {
    if (sd < -100.0) {
      final oneMinusS = 1.0 - sd;
      final sinVal = sin(0.5 * pi * sd);
      if (sinVal == 0.0) return 0.0;
      final sign = sinVal > 0.0 ? 1.0 : -1.0;
      final logMag =
          sd * ln2 +
          (sd - 1.0) * _lnPi +
          log(sinVal.abs()) +
          gammaLn(oneMinusS) +
          log(zeta(oneMinusS));
      if (logMag > 709.782712893384) {
        return sign * double.infinity;
      }
      return sign * exp(logMag);
    }
    final oneMinusS = 1.0 - sd;
    final term =
        pow(2.0, sd) *
        pow(pi, sd - 1.0) *
        sin(0.5 * pi * sd) *
        gamma(oneMinusS) *
        zeta(oneMinusS);
    return term;
  }

  // Rapid direct summation for large positive s
  if (sd > 35.0) {
    return 1.0 + pow(2.0, -sd);
  }

  // Borwein's algorithm with n = 18
  const n = 18;
  const dCoeffs = <double>[
    1.0,
    649.0,
    70417.0,
    3047185.0,
    70024465.0,
    986869009.0,
    9294036241.0,
    61875666193.0,
    302874803473.0,
    1121956838673.0,
    3217082465553.0,
    7280356408593.0,
    13257491266833.0,
    19878317571345.0,
    25308095757585.0,
    28503551425809.0,
    29779156712721.0,
    30088394358033.0,
    30122754096401.0,
  ];

  const dn = 30122754096401.0;

  var sum = 0.0;
  for (var k = 0; k < n; k++) {
    final sign = k.isEven ? 1.0 : -1.0;
    final diff = dCoeffs[k] - dn;
    sum += sign * diff / pow(k + 1, sd);
  }

  final denom = dn * (1.0 - pow(2.0, 1.0 - sd));
  return -sum / denom;
}

const _lnPi = 1.1447298858494002;
