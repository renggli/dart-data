import 'dart:math';

import 'package:more/number.dart' show Complex;

import 'gamma.dart';
import 'utils.dart';

/// Returns the generalized binomial coefficient
/// `C(n, k) = Γ(n + 1) / (Γ(k + 1) * Γ(n - k + 1))`.
///
/// Uses exact integer arithmetic with overflow fallback to [BigInt] for safe
/// non-negative integers with `min(k, n - k) <= 1000`, falling-factorial
/// products for small integer `k`, and [logAbsGammaWithSign] for general real
/// inputs (including negative and fractional `n`).
///
/// See https://en.wikipedia.org/wiki/Binomial_coefficient for details.
///
/// ```dart
/// print(binomial(5, 2)); // 10.0
/// ```
double binomial(num n, num k) {
  if (n.isNaN || k.isNaN) return double.nan;
  final nd = n.toDouble();
  final kd = k.toDouble();
  if (kd == 0.0) return 1.0;
  final isKInt = kd.isFinite && kd.roundToDouble() == kd;
  if (isKInt && kd < 0.0) return 0.0;
  final isNInt = nd.isFinite && nd.roundToDouble() == nd;
  if (nd.isInfinite) {
    if (nd < 0.0 || kd.isInfinite || !isKInt) return double.nan;
    return double.infinity;
  }
  if (kd.isInfinite) {
    return isNInt && nd >= 0.0 && kd > 0.0 ? 0.0 : double.nan;
  }
  if (isNInt && nd >= 0.0 && isKInt) {
    if (kd > nd) return 0.0;
    if (kd == nd) return 1.0;
    final m = min(kd, nd - kd);
    if (nd <= maxSafeInt && m <= 1000.0) {
      final totalInt = nd.toInt();
      final mInt = m.toInt();
      var res = 1;
      var canUseInt = true;
      for (var i = 1; i <= mInt; i++) {
        final term = totalInt - i + 1;
        final g = term.gcd(i);
        final numPart = term ~/ g;
        final denPart = i ~/ g;
        res = res ~/ denPart;
        if (res > maxSafeInt ~/ numPart) {
          canUseInt = false;
          break;
        }
        res *= numPart;
      }
      if (canUseInt) return res.toDouble();
      var bigRes = BigInt.one;
      final totalBig = BigInt.from(totalInt);
      for (var i = 1; i <= mInt; i++) {
        bigRes =
            (bigRes * (totalBig - BigInt.from(mInt - i))) ~/ BigInt.from(i);
      }
      return bigRes.toDouble();
    }
  }
  if (isKInt && kd > 0.0 && kd <= 1000.0) {
    final kInt = kd.toInt();
    var res = 1.0;
    for (var i = 0; i < kInt; i++) {
      res = res * (nd - i) / (i + 1);
    }
    return res;
  }
  if (isNInt && nd < 0.0 && isKInt) {
    final sign = kd % 2.0 == 0.0 ? 1.0 : -1.0;
    return sign * binomial(-nd + kd - 1.0, kd);
  }
  final numG = logAbsGammaWithSign(nd + 1.0);
  final den1G = logAbsGammaWithSign(kd + 1.0);
  final den2G = logAbsGammaWithSign(nd - kd + 1.0);
  if (numG.logAbs.isNaN || den1G.logAbs.isNaN || den2G.logAbs.isNaN) {
    return double.nan;
  }
  if (numG.sign == 0) return double.nan;
  if (den1G.sign == 0 || den2G.sign == 0) return 0.0;
  final logVal = numG.logAbs - den1G.logAbs - den2G.logAbs;
  final sign = numG.sign * den1G.sign * den2G.sign;
  return logVal > 709.782712893384
      ? sign * double.infinity
      : sign * exp(logVal);
}

/// Returns the complex binomial coefficient
/// `C(n, k) = Γ(n + 1) / (Γ(k + 1) * Γ(n - k + 1))`.
///
/// See https://en.wikipedia.org/wiki/Binomial_coefficient for details.
Complex binomialComplex(Complex n, Complex k) {
  if (n.isNaN || k.isNaN) return Complex.nan;
  if (!n.a.isFinite || !n.b.isFinite || !k.a.isFinite || !k.b.isFinite) {
    return Complex.nan;
  }
  if (k == Complex.zero) return Complex.one;
  if (k.b == 0.0 && k.a == k.a.roundToDouble()) {
    final kd = k.a.toDouble();
    if (kd < 0.0) return Complex.zero;
    final isNRealInt = n.b == 0.0 && n.a == n.a.roundToDouble();
    if (isNRealInt && n.a >= 0.0 && kd > n.a) {
      return Complex.zero;
    }
    var m = kd;
    if (isNRealInt && n.a >= 0.0 && n.a - kd < m) {
      m = n.a - kd;
    }
    if (m <= 1000.0) {
      final mInt = m.round();
      var res = Complex.one;
      for (var i = 0; i < mInt; i++) {
        res = res * (n - i.toDouble()) / (i + 1).toDouble();
      }
      return res;
    }
    if (isNRealInt && n.a < 0.0) {
      final sign = kd % 2.0 == 0.0 ? 1.0 : -1.0;
      return Complex(sign) * binomialComplex(Complex(-n.a + kd - 1.0), k);
    }
  }
  return (gammaLnComplex(n + 1) -
          gammaLnComplex(k + 1) -
          gammaLnComplex(n - k + 1))
      .exp();
}

/// Returns the natural logarithm of the binomial coefficient
/// `ln(C(n, k))` for `0 <= k <= n`.
///
/// Returns `double.nan` when `n < 0`, `k < 0`, `k > n`, or either argument is
/// `NaN`.
///
/// See https://en.wikipedia.org/wiki/Binomial_coefficient for details.
double binomialLn(num n, num k) {
  if (n.isNaN || k.isNaN) return double.nan;
  final nd = n.toDouble();
  final kd = k.toDouble();
  if (kd < 0.0 || kd > nd || nd < 0.0) return double.nan;
  if (kd == 0.0) return 0.0;
  if (nd.isInfinite) {
    return kd.isInfinite || kd.roundToDouble() != kd
        ? double.nan
        : double.infinity;
  }
  if (kd == nd) return 0.0;
  if (kd.roundToDouble() == kd) {
    final m = min(kd, nd - kd);
    if (m <= 32.0) {
      final mInt = m.toInt();
      var sum = 0.0;
      for (var i = 1; i <= mInt; i++) {
        sum += log(nd - i + 1) - log(i);
      }
      return sum;
    }
  }
  return gammaLn(nd + 1.0) - gammaLn(kd + 1.0) - gammaLn(nd - kd + 1.0);
}
