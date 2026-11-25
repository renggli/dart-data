import 'dart:math';

import 'package:more/number.dart' show Complex;

import 'gamma.dart';
import 'utils.dart';

/// Returns the number of `k`-permutations of `n`:
/// `P(n, k) = Γ(n + 1) / Γ(n - k + 1)`.
///
/// Uses exact integer arithmetic with overflow fallback to [BigInt] for safe
/// non-negative integers with `k <= 1000`, and [permutationLn] via [gammaLn]
/// for general real inputs.
///
/// See https://en.wikipedia.org/wiki/Permutation#k-permutations_of_n for details.
///
/// ```dart
/// print(permutation(5, 2)); // 20.0
/// ```
double permutation(num n, num k) {
  if (n.isNaN || k.isNaN) return double.nan;
  final nd = n.toDouble();
  final kd = k.toDouble();
  if (kd < 0.0 || kd > nd) return 0.0;
  if (kd == 0.0) return 1.0;
  if (nd.isInfinite) {
    return nd < 0.0 || kd.isInfinite ? double.nan : double.infinity;
  }

  final isNInt = nd.isFinite && nd <= maxSafeInt && nd.roundToDouble() == nd;
  final isKInt = kd.isFinite && kd.roundToDouble() == kd;
  if (isNInt && isKInt && kd <= 1000.0) {
    final nInt = nd.toInt();
    final kInt = kd.toInt();
    var res = 1;
    var canUseInt = true;
    for (var i = 0; i < kInt; i++) {
      final term = nInt - i;
      if (res > maxSafeInt ~/ term) {
        canUseInt = false;
        break;
      }
      res *= term;
    }
    if (canUseInt) return res.toDouble();
    var bigRes = BigInt.one;
    final nBig = BigInt.from(nInt);
    for (var i = 0; i < kInt; i++) {
      bigRes *= nBig - BigInt.from(i);
    }
    return bigRes.toDouble();
  }
  return exp(permutationLn(nd, kd));
}

/// Returns the complex `k`-permutation `P(n, k) = Γ(n + 1) / Γ(n - k + 1)`.
///
/// See https://en.wikipedia.org/wiki/Permutation#k-permutations_of_n for details.
Complex permutationComplex(Complex n, Complex k) {
  if (n.isNaN || k.isNaN) return Complex.nan;
  if (!n.a.isFinite || !n.b.isFinite || !k.a.isFinite || !k.b.isFinite) {
    return Complex.nan;
  }
  if (k == Complex.zero) return Complex.one;
  if (k.b == 0.0 && k.a == k.a.roundToDouble()) {
    final kd = k.a.toDouble();
    if (kd < 0.0) return Complex.zero;
    if (n.b == 0.0 && n.a >= 0.0 && n.a == n.a.roundToDouble() && kd > n.a) {
      return Complex.zero;
    }
    if (kd <= 1000.0) {
      final kInt = kd.round();
      var res = Complex.one;
      for (var i = 0; i < kInt; i++) {
        res *= n - i.toDouble();
      }
      return res;
    }
  }
  return (gammaLnComplex(n + 1) - gammaLnComplex(n - k + 1)).exp();
}

/// Returns the natural logarithm of `P(n, k)` for `0 <= k <= n`.
///
/// Returns `double.nan` when `n < 0`, `k < 0`, `k > n`, or either argument is
/// `NaN`.
///
/// See https://en.wikipedia.org/wiki/Permutation#k-permutations_of_n for details.
double permutationLn(num n, num k) {
  if (n.isNaN || k.isNaN) return double.nan;
  final nd = n.toDouble();
  final kd = k.toDouble();
  if (kd < 0.0 || kd > nd || nd < 0.0) return double.nan;
  if (kd == 0.0) return 0.0;
  if (nd.isInfinite) {
    return kd.isInfinite ? double.nan : double.infinity;
  }
  if (kd.roundToDouble() == kd && kd <= 32.0) {
    final kInt = kd.toInt();
    var sum = 0.0;
    for (var i = 0; i < kInt; i++) {
      sum += log(nd - i);
    }
    return sum;
  }
  return gammaLn(nd + 1.0) - gammaLn(nd - kd + 1.0);
}
