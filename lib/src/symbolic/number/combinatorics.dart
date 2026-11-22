import '../ast.dart';
import 'integer.dart';

/// Computes the Bernoulli numbers `B_0, B_1, ..., B_maxIndex` using the
/// first convention (`B_1 = -1/2`).
List<RationalNumber> bernoulliNumbers(int maxIndex) {
  if (maxIndex < 0) return const [];
  final b = <RationalNumber>[IntegerNumber.one];
  for (var m = 1; m <= maxIndex; m++) {
    if (m == 1) {
      b.add(FractionNumber.negativeHalf);
      continue;
    }
    if (m.isOdd) {
      b.add(IntegerNumber.zero);
      continue;
    }
    var sum = IntegerNumber.zero as RationalNumber;
    for (var j = 0; j < m; j++) {
      if (b[j].isZero) continue;
      final binom = IntegerNumber(
        Integer.from(m + 1).binomial(Integer.from(j)),
      );
      sum = sum.addRational(binom.mulRational(b[j]));
    }
    b.add(sum.neg().divRational(IntegerNumber.of(m + 1)));
  }
  return b;
}

/// Computes the triangle of Stirling numbers of the second kind `S(n, k)`
/// for `0 <= k <= n <= maxN`.
List<List<Integer>> stirlingSecondKind(int maxN) {
  if (maxN < 0) return const [];
  final table = List<List<Integer>>.generate(
    maxN + 1,
    (_) => List<Integer>.filled(maxN + 1, Integer.zero),
  );
  table[0][0] = Integer.one;
  for (var n = 1; n <= maxN; n++) {
    for (var k = 1; k <= n; k++) {
      table[n][k] = Integer.from(k) * table[n - 1][k] + table[n - 1][k - 1];
    }
  }
  return table;
}
