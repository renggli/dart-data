import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('PuiseuxSeries algebra', () {
    const x = Variable('x');

    test('computes leadingTerm, valuation, poleOrder, and arithmetic', () {
      final a = Expr.parse('x^(1/2) + x').toPuiseuxSeries('x', order: 2);
      final b = Expr.parse('x^(1/2) - x^(3/2)').toPuiseuxSeries('x', order: 2);

      check(a.valuation).equals(FractionNumber.half);
      check(a.poleOrder).equals(IntegerNumber.zero);
      check((a + b).toExpr(includeOrder: false))
          .equals(Expr.parse('2*sqrt(x) + x - x^(3/2)').simplify());
      check((a * b).toExpr(includeOrder: false))
          .equals(Expr.parse('x + x^(3/2) - x^2').simplify());
    });

    test('computes reciprocals, divisions, derivatives, and integrals', () {
      final s = Expr.parse('x^(1/2) + x^(3/2)').toPuiseuxSeries('x', order: 3);
      final inv = s.reciprocal();

      check(inv.valuation).equals(RationalNumber(-1, 2));
      check(inv.poleOrder).equals(FractionNumber.half);
      check(inv.coefficients[RationalNumber(-1, 2)]).equals(IntegerNumber.one);
      check(inv.coefficients[FractionNumber.half])
          .equals(IntegerNumber.negativeOne);

      final deriv = s.derivative();
      check(deriv.coefficients[RationalNumber(-1, 2)])
          .equals(FractionNumber.half);
      final integ = deriv.integrate();
      check(integ.coefficients[FractionNumber.half]).equals(IntegerNumber.one);

      final zero = PuiseuxSeries(
        'x',
        IntegerNumber.zero,
        const {},
        IntegerNumber.of(2),
      );
      check(() => zero.valuation).throws<StateError>();
      check(zero.reciprocal).throws<UnsupportedError>();
      check(
        () =>
            (IntegerNumber.one / x).toPuiseuxSeries('x', order: 2).integrate(),
      ).throws<UnsupportedError>();
    });
  });

  group('PuiseuxSeries expansion', () {
    test('expands fractional powers of analytic functions', () {
      final sqrtSin = Expr.parse('sqrt(sin(x))').toPuiseuxSeries('x', order: 3);
      check(sqrtSin.coefficients[FractionNumber.half])
          .equals(IntegerNumber.one);
      check(sqrtSin.coefficients[RationalNumber(5, 2)])
          .equals(RationalNumber(-1, 12));

      final invSqrtSin = Expr.parse('sin(x)^(-1/2)')
          .toPuiseuxSeries('x', order: 2);
      check(invSqrtSin.coefficients[RationalNumber(-1, 2)])
          .equals(IntegerNumber.one);
      check(invSqrtSin.coefficients[RationalNumber(3, 2)])
          .equals(RationalNumber(1, 12));
    });

    test('expands transcendental compositions with fractional series', () {
      final sinSqrt = Expr.parse('sin(sqrt(x))').toPuiseuxSeries('x', order: 2);
      check(sinSqrt.coefficients[FractionNumber.half])
          .equals(IntegerNumber.one);
      check(sinSqrt.coefficients[RationalNumber(3, 2)])
          .equals(RationalNumber(-1, 6));

      final expSqrt = Expr.parse('exp(sqrt(x))').toPuiseuxSeries('x', order: 2);
      check(expSqrt.coefficients[IntegerNumber.zero]).equals(IntegerNumber.one);
      check(expSqrt.coefficients[FractionNumber.half])
          .equals(IntegerNumber.one);
      check(expSqrt.coefficients[IntegerNumber.one])
          .equals(FractionNumber.half);
      check(expSqrt.coefficients[RationalNumber(3, 2)])
          .equals(RationalNumber(1, 6));

      final lnOnePlusSqrt = Expr.parse('ln(1 + sqrt(x))')
          .toPuiseuxSeries('x', order: 2);
      check(lnOnePlusSqrt.coefficients[FractionNumber.half])
          .equals(IntegerNumber.one);
      check(lnOnePlusSqrt.coefficients[IntegerNumber.one])
          .equals(RationalNumber(-1, 2));
      check(lnOnePlusSqrt.coefficients[RationalNumber(3, 2)])
          .equals(RationalNumber(1, 3));
    });

    test('handles variable fractional powers and rational cancellations', () {
      final varPow = Expr.parse('(1 + sqrt(x))^(1 / sqrt(x))')
          .toPuiseuxSeries('x', order: 1);
      check(varPow.coefficients[IntegerNumber.zero]).equals(Constant.e);
      check(varPow.coefficients[FractionNumber.half])
          .equals(-(Constant.e * FractionNumber.half).simplify());
    });
  });

  group('PuiseuxSeries limit integration', () {
    test('resolves fractional branch-point limits cleanly', () {
      check(
        Expr.parse('(sqrt(x + x^2) - sqrt(x)) / x^(3/2)')
            .limit('x', 0, direction: LimitDirection.fromAbove),
      ).equals(FractionNumber.half);

      check(
        Expr.parse('sin(sqrt(x)) / sqrt(x)')
            .limit('x', 0, direction: LimitDirection.fromAbove),
      ).equals(IntegerNumber.one);

      check(
        Expr.parse('(1 + sqrt(x))^(1 / sqrt(x))')
            .limit('x', 0, direction: LimitDirection.fromAbove),
      ).equals(Constant.e);

      check(
        Expr.parse('1 / sqrt(x)')
            .limit('x', 0, direction: LimitDirection.fromAbove),
      ).equals(Constant.infinity);
    });
  });
}
