import 'package:checks/checks.dart';
import 'package:data/src/symbolic/textualization/formatting.dart';
import 'package:data/symbolic.dart';
import 'package:test/test.dart';

void main() {
  group('Leading negative and fraction partitioning helpers', () {
    test('stripLeadingNegative extracts positive remainders', () {
      const x = Variable('x');
      const y = Variable('y');
      check(stripLeadingNegative(IntegerNumber.of(-3)))
          .equals(IntegerNumber.of(3));
      check(stripLeadingNegative(ComplexNumber.negativeI))
          .equals(ComplexNumber.i);
      check(stripLeadingNegative(-x)).equals(x);
      check(stripLeadingNegative(Mul([IntegerNumber.negativeOne, x, y])))
          .equals(Mul([x, y]));
      check(stripLeadingNegative(Mul([IntegerNumber.of(-2), x])))
          .equals(Mul([IntegerNumber.two, x]));
      check(stripLeadingNegative(Mul([ComplexNumber.negativeI, x])))
          .equals(Mul([ComplexNumber.i, x]));
      check(stripLeadingNegative(x)).isNull();
    });

    test('partitionMulFraction separates sign, numerator, and denominator', () {
      const x = Variable('x');
      const y = Variable('y');
      final part = partitionMulFraction([
        RationalNumber(-3, 4),
        x,
        Pow(y, IntegerNumber.of(-2)),
      ]);
      check(part.isNegative).isTrue();
      check(part.numerator).deepEquals([IntegerNumber.of(3), x]);
      check(part.denominator)
          .deepEquals([IntegerNumber.of(4), Pow(y, IntegerNumber.two)]);
    });
  });

  group('Function power, multiplication dot, and parenthesization helpers', () {
    test('matchFunctionPower and canOmitMulDot rules', () {
      const x = Variable('x');
      const y = Variable('y');
      check(matchFunctionPower(Sin(x), IntegerNumber.two)).isNotNull();
      check(matchFunctionPower(Sin(x), IntegerNumber.one)).isNull();
      check(matchFunctionPower(Asin(x), IntegerNumber.two)).isNull();

      check(canOmitMulDot(IntegerNumber.two, x)).isTrue();
      check(canOmitMulDot(x, y)).isTrue();
      check(canOmitMulDot(IntegerNumber.two, IntegerNumber.of(3))).isFalse();
      check(canOmitMulDot(x, IntegerNumber.of(-2))).isFalse();
      check(canOmitMulDot(x, Pow(y, IntegerNumber.negativeOne))).isFalse();
    });

    test('parenthesization predicates for sub, mul, pow, and neg', () {
      const x = Variable('x');
      const y = Variable('y');
      const comp = ComplexNumber(IntegerNumber.one, IntegerNumber.one);

      check(needsSubRightParens(x + y)).isTrue();
      check(needsSubRightParens(comp)).isTrue();
      check(needsSubRightParens(-x)).isTrue();
      check(needsSubRightParens(x)).isFalse();

      check(needsMulLeftParens(x + y)).isTrue();
      check(needsMulLeftParens(comp)).isTrue();
      check(needsMulLeftParens(x)).isFalse();

      check(needsMulRightParens(x + y)).isTrue();
      check(needsMulRightParens(comp)).isTrue();
      check(needsMulRightParens(-x)).isTrue();
      check(needsMulRightParens(x)).isFalse();

      check(needsPowBaseParens(x + y)).isTrue();
      check(needsPowBaseParens(x * y)).isTrue();
      check(needsPowBaseParens(FractionNumber.half)).isTrue();
      check(needsPowBaseParens(IntegerNumber.of(-2))).isTrue();
      check(needsPowBaseParens(comp)).isTrue();
      check(needsPowBaseParens(Pow(x, IntegerNumber.negativeOne))).isTrue();
      check(needsPowBaseParens(x)).isFalse();

      check(needsNegOperandParens(x + y)).isTrue();
      check(needsNegOperandParens(comp)).isTrue();
      check(needsNegOperandParens(-x)).isTrue();
      check(needsNegOperandParens(x)).isFalse();
    });
  });
}
