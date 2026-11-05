import 'dart:math';

/// Returns the complete elliptic integral of the first kind $K(k)$.
///
/// Defined for $-1 \le k \le 1$.
///
/// See https://en.wikipedia.org/wiki/Elliptic_integral for details.
double ellipticK(num modulus) {
  if (modulus.isNaN || modulus.abs() > 1.0) {
    return double.nan;
  }
  final kd = modulus.toDouble();
  if (kd.abs() == 1.0) {
    return double.infinity;
  }
  if (kd == 0.0) {
    return pi / 2.0;
  }
  var a = 1.0;
  var b = sqrt(1.0 - kd * kd);
  for (var i = 0; i < 20; i++) {
    final aNext = 0.5 * (a + b);
    final bNext = sqrt(a * b);
    if ((a - b).abs() < 1.0e-15 * a) {
      a = aNext;
      break;
    }
    a = aNext;
    b = bNext;
  }
  return pi / (2.0 * a);
}

/// Returns the complete elliptic integral of the second kind $E(k)$.
///
/// Defined for $-1 \le k \le 1$.
///
/// See https://en.wikipedia.org/wiki/Elliptic_integral for details.
double ellipticE(num modulus) {
  if (modulus.isNaN || modulus.abs() > 1.0) {
    return double.nan;
  }
  final kd = modulus.toDouble();
  if (kd.abs() == 1.0) {
    return 1.0;
  }
  if (kd == 0.0) {
    return pi / 2.0;
  }
  var a = 1.0;
  var b = sqrt(1.0 - kd * kd);
  var sum = 0.5 * kd * kd;
  var power = 1.0;
  for (var i = 0; i < 20; i++) {
    final aNext = 0.5 * (a + b);
    final bNext = sqrt(a * b);
    final cDiff = a - aNext;
    sum += power * cDiff * cDiff;
    power *= 2.0;
    if ((a - b).abs() < 1.0e-15 * a) {
      a = aNext;
      break;
    }
    a = aNext;
    b = bNext;
  }
  return (pi / (2.0 * a)) * (1.0 - sum);
}

/// Returns the incomplete elliptic integral of the first kind $F(\phi, k)$:
/// $F(\phi, k) = \int_0^\phi \frac{d\theta}{\sqrt{1 - k^2 \sin^2 \theta}}$.
///
/// For $\phi = \pi / 2$, this equals the complete integral [ellipticK].
///
/// Evaluated via Carlson's symmetric form $R_F$.
double ellipticF(num phi, num k) {
  final phiD = phi.toDouble();
  final kd = k.toDouble();
  if (phiD.isNaN || kd.isNaN || kd.abs() > 1.0) {
    return double.nan;
  }
  if (phiD.isInfinite) return phiD;
  if (phiD == 0.0) return 0.0;
  if (kd == 0.0) return phiD;

  // Quasi-periodicity: phi = m * pi + psi with psi in [-pi/2, pi/2]
  final m = (phiD / pi).round();
  final psi = phiD - m * pi;
  final sign = psi >= 0 ? 1.0 : -1.0;
  final absPsi = psi.abs();

  if (kd.abs() == 1.0 && (absPsi >= pi / 2.0 - 1e-15 || m != 0)) {
    return double.infinity * phiD.sign;
  }

  final s = sin(absPsi);
  final c = cos(absPsi);
  final q = 1.0 - kd * kd * s * s;
  final fPsi = sign * s * _carlsonRF(c * c, q, 1.0);

  return m == 0 ? fPsi : 2.0 * m * ellipticK(kd) + fPsi;
}

/// Returns the incomplete elliptic integral of the second kind $E(\phi, k)$:
/// $E(\phi, k) = \int_0^\phi \sqrt{1 - k^2 \sin^2 \theta} \, d\theta$.
///
/// For $\phi = \pi / 2$, this equals the complete integral [ellipticE].
///
/// Evaluated via Carlson's symmetric forms $R_F$ and $R_D$.
double ellipticEIncomplete(num phi, num k) {
  final phiD = phi.toDouble();
  final kd = k.toDouble();
  if (phiD.isNaN || kd.isNaN || kd.abs() > 1.0) {
    return double.nan;
  }
  if (phiD.isInfinite) return phiD;
  if (phiD == 0.0) return 0.0;
  if (kd == 0.0) return phiD;

  final m = (phiD / pi).round();
  final psi = phiD - m * pi;
  final sign = psi >= 0 ? 1.0 : -1.0;
  final absPsi = psi.abs();

  final s = sin(absPsi);
  final c = cos(absPsi);
  final k2 = kd * kd;
  final q = 1.0 - k2 * s * s;
  final rf = _carlsonRF(c * c, q, 1.0);
  final rd = (k2 == 0.0 || s == 0.0) ? 0.0 : _carlsonRD(c * c, q, 1.0);
  final ePsi = sign * (s * rf - (k2 * s * s * s / 3.0) * rd);

  return m == 0 ? ePsi : 2.0 * m * ellipticE(kd) + ePsi;
}

double _carlsonRF(double x, double y, double z) {
  var xn = x;
  var yn = y;
  var zn = z;
  while (true) {
    final sqrtX = sqrt(xn);
    final sqrtY = sqrt(yn);
    final sqrtZ = sqrt(zn);
    final lambda = sqrtX * (sqrtY + sqrtZ) + sqrtY * sqrtZ;
    final mu = (xn + yn + zn) / 3.0;
    final xDev = (mu - xn) / mu;
    final yDev = (mu - yn) / mu;
    final zDev = (mu - zn) / mu;
    final maxDev = max(xDev.abs(), max(yDev.abs(), zDev.abs()));
    if (maxDev < 0.002) {
      final e2 = xDev * yDev - zDev * zDev;
      final e3 = xDev * yDev * zDev;
      return (1.0 -
              0.1 * e2 +
              (1.0 / 14.0) * e3 +
              (1.0 / 24.0) * e2 * e2 -
              (3.0 / 44.0) * e2 * e3) /
          sqrt(mu);
    }
    xn = 0.25 * (xn + lambda);
    yn = 0.25 * (yn + lambda);
    zn = 0.25 * (zn + lambda);
  }
}

double _carlsonRD(double x, double y, double z) {
  var xn = x;
  var yn = y;
  var zn = z;
  var sum = 0.0;
  var fac = 1.0;
  while (true) {
    final sqrtX = sqrt(xn);
    final sqrtY = sqrt(yn);
    final sqrtZ = sqrt(zn);
    final lambda = sqrtX * (sqrtY + sqrtZ) + sqrtY * sqrtZ;
    sum += fac / (sqrtZ * (zn + lambda));
    fac *= 0.25;
    final mu = (xn + yn + 3.0 * zn) * 0.2;
    final xDev = (mu - xn) / mu;
    final yDev = (mu - yn) / mu;
    final zDev = (mu - zn) / mu;
    final maxDev = max(xDev.abs(), max(yDev.abs(), zDev.abs()));
    if (maxDev < 0.002) {
      final ea = xDev * yDev;
      final eb = zDev * zDev;
      final ec = ea - eb;
      final ed = ea - 6.0 * eb;
      final ee = ed + 2.0 * ec;
      return 3.0 * sum +
          fac *
              (1.0 -
                  (3.0 / 14.0) * ed +
                  (1.0 / 6.0) * zDev * ee +
                  (9.0 / 22.0) * ec * eb -
                  (3.0 / 26.0) * ea * eb * zDev) /
              (mu * sqrt(mu));
    }
    xn = 0.25 * (xn + lambda);
    yn = 0.25 * (yn + lambda);
    zn = 0.25 * (zn + lambda);
  }
}
