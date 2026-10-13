import 'dart:math';

/// Returns the principal branch of the Lambert W function $W_0(z)$.
///
/// Conceptually, the Lambert W function solves transcendental equations where
/// the unknown variable appears both linearly and in an exponent, such as
/// $w e^w = z$. Formally, this calculates the principal branch $W_0(z)$ of the
/// inverse of the transcendental relation $f(w) = w e^w$, defined for real
/// $z \ge -1/e$.
///
/// Satisfies $W(z) e^{W(z)} = z$ for $z \ge -1/e$.
///
/// See https://en.wikipedia.org/wiki/Lambert_W_function for details.
///
/// ```dart
/// final val = lambertW0(0.0); // 0.0
/// ```
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
  } else if (zd < _e) {
    wVal = zd / (1.0 + zd * (1.0 + zd * (0.5 - zd / 6.0)));
  } else {
    final lz = log(zd);
    final llz = log(lz);
    wVal = lz - llz + llz / lz;
  }
  for (var i = 0; i < 25; i++) {
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
/// Conceptually, this calculates the secondary negative solution to $w e^w = z$
/// when $-1/e \le z < 0$. Formally, this calculates the secondary real branch
/// $W_{-1}(z)$ of the inverse of $f(w) = w e^w$, satisfying $W(z) \le -1$.
///
/// Defined for $-1/e \le z < 0$.
///
/// See https://en.wikipedia.org/wiki/Lambert_W_function for details.
///
/// ```dart
/// final val = lambertW1(-0.1); // ~ -3.577152063957297
/// ```
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
  for (var i = 0; i < 25; i++) {
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
