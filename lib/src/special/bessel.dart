import 'dart:math';

import 'package:more/number.dart' show Complex;

import 'gamma.dart';
import 'utils.dart';

/// Returns the Bessel function of the first kind `J_ν(x)` of real order [nu].
///
/// For integer order [nu], evaluates `J_n(x)` via Miller's backward
/// recurrence or forward recurrence; for non-integer order, uses the series
/// definition `∑_{m=0}^∞ (-1)^m / (m! * Γ(m + ν + 1)) * (x/2)^(2m + ν)`.
///
/// See https://en.wikipedia.org/wiki/Bessel_function for details.
double besselJ(num nu, num x) {
  if (nu.isNaN || x.isNaN) return double.nan;
  final nud = nu.toDouble();
  final xd = x.toDouble();
  if (!nud.isFinite) return double.nan;
  if (nud == 0.0) return _besselJ0(xd);
  if (nud == 1.0) return _besselJ1(xd);
  if (xd.isInfinite) {
    if (xd.isNegative) return double.nan;
    return 0.0;
  }

  // Integer order branch
  if (nud.abs() <= 1e7 && nud.roundToDouble() == nud) {
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
    if (xd < 1e-4) {
      final halfX = 0.5 * xd;
      var term = pow(halfX, n) / gamma(n + 1.0);
      var sum = term;
      final halfX2 = -halfX * halfX;
      for (var m = 1; m <= 20; m++) {
        term *= halfX2 / (m * (m + n));
        sum += term;
        if (term.abs() <= 1.0e-15 * sum.abs()) break;
      }
      return sum;
    }
    if (xd > max(25.0, n * n.toDouble())) {
      return _hankelAsymptotic(nud, xd).j;
    }
    if (xd > n) {
      // Forward recurrence
      var jPrev = _besselJ0(xd);
      var jCur = _besselJ1(xd);
      for (var k = 1; k < n; k++) {
        final jNext = (2.0 * k / xd) * jCur - jPrev;
        jPrev = jCur;
        jCur = jNext;
      }
      return jCur;
    } else {
      // Backward recurrence (Miller's algorithm)
      final m = 2 * (n + sqrt(40.0 * n).toInt() + 10);
      var fNext = 0.0;
      var fCur = 1.0e-30;
      var fn = 0.0;
      var sum = 0.0;
      for (var k = m; k > 0; k--) {
        final fPrev = (2.0 * k / xd) * fCur - fNext;
        fNext = fCur;
        fCur = fPrev;
        if (fCur.abs() > 1e100) {
          fCur *= 1e-100;
          fNext *= 1e-100;
          fn *= 1e-100;
          sum *= 1e-100;
        }
        if (k - 1 == n) fn = fCur;
        if ((k - 1).isEven) {
          sum += (k - 1 == 0) ? fCur : 2.0 * fCur;
        }
      }
      return (sum == 0.0) ? 0.0 : (fn / sum);
    }
  }

  // Non-integer order branch
  if (xd < 0.0) return double.nan;
  if (xd == 0.0) return nud == 0.0 ? 1.0 : 0.0;
  if (xd > max(25.0, nud * nud)) {
    return _hankelAsymptotic(nud, xd).j;
  }

  final halfX = 0.5 * xd;
  final gammaVal = gamma(nud + 1.0);
  if (gammaVal.isInfinite) return 0.0;
  var term = pow(halfX, nud) / gammaVal;
  var sum = term;
  final halfX2 = -halfX * halfX;
  for (var m = 1; m <= 100; m++) {
    term *= halfX2 / (m * (m + nud));
    sum += term;
    if (term.abs() <= 1.0e-15 * sum.abs()) break;
  }
  return sum;
}

/// Returns the complex Bessel function of the first kind `J_ν(z)`.
///
/// See https://en.wikipedia.org/wiki/Bessel_function for details.
Complex besselJComplex(Complex nu, Complex z) {
  if (nu.isNaN || z.isNaN) {
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
    final pos = besselJComplex(Complex(-n), z);
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
    term *= halfZ2 / (Complex(m) * (Complex(m) + nu));
    sum += term;
    if (term.abs() <= 1.0e-15 * sum.abs()) break;
  }
  return sum;
}

/// Returns the Bessel function of the second kind `Y_ν(x)` of real order [nu].
///
/// See https://en.wikipedia.org/wiki/Bessel_function for details.
double besselY(num nu, num x) {
  if (nu.isNaN || x.isNaN) return double.nan;
  final nud = nu.toDouble();
  final xd = x.toDouble();
  if (!nud.isFinite || xd <= 0.0) return double.nan;
  if (xd.isInfinite) return 0.0;
  if (nud == 0.0) return _besselY0(xd);
  if (nud == 1.0) return _besselY1(xd);
  if (xd > max(25.0, nud * nud)) {
    return _hankelAsymptotic(nud, xd).y;
  }

  // Integer order branch via forward recurrence
  if (nud.abs() <= 1e7 && nud.roundToDouble() == nud) {
    final n = nud.toInt();
    if (n < 0) {
      final yPos = besselY(-n, xd);
      return n.isOdd ? -yPos : yPos;
    }
    var yPrev = _besselY0(xd);
    var yCur = _besselY1(xd);
    for (var k = 1; k < n; k++) {
      final yNext = (2.0 * k / xd) * yCur - yPrev;
      yPrev = yCur;
      yCur = yNext;
    }
    return yCur;
  }

  // Non-integer order via relation to J_nu and J_{-nu}
  final sinPiNu = sin(pi * nud);
  if (sinPiNu.abs() < 1e-15) {
    return besselY(nud.round(), xd);
  }
  return (besselJ(nud, xd) * cos(pi * nud) - besselJ(-nud, xd)) / sinPiNu;
}

/// Returns the complex Bessel function of the second kind `Y_ν(z)`.
///
/// See https://en.wikipedia.org/wiki/Bessel_function for details.
Complex besselYComplex(Complex nu, Complex z) {
  if (nu.isNaN || z.isNaN) {
    return Complex.nan;
  }
  if (z.a == 0.0 && z.b == 0.0) {
    return Complex.nan;
  }
  if (nu.b == 0.0 && z.b == 0.0 && z.a > 0.0) {
    return Complex(besselY(nu.a.toDouble(), z.a.toDouble()));
  }
  if (z.abs() > max(12.0, nu.abs() * nu.abs()) && z.a >= 0.0) {
    return _hankelAsymptoticComplex(nu, z).y;
  }
  final sinPiNu = (const Complex(pi) * nu).sin();
  if (sinPiNu.abs() < 1e-12) {
    const eps = Complex(1e-6);
    return (besselYComplex(nu + eps, z) + besselYComplex(nu - eps, z)) *
        const Complex(0.5);
  }
  return (besselJComplex(nu, z) * (const Complex(pi) * nu).cos() -
          besselJComplex(-nu, z)) /
      sinPiNu;
}

/// Returns the modified Bessel function of the first kind `I_ν(x)` of real order [nu].
double besselI(num nu, num x) {
  if (nu.isNaN || x.isNaN) return double.nan;
  final nud = nu.toDouble();
  final xd = x.toDouble();
  if (!nud.isFinite) return double.nan;
  if (xd.isInfinite) {
    if (xd.isNegative) {
      if (nud.abs() <= 1e7 && nud.roundToDouble() == nud) {
        return nud.toInt().isOdd ? double.negativeInfinity : double.infinity;
      }
      return double.nan;
    }
    return double.infinity;
  }
  if (nud == 0.0) return _besselI0(xd);
  if (nud == 1.0) return _besselI1(xd);

  // Integer order branch
  if (nud.abs() <= 1e7 && nud.roundToDouble() == nud) {
    final n = nud.toInt();
    if (n < 0) {
      return besselI(-n, xd);
    }
    if (n == 0) return _besselI0(xd);
    if (n == 1) return _besselI1(xd);
    if (xd == 0.0) return 0.0;
    if (xd < 0.0) {
      final iPos = besselI(n, -xd);
      return n.isOdd ? -iPos : iPos;
    }
    if (xd < 1e-4) {
      final halfX = 0.5 * xd;
      var term = pow(halfX, n) / gamma(n + 1.0);
      var sum = term;
      final halfX2 = halfX * halfX;
      for (var m = 1; m <= 20; m++) {
        term *= halfX2 / (m * (m + n));
        sum += term;
        if (term.abs() <= 1.0e-15 * sum.abs()) break;
      }
      return sum;
    }
    if (xd > max(25.0, n * n.toDouble())) {
      return _modifiedBesselAsymptotic(nud, xd).i;
    }
    final m = 2 * (n + sqrt(40.0 * n).toInt() + 10);
    var fNext = 0.0;
    var fCur = 1.0e-30;
    var fn = 0.0;
    for (var k = m; k > 0; k--) {
      final fPrev = (2.0 * k / xd) * fCur + fNext;
      fNext = fCur;
      fCur = fPrev;
      if (fCur.abs() > 1e100) {
        fCur *= 1e-100;
        fNext *= 1e-100;
        fn *= 1e-100;
      }
      if (k - 1 == n) fn = fCur;
    }
    final trueI0 = _besselI0(xd);
    return fCur == 0.0 ? 0.0 : fn * (trueI0 / fCur);
  }

  // Non-integer order branch
  if (xd < 0.0) return double.nan;
  if (xd == 0.0) return nud == 0.0 ? 1.0 : 0.0;
  if (xd > max(25.0, nud * nud)) {
    return _modifiedBesselAsymptotic(nud, xd).i;
  }

  final halfX = 0.5 * xd;
  final gammaVal = gamma(nud + 1.0);
  if (gammaVal.isInfinite) return 0.0;
  var term = pow(halfX, nud) / gammaVal;
  var sum = term;
  final halfX2 = halfX * halfX;
  for (var m = 1; m <= 100; m++) {
    term *= halfX2 / (m * (m + nud));
    sum += term;
    if (term.abs() <= 1.0e-15 * sum.abs()) break;
  }
  return sum;
}

/// Returns the complex modified Bessel function of the first kind `I_ν(z)`.
///
/// See https://en.wikipedia.org/wiki/Bessel_function#Modified_Bessel_functions
/// for details.
Complex besselIComplex(Complex nu, Complex z) {
  if (nu.isNaN || z.isNaN) {
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
    term *= halfZ2 / (Complex(m) * (Complex(m) + nu));
    sum += term;
    if (term.abs() <= 1.0e-15 * sum.abs()) break;
  }
  return sum;
}

/// Returns the modified Bessel function of the second kind `K_ν(x)` of real order [nu].
double besselK(num nu, num x) {
  if (nu.isNaN || x.isNaN) return double.nan;
  final nud = nu.toDouble();
  final xd = x.toDouble();
  if (!nud.isFinite || xd <= 0.0) return double.nan;
  if (xd.isInfinite) return 0.0;
  if (nud == 0.0) return _besselK0(xd);
  if (nud == 1.0) return _besselK1(xd);

  final absNu = nud.abs();
  if (xd > max(25.0, absNu * absNu)) {
    return _modifiedBesselAsymptotic(absNu, xd).k;
  }

  // Integer order branch via forward recurrence
  if (absNu <= 1e7 && absNu.roundToDouble() == absNu) {
    final n = absNu.toInt();
    var kPrev = _besselK0(xd);
    var kCur = _besselK1(xd);
    for (var k = 1; k < n; k++) {
      final kNext = (2.0 * k / xd) * kCur + kPrev;
      kPrev = kCur;
      kCur = kNext;
    }
    return kCur;
  }

  // Non-integer order via relation to I_{-nu} and I_{nu}
  final sinPiNu = sin(pi * absNu);
  if (sinPiNu.abs() < 1e-15) {
    return besselK(absNu.round(), xd);
  }
  return (pi / 2.0) * (besselI(-absNu, xd) - besselI(absNu, xd)) / sinPiNu;
}

/// Returns the complex modified Bessel function of the second kind `K_ν(z)`.
///
/// See https://en.wikipedia.org/wiki/Bessel_function#Modified_Bessel_functions
/// for details.
Complex besselKComplex(Complex nu, Complex z) {
  if (nu.isNaN || z.isNaN) {
    return Complex.nan;
  }
  if (z.a == 0.0 && z.b == 0.0) {
    return const Complex(double.infinity);
  }
  if (nu.b == 0.0 && z.b == 0.0 && z.a > 0.0) {
    return Complex(besselK(nu.a.toDouble(), z.a.toDouble()));
  }
  if (z.abs() > max(12.0, nu.abs() * nu.abs()) && z.a >= 0.0) {
    return _modifiedBesselAsymptoticComplex(nu, z).k;
  }
  final sinPiNu = (const Complex(pi) * nu).sin();
  if (sinPiNu.abs() < 1e-12) {
    const eps = Complex(1e-6);
    return (besselKComplex(nu + eps, z) + besselKComplex(nu - eps, z)) *
        const Complex(0.5);
  }
  return const Complex(pi / 2.0) *
      (besselIComplex(-nu, z) - besselIComplex(nu, z)) /
      sinPiNu;
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
    termI *= factor;
    termK *= -factor;
    if (k > 2 && termI.abs() >= prevTerm) break;
    sumI += termI;
    sumK += termK;
    if (termI.abs() < 1e-16 * sumI.abs() && termK.abs() < 1e-16 * sumK.abs()) {
      break;
    }
  }

  final factorI = exp(x) / sqrt(2.0 * pi * x);
  final factorK = sqrt(pi / (2.0 * x)) * exp(-x);

  return (i: factorI * sumI, k: factorK * sumK);
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
    final num = mu - Complex((2 * k - 1) * (2 * k - 1));
    term = term * num / (Complex(k) * eightZ);
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
        (mu - Complex((2 * k - 1) * (2 * k - 1))) / (Complex(k) * eightZ);
    termI *= factor;
    termK *= -factor;
    if (k > 2 && termI.abs() >= prevTerm) break;
    sumI += termI;
    sumK += termK;
    if (termI.abs() < 1e-16 * sumI.abs() && termK.abs() < 1e-16 * sumK.abs()) {
      break;
    }
  }

  final factorI = z.exp() / (const Complex(2.0 * pi) * z).sqrt();
  final factorK = (const Complex(pi / 2.0) / z).sqrt() * (-z).exp();

  return (i: factorI * sumI, k: factorK * sumK);
}

double _besselI0(num x) {
  if (x.isNaN) return double.nan;
  if (x == 0) return 1.0;
  if (x.isInfinite) return double.infinity;
  final ax = x.abs().toDouble();
  if (ax < 3.75) {
    final t = x / 3.75;
    return horner(t * t, _i0SmallCoeffs);
  }
  return (exp(ax) / sqrt(ax)) * horner(3.75 / ax, _i0LargeCoeffs);
}

double _besselI1(num x) {
  if (x.isNaN) return double.nan;
  if (x == 0) return 0.0;
  if (x.isInfinite) {
    return x.isNegative ? double.negativeInfinity : double.infinity;
  }
  final ax = x.abs().toDouble();
  final ans = ax < 3.75
      ? ax * horner((x / 3.75) * (x / 3.75), _i1SmallCoeffs)
      : (exp(ax) / sqrt(ax)) * horner(3.75 / ax, _i1LargeCoeffs);
  return x.isNegative ? -ans : ans;
}

double _besselK0(num x) {
  if (x.isNaN || x <= 0) return double.nan;
  if (x.isInfinite) return 0.0;
  final xd = x.toDouble();
  if (xd <= 2.0) {
    return -log(xd / 2.0) * _besselI0(xd) +
        horner(xd * xd / 4.0, _k0SmallCoeffs);
  }
  return (exp(-xd) / sqrt(xd)) * horner(2.0 / xd, _k0LargeCoeffs);
}

double _besselK1(num x) {
  if (x.isNaN || x <= 0) return double.nan;
  if (x.isInfinite) return 0.0;
  final xd = x.toDouble();
  if (xd <= 2.0) {
    return log(xd / 2.0) * _besselI1(xd) +
        (1.0 / xd) * horner(xd * xd / 4.0, _k1SmallCoeffs);
  }
  return (exp(-xd) / sqrt(xd)) * horner(2.0 / xd, _k1LargeCoeffs);
}

double _besselJ0(num x) {
  if (x.isNaN) return double.nan;
  if (x == 0) return 1.0;
  if (x.isInfinite) return 0.0;
  final ax = x.abs().toDouble();
  if (ax < 8.0) return hornerRatio(ax * ax, _j0Num, _j0Den);
  final z = 8.0 / ax;
  final y = z * z;
  final xx = ax - pi / 4.0;
  return sqrt(2.0 / (pi * ax)) *
      (horner(y, _f0Coeffs) * cos(xx) - z * horner(y, _g0Coeffs) * sin(xx));
}

double _besselJ1(num x) {
  if (x.isNaN) return double.nan;
  if (x == 0) return 0.0;
  if (x.isInfinite) return 0.0;
  final ax = x.abs().toDouble();
  final double ans;
  if (ax < 8.0) {
    ans = ax * hornerRatio(ax * ax, _j1Num, _j1Den);
  } else {
    final z = 8.0 / ax;
    final y = z * z;
    final xx = ax - _threePiOver4;
    ans =
        sqrt(2.0 / (pi * ax)) *
        (horner(y, _f1Coeffs) * cos(xx) - z * horner(y, _g1Coeffs) * sin(xx));
  }
  return x.isNegative ? -ans : ans;
}

double _besselY0(num x) {
  if (x.isNaN || x <= 0) return double.nan;
  if (x.isInfinite) return 0.0;
  final xd = x.toDouble();
  if (xd < 8.0) {
    return (2.0 / pi) * log(xd) * _besselJ0(xd) +
        hornerRatio(xd * xd, _y0Num, _y0Den);
  }
  final z = 8.0 / xd;
  final y = z * z;
  final xx = xd - pi / 4.0;
  return sqrt(2.0 / (pi * xd)) *
      (horner(y, _f0Coeffs) * sin(xx) + z * horner(y, _g0Coeffs) * cos(xx));
}

double _besselY1(num x) {
  if (x.isNaN || x <= 0) return double.nan;
  if (x.isInfinite) return 0.0;
  final xd = x.toDouble();
  if (xd < 8.0) {
    return (2.0 / pi) * (log(xd) * _besselJ1(xd) - 1.0 / xd) +
        xd * hornerRatio(xd * xd, _y1Num, _y1Den);
  }
  final z = 8.0 / xd;
  final y = z * z;
  final xx = xd - _threePiOver4;
  return sqrt(2.0 / (pi * xd)) *
      (horner(y, _f1Coeffs) * sin(xx) + z * horner(y, _g1Coeffs) * cos(xx));
}

const double _threePiOver4 = 2.356194490192345;

const List<double> _i0SmallCoeffs = [
  1.0,
  3.5156229,
  3.0899424,
  1.2067492,
  0.2659732,
  0.0360768,
  0.0045813,
];

const List<double> _i0LargeCoeffs = [
  0.39894228,
  0.01328592,
  0.00225319,
  -0.00157565,
  0.00916281,
  -0.02057706,
  0.02635537,
  -0.01647633,
  0.00392377,
];

const List<double> _i1SmallCoeffs = [
  0.5,
  0.87890594,
  0.51498869,
  0.15084934,
  0.02658733,
  0.00301532,
  0.00032411,
];

const List<double> _i1LargeCoeffs = [
  0.39894228,
  -0.03988024,
  -0.00362018,
  0.00163801,
  -0.01031555,
  0.02282967,
  -0.02895312,
  0.01787654,
  -0.00420059,
];

const List<double> _k0SmallCoeffs = [
  -0.57721566,
  0.42278420,
  0.23069756,
  0.03488590,
  0.00262698,
  0.00010750,
  0.00000740,
];

const List<double> _k0LargeCoeffs = [
  1.25331414,
  -0.07832358,
  0.02189568,
  -0.01062446,
  0.00587872,
  -0.00251540,
  0.00053208,
];

const List<double> _k1SmallCoeffs = [
  1.0,
  0.15443144,
  -0.67278579,
  -0.18156897,
  -0.01919402,
  -0.00110404,
  -0.00004686,
];

const List<double> _k1LargeCoeffs = [
  1.25331414,
  0.23498619,
  -0.03655620,
  0.01504268,
  -0.00780353,
  0.00325614,
  -0.00068245,
];

const List<double> _j0Num = [
  57568490574.0,
  -13362590354.0,
  651619640.7,
  -11214424.18,
  77392.33017,
  -184.9052456,
];

const List<double> _j0Den = [
  57568490411.0,
  1029532985.0,
  9494680.718,
  59272.64853,
  267.8532712,
  1.0,
];

const List<double> _j1Num = [
  72362614232.0,
  -7895059235.0,
  242396853.1,
  -2972611.439,
  15704.48260,
  -30.16036606,
];

const List<double> _j1Den = [
  144725228442.0,
  2300535178.0,
  18583304.74,
  99447.43394,
  376.9991397,
  1.0,
];

const List<double> _y0Num = [
  -2957821389.0,
  7062834065.0,
  -512359803.6,
  10879881.29,
  -86327.92757,
  228.4622733,
];

const List<double> _y0Den = [
  40076544269.0,
  745249964.8,
  7189466.438,
  47447.26470,
  226.1030244,
  1.0,
];

const List<double> _y1Num = [
  -0.4900604943e13,
  0.1275274390e13,
  -0.5153438139e11,
  0.7349264551e9,
  -0.4237922726e7,
  0.8511937935e4,
];

const List<double> _y1Den = [
  0.2499580570e14,
  0.4244419664e12,
  0.3733650367e10,
  0.2245904002e8,
  0.1020426050e6,
  0.3549632885e3,
  1.0,
];

const List<double> _f0Coeffs = [
  1.0,
  -0.001098628627,
  0.00002734510407,
  -0.000002073370912,
  0.0000002093887211,
];

const List<double> _g0Coeffs = [
  -0.01562499995,
  0.0001430488765,
  -0.0000190333399,
  0.0000017122914,
  -0.000000122476,
];

const List<double> _f1Coeffs = [
  1.0,
  0.00183105,
  -0.00003516396496,
  0.000002457520174,
  -0.000000240337019,
];

const List<double> _g1Coeffs = [
  0.04687499995,
  -0.0002002690873,
  0.000008449199096,
  -0.00000088228987,
  0.000000105787412,
];
