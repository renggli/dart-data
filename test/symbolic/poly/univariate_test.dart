import 'package:checks/checks.dart';
import 'package:data/src/symbolic/poly/univariate.dart';
import 'package:data/symbolic.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('PolyZ exact integer polynomials', () {
    test('normalizes coefficients, arithmetic, content, and primitivePart', () {
      check(PolyZ.zero.isZero).isTrue;
      check(PolyZ.zero.degree).equals(-1);
      check(PolyZ([BigInt.zero, BigInt.zero]).isZero).isTrue;

      final p = PolyZ([BigInt.from(-6), BigInt.from(12), BigInt.from(-6)]);
      check(p.degree).equals(2);
      check(p.content()).equals(BigInt.from(6));
      check(p.primitivePart())
          .equals(PolyZ([BigInt.one, BigInt.from(-2), BigInt.one]));
      check(p.evaluate(BigInt.from(2))).equals(BigInt.from(-6));
      check(p.derivative()).equals(PolyZ([BigInt.from(12), BigInt.from(-12)]));

      final a = PolyZ([BigInt.one, BigInt.two]);
      final b = PolyZ([BigInt.from(-1), BigInt.one]);
      check(a + b).equals(PolyZ([BigInt.zero, BigInt.from(3)]));
      check(a * b)
          .equals(PolyZ([BigInt.from(-1), BigInt.from(-1), BigInt.two]));
    });

    test(
      'computes pseudoDivide, exactDivide, gcd, squareFree, and resultant',
      () {
        final f = PolyZ([BigInt.one, BigInt.zero, BigInt.one]); // x^2 + 1
        final g = PolyZ([BigInt.from(-1), BigInt.one]); // x - 1
        final gSq = g * g;
        final prod = f * gSq;

        check(prod.exactDivide(f)).equals(gSq);
        check(prod.exactDivide(PolyZ([BigInt.two, BigInt.one]))).isNull;
        check((prod * PolyZ.constant(BigInt.from(3))).gcd(gSq)).equals(gSq);

        final sqFree = prod.squareFreeDecomposition();
        check(sqFree.length).equals(2);
        check(sqFree[0]).equals((factor: f, multiplicity: 1));
        check(sqFree[1]).equals((factor: g, multiplicity: 2));

        check(f.resultant(g)).equals(BigInt.two);
        check(prod.resultant(g)).equals(BigInt.zero);

        final pseudo = prod.pseudoDivide(f);
        check(pseudo.remainder.isZero).isTrue;
        check(pseudo.quotient).equals(gSq);
      },
    );
  });

  group('PolyQ exact rational polynomials', () {
    test(
      'computes divRem, gcd, extendedGcd, lcm, and squareFreeDecomposition',
      () {
        final xMinus1 = PolyQ([IntegerNumber.negativeOne, IntegerNumber.one]);
        final xPlus1 = PolyQ([IntegerNumber.one, IntegerNumber.one]);
        final half = PolyQ.constant(RationalNumber(1, 2));

        final a = (xMinus1 * xPlus1).scale(RationalNumber(3, 2));
        final b = xMinus1 * half;
        final (:quotient, :remainder) = a.divRem(b);
        check(remainder.isZero).isTrue;
        check(quotient).equals(xPlus1.scale(IntegerNumber.of(3)));

        check(a.gcd(b)).equals(xMinus1);
        check(a.lcm(b)).equals(xMinus1 * xPlus1);

        final (:gcd, :s, :t) = xMinus1.extendedGcd(xPlus1);
        check(gcd).equals(PolyQ.one);
        check(s * xMinus1 + t * xPlus1).equals(PolyQ.one);

        final sq = (xMinus1 * xMinus1 * xPlus1).squareFreeDecomposition();
        check(sq.length).equals(2);
        check(sq[0]).equals((factor: xPlus1, multiplicity: 1));
        check(sq[1]).equals((factor: xMinus1, multiplicity: 2));

        check(PolyZ.one.isConstant).isTrue;
        check(() => PolyZ.monomial(-1)).throws<ArgumentError>();
        check(-PolyZ.monomial(2))
            .equals(PolyZ([BigInt.zero, BigInt.zero, BigInt.from(-1)]));
        check(PolyZ.monomial(1) - PolyZ.one)
            .equals(PolyZ([BigInt.from(-1), BigInt.one]));
        check(PolyZ.monomial(1).scale(BigInt.from(3)))
            .equals(PolyZ([BigInt.zero, BigInt.from(3)]));
        check(() => PolyZ.one.pseudoDivide(PolyZ.zero)).throws<ArgumentError>();
        check(() => PolyZ.one.exactDivide(PolyZ.zero)).throws<ArgumentError>();
        check(
          PolyZ.constant(BigInt.two).resultant(PolyZ([BigInt.one, BigInt.one])),
        ).equals(BigInt.two);
        check(
          PolyZ([BigInt.one, BigInt.one])
              .resultant(PolyZ.constant(BigInt.from(3))),
        ).equals(BigInt.from(3));
        check(PolyZ.one.toString()).isNotEmpty;

        check(() => PolyQ.monomial(-1)).throws<ArgumentError>();
        check(
          PolyQ.monomial(2, RationalNumber(1, 2)).evaluate(IntegerNumber.two),
        ).equals(IntegerNumber.two);
        check(PolyQ.zero.clearDenominators().primitive).equals(PolyZ.zero);
        check(() => PolyQ.one.divRem(PolyQ.zero)).throws<ArgumentError>();
        check(
          PolyQ.constant(IntegerNumber.two)
              .resultant(PolyQ([IntegerNumber.one, IntegerNumber.one])),
        ).equals(IntegerNumber.two);
        check(PolyQ.one.hashCode).equals(PolyQ.one.hashCode);
        check(PolyQ.one.toString()).isNotEmpty;
      },
    );
  });
}
