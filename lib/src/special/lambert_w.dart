import 'dart:math';

/// Returns the principal branch of the Lambert W function $W_0(z)$.
///
/// Satisfies $W(z) e^{W(z)} = z$ for $z \ge -1/e$.
///
/// See https://en.wikipedia.org/wiki/Lambert_W_function for details.
double lambertW0(num z) {
  if (z.isNaN || z < -_invE) {
    return double.nan;
  }
  if (z == 0.0) return 0.0;
  if (z.isInfinite) return double.infinity;
  final zd = z.toDouble();
  var wVal = 0.0;
  if (zd < -0.3) {
    final pVal = sqrt(2.0 * (_e * zd + 1.0));
    wVal =
        -1.0 +
        pVal -
        (1.0 / 3.0) * pVal * pVal +
        (11.0 / 72.0) * pVal * pVal * pVal;
  } else if (zd < 1.0) {
    wVal = zd / (1.0 + zd * (1.0 + zd * (0.5 - zd / 6.0)));
  } else {
    final lz = log(zd);
    final llz = log(lz);
    wVal = lz - llz + llz / lz;
  }
  for (var i = 0; i < 10; i++) {
    final ew = exp(wVal);
    final fVal = wVal * ew - zd;
    if (fVal.abs() < 1.0e-15 * (1.0 + wVal.abs()) * ew) {
      break;
    }
    final w1 = wVal + 1.0;
    final step = fVal / (ew * w1 - (wVal + 2.0) * fVal / (2.0 * w1));
    wVal -= step;
    if (step.abs() < 1.0e-15 * (1.0 + wVal.abs())) {
      break;
    }
  }
  return wVal;
}

/// Returns the secondary branch of the Lambert W function $W_{-1}(z)$ (exported
/// as `lambertW1(z)`).
///
/// Defined for $-1/e \le z < 0$.
///
/// See https://en.wikipedia.org/wiki/Lambert_W_function for details.
double lambertW1(num z) {
  if (z.isNaN || z < -_invE || z >= 0.0) {
    return double.nan;
  }
  final zd = z.toDouble();
  var wVal = -1.0;
  if (zd < -0.3) {
    final pVal = -sqrt(2.0 * (_e * zd + 1.0));
    wVal =
        -1.0 +
        pVal -
        (1.0 / 3.0) * pVal * pVal +
        (11.0 / 72.0) * pVal * pVal * pVal;
  } else {
    final lz = log(-zd);
    final llz = log(-lz);
    wVal = lz - llz + llz / lz;
  }
  for (var i = 0; i < 15; i++) {
    final ew = exp(wVal);
    final fVal = wVal * ew - zd;
    if (fVal.abs() < 1.0e-15 * (1.0 + wVal.abs()) * ew) {
      break;
    }
    final w1 = wVal + 1.0;
    if (w1.abs() < 1.0e-15) {
      break;
    }
    final step = fVal / (ew * w1 - (wVal + 2.0) * fVal / (2.0 * w1));
    wVal -= step;
    if (step.abs() < 1.0e-15 * (1.0 + wVal.abs())) {
      break;
    }
  }
  return wVal;
}

const _invE = 0.36787944117144232159587; // 1/e
const _e = 2.718281828459045235360287; // e
