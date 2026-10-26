import 'dart:math';

import 'gamma.dart';

/// Beta function based on the [gamma] function.
///
/// Conceptually, the beta function connects two continuous parameters $x$ and
/// $y$, playing a fundamental role in combinatorics, calculus, and Bayesian
/// probability distributions. Formally, this calculates the Euler integral of
/// the first kind
/// $B(x, y) = \int_0^1 t^{x-1} (1-t)^{y-1} dt$
/// $= \frac{\Gamma(x)\Gamma(y)}{\Gamma(x+y)}$.
///
/// ```dart
/// final val = beta(2, 3); // ~ 0.08333333333333333 (1/12)
/// ```
double beta(num x, num y) {
  if (x.isNaN || y.isNaN || x <= 0 || y <= 0) {
    return double.nan;
  }
  if (x > 100 || y > 100) {
    return exp(betaLn(x, y));
  }
  return gamma(x) * gamma(y) / gamma(x + y);
}

/// Logarithm of the beta function based on the [gammaLn] function.
///
/// Conceptually, this computes $\ln(B(x, y))$ directly to prevent numerical
/// overflow when calculating ratios of large factorials or probability
/// densities. Formally, this calculates
/// $\ln B(x, y) = \ln \Gamma(x) + \ln \Gamma(y) - \ln \Gamma(x+y)$.
///
/// ```dart
/// final val = betaLn(2, 3); // ~ -2.484906649788
/// ```
double betaLn(num x, num y) => x.isNaN || y.isNaN || x <= 0 || y <= 0
    ? double.nan
    : gammaLn(x) + gammaLn(y) - gammaLn(x + y);

/// Incomplete beta function $I_x(a, b)$.
///
/// Conceptually, this calculates the cumulative probability area under a beta
/// distribution curve from 0 up to point $x$. Formally, this evaluates the
/// regularized incomplete beta function
/// $I_x(a, b) = \frac{1}{B(a, b)} \int_0^x t^{a-1} (1-t)^{b-1} dt$ via
/// continued fractions.
///
/// ```dart
/// final p = ibeta(0.5, 2, 3); // 0.6875
/// ```
double ibeta(num x, num a, num b) {
  if (x.isNaN || a.isNaN || b.isNaN || x < 0 || 1 < x || a <= 0 || b <= 0) {
    return double.nan;
  }
  if (x == 0) return 0.0;
  if (x == 1) return 1.0;
  // Factor in front of the continued fraction.
  final bt = exp(
    gammaLn(a + b) - gammaLn(a) - gammaLn(b) + a * log(x) + b * log(1.0 - x),
  );
  if (x < (a + 1.0) / (a + b + 2.0)) {
    // Use continued fraction directly.
    return bt * _betacf(x, a, b) / a;
  } else {
    // Use continued fraction after making the symmetry transformation.
    return 1.0 - bt * _betacf(1.0 - x, b, a) / b;
  }
}

/// Inverse of the incomplete beta function $I_p^{-1}(a, b)$.
///
/// Conceptually, this computes the inverse cumulative distribution: given a
/// target probability or percentile $p$, it determines the cutoff value $x$
/// such that $I_x(a, b) = p$. Formally, it computes the quantile function
/// $x = I_p^{-1}(a, b)$ satisfying $I_x(a, b) = p$, utilizing asymptotic
/// expansions followed by iterative root refinement.
///
/// ```dart
/// final x = ibetaInv(0.6875, 2, 3); // ~ 0.5
/// ```
double ibetaInv(num probability, num a, num b) {
  if (probability.isNaN ||
      a.isNaN ||
      b.isNaN ||
      probability < 0.0 ||
      probability > 1.0 ||
      a <= 0 ||
      b <= 0) {
    return double.nan;
  }
  if (probability == 0.0) {
    return 0.0;
  }
  if (probability == 1.0) {
    return 1.0;
  }
  const epsilon = 1.0e-14;
  final a1 = a - 1.0;
  final b1 = b - 1.0;
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
  var xMin = 0.0;
  var xMax = 1.0;
  if (x <= 0.0 || x >= 1.0 || x.isNaN) {
    x = 0.5;
  }
  for (var j = 0; j < 60; j++) {
    if (x <= xMin || x >= xMax) {
      x = 0.5 * (xMin + xMax);
    }
    final curProb = ibeta(x, a, b);
    final err = curProb - probability;
    if (err > 0) {
      if (x < xMax) xMax = x;
    } else {
      if (x > xMin) xMin = x;
    }
    if (err.abs() <= 1.0e-15 || (xMax - xMin) <= epsilon * x) {
      break;
    }
    final tVal = exp(a1 * log(x) + b1 * log(1.0 - x) + afac);
    if (tVal <= 0.0 || tVal.isNaN || tVal.isInfinite) {
      x = 0.5 * (xMin + xMax);
      continue;
    }
    final uVal = err / tVal;
    final denom = 1.0 - 0.5 * min(1.0, uVal * (a1 / x - b1 / (1.0 - x)));
    if (denom <= 0.0 || denom.isNaN) {
      x = 0.5 * (xMin + xMax);
      continue;
    }
    final step = uVal / denom;
    final nextX = x - step;
    if (nextX <= xMin || nextX >= xMax || nextX.isNaN) {
      x = 0.5 * (xMin + xMax);
    } else {
      final change = (x - nextX).abs();
      x = nextX;
      if (change < epsilon * x && j > 0) {
        break;
      }
    }
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
  final maxIter = qab.isFinite ? max(200, min(100000, (qab * 2).ceil())) : 200;
  for (var stepIdx = 1; stepIdx <= maxIter; stepIdx++) {
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
