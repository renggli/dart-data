import 'dart:math';

import 'package:more/number.dart' show Complex;

import 'gamma.dart';
import 'utils.dart';

/// Returns the Bessel function of the first kind `J_ν(x)` of real order [nu].
///
/// Evaluates `J_ν(x)` to 15-16 digits of relative precision using power series
/// for small `|x| <= 2`, Miller's backward recurrence and upward recurrence for
/// intermediate `x`, and Hankel's asymptotic expansion for large `x`.
///
/// For non-integer [nu], requires `x >= 0` (with `J_ν(0) = NaN` for negative
/// non-integer [nu]). For integer `ν = n`, defined for all real `x` with
/// `J_{-n}(x) = (-1)^n J_n(x)` and `J_n(±∞) = 0`.
///
/// See https://en.wikipedia.org/wiki/Bessel_function for details.
double besselJ(num nu, num x) {
  if (nu.isNaN || x.isNaN) return double.nan;
  final nud = nu.toDouble();
  final xd = x.toDouble();
  if (!nud.isFinite) return double.nan;

  final isInt = nud.abs() <= maxSafeInt && nud.roundToDouble() == nud;
  if (xd.isInfinite) {
    if (xd.isNegative && !isInt) return double.nan;
    return 0.0;
  }
  if (isInt) {
    final n = nud.toInt();
    if (n < 0) {
      final jPos = besselJ(-n, xd);
      return n.isOdd ? -jPos : jPos;
    }
    if (xd == 0.0) return n == 0 ? 1.0 : 0.0;
    if (xd < 0.0) {
      final jPos = besselJ(n, -xd);
      return n.isOdd ? -jPos : jPos;
    }
    if (xd <= 2.0) return _besselJSeries(n.toDouble(), xd);
    if (xd > max(25.0, n * n.toDouble())) return _hankelAsymptotic(nud, xd).j;
    if (n == 0) return _besselJMillerPair(0.0, xd).j0;
    if (n == 1) return _besselJMillerPair(0.0, xd).j1;
    if (xd > n) {
      final pair = _besselJMillerPair(0.0, xd);
      var j0 = pair.j0;
      var j1 = pair.j1;
      for (var k = 1; k < n; k++) {
        final jNext = (2.0 * k / xd) * j1 - j0;
        j0 = j1;
        j1 = jNext;
      }
      return j1;
    }
    return _besselJMillerNth(0.0, n, xd);
  }

  if (xd < 0.0) return double.nan;
  if (xd == 0.0) return nud > 0.0 ? 0.0 : double.nan;
  if (xd <= 2.0) return _besselJSeries(nud, xd);
  if (xd > max(25.0, nud * nud)) return _hankelAsymptotic(nud, xd).j;

  // Decompose nu = n + mu with mu in (-0.5, 0.5]
  final n = (nud + 0.5).floor();
  final mu = nud - n;
  if (n < 0) {
    // Downward recurrence from (J_mu, J_{mu+1}) is unconditionally stable.
    final (:j0, :j1) = _besselJMillerPair(mu, xd);
    var cur = j0;
    var next = j1;
    for (var k = 0; k > n; k--) {
      final prev = (2.0 * (k + mu) / xd) * cur - next;
      next = cur;
      cur = prev;
    }
    return cur;
  }
  if (xd > nud) {
    final pair = _besselJMillerPair(mu, xd);
    var j0 = pair.j0;
    var j1 = pair.j1;
    if (n == 0) return j0;
    if (n == 1) return j1;
    for (var k = 1; k < n; k++) {
      final jNext = (2.0 * (k + mu) / xd) * j1 - j0;
      j0 = j1;
      j1 = jNext;
    }
    return j1;
  }
  return _besselJMillerNth(mu, n, xd);
}

/// Returns the complex Bessel function of the first kind `J_ν(z)`.
///
/// See https://en.wikipedia.org/wiki/Bessel_function for details.
Complex besselJComplex(Complex nu, Complex z) {
  if (nu.isNaN || z.isNaN) return Complex.nan;
  if (!nu.a.isFinite || !nu.b.isFinite || !z.a.isFinite || !z.b.isFinite) {
    return Complex.nan;
  }
  if (z.a == 0.0 && z.b == 0.0) {
    if (nu.a == 0.0 && nu.b == 0.0) return Complex.one;
    if (nu.a > 0.0 ||
        (nu.b == 0.0 && nu.a < 0.0 && nu.a == nu.a.roundToDouble())) {
      return Complex.zero;
    }
    return Complex.nan;
  }
  if (nu.b == 0.0 && nu.a < 0.0 && nu.a == nu.a.roundToDouble()) {
    final n = nu.a.round();
    final pos = besselJComplex(Complex(-n.toDouble()), z);
    return n.isOdd ? -pos : pos;
  }
  if (z.abs() > max(12.0, nu.abs() * nu.abs())) {
    if (z.a < 0.0) {
      final phase = z.b < 0.0 ? -pi : pi;
      return (Complex.i * Complex(phase) * nu).exp() *
          _hankelAsymptoticComplex(nu, -z).j;
    }
    return _hankelAsymptoticComplex(nu, z).j;
  }
  final halfZ = const Complex(0.5) * z;
  var term = halfZ.pow(nu) / gammaComplex(nu + Complex.one);
  var sum = term;
  final halfZ2 = -halfZ * halfZ;
  for (var m = 1; m <= 80; m++) {
    term *= halfZ2 / (Complex(m.toDouble()) * (Complex(m.toDouble()) + nu));
    sum += term;
    if (term.abs() <= 1.0e-15 * sum.abs()) break;
  }
  return sum;
}

/// Returns the Bessel function of the second kind `Y_ν(x)` of real order [nu].
///
/// Defined for `x > 0` and finite real [nu]; returns `0.0` at `+∞` and
/// `double.nan` for `x <= 0`, non-finite [nu], or `NaN`. Uses Temme's small-`x`
/// series for `0 < x < 2`, Miller + Steed's CF2 for `2 <= x <= max(25, nu^2)`
/// (eliminating near-integer cancellation), and Hankel asymptotics for large `x`.
///
/// See https://en.wikipedia.org/wiki/Bessel_function for details.
double besselY(num nu, num x) {
  if (nu.isNaN || x.isNaN) return double.nan;
  final nud = nu.toDouble();
  final xd = x.toDouble();
  if (!nud.isFinite || xd <= 0.0) return double.nan;
  if (xd.isInfinite) return 0.0;
  if (xd > max(25.0, nud * nud)) return _hankelAsymptotic(nud, xd).y;

  final n = (nud + 0.5).floor();
  final mu = nud - n;
  final double y0;
  final double y1;
  if (xd < 2.0) {
    (y0: y0, y1: y1) = _besselYTemmeSmall(mu, xd);
  } else {
    final (:j0, :j1) = _besselJMillerPair(mu, xd);
    final (:p, :q) = _steedCF2(mu, xd);
    y0 = ((p - mu / xd) * j0 + j1) / q;
    y1 = (mu / xd - p) * y0 - q * j0;
  }

  if (n == 0) return y0;
  if (n == 1) return y1;
  if (n < 0) {
    var cur = y0;
    var next = y1;
    for (var k = 0; k > n; k--) {
      final prev = (2.0 * (k + mu) / xd) * cur - next;
      next = cur;
      cur = prev;
    }
    return cur;
  }
  var prev = y0;
  var cur = y1;
  for (var k = 1; k < n; k++) {
    final next = (2.0 * (k + mu) / xd) * cur - prev;
    prev = cur;
    cur = next;
  }
  return cur;
}

/// Returns the complex Bessel function of the second kind `Y_ν(z)`.
///
/// See https://en.wikipedia.org/wiki/Bessel_function for details.
Complex besselYComplex(Complex nu, Complex z) {
  if (nu.isNaN || z.isNaN) return Complex.nan;
  if (!nu.a.isFinite || !nu.b.isFinite || !z.a.isFinite || !z.b.isFinite) {
    return Complex.nan;
  }
  if (z.a == 0.0 && z.b == 0.0) return Complex.nan;
  if (nu.b == 0.0 && z.b == 0.0 && z.a > 0.0) {
    return Complex(besselY(nu.a.toDouble(), z.a.toDouble()));
  }
  if (z.abs() > max(12.0, nu.abs() * nu.abs()) && z.a >= 0.0) {
    return _hankelAsymptoticComplex(nu, z).y;
  }
  final sinPiNu = (const Complex(pi) * nu).sin();
  if (sinPiNu.abs() < 1e-12) {
    return _besselYIntComplex(nu.a.round(), z);
  }
  return (besselJComplex(nu, z) * (const Complex(pi) * nu).cos() -
          besselJComplex(-nu, z)) /
      sinPiNu;
}

/// Returns the modified Bessel function of the first kind `I_ν(x)` of real
/// order [nu].
///
/// For non-integer [nu], requires `x >= 0` (returning `double.nan` at `x = 0`
/// for negative non-integer [nu]). For integer `ν = n`, defined for all real
/// `x` with `I_{-n}(x) = I_n(x)` and `I_n(-x) = (-1)^n I_n(x)`.
///
/// See https://en.wikipedia.org/wiki/Bessel_function#Modified_Bessel_functions
/// for details.
double besselI(num nu, num x) {
  if (nu.isNaN || x.isNaN) return double.nan;
  final nud = nu.toDouble();
  final xd = x.toDouble();
  if (!nud.isFinite) return double.nan;

  final isInt = nud.abs() <= maxSafeInt && nud.roundToDouble() == nud;
  if (xd.isInfinite) {
    if (xd.isNegative) {
      if (!isInt) return double.nan;
      return nud.toInt().isOdd ? double.negativeInfinity : double.infinity;
    }
    return double.infinity;
  }
  if (isInt) {
    final n = nud.toInt().abs();
    if (xd == 0.0) return n == 0 ? 1.0 : 0.0;
    if (xd < 0.0) {
      final iPos = besselI(n, -xd);
      return n.isOdd ? -iPos : iPos;
    }
    if (xd > max(25.0, n * n.toDouble())) {
      return _modifiedBesselAsymptotic(n.toDouble(), xd).i;
    }
    return _besselISeries(n.toDouble(), xd);
  }

  if (xd < 0.0) return double.nan;
  if (xd == 0.0) return nud > 0.0 ? 0.0 : double.nan;
  if (xd > max(25.0, nud * nud)) return _modifiedBesselAsymptotic(nud, xd).i;
  if (nud >= -0.5) return _besselISeries(nud, xd);

  // Negative non-integer order via I_{-nu}(x) = I_{nu}(x) + (2/pi)*sin(pi*nu)*K_{nu}(x)
  final posNu = -nud;
  final r = posNu - 2.0 * (posNu / 2.0).roundToDouble();
  return _besselISeries(posNu, xd) +
      (2.0 / pi) * sin(pi * r) * besselK(posNu, xd);
}

/// Returns the complex modified Bessel function of the first kind `I_ν(z)`.
///
/// See https://en.wikipedia.org/wiki/Bessel_function#Modified_Bessel_functions
/// for details.
Complex besselIComplex(Complex nu, Complex z) {
  if (nu.isNaN || z.isNaN) return Complex.nan;
  if (!nu.a.isFinite || !nu.b.isFinite || !z.a.isFinite || !z.b.isFinite) {
    return Complex.nan;
  }
  if (z.a == 0.0 && z.b == 0.0) {
    if (nu.a == 0.0 && nu.b == 0.0) return Complex.one;
    if (nu.a > 0.0 ||
        (nu.b == 0.0 && nu.a < 0.0 && nu.a == nu.a.roundToDouble())) {
      return Complex.zero;
    }
    return Complex.nan;
  }
  if (nu.b == 0.0 && nu.a < 0.0 && nu.a == nu.a.roundToDouble()) {
    return besselIComplex(-nu, z);
  }
  if (z.abs() > max(12.0, nu.abs() * nu.abs())) {
    if (z.a < 0.0) {
      final phase = z.b < 0.0 ? -pi : pi;
      return (Complex.i * Complex(phase) * nu).exp() *
          _modifiedBesselAsymptoticComplex(nu, -z).i;
    }
    return _modifiedBesselAsymptoticComplex(nu, z).i;
  }
  final halfZ = const Complex(0.5) * z;
  var term = halfZ.pow(nu) / gammaComplex(nu + Complex.one);
  var sum = term;
  final halfZ2 = halfZ * halfZ;
  for (var m = 1; m <= 80; m++) {
    term *= halfZ2 / (Complex(m.toDouble()) * (Complex(m.toDouble()) + nu));
    sum += term;
    if (term.abs() <= 1.0e-15 * sum.abs()) break;
  }
  return sum;
}

/// Returns the modified Bessel function of the second kind `K_ν(x)` of real
/// order [nu].
///
/// Even in [nu] (`K_{-ν}(x) = K_ν(x)`), defined for `x > 0` and finite real
/// [nu], returning `0.0` at `+∞` and `double.nan` for `x <= 0`, non-finite
/// [nu], or `NaN`. Uses exponentially scaled trapezoidal quadrature for
/// `|μ| <= 0.5` combined with unconditionally stable upward recurrence, avoiding
/// `I_{-ν} - I_ν` cancellation.
///
/// See https://en.wikipedia.org/wiki/Bessel_function#Modified_Bessel_functions
/// for details.
double besselK(num nu, num x) {
  if (nu.isNaN || x.isNaN) return double.nan;
  final nud = nu.toDouble();
  final xd = x.toDouble();
  if (!nud.isFinite || xd <= 0.0) return double.nan;
  if (xd.isInfinite) return 0.0;

  final absNu = nud.abs();
  if (xd > max(25.0, absNu * absNu)) {
    return _modifiedBesselAsymptotic(absNu, xd).k;
  }

  final n = (absNu + 0.5).floor();
  final mu = absNu - n;

  final double k0;
  final double k1;
  if (xd < 1e-4 && mu.abs() > 1e-4) {
    final sinPiMu = sin(pi * mu);
    k0 =
        (pi / 2.0) *
        (_besselISeries(-mu, xd) - _besselISeries(mu, xd)) /
        sinPiMu;
    k1 =
        (pi / 2.0) *
        (_besselISeries(-(mu + 1.0), xd) - _besselISeries(mu + 1.0, xd)) /
        (-sinPiMu);
  } else if (xd < 0.5 && mu == 0.0) {
    k0 = _besselK0Series(xd);
    k1 = _besselK1Series(xd);
  } else {
    k0 = _besselKTrap(mu, xd);
    k1 = _besselKTrap(mu + 1.0, xd);
  }

  if (n == 0) return k0;
  if (n == 1) return k1;
  var kPrev = k0;
  var kCur = k1;
  for (var k = 1; k < n; k++) {
    final kNext = (2.0 * (k + mu) / xd) * kCur + kPrev;
    kPrev = kCur;
    kCur = kNext;
    if (!kCur.isFinite) return double.infinity;
  }
  return kCur;
}

/// Returns the complex modified Bessel function of the second kind `K_ν(z)`.
///
/// See https://en.wikipedia.org/wiki/Bessel_function#Modified_Bessel_functions
/// for details.
Complex besselKComplex(Complex nu, Complex z) {
  if (nu.isNaN || z.isNaN) return Complex.nan;
  if (!nu.a.isFinite || !nu.b.isFinite || !z.a.isFinite || !z.b.isFinite) {
    return Complex.nan;
  }
  if (z.a == 0.0 && z.b == 0.0) {
    return nu.b == 0.0 ? const Complex(double.infinity) : Complex.nan;
  }
  if (nu.b == 0.0 && z.b == 0.0 && z.a > 0.0) {
    return Complex(besselK(nu.a.toDouble(), z.a.toDouble()));
  }
  if (z.abs() > max(12.0, nu.abs() * nu.abs()) && z.a >= 0.0) {
    return _modifiedBesselAsymptoticComplex(nu, z).k;
  }
  final sinPiNu = (const Complex(pi) * nu).sin();
  if (sinPiNu.abs() < 1e-12) {
    return _besselKIntComplex(nu.a.round(), z);
  }
  return const Complex(pi / 2.0) *
      (besselIComplex(-nu, z) - besselIComplex(nu, z)) /
      sinPiNu;
}

double _besselJSeries(double nu, double x) {
  final halfX = 0.5 * x;
  double term;
  if (nu > 100.0) {
    final g = logAbsGammaWithSign(nu + 1.0);
    if (g.sign == 0) return 0.0;
    final logTerm = nu * log(halfX) - g.logAbs;
    if (logTerm < -745.0) return 0.0;
    term = g.sign * exp(logTerm);
  } else {
    final gammaVal = gamma(nu + 1.0);
    if (gammaVal.isInfinite || gammaVal.isNaN) return 0.0;
    term = pow(halfX, nu).toDouble() / gammaVal;
  }
  var sum = term;
  final halfX2 = -halfX * halfX;
  for (var m = 1; m <= 100; m++) {
    term *= halfX2 / (m * (m + nu));
    sum += term;
    if (term.abs() <= 1.0e-16 * sum.abs()) break;
  }
  return sum;
}

double _besselISeries(double nu, double x) {
  final halfX = 0.5 * x;
  double term;
  if (nu > 100.0) {
    final g = logAbsGammaWithSign(nu + 1.0);
    if (g.sign == 0) return 0.0;
    final logTerm = nu * log(halfX) - g.logAbs;
    if (logTerm < -745.0) return 0.0;
    term = g.sign * exp(logTerm);
  } else {
    final gammaVal = gamma(nu + 1.0);
    if (gammaVal.isInfinite || gammaVal.isNaN) return 0.0;
    term = pow(halfX, nu).toDouble() / gammaVal;
  }
  var sum = term;
  final halfX2 = halfX * halfX;
  for (var m = 1; m <= 150; m++) {
    term *= halfX2 / (m * (m + nu));
    sum += term;
    if (term.abs() <= 1.0e-16 * sum.abs()) break;
  }
  return sum;
}

({double j0, double j1}) _besselJMillerPair(double mu, double x) {
  final m = 2 * (x.toInt() + sqrt(40.0 * max(x, 1.0)).toInt() + 15);
  final halfM = m ~/ 2;
  var fNext = 0.0;
  var fCur = 1.0e-30;
  var j0 = 0.0;
  var j1 = 0.0;
  var norm = 0.0;

  if (mu == 0.0) {
    for (var k = m; k > 0; k--) {
      final fPrev = (2.0 * k / x) * fCur - fNext;
      fNext = fCur;
      fCur = fPrev;
      if (fCur.abs() > 1e100) {
        fCur *= 1e-100;
        fNext *= 1e-100;
        norm *= 1e-100;
        j0 *= 1e-100;
        j1 *= 1e-100;
      }
      final idx = k - 1;
      if (idx == 1) j1 = fCur;
      if (idx == 0) {
        j0 = fCur;
        norm += fCur;
      } else if (idx.isEven) {
        norm += 2.0 * fCur;
      }
    }
    return norm == 0.0 ? (j0: 0.0, j1: 0.0) : (j0: j0 / norm, j1: j1 / norm);
  }

  final weights = List<double>.filled(halfM + 1, 0.0);
  weights[0] = 1.0;
  var p = 1.0;
  for (var k = 1; k <= halfM; k++) {
    if (k > 1) p *= (mu + k - 1.0) / k;
    weights[k] = (mu + 2.0 * k) * p;
  }

  for (var k = m; k > 0; k--) {
    final fPrev = (2.0 * (k + mu) / x) * fCur - fNext;
    fNext = fCur;
    fCur = fPrev;
    if (fCur.abs() > 1e100) {
      fCur *= 1e-100;
      fNext *= 1e-100;
      norm *= 1e-100;
      j0 *= 1e-100;
      j1 *= 1e-100;
    }
    final idx = k - 1;
    if (idx == 1) j1 = fCur;
    if (idx == 0) {
      j0 = fCur;
      norm += fCur;
    } else if (idx.isEven) {
      norm += weights[idx ~/ 2] * fCur;
    }
  }
  if (norm == 0.0) return (j0: 0.0, j1: 0.0);
  final rhs = pow(0.5 * x, mu).toDouble() / gamma(mu + 1.0);
  final scale = rhs / norm;
  return (j0: j0 * scale, j1: j1 * scale);
}

double _besselJMillerNth(double mu, int n, double x) {
  final m = 2 * (max(n, x.toInt()) + sqrt(40.0 * max(n, 1)).toInt() + 15);
  var fNext = 0.0;
  var fCur = 1.0e-30;
  var fn = 0.0;
  var norm = 0.0;

  if (mu == 0.0) {
    for (var k = m; k > 0; k--) {
      final fPrev = (2.0 * k / x) * fCur - fNext;
      fNext = fCur;
      fCur = fPrev;
      if (fCur.abs() > 1e100) {
        fCur *= 1e-100;
        fNext *= 1e-100;
        fn *= 1e-100;
        norm *= 1e-100;
      }
      final idx = k - 1;
      if (idx == n) fn = fCur;
      if (idx.isEven) {
        norm += idx == 0 ? fCur : 2.0 * fCur;
      }
    }
    return norm == 0.0 ? 0.0 : fn / norm;
  }

  final halfM = m ~/ 2;
  final weights = List<double>.filled(halfM + 1, 0.0);
  weights[0] = 1.0;
  var p = 1.0;
  for (var k = 1; k <= halfM; k++) {
    if (k > 1) p *= (mu + k - 1.0) / k;
    weights[k] = (mu + 2.0 * k) * p;
  }
  for (var k = m; k > 0; k--) {
    final fPrev = (2.0 * (k + mu) / x) * fCur - fNext;
    fNext = fCur;
    fCur = fPrev;
    if (fCur.abs() > 1e100) {
      fCur *= 1e-100;
      fNext *= 1e-100;
      fn *= 1e-100;
      norm *= 1e-100;
    }
    final idx = k - 1;
    if (idx == n) fn = fCur;
    if (idx.isEven) {
      norm += weights[idx ~/ 2] * fCur;
    }
  }
  if (norm == 0.0) return 0.0;
  final rhs = pow(0.5 * x, mu).toDouble() / gamma(mu + 1.0);
  return fn * (rhs / norm);
}

({double p, double q}) _steedCF2(double mu, double x) {
  final mu2 = mu * mu;
  final h = lentzCFComplex(
    Complex(2.0 * x, 2.0),
    (k) => Complex((k + 0.5) * (k + 0.5) - mu2),
    (k) => Complex(2.0 * x, 2.0 * (k + 1)),
    maxIter: 400,
    tol: 1e-15,
  );
  final pq = Complex(-0.5 / x, 1.0) + Complex(0.0, (0.25 - mu2) / x) * h;
  return (p: pq.a.toDouble(), q: pq.b.toDouble());
}

({double y0, double y1}) _besselYTemmeSmall(double mu, double x) {
  final x2 = 0.5 * x;
  final fact = mu == 0.0 ? 1.0 : (pi * mu) / sin(pi * mu);
  final d = -log(x2);
  final eVal = mu * d;
  final fact2 = eVal.abs() < 1e-8
      ? 1.0
      : (exp(eVal) - exp(-eVal)) / (2.0 * eVal);
  final mu2 = mu * mu;
  var even = 0.0;
  for (var i = _invGammaTaylor.length - 1; i >= 0; i -= 2) {
    even = even * mu2 + _invGammaTaylor[i];
  }
  var odd = 0.0;
  for (var i = _invGammaTaylor.length - 2; i >= 1; i -= 2) {
    odd = odd * mu2 + _invGammaTaylor[i];
  }
  final gam1 = -odd;
  final gam2 = even;
  final gampl = gam2 - mu * gam1;
  final gammi = gam2 + mu * gam1;
  final coshE = 0.5 * (exp(eVal) + exp(-eVal));
  var ff = 2.0 / pi * fact * (gam1 * coshE + gam2 * fact2 * d);
  final expE = exp(eVal);
  var p = expE / (gampl * pi);
  var q = 1.0 / (expE * pi * gammi);
  final pimu2 = 0.5 * pi * mu;
  final fact3 = pimu2.abs() < 1e-8 ? 1.0 : sin(pimu2) / pimu2;
  final r = pi * pimu2 * fact3 * fact3;
  var c = 1.0;
  final dSq = -x2 * x2;
  var sumY = ff + r * q;
  var sum1 = p;
  for (var i = 1; i <= 100; i++) {
    ff = (i * ff + p + q) / (i * i - mu2);
    c *= dSq / i;
    p /= i - mu;
    q /= i + mu;
    final delY = c * (ff + r * q);
    sumY += delY;
    sum1 += c * p - i * delY;
    if (delY.abs() <= (1.0 + sumY.abs()) * 1e-16) break;
  }
  return (y0: -sumY, y1: -sum1 * 2.0 / x);
}

double _besselKTrap(double mu, double x) {
  final h = min(0.22, 0.5 / sqrt(x));
  var sum = 0.5;
  for (var k = 1; k < 4000; k++) {
    final t = k * h;
    final halfT = 0.5 * t;
    final sh = 0.5 * (exp(halfT) - exp(-halfT));
    final arg = -2.0 * x * sh * sh;
    final e1 = arg + mu * t;
    final e2 = arg - mu * t;
    if (e1 < -40.0 && e2 < -40.0) break;
    final term = 0.5 * (exp(e1) + exp(e2));
    sum += term;
    if (term < 1e-17 * sum) break;
  }
  return h * exp(-x) * sum;
}

double _besselK0Series(double x) {
  final hx = 0.5 * x;
  final hx2 = hx * hx;
  var i0 = 1.0;
  var term = 1.0;
  var h = 0.0;
  var sum = 0.0;
  for (var m = 1; m <= 30; m++) {
    term *= hx2 / (m * m);
    i0 += term;
    h += 1.0 / m;
    final add = term * h;
    sum += add;
    if (add.abs() <= 1e-16 * max(1.0, sum.abs())) break;
  }
  return -(log(hx) + eulerMascheroni) * i0 + sum;
}

double _besselK1Series(double x) {
  final hx = 0.5 * x;
  final hx2 = hx * hx;
  var i1 = hx;
  var term = hx;
  var hk = 0.0;
  var hk1 = 1.0;
  var sum = hx;
  for (var k = 1; k <= 30; k++) {
    term *= hx2 / (k * (k + 1));
    i1 += term;
    hk = hk1;
    hk1 += 1.0 / (k + 1);
    final add = term * (hk + hk1);
    sum += add;
    if (add.abs() <= 1e-16 * max(1.0, sum.abs())) break;
  }
  return 1.0 / x + (log(hx) + eulerMascheroni) * i1 - 0.5 * sum;
}

({double j, double y}) _hankelAsymptotic(double nu, double x) {
  final mu = 4.0 * nu * nu;
  final eightX = 8.0 * x;
  var p = 1.0;
  var q = 0.0;
  var a = 1.0;
  var pSign = -1.0;
  var qSign = 1.0;

  for (var k = 1; k <= 30; k++) {
    final prevA = a.abs();
    a *= (mu - (2 * k - 1) * (2 * k - 1)) / (k * eightX);
    if (a.abs() >= prevA) break;
    if (k.isOdd) {
      q += qSign * a;
      qSign = -qSign;
    } else {
      p += pSign * a;
      pSign = -pSign;
    }
    if (a.abs() < 1e-16 * (p.abs() + q.abs())) break;
  }

  final theta = x - (2.0 * nu + 1.0) * pi / 4.0;
  final cosTheta = cos(theta);
  final sinTheta = sin(theta);
  final factor = sqrt(2.0 / (pi * x));

  return (
    j: factor * (p * cosTheta - q * sinTheta),
    y: factor * (p * sinTheta + q * cosTheta),
  );
}

({double i, double k}) _modifiedBesselAsymptotic(double nu, double x) {
  final mu = 4.0 * nu * nu;
  final eightX = 8.0 * x;
  var sumI = 1.0;
  var sumK = 1.0;
  var termI = 1.0;
  var termK = 1.0;

  for (var k = 1; k <= 30; k++) {
    final prevTerm = termI.abs();
    final factor = (mu - (2 * k - 1) * (2 * k - 1)) / (k * eightX);
    termI *= -factor;
    termK *= factor;
    if (k > 2 && termI.abs() >= prevTerm) break;
    sumI += termI;
    sumK += termK;
    if (termI.abs() < 1e-16 * sumI.abs() && termK.abs() < 1e-16 * sumK.abs()) {
      break;
    }
  }

  final invSqrt2PiX = 1.0 / sqrt(2.0 * pi * x);
  final double valI;
  if (x > 700.0) {
    final halfExp = exp(0.5 * x);
    valI = halfExp * (halfExp * invSqrt2PiX * sumI);
  } else {
    valI = exp(x) * invSqrt2PiX * sumI;
  }
  final valK = sqrt(pi / (2.0 * x)) * exp(-x) * sumK;
  return (i: valI, k: valK);
}

({Complex j, Complex y}) _hankelAsymptoticComplex(Complex nu, Complex z) {
  final mu = const Complex(4.0) * nu * nu;
  final eightZ = const Complex(8.0) * z;
  var p = Complex.one;
  var q = Complex.zero;
  var term = Complex.one;
  var sign = 1.0;

  for (var k = 1; k <= 20; k++) {
    final prevTerm = term.abs();
    final num = mu - Complex(((2 * k - 1) * (2 * k - 1)).toDouble());
    term = term * num / (Complex(k.toDouble()) * eightZ);
    if (k > 2 && term.abs() >= prevTerm) break;
    if (k.isOdd) {
      q += Complex(sign) * term;
      sign = -sign;
    } else {
      p += Complex(sign) * term;
    }
    if (term.abs() < 1e-16) break;
  }

  final theta =
      z - (nu * const Complex(0.5) + const Complex(0.25)) * const Complex(pi);
  final cosTheta = theta.cos();
  final sinTheta = theta.sin();
  final factor = (const Complex(2.0) / (const Complex(pi) * z)).sqrt();

  return (
    j: factor * (p * cosTheta - q * sinTheta),
    y: factor * (p * sinTheta + q * cosTheta),
  );
}

({Complex i, Complex k}) _modifiedBesselAsymptoticComplex(
  Complex nu,
  Complex z,
) {
  final mu = const Complex(4.0) * nu * nu;
  final eightZ = const Complex(8.0) * z;
  var sumI = Complex.one;
  var sumK = Complex.one;
  var termI = Complex.one;
  var termK = Complex.one;

  for (var k = 1; k <= 30; k++) {
    final prevTerm = termI.abs();
    final factor =
        (mu - Complex(((2 * k - 1) * (2 * k - 1)).toDouble())) /
        (Complex(k.toDouble()) * eightZ);
    termI *= -factor;
    termK *= factor;
    if (k > 2 && termI.abs() >= prevTerm) break;
    sumI += termI;
    sumK += termK;
    if (termI.abs() < 1e-16 * sumI.abs() && termK.abs() < 1e-16 * sumK.abs()) {
      break;
    }
  }

  final factorI = z.exp() / (const Complex(2.0 * pi) * z).sqrt();
  final factorK = (const Complex(pi / 2.0) / z).sqrt() * (-z).exp();
  var valI = factorI * sumI;
  if (z.a < 20.0) {
    final stokesPhase = z.b >= 0.0 ? 1.0 : -1.0;
    final stokesExp = (Complex(0.0, stokesPhase * pi) * (nu + 0.5)).exp();
    valI +=
        stokesExp * (-z).exp() / (const Complex(2.0 * pi) * z).sqrt() * sumK;
  }
  return (i: valI, k: factorK * sumK);
}

Complex _besselYIntComplex(int n, Complex z) {
  if (n < 0) {
    final pos = _besselYIntComplex(-n, z);
    return n.isOdd ? -pos : pos;
  }
  final hz = const Complex(0.5) * z;
  final hz2 = hz * hz;
  var fin = Complex.zero;
  if (n > 0) {
    var fTerm = Complex(exp(gammaLn(n.toDouble())));
    for (var k = 0; k < n; k++) {
      fin += fTerm;
      if (k + 1 < n) {
        fTerm *= hz2 / Complex(((k + 1) * (n - 1 - k)).toDouble());
      }
    }
    fin *= hz.pow(Complex(-n.toDouble()));
  }
  var hk = 0.0;
  var hkn = 0.0;
  for (var j = 1; j <= n; j++) {
    hkn += 1.0 / j;
  }
  var iTerm = Complex(exp(-gammaLn(n + 1.0)));
  var infSum = iTerm * Complex(hk + hkn);
  for (var k = 1; k <= 80; k++) {
    iTerm *= -hz2 / Complex((k * (n + k)).toDouble());
    hk += 1.0 / k;
    hkn += 1.0 / (n + k);
    final add = iTerm * Complex(hk + hkn);
    infSum += add;
    if (add.abs() <= 1e-15 * max(1.0, infSum.abs())) break;
  }
  infSum *= hz.pow(Complex(n.toDouble()));
  return const Complex(2.0 / pi) *
          (hz.log() + const Complex(eulerMascheroni)) *
          besselJComplex(Complex(n.toDouble()), z) -
      (fin + infSum) / const Complex(pi);
}

Complex _besselKIntComplex(int n, Complex z) {
  final m = n.abs();
  final hz = const Complex(0.5) * z;
  final hz2 = hz * hz;
  var fin = Complex.zero;
  if (m > 0) {
    var fTerm = Complex(exp(gammaLn(m.toDouble())));
    for (var k = 0; k < m; k++) {
      fin += fTerm;
      if (k + 1 < m) {
        fTerm *= -hz2 / Complex(((k + 1) * (m - 1 - k)).toDouble());
      }
    }
    fin *= const Complex(0.5) * hz.pow(Complex(-m.toDouble()));
  }
  var hk = 0.0;
  var hkm = 0.0;
  for (var j = 1; j <= m; j++) {
    hkm += 1.0 / j;
  }
  var iTerm = Complex(exp(-gammaLn(m + 1.0)));
  var infSum = iTerm * Complex(hk + hkm);
  for (var k = 1; k <= 80; k++) {
    iTerm *= hz2 / Complex((k * (m + k)).toDouble());
    hk += 1.0 / k;
    hkm += 1.0 / (m + k);
    final add = iTerm * Complex(hk + hkm);
    infSum += add;
    if (add.abs() <= 1e-15 * max(1.0, infSum.abs())) break;
  }
  final sign = m.isEven ? 1.0 : -1.0;
  return fin -
      Complex(sign) *
          (hz.log() + const Complex(eulerMascheroni)) *
          besselIComplex(Complex(m.toDouble()), z) +
      Complex(0.5 * sign) * hz.pow(Complex(m.toDouble())) * infSum;
}

/// Taylor coefficients of `1 / Γ(1 + x)` around `x = 0`.
const List<double> _invGammaTaylor = [
  1.0,
  0.57721566490153286061,
  -0.65587807152025388108,
  -0.04200263503409523553,
  0.16653861138229148950,
  -0.04219773455554433675,
  -0.00962197152787697356,
  0.00721894324666309954,
  -0.00116516759185906511,
  -0.00021524167411495097,
  0.00012805028238811619,
  -0.00002013485478078824,
  -0.00000125049348214267,
  0.00000113302723198170,
  -0.00000020563384169776,
  0.00000000611609510448,
  0.00000000500200764447,
  -0.00000000118127457049,
  0.00000000010434267117,
  0.00000000000778226344,
  -0.00000000000369680562,
];
