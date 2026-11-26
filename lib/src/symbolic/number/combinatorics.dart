import '../ast.dart';
import 'integer.dart';
import 'rational.dart';

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
    var binom = Integer.one;
    var sum = (numerator: Integer.zero, denominator: Integer.one);
    for (var j = 0; j < m; j++) {
      if (j > 0) {
        binom = (binom * Integer.from(m + 2 - j)) ~/ Integer.from(j);
      }
      final bj = b[j];
      if (!bj.isZero) {
        sum = rationalAdd(
          sum,
          rationalMultiply(
            (numerator: binom, denominator: Integer.one),
            (numerator: bj.numerator, denominator: bj.denominator),
          ),
        );
      }
    }
    final next = rationalDivide(rationalNegate(sum), (
      numerator: Integer.from(m + 1),
      denominator: Integer.one,
    ));
    b.add(RationalNumber.of(next.numerator, next.denominator));
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
