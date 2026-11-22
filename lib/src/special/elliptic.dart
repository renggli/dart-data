import 'dart:math';

import 'package:more/number.dart' show Complex;

/// Returns the complete elliptic integral of the first kind `K(k)`.
///
/// Defined for `-1 <= k <= 1`.
///
/// See https://en.wikipedia.org/wiki/Elliptic_integral for details.
double ellipticK(num k) {
  if (k.isNaN || k.abs() > 1.0) {
    return double.nan;
  }
  final kd = k.toDouble();
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

/// Returns the complex complete elliptic integral of the first kind `K(k)`.
///
/// See https://en.wikipedia.org/wiki/Elliptic_integral for details.
Complex ellipticKComplex(Complex k) {
  if (k.isNaN) return Complex.nan;
  if ((k - Complex.one).abs() == 0.0 || (k + Complex.one).abs() == 0.0) {
    return const Complex(double.infinity);
  }
  if (k.a == 0.0 && k.b == 0.0) return const Complex(pi / 2.0);
  return _carlsonRFComplex(Complex.zero, Complex.one - k * k, Complex.one);
}

/// Returns the elliptic integral of the second kind `E(k)` or `E(φ, k)`.
///
/// When [phi] is omitted, returns the complete integral `E(k)` defined for
/// `-1 <= k <= 1`. When [phi] is provided, returns the incomplete integral
/// `E(φ, k) = ∫_0^φ sqrt(1 - k^2 * sin(θ)^2) dθ`.
///
/// See https://en.wikipedia.org/wiki/Elliptic_integral for details.
double ellipticE(num k, {num? phi}) {
  if (phi != null) {
    return _ellipticEIncomplete(phi, k);
  }
  if (k.isNaN || k.abs() > 1.0) {
    return double.nan;
  }
  final kd = k.toDouble();
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

/// Returns the complex elliptic integral of the second kind `E(k)` or `E(φ, k)`.
///
/// See https://en.wikipedia.org/wiki/Elliptic_integral for details.
Complex ellipticEComplex(Complex k, {Complex? phi}) {
  if (k.isNaN) return Complex.nan;
  if (phi == null) {
    if (k.a == 0.0 && k.b == 0.0) return const Complex(pi / 2.0);
    final k2 = k * k;
    final q = Complex.one - k2;
    return _carlsonRFComplex(Complex.zero, q, Complex.one) -
        (k2 / const Complex(3.0)) *
            _carlsonRDComplex(Complex.zero, q, Complex.one);
  }
  if (phi.isNaN) return Complex.nan;
  if (phi.a == 0.0 && phi.b == 0.0) return Complex.zero;
  if (k.a == 0.0 && k.b == 0.0) return phi;

  final m = (phi.a / pi).round();
  final psi = phi - Complex(m * pi);
  final s = psi.sin();
  final c = psi.cos();
  final k2 = k * k;
  final s2 = s * s;
  final c2 = c * c;
  final q = Complex.one - k2 * s2;
  final rf = _carlsonRFComplex(c2, q, Complex.one);
  final rd = _carlsonRDComplex(c2, q, Complex.one);
  final ePsi = s * rf - (k2 * s * s2 / const Complex(3.0)) * rd;
  return m == 0 ? ePsi : Complex(2.0 * m) * ellipticEComplex(k) + ePsi;
}

/// Returns the incomplete elliptic integral of the first kind
/// `F(φ, k) = ∫_0^φ dθ / sqrt(1 - k^2 * sin(θ)^2)`.
///
/// For `φ = π / 2`, this equals the complete integral [ellipticK].
/// Evaluated via Carlson's symmetric form `R_F`.
///
/// See https://en.wikipedia.org/wiki/Elliptic_integral for details.
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

/// Returns the complex incomplete elliptic integral of the first kind `F(φ, k)`.
///
/// See https://en.wikipedia.org/wiki/Elliptic_integral for details.
Complex ellipticFComplex(Complex phi, Complex k) {
  if (phi.isNaN || k.isNaN) {
    return Complex.nan;
  }
  if (phi.a == 0.0 && phi.b == 0.0) return Complex.zero;
  if (k.a == 0.0 && k.b == 0.0) return phi;

  final m = (phi.a / pi).round();
  final psi = phi - Complex(m * pi);
  final s = psi.sin();
  final c = psi.cos();
  final q = Complex.one - k * k * s * s;
  final fPsi = s * _carlsonRFComplex(c * c, q, Complex.one);
  return m == 0 ? fPsi : Complex(2.0 * m) * ellipticKComplex(k) + fPsi;
}

/// Returns the elliptic integral of the third kind `Π(n, k)` or `Π(n, φ, k)`.
///
/// When [phi] is omitted, returns the complete integral `Π(n, k)` defined for
/// `n < 1` and `-1 <= k <= 1`. When [phi] is provided, returns the incomplete
/// integral `Π(n, φ, k) = ∫_0^φ dθ / ((1 - n * sin(θ)^2) * sqrt(1 - k^2 * sin(θ)^2))`.
///
/// See https://en.wikipedia.org/wiki/Elliptic_integral for details.
double ellipticPi(num n, num k, {num? phi}) {
  final nd = n.toDouble();
  final kd = k.toDouble();
  if (nd.isNaN || kd.isNaN || kd.abs() > 1.0) return double.nan;
  if (phi == null) {
    if (nd >= 1.0) return double.nan;
    if (nd == 0.0) return ellipticK(kd);
    final k2 = kd * kd;
    final q = 1.0 - k2;
    return _carlsonRF(0.0, q, 1.0) +
        (nd / 3.0) * _carlsonRJ(0.0, q, 1.0, 1.0 - nd);
  }
  final phiD = phi.toDouble();
  if (phiD.isNaN) return double.nan;
  if (phiD.isInfinite) return phiD;
  if (phiD == 0.0) return 0.0;
  if (nd == 0.0) return ellipticF(phiD, kd);

  final m = (phiD / pi).round();
  final psi = phiD - m * pi;
  final sign = psi >= 0 ? 1.0 : -1.0;
  final absPsi = psi.abs();
  final s = sin(absPsi);
  final c = cos(absPsi);
  final s2 = s * s;
  final p = 1.0 - nd * s2;
  if (p <= 0.0) return double.nan;
  final q = 1.0 - kd * kd * s2;
  final piPsi =
      sign *
      (s * _carlsonRF(c * c, q, 1.0) +
          (nd * s * s2 / 3.0) * _carlsonRJ(c * c, q, 1.0, p));
  return m == 0 ? piPsi : 2.0 * m * ellipticPi(nd, kd) + piPsi;
}

/// Returns the complex elliptic integral of the third kind `Π(n, k)` or
/// `Π(n, φ, k)`.
///
/// See https://en.wikipedia.org/wiki/Elliptic_integral for details.
Complex ellipticPiComplex(Complex n, Complex k, {Complex? phi}) {
  if (n.isNaN || k.isNaN) {
    return Complex.nan;
  }
  if (phi == null) {
    if (n.a == 0.0 && n.b == 0.0) return ellipticKComplex(k);
    final q = Complex.one - k * k;
    return _carlsonRFComplex(Complex.zero, q, Complex.one) +
        (n / const Complex(3.0)) *
            _carlsonRJComplex(Complex.zero, q, Complex.one, Complex.one - n);
  }
  if (phi.isNaN) return Complex.nan;
  if (phi.a == 0.0 && phi.b == 0.0) return Complex.zero;
  if (n.a == 0.0 && n.b == 0.0) return ellipticFComplex(phi, k);

  final m = (phi.a / pi).round();
  final psi = phi - Complex(m * pi);
  final s = psi.sin();
  final c = psi.cos();
  final s2 = s * s;
  final c2 = c * c;
  final q = Complex.one - k * k * s2;
  final p = Complex.one - n * s2;
  final piPsi =
      s * _carlsonRFComplex(c2, q, Complex.one) +
      (n * s * s2 / const Complex(3.0)) *
          _carlsonRJComplex(c2, q, Complex.one, p);
  return m == 0 ? piPsi : Complex(2.0 * m) * ellipticPiComplex(n, k) + piPsi;
}

double _ellipticEIncomplete(num phi, num k) {
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
    if (maxDev < 0.0002) {
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

double _carlsonRC(double x, double y) {
  var xn = x;
  var yn = y;
  for (var iter = 0; iter < 100; iter++) {
    final lambda = 2.0 * sqrt(xn) * sqrt(yn) + yn;
    xn = 0.25 * (xn + lambda);
    yn = 0.25 * (yn + lambda);
    final mu = (xn + 2.0 * yn) / 3.0;
    final s = (yn - mu) / mu;
    if (s.abs() < 0.0002) {
      return (1.0 +
              s *
                  s *
                  (0.3 + s * (1.0 / 7.0 + s * (0.375 + s * (9.0 / 22.0))))) /
          sqrt(mu);
    }
  }
  return double.nan;
}

double _carlsonRJ(double x, double y, double z, double p) {
  var xn = x;
  var yn = y;
  var zn = z;
  var pn = p;
  var sum = 0.0;
  var fac = 1.0;
  for (var iter = 0; iter < 100; iter++) {
    final sx = sqrt(xn);
    final sy = sqrt(yn);
    final sz = sqrt(zn);
    final lambda = sx * (sy + sz) + sy * sz;
    final alphaBase = pn * (sx + sy + sz) + sx * sy * sz;
    final alpha = alphaBase * alphaBase;
    final beta = pn * (pn + lambda) * (pn + lambda);
    sum += fac * _carlsonRC(alpha, beta);
    fac *= 0.25;
    xn = 0.25 * (xn + lambda);
    yn = 0.25 * (yn + lambda);
    zn = 0.25 * (zn + lambda);
    pn = 0.25 * (pn + lambda);
    final mu = 0.2 * (xn + yn + zn + 2.0 * pn);
    final xDev = (mu - xn) / mu;
    final yDev = (mu - yn) / mu;
    final zDev = (mu - zn) / mu;
    final pDev = (mu - pn) / mu;
    final maxDev = max(
      max(xDev.abs(), yDev.abs()),
      max(zDev.abs(), pDev.abs()),
    );
    if (maxDev < 0.0002) {
      final ea = xDev * (yDev + zDev) + yDev * zDev;
      final eb = xDev * yDev * zDev;
      final ec = pDev * pDev;
      final e2 = ea - 3.0 * ec;
      final e3 = eb + 2.0 * pDev * (ea - ec);
      final s1 =
          1.0 +
          e2 * (-3.0 / 14.0 + 9.0 / 88.0 * e2 - 9.0 / 52.0 * e3) +
          e3 * (1.0 / 6.0);
      final s2 =
          pDev *
          (-3.0 / 22.0 * (2.0 * eb + pDev * (ea - ec)) +
              3.0 / 26.0 * eb * pDev);
      return 3.0 * sum + fac * (s1 + s2) / (mu * sqrt(mu));
    }
  }
  return double.nan;
}

Complex _carlsonRFComplex(Complex x, Complex y, Complex z) {
  var xn = x;
  var yn = y;
  var zn = z;
  for (var iter = 0; iter < 100; iter++) {
    final sx = xn.sqrt();
    final sy = yn.sqrt();
    final sz = zn.sqrt();
    final lambda = sx * (sy + sz) + sy * sz;
    xn = const Complex(0.25) * (xn + lambda);
    yn = const Complex(0.25) * (yn + lambda);
    zn = const Complex(0.25) * (zn + lambda);
    final mu = (xn + yn + zn) / const Complex(3.0);
    final xDev = (mu - xn) / mu;
    final yDev = (mu - yn) / mu;
    final zDev = (mu - zn) / mu;
    final maxDev = max(xDev.abs(), max(yDev.abs(), zDev.abs()));
    if (maxDev < 0.0002) {
      final e2 = xDev * yDev - zDev * zDev;
      final e3 = xDev * yDev * zDev;
      return (Complex.one -
              const Complex(0.1) * e2 +
              const Complex(1.0 / 14.0) * e3 +
              const Complex(1.0 / 24.0) * e2 * e2 -
              const Complex(3.0 / 44.0) * e2 * e3) /
          mu.sqrt();
    }
  }
  return Complex.nan;
}

Complex _carlsonRDComplex(Complex x, Complex y, Complex z) {
  var xn = x;
  var yn = y;
  var zn = z;
  var sum = Complex.zero;
  var fac = Complex.one;
  for (var iter = 0; iter < 100; iter++) {
    final sx = xn.sqrt();
    final sy = yn.sqrt();
    final sz = zn.sqrt();
    final lambda = sx * (sy + sz) + sy * sz;
    sum += fac / (sz * (zn + lambda));
    fac *= const Complex(0.25);
    xn = const Complex(0.25) * (xn + lambda);
    yn = const Complex(0.25) * (yn + lambda);
    zn = const Complex(0.25) * (zn + lambda);
    final mu = (xn + yn + const Complex(3.0) * zn) * const Complex(0.2);
    final xDev = (mu - xn) / mu;
    final yDev = (mu - yn) / mu;
    final zDev = (mu - zn) / mu;
    final maxDev = max(xDev.abs(), max(yDev.abs(), zDev.abs()));
    if (maxDev < 0.0002) {
      final ea = xDev * yDev;
      final eb = zDev * zDev;
      final ec = ea - eb;
      final ed = ea - const Complex(6.0) * eb;
      final ee = ed + const Complex(2.0) * ec;
      return const Complex(3.0) * sum +
          fac *
              (Complex.one -
                  const Complex(3.0 / 14.0) * ed +
                  const Complex(1.0 / 6.0) * zDev * ee +
                  const Complex(9.0 / 22.0) * ec * eb -
                  const Complex(3.0 / 26.0) * ea * eb * zDev) /
              (mu * mu.sqrt());
    }
  }
  return Complex.nan;
}

Complex _carlsonRCComplex(Complex x, Complex y) {
  var xn = x;
  var yn = y;
  for (var iter = 0; iter < 100; iter++) {
    final lambda = const Complex(2.0) * xn.sqrt() * yn.sqrt() + yn;
    xn = const Complex(0.25) * (xn + lambda);
    yn = const Complex(0.25) * (yn + lambda);
    final mu = (xn + const Complex(2.0) * yn) / const Complex(3.0);
    final s = (yn - mu) / mu;
    if (s.abs() < 0.0002) {
      return (Complex.one +
              s *
                  s *
                  (const Complex(0.3) +
                      s *
                          (const Complex(1.0 / 7.0) +
                              s *
                                  (const Complex(0.375) +
                                      s * const Complex(9.0 / 22.0))))) /
          mu.sqrt();
    }
  }
  return Complex.nan;
}

Complex _carlsonRJComplex(Complex x, Complex y, Complex z, Complex p) {
  var xn = x;
  var yn = y;
  var zn = z;
  var pn = p;
  var sum = Complex.zero;
  var fac = Complex.one;
  for (var iter = 0; iter < 100; iter++) {
    final sx = xn.sqrt();
    final sy = yn.sqrt();
    final sz = zn.sqrt();
    final lambda = sx * (sy + sz) + sy * sz;
    final alphaBase = pn * (sx + sy + sz) + sx * sy * sz;
    final alpha = alphaBase * alphaBase;
    final beta = pn * (pn + lambda) * (pn + lambda);
    sum += fac * _carlsonRCComplex(alpha, beta);
    fac *= const Complex(0.25);
    xn = const Complex(0.25) * (xn + lambda);
    yn = const Complex(0.25) * (yn + lambda);
    zn = const Complex(0.25) * (zn + lambda);
    pn = const Complex(0.25) * (pn + lambda);
    final mu = const Complex(0.2) * (xn + yn + zn + const Complex(2.0) * pn);
    final xDev = (mu - xn) / mu;
    final yDev = (mu - yn) / mu;
    final zDev = (mu - zn) / mu;
    final pDev = (mu - pn) / mu;
    final maxDev = max(
      max(xDev.abs(), yDev.abs()),
      max(zDev.abs(), pDev.abs()),
    );
    if (maxDev < 0.0002) {
      final ea = xDev * (yDev + zDev) + yDev * zDev;
      final eb = xDev * yDev * zDev;
      final ec = pDev * pDev;
      final e2 = ea - const Complex(3.0) * ec;
      final e3 = eb + const Complex(2.0) * pDev * (ea - ec);
      final s1 =
          Complex.one +
          e2 *
              (const Complex(-3.0 / 14.0) +
                  const Complex(9.0 / 88.0) * e2 -
                  const Complex(9.0 / 52.0) * e3) +
          e3 * const Complex(1.0 / 6.0);
      final s2 =
          pDev *
          (const Complex(-3.0 / 22.0) *
                  (const Complex(2.0) * eb + pDev * (ea - ec)) +
              const Complex(3.0 / 26.0) * eb * pDev);
      return const Complex(3.0) * sum + fac * (s1 + s2) / (mu * mu.sqrt());
    }
  }
  return Complex.nan;
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
    xn = 0.25 * (xn + lambda);
    yn = 0.25 * (yn + lambda);
    zn = 0.25 * (zn + lambda);
    final mu = (xn + yn + 3.0 * zn) * 0.2;
    final xDev = (mu - xn) / mu;
    final yDev = (mu - yn) / mu;
    final zDev = (mu - zn) / mu;
    final maxDev = max(xDev.abs(), max(yDev.abs(), zDev.abs()));
    if (maxDev < 0.0002) {
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
  }
}
