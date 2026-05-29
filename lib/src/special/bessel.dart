import 'dart:math';

/// Returns the modified Bessel function $I_0(x)$ of the first kind of order 0.
///
/// See https://en.wikipedia.org/wiki/Bessel_function for details.
double besselI0(num x) {
  if (x.isNaN) return double.nan;
  if (x == 0) return 1.0;
  final ax = x.abs().toDouble();
  if (ax < 3.75) {
    final y = pow(x / 3.75, 2);
    return 1.0 +
        3.5156229 * y +
        3.0899424 * pow(y, 2) +
        1.2067492 * pow(y, 3) +
        0.2659732 * pow(y, 4) +
        0.0360768 * pow(y, 5) +
        0.0045813 * pow(y, 6);
  } else {
    final y = 3.75 / ax;
    return (exp(ax) / sqrt(ax)) *
        (0.39894228 +
            0.01328592 * y +
            0.00225319 * pow(y, 2) -
            0.00157565 * pow(y, 3) +
            0.00916281 * pow(y, 4) -
            0.02057706 * pow(y, 5) +
            0.02635537 * pow(y, 6) -
            0.01647633 * pow(y, 7) +
            0.00392377 * pow(y, 8));
  }
}

/// Returns the modified Bessel function $I_1(x)$ of the first kind of order 1.
///
/// See https://en.wikipedia.org/wiki/Bessel_function for details.
double besselI1(num x) {
  if (x.isNaN) return double.nan;
  if (x == 0) return 0.0;
  final ax = x.abs().toDouble();
  if (ax < 3.75) {
    final y = pow(x / 3.75, 2);
    final ans =
        ax *
        (0.5 +
            0.87890594 * y +
            0.51498869 * pow(y, 2) +
            0.15084934 * pow(y, 3) +
            0.02658733 * pow(y, 4) +
            0.00301532 * pow(y, 5) +
            0.00032411 * pow(y, 6));
    return x.isNegative ? -ans : ans;
  } else {
    final y = 3.75 / ax;
    final ans =
        (exp(ax) / sqrt(ax)) *
        (0.39894228 -
            0.03988024 * y -
            0.00362018 * pow(y, 2) +
            0.00163801 * pow(y, 3) -
            0.01031555 * pow(y, 4) +
            0.02282967 * pow(y, 5) -
            0.02895312 * pow(y, 6) +
            0.01787654 * pow(y, 7) -
            0.00420059 * pow(y, 8));
    return x.isNegative ? -ans : ans;
  }
}

/// Returns the modified Bessel function $K_0(x)$ of the second kind of order 0.
///
/// See https://en.wikipedia.org/wiki/Bessel_function for details.
double besselK0(num x) {
  if (x.isNaN || x <= 0) return double.nan;
  final xd = x.toDouble();
  if (xd <= 2.0) {
    final y = xd * xd / 4.0;
    return -log(xd / 2.0) * besselI0(xd) +
        (-0.57721566 +
            0.42278420 * y +
            0.23069756 * pow(y, 2) +
            0.03488590 * pow(y, 3) +
            0.00262698 * pow(y, 4) +
            0.00010750 * pow(y, 5) +
            0.00000740 * pow(y, 6));
  } else {
    final y = 2.0 / xd;
    return (exp(-xd) / sqrt(xd)) *
        (1.25331414 -
            0.07832358 * y +
            0.02189568 * pow(y, 2) -
            0.01062446 * pow(y, 3) +
            0.00587872 * pow(y, 4) -
            0.00251540 * pow(y, 5) +
            0.00053208 * pow(y, 6));
  }
}

/// Returns the modified Bessel function $K_1(x)$ of the second kind of order 1.
///
/// See https://en.wikipedia.org/wiki/Bessel_function for details.
double besselK1(num x) {
  if (x.isNaN || x <= 0) return double.nan;
  final xd = x.toDouble();
  if (xd <= 2.0) {
    final y = xd * xd / 4.0;
    return log(xd / 2.0) * besselI1(xd) +
        (1.0 / xd) *
            (1.0 +
                0.15443144 * y -
                0.67278579 * pow(y, 2) -
                0.18156897 * pow(y, 3) -
                0.01919402 * pow(y, 4) -
                0.00110404 * pow(y, 5) -
                0.00004686 * pow(y, 6));
  } else {
    final y = 2.0 / xd;
    return (exp(-xd) / sqrt(xd)) *
        (1.25331414 +
            0.23498619 * y -
            0.03655620 * pow(y, 2) +
            0.01504268 * pow(y, 3) -
            0.00780353 * pow(y, 4) +
            0.00325614 * pow(y, 5) -
            0.00068245 * pow(y, 6));
  }
}

/// Returns the Bessel function $J_0(x)$ of the first kind of order 0.
///
/// See https://en.wikipedia.org/wiki/Bessel_function for details.
double besselJ0(num x) {
  if (x.isNaN) return double.nan;
  if (x == 0) return 1.0;
  final ax = x.abs().toDouble();
  if (ax < 8.0) {
    final y = ax * ax;
    final num =
        57568490574.0 -
        13362590354.0 * y +
        651619640.7 * pow(y, 2) -
        11214424.18 * pow(y, 3) +
        77392.33017 * pow(y, 4) -
        184.9052456 * pow(y, 5);
    final den =
        57568490411.0 +
        1029532985.0 * y +
        9494680.718 * pow(y, 2) +
        59272.64853 * pow(y, 3) +
        267.8532712 * pow(y, 4) +
        pow(y, 5);
    return num / den;
  } else {
    final z = 8.0 / ax;
    final y = z * z;
    final xx = ax - 0.785398164;
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
  final ax = x.abs().toDouble();
  if (ax < 8.0) {
    final y = ax * ax;
    final num =
        ax *
        (72362614232.0 -
            7895059235.0 * y +
            242396853.1 * pow(y, 2) -
            2972611.439 * pow(y, 3) +
            15704.48260 * pow(y, 4) -
            30.16036606 * pow(y, 5));
    final den =
        144725228442.0 +
        2300535178.0 * y +
        18583304.74 * pow(y, 2) +
        99447.43394 * pow(y, 3) +
        376.9991397 * pow(y, 4) +
        pow(y, 5);
    final ans = num / den;
    return x.isNegative ? -ans : ans;
  } else {
    final z = 8.0 / ax;
    final y = z * z;
    final xx = ax - 2.356194491;
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
  final xd = x.toDouble();
  if (xd < 8.0) {
    final y = xd * xd;
    final num =
        -2957821389.0 +
        7062834065.0 * y -
        512359803.6 * pow(y, 2) +
        10879881.29 * pow(y, 3) -
        86327.92757 * pow(y, 4) +
        228.4622733 * pow(y, 5);
    final den =
        40076544269.0 +
        745249964.8 * y +
        7189466.438 * pow(y, 2) +
        47447.26470 * pow(y, 3) +
        226.1030244 * pow(y, 4) +
        pow(y, 5);
    return (2.0 / pi) * log(xd) * besselJ0(xd) + num / den;
  } else {
    final z = 8.0 / xd;
    final y = z * z;
    final xx = xd - 0.785398164;
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
    final xx = xd - 2.356194491;
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
