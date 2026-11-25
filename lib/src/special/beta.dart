import 'dart:math';

import 'package:more/number.dart' show Complex;

import 'gamma.dart';
import 'utils.dart';

/// Returns Euler's beta function
/// `B(a, b) = ∫_0^1 t^(a-1) * (1 - t)^(b-1) dt = Γ(a) * Γ(b) / Γ(a + b)`.
///
/// Defined for `a > 0` and `b > 0`. Returns `0.0` when either argument is
/// `+∞` (with both `> 0`), and `double.nan` for `a <= 0`, `b <= 0`, or `NaN`.
///
/// See https://en.wikipedia.org/wiki/Beta_function for details.
///
/// ```dart
/// final val = beta(2, 3); // ~ 0.08333333333333333 (1/12)
/// ```
double beta(num a, num b) {
  if (a.isNaN || b.isNaN || a <= 0 || b <= 0) {
    return double.nan;
  }
  if (a.isInfinite || b.isInfinite) {
    return 0.0;
  }
  final ad = a.toDouble();
  final bd = b.toDouble();
  final lo = min(ad, bd);
  final hi = max(ad, bd);
  if (lo + hi > 150.0) {
    return exp(betaLn(lo, hi));
  }
  return gamma(lo) * (gamma(hi) / gamma(lo + hi));
}

/// Returns the complex beta function `B(a, b) = Γ(a) * Γ(b) / Γ(a + b)`.
///
/// See https://en.wikipedia.org/wiki/Beta_function for details.
Complex betaComplex(Complex a, Complex b) {
  if (a.isNaN || b.isNaN) return Complex.nan;
  if (!a.a.isFinite || !a.b.isFinite || !b.a.isFinite || !b.b.isFinite) {
    return Complex.nan;
  }
  if (a.abs() < 50.0 && b.abs() < 50.0) {
    return gammaComplex(a) * gammaComplex(b) / gammaComplex(a + b);
  }
  return betaLnComplex(a, b).exp();
}

/// Returns the natural logarithm of the beta function
/// `ln(B(a, b)) = ln(Γ(a)) + ln(Γ(b)) - ln(Γ(a + b))`.
///
/// Defined for `a > 0` and `b > 0`. Returns `double.negativeInfinity` when
/// either argument is `+∞`, and `double.nan` for `a <= 0`, `b <= 0`, or `NaN`.
///
/// See https://en.wikipedia.org/wiki/Beta_function for details.
///
/// ```dart
/// final val = betaLn(2, 3); // ~ -2.484906649788
/// ```
double betaLn(num a, num b) {
  if (a.isNaN || b.isNaN || a <= 0 || b <= 0) {
    return double.nan;
  }
  if (a.isInfinite || b.isInfinite) {
    return double.negativeInfinity;
  }
  return gammaLn(a) + gammaLn(b) - gammaLn(a + b);
}

/// Returns the complex log-beta function
/// `ln(B(a, b)) = ln(Γ(a)) + ln(Γ(b)) - ln(Γ(a + b))`.
///
/// See https://en.wikipedia.org/wiki/Beta_function for details.
Complex betaLnComplex(Complex a, Complex b) =>
    gammaLnComplex(a) + gammaLnComplex(b) - gammaLnComplex(a + b);

/// Returns the regularized incomplete beta function `I_x(a, b)`.
///
/// Evaluates `I_x(a, b) = (1 / B(a, b)) * ∫_0^x t^(a-1) * (1 - t)^(b-1) dt`
/// via continued fractions, defined for `0 <= x <= 1`, `a > 0`, and `b > 0`.
///
/// See https://en.wikipedia.org/wiki/Beta_function#Incomplete_beta_function for
/// details.
///
/// ```dart
/// final p = betaI(0.5, 2, 3); // 0.6875
/// ```
double betaI(num x, num a, num b) {
  if (x.isNaN || a.isNaN || b.isNaN || x < 0 || x > 1 || a <= 0 || b <= 0) {
    return double.nan;
  }
  if (a.isInfinite && b.isInfinite) return double.nan;
  if (a.isInfinite) return x == 1 ? 1.0 : 0.0;
  if (b.isInfinite) return x == 0 ? 0.0 : 1.0;
  if (x == 0) return 0.0;
  if (x == 1) return 1.0;
  final xd = x.toDouble();
  final ad = a.toDouble();
  final bd = b.toDouble();
  final bt = exp(
    gammaLn(ad + bd) -
        gammaLn(ad) -
        gammaLn(bd) +
        ad * log(xd) +
        bd * log1p(-xd),
  );
  if (xd < (ad + 1.0) / (ad + bd + 2.0)) {
    return bt * _betacf(xd, ad, bd) / ad;
  } else {
    return 1.0 - bt * _betacf(1.0 - xd, bd, ad) / bd;
  }
}

/// Returns the inverse `x` of the regularized incomplete beta function
/// such that `I_x(a, b) = p`, for `0 <= p <= 1`, `a > 0`, and `b > 0`.
///
/// Returns `0.0` at `p = 0`, `1.0` at `p = 1`, and `double.nan` for
/// out-of-domain or infinite parameters.
///
/// See https://en.wikipedia.org/wiki/Beta_function#Incomplete_beta_function for
/// details.
///
/// ```dart
/// final x = betaIInv(0.6875, 2, 3); // ~ 0.5
/// ```
double betaIInv(num p, num a, num b) {
  if (p.isNaN ||
      a.isNaN ||
      b.isNaN ||
      p < 0.0 ||
      p > 1.0 ||
      a <= 0 ||
      b <= 0 ||
      a.isInfinite ||
      b.isInfinite) {
    return double.nan;
  }
  if (p == 0.0) return 0.0;
  if (p == 1.0) return 1.0;

  const epsilon = 1.0e-14;
  final pd = p.toDouble();
  final ad = a.toDouble();
  final bd = b.toDouble();
  final a1 = ad - 1.0;
  final b1 = bd - 1.0;
  var x = 0.0;
  if (ad >= 1.0 && bd >= 1.0) {
    final pp = pd < 0.5 ? pd : 1.0 - pd;
    final tVal = sqrt(-2.0 * log(pp));
    x =
        (2.30753 + tVal * 0.27061) / (1.0 + tVal * (0.99229 + tVal * 0.04481)) -
        tVal;
    if (pd < 0.5) {
      x = -x;
    }
    final al = (x * x - 3.0) / 6.0;
    final hVal = 2.0 / (1.0 / (2.0 * ad - 1.0) + 1.0 / (2.0 * bd - 1.0));
    final wVal =
        (x * sqrt(al + hVal) / hVal) -
        (1.0 / (2.0 * bd - 1.0) - 1.0 / (2.0 * ad - 1.0)) *
            (al + 5.0 / 6.0 - 2.0 / (3.0 * hVal));
    x = ad / (ad + bd * exp(2.0 * wVal));
  } else {
    final lna = log(ad / (ad + bd));
    final lnb = log(bd / (ad + bd));
    final tVal = exp(ad * lna) / ad;
    final uVal = exp(bd * lnb) / bd;
    final wVal = tVal + uVal;
    if (pd < tVal / wVal) {
      x = pow(ad * wVal * pd, 1.0 / ad).toDouble();
    } else {
      x = 1.0 - pow(bd * wVal * (1.0 - pd), 1.0 / bd);
    }
  }
  final afac = -gammaLn(ad) - gammaLn(bd) + gammaLn(ad + bd);
  var xMin = 0.0;
  var xMax = 1.0;
  if (x <= 0.0 || x >= 1.0 || x.isNaN) {
    x = 0.5;
  }
  final errTol = 1.0e-15 * min(pd, 1.0 - pd);
  for (var j = 0; j < 60; j++) {
    if (x <= xMin || x >= xMax) {
      x = 0.5 * (xMin + xMax);
    }
    final curProb = betaI(x, ad, bd);
    final err = curProb - pd;
    if (err > 0) {
      if (x < xMax) xMax = x;
    } else {
      if (x > xMin) xMin = x;
    }
    if (err.abs() <= errTol || (xMax - xMin) <= epsilon * x) {
      break;
    }
    final tVal = exp(a1 * log(x) + b1 * log1p(-x) + afac);
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
    final nextX = x - uVal / denom;
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
double _betacf(double x, double a, double b) {
  final qab = a + b;
  final qap = a + 1.0;
  final qam = a - 1.0;
  var cVal = 1.0;
  var dVal = 1.0 - qab * x / qap;
  if (dVal.abs() < tinyDouble) {
    dVal = tinyDouble;
  }
  dVal = 1.0 / dVal;
  var hVal = dVal;
  final maxIter = qab.isFinite ? max(200, min(100000, (qab * 2).ceil())) : 200;
  for (var stepIdx = 1; stepIdx <= maxIter; stepIdx++) {
    final m2 = 2.0 * stepIdx;
    var aa = stepIdx * (b - stepIdx) * x / ((qam + m2) * (a + m2));
    dVal = 1.0 + aa * dVal;
    if (dVal.abs() < tinyDouble) dVal = tinyDouble;
    cVal = 1.0 + aa / cVal;
    if (cVal.abs() < tinyDouble) cVal = tinyDouble;
    dVal = 1.0 / dVal;
    hVal *= dVal * cVal;
    aa = -(a + stepIdx) * (qab + stepIdx) * x / ((a + m2) * (qap + m2));
    dVal = 1.0 + aa * dVal;
    if (dVal.abs() < tinyDouble) dVal = tinyDouble;
    cVal = 1.0 + aa / cVal;
    if (cVal.abs() < tinyDouble) cVal = tinyDouble;
    dVal = 1.0 / dVal;
    final del = dVal * cVal;
    hVal *= del;
    if ((del - 1.0).abs() < 1.0e-15) {
      break;
    }
  }
  return hVal;
}
