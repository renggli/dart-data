import 'dart:math';

import 'gamma.dart';

/// Returns the Bessel function of the first kind $J_\nu(x)$ of real order [nu].
///
/// For integer order [nu], this evaluates $J_n(x)$ via Miller's backward
/// recurrence or forward recurrence. For non-integer order, evaluates via
/// the series definition $\sum_{m=0}^\infty \frac{(-1)^m}{m! \Gamma(m + \nu + 1)} (x/2)^{2m + \nu}$.
double besselJ(num nu, num x) {
  if (nu.isNaN || x.isNaN) return double.nan;
  final nud = nu.toDouble();
  final xd = x.toDouble();
  if (!nud.isFinite) return double.nan;
  if (xd.isInfinite) {
    if (xd.isNegative) return double.nan;
    return 0.0;
  }
  if (nud == 0.0) return besselJ0(xd);
  if (nud == 1.0) return besselJ1(xd);

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
      var jPrev = besselJ0(xd);
      var jCur = besselJ1(xd);
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

/// Returns the Bessel function of the second kind $Y_\nu(x)$ of real order [nu].
double besselY(num nu, num x) {
  if (nu.isNaN || x.isNaN) return double.nan;
  final nud = nu.toDouble();
  final xd = x.toDouble();
  if (!nud.isFinite || xd <= 0.0) return double.nan;
  if (xd.isInfinite) return 0.0;
  if (nud == 0.0) return besselY0(xd);
  if (nud == 1.0) return besselY1(xd);
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
    var yPrev = besselY0(xd);
    var yCur = besselY1(xd);
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

/// Returns the modified Bessel function of the first kind $I_\nu(x)$ of real order [nu].
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
  if (nud == 0.0) return besselI0(xd);
  if (nud == 1.0) return besselI1(xd);

  // Integer order branch
  if (nud.abs() <= 1e7 && nud.roundToDouble() == nud) {
    final n = nud.toInt();
    if (n < 0) {
      return besselI(-n, xd);
    }
    if (n == 0) return besselI0(xd);
    if (n == 1) return besselI1(xd);
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
    final trueI0 = besselI0(xd);
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

/// Returns the modified Bessel function of the second kind $K_\nu(x)$ of real order [nu].
double besselK(num nu, num x) {
  if (nu.isNaN || x.isNaN) return double.nan;
  final nud = nu.toDouble();
  final xd = x.toDouble();
  if (!nud.isFinite || xd <= 0.0) return double.nan;
  if (xd.isInfinite) return 0.0;
  if (nud == 0.0) return besselK0(xd);
  if (nud == 1.0) return besselK1(xd);

  final absNu = nud.abs();
  if (xd > max(25.0, absNu * absNu)) {
    return _modifiedBesselAsymptotic(absNu, xd).k;
  }

  // Integer order branch via forward recurrence
  if (absNu <= 1e7 && absNu.roundToDouble() == absNu) {
    final n = absNu.toInt();
    var kPrev = besselK0(xd);
    var kCur = besselK1(xd);
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

/// Returns the modified Bessel function $I_0(x)$ of the first kind of order 0.
///
/// Conceptually, modified Bessel functions describe physical diffusion
/// processes, such as heat dissipation or electric fields around cylindrical
/// conductors. Formally, this calculates the non-oscillatory modified Bessel
/// function
/// $I_0(x) = J_0(i x)$
/// $= \sum_{m=0}^\infty \frac{1}{(m!)^2} \left( \frac{x}{2} \right)^{2m}$.
///
/// See https://en.wikipedia.org/wiki/Bessel_function for details.
///
/// ```dart
/// final val = besselI0(0.0); // 1.0
/// ```
double besselI0(num x) {
  if (x.isNaN) return double.nan;
  if (x == 0) return 1.0;
  if (x.isInfinite) return double.infinity;
  final ax = x.abs().toDouble();
  if (ax < 3.75) {
    final tVal = x / 3.75;
    final y = tVal * tVal;
    return 1.0 +
        y *
            (3.5156229 +
                y *
                    (3.0899424 +
                        y *
                            (1.2067492 +
                                y *
                                    (0.2659732 +
                                        y * (0.0360768 + y * 0.0045813)))));
  } else {
    final y = 3.75 / ax;
    return (exp(ax) / sqrt(ax)) *
        (0.39894228 +
            y *
                (0.01328592 +
                    y *
                        (0.00225319 +
                            y *
                                (-0.00157565 +
                                    y *
                                        (0.00916281 +
                                            y *
                                                (-0.02057706 +
                                                    y *
                                                        (0.02635537 +
                                                            y *
                                                                (-0.01647633 +
                                                                    y * 0.00392377))))))));
  }
}

/// Returns the modified Bessel function $I_1(x)$ of the first kind of order 1.
///
/// See https://en.wikipedia.org/wiki/Bessel_function for details.
double besselI1(num x) {
  if (x.isNaN) return double.nan;
  if (x == 0) return 0.0;
  if (x.isInfinite) {
    return x.isNegative ? double.negativeInfinity : double.infinity;
  }
  final ax = x.abs().toDouble();
  if (ax < 3.75) {
    final tVal = x / 3.75;
    final y = tVal * tVal;
    final ans =
        ax *
        (0.5 +
            y *
                (0.87890594 +
                    y *
                        (0.51498869 +
                            y *
                                (0.15084934 +
                                    y *
                                        (0.02658733 +
                                            y *
                                                (0.00301532 +
                                                    y * 0.00032411))))));
    return x.isNegative ? -ans : ans;
  } else {
    final y = 3.75 / ax;
    final ans =
        (exp(ax) / sqrt(ax)) *
        (0.39894228 +
            y *
                (-0.03988024 +
                    y *
                        (-0.00362018 +
                            y *
                                (0.00163801 +
                                    y *
                                        (-0.01031555 +
                                            y *
                                                (0.02282967 +
                                                    y *
                                                        (-0.02895312 +
                                                            y *
                                                                (0.01787654 -
                                                                    y * 0.00420059))))))));
    return x.isNegative ? -ans : ans;
  }
}

/// Returns the modified Bessel function $K_0(x)$ of the second kind of order 0.
///
/// See https://en.wikipedia.org/wiki/Bessel_function for details.
double besselK0(num x) {
  if (x.isNaN || x <= 0) return double.nan;
  if (x.isInfinite) return 0.0;
  final xd = x.toDouble();
  if (xd <= 2.0) {
    final y = xd * xd / 4.0;
    return -log(xd / 2.0) * besselI0(xd) +
        (-0.57721566 +
            y *
                (0.42278420 +
                    y *
                        (0.23069756 +
                            y *
                                (0.03488590 +
                                    y *
                                        (0.00262698 +
                                            y *
                                                (0.00010750 +
                                                    y * 0.00000740))))));
  } else {
    final y = 2.0 / xd;
    return (exp(-xd) / sqrt(xd)) *
        (1.25331414 +
            y *
                (-0.07832358 +
                    y *
                        (0.02189568 +
                            y *
                                (-0.01062446 +
                                    y *
                                        (0.00587872 +
                                            y *
                                                (-0.00251540 +
                                                    y * 0.00053208))))));
  }
}

/// Returns the modified Bessel function $K_1(x)$ of the second kind of order 1.
///
/// See https://en.wikipedia.org/wiki/Bessel_function for details.
double besselK1(num x) {
  if (x.isNaN || x <= 0) return double.nan;
  if (x.isInfinite) return 0.0;
  final xd = x.toDouble();
  if (xd <= 2.0) {
    final y = xd * xd / 4.0;
    return log(xd / 2.0) * besselI1(xd) +
        (1.0 / xd) *
            (1.0 +
                y *
                    (0.15443144 +
                        y *
                            (-0.67278579 +
                                y *
                                    (-0.18156897 +
                                        y *
                                            (-0.01919402 +
                                                y *
                                                    (-0.00110404 -
                                                        y * 0.00004686))))));
  } else {
    final y = 2.0 / xd;
    return (exp(-xd) / sqrt(xd)) *
        (1.25331414 +
            y *
                (0.23498619 +
                    y *
                        (-0.03655620 +
                            y *
                                (0.01504268 +
                                    y *
                                        (-0.00780353 +
                                            y *
                                                (0.00325614 -
                                                    y * 0.00068245))))));
  }
}

/// Returns the Bessel function $J_0(x)$ of the first kind of order 0.
///
/// Conceptually, Bessel functions describe radial wave phenomena, such as
/// concentric ripple patterns on water surfaces or the vibrational modes of a
/// circular drumhead. Formally, this is the solution to Bessel's differential
/// equation $x^2 y'' + x y' + x^2 y = 0$ that is non-singular at $x=0$, given
/// by
/// $J_0(x) =$
/// $\sum_{m=0}^\infty \frac{(-1)^m}{(m!)^2} \left( \frac{x}{2} \right)^{2m}$.
///
/// See https://en.wikipedia.org/wiki/Bessel_function for details.
///
/// ```dart
/// final val = besselJ0(0.0); // 1.0
/// ```
double besselJ0(num x) {
  if (x.isNaN) return double.nan;
  if (x == 0) return 1.0;
  if (x.isInfinite) return 0.0;
  final ax = x.abs().toDouble();
  if (ax < 8.0) {
    final y = ax * ax;
    final num =
        57568490574.0 +
        y *
            (-13362590354.0 +
                y *
                    (651619640.7 +
                        y *
                            (-11214424.18 +
                                y * (77392.33017 - y * 184.9052456))));
    final den =
        57568490411.0 +
        y *
            (1029532985.0 +
                y * (9494680.718 + y * (59272.64853 + y * (267.8532712 + y))));
    return num / den;
  } else {
    final z = 8.0 / ax;
    final y = z * z;
    final xx = ax - (pi / 4.0);
    final f0 =
        1.0 +
        y *
            (-0.001098628627 +
                y *
                    (0.00002734510407 +
                        y * (-0.000002073370912 + y * 0.0000002093887211)));
    final g0 =
        -0.01562499995 +
        y *
            (0.0001430488765 +
                y *
                    (-0.0000190333399 +
                        y * (0.0000017122914 - y * 0.000000122476)));
    return sqrt(2.0 / (pi * ax)) * (f0 * cos(xx) - z * g0 * sin(xx));
  }
}

/// Returns the Bessel function $J_1(x)$ of the first kind of order 1.
///
/// See https://en.wikipedia.org/wiki/Bessel_function for details.
double besselJ1(num x) {
  if (x.isNaN) return double.nan;
  if (x == 0) return 0.0;
  if (x.isInfinite) return 0.0;
  final ax = x.abs().toDouble();
  if (ax < 8.0) {
    final y = ax * ax;
    final num =
        ax *
        (72362614232.0 +
            y *
                (-7895059235.0 +
                    y *
                        (242396853.1 +
                            y *
                                (-2972611.439 +
                                    y * (15704.48260 - y * 30.16036606)))));
    final den =
        144725228442.0 +
        y *
            (2300535178.0 +
                y * (18583304.74 + y * (99447.43394 + y * (376.9991397 + y))));
    final ans = num / den;
    return x.isNegative ? -ans : ans;
  } else {
    final z = 8.0 / ax;
    final y = z * z;
    final xx = ax - _threePiOver4;
    final f1 =
        1.0 +
        y *
            (0.00183105 +
                y *
                    (-0.00003516396496 +
                        y * (0.000002457520174 - y * 0.000000240337019)));
    final g1 =
        0.04687499995 +
        y *
            (-0.0002002690873 +
                y *
                    (0.000008449199096 +
                        y * (-0.00000088228987 + y * 0.000000105787412)));
    final ans = sqrt(2.0 / (pi * ax)) * (f1 * cos(xx) - z * g1 * sin(xx));
    return x.isNegative ? -ans : ans;
  }
}

/// Returns the Bessel function $Y_0(x)$ of the second kind of order 0.
///
/// See https://en.wikipedia.org/wiki/Bessel_function for details.
double besselY0(num x) {
  if (x.isNaN || x <= 0) return double.nan;
  if (x.isInfinite) return 0.0;
  final xd = x.toDouble();
  if (xd < 8.0) {
    final y = xd * xd;
    final num =
        -2957821389.0 +
        y *
            (7062834065.0 +
                y *
                    (-512359803.6 +
                        y *
                            (10879881.29 +
                                y * (-86327.92757 + y * 228.4622733))));
    final den =
        40076544269.0 +
        y *
            (745249964.8 +
                y * (7189466.438 + y * (47447.26470 + y * (226.1030244 + y))));
    return (2.0 / pi) * log(xd) * besselJ0(xd) + num / den;
  } else {
    final z = 8.0 / xd;
    final y = z * z;
    final xx = xd - (pi / 4.0);
    final f0 =
        1.0 +
        y *
            (-0.001098628627 +
                y *
                    (0.00002734510407 +
                        y * (-0.000002073370912 + y * 0.0000002093887211)));
    final g0 =
        -0.01562499995 +
        y *
            (0.0001430488765 +
                y *
                    (-0.0000190333399 +
                        y * (0.0000017122914 - y * 0.000000122476)));
    return sqrt(2.0 / (pi * xd)) * (f0 * sin(xx) + z * g0 * cos(xx));
  }
}

/// Returns the Bessel function $Y_1(x)$ of the second kind of order 1.
///
/// See https://en.wikipedia.org/wiki/Bessel_function for details.
double besselY1(num x) {
  if (x.isNaN || x <= 0) return double.nan;
  if (x.isInfinite) return 0.0;
  final xd = x.toDouble();
  if (xd < 8.0) {
    final y = xd * xd;
    const r1 = -0.4900604943e13;
    const r2 = 0.1275274390e13;
    const r3 = -0.5153438139e11;
    const r4 = 0.7349264551e9;
    const r5 = -0.4237922726e7;
    const r6 = 0.8511937935e4;

    const s1 = 0.2499580570e14;
    const s2 = 0.4244419664e12;
    const s3 = 0.3733650367e10;
    const s4 = 0.2245904002e8;
    const s5 = 0.1020426050e6;
    const s6 = 0.3549632885e3;
    const s7 = 1.0;

    final num = xd * (r1 + y * (r2 + y * (r3 + y * (r4 + y * (r5 + y * r6)))));
    final den =
        s1 + y * (s2 + y * (s3 + y * (s4 + y * (s5 + y * (s6 + y * s7)))));

    return (2.0 / pi) * (log(xd) * besselJ1(xd) - 1.0 / xd) + num / den;
  } else {
    final z = 8.0 / xd;
    final y = z * z;
    final xx = xd - _threePiOver4;
    final f1 =
        1.0 +
        y *
            (0.00183105 +
                y *
                    (-0.00003516396496 +
                        y * (0.000002457520174 - y * 0.000000240337019)));
    final g1 =
        0.04687499995 +
        y *
            (-0.0002002690873 +
                y *
                    (0.000008449199096 +
                        y * (-0.00000088228987 + y * 0.000000105787412)));
    return sqrt(2.0 / (pi * xd)) * (f1 * sin(xx) + z * g1 * cos(xx));
  }
}

const _threePiOver4 = 2.356194490192345;
