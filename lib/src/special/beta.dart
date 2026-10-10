import 'dart:math';

import 'gamma.dart';

/// Beta function based on the [gamma] function.
///
/// ```dart
/// print(beta(2, 3));  // 0.08333333333333333
/// ```
double beta(num x, num y) {
  if (x <= 0 || y <= 0) {
    return double.nan;
  }
  if (x > 100 || y > 100) {
    return exp(betaLn(x, y));
  }
  return gamma(x) * gamma(y) / gamma(x + y);
}

/// Logarithm of the beta function based on the [gammaLn] function.
double betaLn(num x, num y) =>
    x <= 0 || y <= 0 ? double.nan : gammaLn(x) + gammaLn(y) - gammaLn(x + y);

/// Incomplete beta function $I_x(a, b)$.
double ibeta(num x, num a, num b) {
  if (x < 0 || 1 < x || a <= 0 || b <= 0) {
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
    return bt * _betacf(x, a, b) / a;
  } else {
    // Use continued fraction after making the symmetry transformation.
    return 1.0 - bt * _betacf(1.0 - x, b, a) / b;
  }
}

/// Inverse of the incomplete beta function.
/// Inverse of the incomplete beta function.
double ibetaInv(num probability, num a, num b) {
  if (a <= 0 || b <= 0) {
    return double.nan;
  }
  const epsilon = 1.0e-8;
  final a1 = a - 1.0;
  final b1 = b - 1.0;
  if (probability <= 0.0) {
    return 0.0;
  }
  if (probability >= 1.0) {
    return 1.0;
  }
  var x = 0.0;
  if (a >= 1.0 && b >= 1.0) {
    final pp = (probability < 0.5) ? probability : 1 - probability;
    final tVal = sqrt(-2 * log(pp));
    x =
        (2.30753 + tVal * 0.27061) / (1 + tVal * (0.99229 + tVal * 0.04481)) -
        tVal;
    if (probability < 0.5) {
      x = -x;
    }
    final al = (x * x - 3) / 6;
    final hVal = 2 / (1 / (2 * a - 1) + 1 / (2 * b - 1));
    final wVal =
        (x * sqrt(al + hVal) / hVal) -
        (1 / (2 * b - 1) - 1 / (2 * a - 1)) * (al + 5 / 6 - 2 / (3 * hVal));
    x = a / (a + b * exp(2 * wVal));
  } else {
    final lna = log(a / (a + b));
    final lnb = log(b / (a + b));
    final tVal = exp(a * lna) / a;
    final uVal = exp(b * lnb) / b;
    final wVal = tVal + uVal;
    if (probability < tVal / wVal) {
      x = pow(a * wVal * probability, 1 / a).toDouble();
    } else {
      x = 1.0 - pow(b * wVal * (1 - probability), 1 / b);
    }
  }
  final afac = -gammaLn(a) - gammaLn(b) + gammaLn(a + b);
  for (var j = 0; j < 10; j++) {
    if (x == 0 || x == 1) return x;
    final err = ibeta(x, a, b) - probability;
    final tVal = exp(a1 * log(x) + b1 * log(1 - x) + afac);
    final uVal = err / tVal;
    final step = uVal / (1 - 0.5 * min(1, uVal * (a1 / x - b1 / (1 - x))));
    x -= step;
    if (x <= 0) {
      x = 0.5 * (x + step);
    }
    if (x >= 1) {
      x = 0.5 * (x + step + 1);
    }
    if (step.abs() < epsilon * x && j > 0) break;
  }
  return x;
}

/// Evaluates the continued fraction for incomplete beta function by modified
/// Lentz's method.
double _betacf(num x, num a, num b) {
  const fpmin = 1.0e-30;
  final qab = a + b + 0.0;
  final qap = a + 1.0;
  final qam = a - 1.0;
  var cVal = 1.0;
  var dVal = 1.0 - qab * x / qap;
  if (dVal.abs() < fpmin) {
    dVal = fpmin;
  }
  dVal = 1.0 / dVal;
  var hVal = dVal;
  for (var stepIdx = 1; stepIdx <= 100; stepIdx++) {
    final m2 = 2.0 * stepIdx;
    var aa = stepIdx * (b - stepIdx) * x / ((qam + m2) * (a + m2));
    dVal = 1.0 + aa * dVal;
    if (dVal.abs() < fpmin) {
      dVal = fpmin;
    }
    cVal = 1.0 + aa / cVal;
    if (cVal.abs() < fpmin) {
      cVal = fpmin;
    }
    dVal = 1.0 / dVal;
    hVal *= dVal * cVal;
    aa = -(a + stepIdx) * (qab + stepIdx) * x / ((a + m2) * (qap + m2));
    dVal = 1.0 + aa * dVal;
    if (dVal.abs() < fpmin) {
      dVal = fpmin;
    }
    cVal = 1.0 + aa / cVal;
    if (cVal.abs() < fpmin) {
      cVal = fpmin;
    }
    dVal = 1.0 / dVal;
    final del = dVal * cVal;
    hVal *= del;
    if ((del - 1.0).abs() < 1.0e-15) {
      break;
    }
  }
  return hVal;
}
