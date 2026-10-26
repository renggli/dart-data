import 'package:checks/checks.dart';
import 'package:data/src/symbolic/algebra/term_accumulator.dart';
import 'package:data/symbolic.dart';
import 'package:test/test.dart';

void main() {
  group('MonomialAccumulator term collection and polynomial extraction', () {
    test('accumulates like monomials and extracts polynomial coefficients', () {
      final acc = MonomialAccumulator();
      acc.add(Expr.parse('3 * x^2 + 2 * x - 5'));
      acc.add(Expr.parse('x^2 - 2 * x + 1'));

      final coeffs = acc.extractPolynomialCoefficients('x');
      check(coeffs).isNotNull();
      check(coeffs![0]).equals(IntegerNumber.of(-4));
      check(coeffs.containsKey(1)).isFalse();
      check(coeffs[2]).equals(IntegerNumber.of(4));

      check(acc.build().toString()).equals('-4 + 4 * x ^ 2');
    });

    test('handles RealNumber promotion, zero scales, and negated Add', () {
      final acc = MonomialAccumulator();
      acc.add(const Variable('x'), IntegerNumber.zero);
      check(acc.terms).isEmpty();

      acc.add(
        Mul([
          IntegerNumber.negativeOne,
          Add([const Variable('x'), IntegerNumber.two]),
        ]),
      );
      acc.add(const Variable('x'), const RealNumber(1.0));
      // x cancels, leaving constant -2 promoted to RealNumber(-2.0)
      final built = acc.build();
      check(built).equals(const RealNumber(-2.0));

      // All terms cancel with RealNumber scale -> RealNumber.zero
      final emptyRealAcc = MonomialAccumulator();
      emptyRealAcc.addDecomposed(const RealNumber(1.5), const Variable('x'));
      emptyRealAcc.addDecomposed(const RealNumber(-1.5), const Variable('x'));
      check(emptyRealAcc.build()).equals(RealNumber.zero);

      // ComplexNumber with RealNumber imaginary component and direct RealNumber constant
      final complexRealAcc = MonomialAccumulator();
      complexRealAcc.add(const RealNumber(2.5));
      complexRealAcc.add(
        IntegerNumber.one,
        ComplexNumber.of(IntegerNumber.one, const RealNumber(1.0)),
      );
      check(complexRealAcc.hasReal).isTrue();
    });

    test('extractPolynomialCoefficients handles multivariate and non-polynomial cases', () {
      final acc = MonomialAccumulator();
      acc.add(Expr.parse('a * x^2 + 2 * b * x^2 + c * x + d + 3 * e'));
      acc.add(Pow(const Variable('x'), const RealNumber(3.0)));
      // Nested Mul inside base
      acc.addDecomposed(
        IntegerNumber.one,
        Mul([
          Mul([const Variable('k'), const Variable('x')]),
          const Variable('x'),
        ]),
      );
      final coeffs = acc.extractPolynomialCoefficients('x');
      check(coeffs).isNotNull();
      check(coeffs![0].toString()).equals('3 * e + d');
      check(coeffs[1].toString()).equals('c');
      check(coeffs[2].toString()).equals('a + 2 * b + k');
      check(coeffs[3]).equals(const RealNumber(1.0));

      // Non-polynomial cases return null
      for (final bad in [
        Expr.parse('sin(x)'),
        Expr.parse('1 / x'),
        Expr.parse('x ^ y'),
        Expr.parse('y * sin(x)'),
        Pow(Sin(const Variable('x')), IntegerNumber.two),
      ]) {
        final badAcc = MonomialAccumulator()..add(bad);
        check(badAcc.extractPolynomialCoefficients('x')).isNull();
      }
    });

    test('collectTerms and negateMonomial preserve structure', () {
      const x = Variable('x');
      const y = Variable('y');

      check(MonomialAccumulator.negateMonomial(IntegerNumber.of(3)))
          .equals(IntegerNumber.of(-3));
      check(
        MonomialAccumulator.negateMonomial(Mul([IntegerNumber.negativeOne, x])),
      ).equals(x);
      check(
        MonomialAccumulator.negateMonomial(
          Mul([IntegerNumber.negativeOne, x, y]),
        ).toString(),
      ).equals('x * y');
      check(
        MonomialAccumulator.negateMonomial(Mul([IntegerNumber.two, x]))
            .toString(),
      ).equals('-2 * x');
      check(MonomialAccumulator.negateMonomial(Mul([x, y])))
          .equals(Mul([IntegerNumber.negativeOne, x, y]));

      final collected = <Expr>[];
      MonomialAccumulator.collectTerms(
        Mul([
          IntegerNumber.negativeOne,
          Add([
            x,
            Mul([
              IntegerNumber.negativeOne,
              Add([y, IntegerNumber.one]),
            ]),
          ]),
        ]),
        collected,
      );
      check(collected.length).equals(3);
    });
  });

  group('Transcendental identity reduction and fraction combination', () {
    test('reduces trigonometric and hyperbolic Pythagorean identities', () {
      // Unequal positive coefficients: 2*sin(x)^2 + 5*cos(x)^2 -> 2 + 3*cos(x)^2
      check(Expr.parse('2 * sin(x)^2 + 5 * cos(x)^2').simplify().toString())
          .equals('2 + 3 * cos(x) ^ 2');
      check(Expr.parse('5 * sin(x)^2 + 2 * cos(x)^2').simplify().toString())
          .equals('2 + 3 * sin(x) ^ 2');

      // 1 - sin(x)^2 -> cos(x)^2 and 1 - cos(x)^2 -> sin(x)^2
      check(Expr.parse('1 - sin(x)^2').simplify().toString())
          .equals('cos(x) ^ 2');
      check(Expr.parse('1 - sin(x)^2 + cos(x)^2').simplify().toString())
          .equals('2 * cos(x) ^ 2');
      check(Expr.parse('1 - cos(x)^2').simplify().toString())
          .equals('sin(x) ^ 2');
      check(Expr.parse('1 - cos(x)^2 + sin(x)^2').simplify().toString())
          .equals('2 * sin(x) ^ 2');

      // Hyperbolic: 3*cosh(x)^2 - 3*sinh(x)^2 -> 3, 1 + sinh(x)^2 -> cosh(x)^2, -1 + cosh(x)^2 -> sinh(x)^2
      check(Expr.parse('3 * cosh(x)^2 - 3 * sinh(x)^2').simplify())
          .equals(IntegerNumber.of(3));
      check(Expr.parse('1 + sinh(x)^2').simplify().toString())
          .equals('cosh(x) ^ 2');
      check(Expr.parse('1 + sinh(x)^2 + cosh(x)^2').simplify().toString())
          .equals('2 * cosh(x) ^ 2');
      check(Expr.parse('-1 + cosh(x)^2').simplify().toString())
          .equals('sinh(x) ^ 2');
      check(Expr.parse('-1 + cosh(x)^2 + sinh(x)^2').simplify().toString())
          .equals('2 * sinh(x) ^ 2');
    });

    test(
      'reduces logarithm sums and differences and guards negative ratios',
      () {
        check(Expr.parse('ln(x) + ln(y)').simplify().toString())
            .equals('ln(x * y)');
        check(Expr.parse('-ln(x) - ln(y)').simplify().toString())
            .equals('ln(1 / (x * y))');
        check(Expr.parse('ln(x) - ln(y)').simplify().toString())
            .equals('ln(x / y)');

        // When num/den simplifies to a negative ratio (scalar or Mul), logs are not merged
        final negRatioLogs1 =
            (Ln(const Variable('x')) -
                    Ln(IntegerNumber.of(-2) * const Variable('x')))
                .simplify();
        check(negRatioLogs1).isA<Add>();

        final negRatioLogs2 =
            (Ln(const Variable('x')) -
                    Ln(IntegerNumber.of(-2) * const Variable('y')))
                .simplify();
        check(negRatioLogs2).isA<Add>();
      },
    );

    test('combines fractions with common denominators', () {
      check(Expr.parse('1 / (x + 1) + x / (x + 1)').simplify())
          .equals(IntegerNumber.one);
      check(Expr.parse('-1 / (x + 1) - x / (x + 1)').simplify())
          .equals(IntegerNumber.negativeOne);
      check(
        Expr.parse('2 / (x + 1)^2 + 3 * y / (x + 1)^2').simplify().toString(),
      ).equals('(2 + 3 * y) / (1 + x) ^ 2');
      check(
        Expr.parse('a * b / (x * y) + c * d / (x * y)').simplify().toString(),
      ).equals('(a * b + c * d) / (x * y)');
      check(Expr.parse('x / (y + 1)^2 - x / (y + 1)^2').simplify())
          .equals(IntegerNumber.zero);
    });
  });

  group('OrderTerm absorption and term decomposition helpers', () {
    test('absorbs polynomial and shifted terms into OrderTerm', () {
      check(
        (Expr.parse('1 + x + x^2 + x^3') + const OrderTerm('x', 2))
            .simplify()
            .toString(),
      ).equals('1 + x + O(x^2)');
      check((IntegerNumber.of(5) + const OrderTerm('x', 0)).simplify())
          .equals(const OrderTerm('x', 0));

      // Shifted OrderTerm around point = 1
      const shiftedOrd = OrderTerm('x', 2, point: IntegerNumber.one);
      final shiftedSum = Add([
        IntegerNumber.one,
        const Variable('x') - IntegerNumber.one,
        Pow(const Variable('x') - IntegerNumber.one, IntegerNumber.two),
        Mul([
          const Variable('y'),
          Pow(const Variable('x') - IntegerNumber.one, IntegerNumber.of(3)),
        ]),
        shiftedOrd,
      ]).simplify();
      check(shiftedSum.toString()).equals('x + O((x - 1)^2)');

      final zeroShifted = Add([
        IntegerNumber.of(5),
        Mul([const Variable('y'), const Variable('x') - IntegerNumber.one]),
        const OrderTerm('x', 0, point: IntegerNumber.one),
      ]).simplify();
      check(zeroShifted)
          .equals(const OrderTerm('x', 0, point: IntegerNumber.one));

      // Multiple distinct OrderTerms are sorted deterministically
      final multiOrd = Add([
        const OrderTerm('y', 2),
        const OrderTerm('x', 2, point: IntegerNumber.one),
        const OrderTerm('x', 2),
      ]).simplify();
      check(multiOrd.toString()).equals('O(x^2) + O((x - 1)^2) + O(y^2)');
    });

    test('decomposeTerm and splitNumeratorDenominator handle all cases', () {
      const x = Variable('x');
      const y = Variable('y');
      const z = Variable('z');

      check(decomposeTerm(IntegerNumber.of(5)))
          .equals((IntegerNumber.of(5), IntegerNumber.one));
      check(decomposeTerm(Mul([IntegerNumber.two, IntegerNumber.of(3)])))
          .equals((IntegerNumber.of(6), IntegerNumber.one));
      final (coeff1, _) = decomposeTerm(
        Mul([
          IntegerNumber.two,
          Mul([IntegerNumber.of(3), x, y]),
        ]),
      );
      check(coeff1).equals(IntegerNumber.of(6));

      check(splitNumeratorDenominator(RationalNumber(3, 4)))
          .equals((IntegerNumber.of(3), IntegerNumber.of(4)));
      check(splitNumeratorDenominator(Pow(x, IntegerNumber.negativeOne)))
          .equals((IntegerNumber.one, x));
      check(splitNumeratorDenominator(Pow(x, IntegerNumber.of(-2))))
          .equals((IntegerNumber.one, Pow(x, IntegerNumber.two)));
      final (num1, _) = splitNumeratorDenominator(
        Mul([
          FractionNumber.half,
          Pow(x, IntegerNumber.negativeOne),
          Pow(y, IntegerNumber.of(-2)),
        ]),
      );
      check(num1).equals(IntegerNumber.one);
      final (num2, _) = splitNumeratorDenominator(
        Mul([RationalNumber(3, 4), x, y, Pow(z, IntegerNumber.negativeOne)]),
      );
      check(num2.toString()).equals('3 * x * y');
      check(
        splitNumeratorDenominator(Mul([x, Pow(y, IntegerNumber.negativeOne)])),
      ).equals((x, y));
      check(splitNumeratorDenominator(Mul([x, y])))
          .equals((Mul([x, y]), IntegerNumber.one));
      check(splitNumeratorDenominator(x)).equals((x, IntegerNumber.one));
    });
  });
}
