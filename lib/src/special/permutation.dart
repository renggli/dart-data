import 'dart:math';

import 'factorial.dart';
import 'utils.dart';

/// Returns the number of `k`-permutations of `total`: `P(total, count) = total! / (total - count)!`.
///
/// See https://en.wikipedia.org/wiki/Permutation#k-permutations_of_n for details.
///
/// ```dart
/// print(permutation(5, 2)); // 20.0
/// ```
double permutation(num total, num count) {
  if (total.isNaN || count.isNaN) return double.nan;
  if (count < 0 || count > total) return 0.0;
  if (count == 0) return 1.0;
  if (total.isInfinite) return count.isInfinite ? double.nan : double.infinity;

  final isTotalInt = total.isFinite && total.roundToDouble() == total;
  final isCountInt = count.isFinite && count.roundToDouble() == count;
  if (isTotalInt && isCountInt && count <= 1000) {
    final totalInt = total.toInt();
    final countInt = count.toInt();
    var res = 1;
    var canUseInt = true;
    for (var i = 0; i < countInt; i++) {
      final term = totalInt - i;
      if (res > maxSafeInt ~/ term) {
        canUseInt = false;
        break;
      }
      res *= term;
    }
    if (canUseInt) return res.toDouble();
    var bigRes = BigInt.one;
    final totalBig = BigInt.from(total);
    for (var i = 0; i < countInt; i++) {
      bigRes *= totalBig - BigInt.from(i);
    }
    return bigRes.toDouble();
  }
  return exp(permutationLn(total, count));
}

/// Returns the natural logarithm of `P(total, count)`.
///
/// See https://en.wikipedia.org/wiki/Permutation#k-permutations_of_n for details.
double permutationLn(num total, num count) =>
    factorialLn(total) - factorialLn(total - count);
