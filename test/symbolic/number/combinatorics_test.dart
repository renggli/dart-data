import 'package:checks/checks.dart';
import 'package:data/src/symbolic/number/combinatorics.dart';
import 'package:data/symbolic.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('bernoulliNumbers', () {
    test('returns empty list for negative maxIndex', () {
      check(bernoulliNumbers(-1)).isEmpty;
    });

    test('computes exact Bernoulli numbers B_0 through B_10', () {
      final b = bernoulliNumbers(10);
      check(b.length).equals(11);
      check(b[0]).equals(IntegerNumber.one);
      check(b[1]).equals(FractionNumber.negativeHalf);
      check(b[2]).equals(RationalNumber(1, 6));
      check(b[3]).equals(IntegerNumber.zero);
      check(b[4]).equals(RationalNumber(-1, 30));
      check(b[5]).equals(IntegerNumber.zero);
      check(b[6]).equals(RationalNumber(1, 42));
      check(b[7]).equals(IntegerNumber.zero);
      check(b[8]).equals(RationalNumber(-1, 30));
      check(b[9]).equals(IntegerNumber.zero);
      check(b[10]).equals(RationalNumber(5, 66));
    });
  });

  group('stirlingSecondKind', () {
    test('returns empty list for negative maxN', () {
      check(stirlingSecondKind(-1)).isEmpty;
    });

    test('computes Stirling numbers of the second kind S(n, k)', () {
      final s = stirlingSecondKind(5);
      check(s[0][0]).equals(BigInt.one);
      check(s[3][1]).equals(BigInt.one);
      check(s[3][2]).equals(BigInt.from(3));
      check(s[3][3]).equals(BigInt.one);
      check(s[4][2]).equals(BigInt.from(7));
      check(s[4][3]).equals(BigInt.from(6));
      check(s[5][2]).equals(BigInt.from(15));
      check(s[5][3]).equals(BigInt.from(25));
      check(s[5][4]).equals(BigInt.from(10));
    });
  });
}
