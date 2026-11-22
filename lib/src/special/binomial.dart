import 'dart:math';

import 'package:more/number.dart' show Complex;

import 'factorial.dart';
import 'gamma.dart';
import 'utils.dart';

/// Returns the binomial coefficient `C(total, choose) = total! / (choose! * (total - choose)!)`.
///
/// Uses exact integer arithmetic with overflow fallback to [BigInt] for integer
/// inputs with `k <= 1000`, and [binomialLn] via [gammaLn] for general real
/// inputs.
///
/// See https://en.wikipedia.org/wiki/Binomial_coefficient for details.
///
/// ```dart
/// print(binomial(5, 2)); // 10.0
/// ```
double binomial(num total, num choose) {
  if (total.isNaN || choose.isNaN) return double.nan;
  if (choose < 0 || choose > total) return 0.0;
  if (choose == 0) return 1.0;
  if (total.isInfinite) {
    if (choose.isInfinite || choose.floorToDouble() != choose) {
      return double.nan;
    }
    return double.infinity;
  }
  if (choose == total) return 1.0;
  final k = choose > total - choose ? total - choose : choose;
  final isTotalInt = total.isFinite && total.roundToDouble() == total;
  final isChooseInt = k.isFinite && k.roundToDouble() == k;
  if (isTotalInt && isChooseInt && k <= 1000) {
    final totalInt = total.toInt();
    final kInt = k.toInt();
    var res = 1;
    var canUseInt = true;
    for (var i = 1; i <= kInt; i++) {
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
    final totalBig = BigInt.from(total);
    for (var i = 1; i <= kInt; i++) {
      bigRes = (bigRes * (totalBig - BigInt.from(kInt - i))) ~/ BigInt.from(i);
    }
    return bigRes.toDouble();
  }
  return exp(binomialLn(total, choose));
}

/// Returns the complex binomial coefficient `C(n, k) = Γ(n + 1) / (Γ(k + 1) * Γ(n - k + 1))`.
///
/// See https://en.wikipedia.org/wiki/Binomial_coefficient for details.
Complex binomialComplex(Complex n, Complex k) {
  if (n.isNaN || k.isNaN) return Complex.nan;
  if (k == Complex.zero) return Complex.one;
  if (k.b == 0.0 && k.a == k.a.roundToDouble()) {
    final kInt = k.a.toInt();
    if (kInt < 0) return Complex.zero;
    if (kInt <= 20) {
      var res = Complex.one;
      for (var i = 0; i < kInt; i++) {
        res = res * (n - i) / (i + 1);
      }
      return res;
    }
  }
  return (gammaLnComplex(n + 1) -
          gammaLnComplex(k + 1) -
          gammaLnComplex(n - k + 1))
      .exp();
}

/// Returns the natural logarithm of the binomial coefficient `ln(C(total, choose))`.
///
/// See https://en.wikipedia.org/wiki/Binomial_coefficient for details.
double binomialLn(num total, num choose) =>
    factorialLn(total) - factorialLn(choose) - factorialLn(total - choose);
