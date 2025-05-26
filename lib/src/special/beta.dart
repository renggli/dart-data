import 'dart:math';

import 'gamma.dart';

/// Beta function based on the [gamma] function.
double beta(num x, num y) =>
    x <= 0 || y <= 0 ? double.nan : gamma(x) * gamma(y) / gamma(x + y);

/// Logarithm of the beta function based on the [gammaLn] function.
double betaLn(num x, num y) =>
    x <= 0 || y <= 0 ? double.nan : gammaLn(x) + gammaLn(y) - gammaLn(x + y);

/// Incomplete beta function.
double ibeta(num x, num a, num b) {
  if (x < 0 || 1 < x) {
    return double.nan;
  }
  // Factor in front of the continued fraction.
  final bt = x == 0 || x == 1
      ? 0.0
      : exp(
          gammaLn(a + b) -
              gammaLn(a) -
              gammaLn(b) +
              a * log(x) +
              b * log(1.0 - x),
        );
  if (x < (a + 1.0) / (a + b + 2.0)) {
    // Use continued fraction directly.
    return bt * betacf_(x, a, b) / a;
  } else {
    // Use continued fraction after making the symmetry transformation.
    return 1.0 - bt * betacf_(1.0 - x, b, a) / b;
  }
}

/// Inverse of the incomplete beta function.
double ibetaInv(num p, num a, num b) {
  const epsilon = 1.0e-8;
  final a1 = a - 1.0;
  final b1 = b - 1.0;
  if (p <= 0.0) {
    return 0.0;
  }
  if (p >= 1.0) {
    return 1.0;
  }
  var x = 0.0;
  if (a >= 1.0 && b >= 1.0) {
    final pp = (p < 0.5) ? p : 1 - p;
    final t = sqrt(-2 * log(pp));
    x = (2.30753 + t * 0.27061) / (1 + t * (0.99229 + t * 0.04481)) - t;
    if (p < 0.5) {
      x = -x;
    }
    final al = (x * x - 3) / 6;
    final h = 2 / (1 / (2 * a - 1) + 1 / (2 * b - 1));
    final w =
        (x * sqrt(al + h) / h) -
        (1 / (2 * b - 1) - 1 / (2 * a - 1)) * (al + 5 / 6 - 2 / (3 * h));
    x = a / (a + b * exp(2 * w));
  } else {
    final lna = log(a / (a + b));
    final lnb = log(b / (a + b));
    final t = exp(a * lna) / a;
    final u = exp(b * lnb) / b;
    final w = t + u;
    if (p < t / w) {
      x = pow(a * w * p, 1 / a).toDouble();
    } else {
      x = 1.0 - pow(b * w * (1 - p), 1 / b);
    }
  }
  final afac = -gammaLn(a) - gammaLn(b) + gammaLn(a + b);
  for (var j = 0; j < 10; j++) {
    if (x == 0 || x == 1) return x;
    final err = ibeta(x, a, b) - p;
    var t = exp(a1 * log(x) + b1 * log(1 - x) + afac);
    final u = err / t;
    x -= t = u / (1 - 0.5 * min(1, u * (a1 / x - b1 / (1 - x))));
    if (x <= 0) {
      x = 0.5 * (x + t);
    }
    if (x >= 1) {
      x = 0.5 * (x + t + 1);
    }
    if (t.abs() < epsilon * x && j > 0) break;
  }
  return x;
}

/// Evaluates the continued fraction for incomplete beta function by modified
/// Lentz's method.
double betacf_(num x, num a, num b) {
  const fpmin = 1.0e-30;
  // These q's will be used in factors that occur in the coefficients
  final qab = a + b + 0.0;
  final qap = a + 1.0;
  final qam = a - 1.0;
  var c = 1.0;
  var d = 1.0 - qab * x / qap;
  if (d.abs() < fpmin) {
    d = fpmin;
  }
  d = 1.0 / d;
  var h = d;
  for (var m = 1; m <= 100; m++) {
    final m2 = 2.0 * m;
    var aa = m * (b - m) * x / ((qam + m2) * (a + m2));
    // One step (the even one) of the recurrence
    d = 1.0 + aa * d;
    if (d.abs() < fpmin) {
      d = fpmin;
    }
    c = 1.0 + aa / c;
    if (c.abs() < fpmin) {
      c = fpmin;
    }
    d = 1.0 / d;
    h *= d * c;
    aa = -(a + m) * (qab + m) * x / ((a + m2) * (qap + m2));
    // Next step of the recurrence (the odd one)
    d = 1.0 + aa * d;
    if (d.abs() < fpmin) {
      d = fpmin;
    }
    c = 1.0 + aa / c;
    if (c.abs() < fpmin) {
      c = fpmin;
    }
    d = 1.0 / d;
    final del = d * c;
    h *= del;
    if ((del - 1.0).abs() < 3.0e-7) {
      break;
    }
  }
  return h;
}
