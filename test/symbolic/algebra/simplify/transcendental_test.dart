import 'package:checks/checks.dart';
import 'package:data/src/symbolic/algebra/simplify/transcendental.dart';
import 'package:data/symbolic.dart';
import 'package:test/test.dart';

void main() {
  group('Trigonometric and inverse trigonometric simplification', () {
    test(
      'simplifies sin, cos, and tan parity, involutions, and pi multiples',
      () {
        const x = Variable('x');
        check(simplifySin(Asin(x))).equals(x);
        check(simplifyCos(Acos(x))).equals(x);
        check(simplifyTan(Atan(x))).equals(x);

        check(simplifySin(Mul([IntegerNumber.of(-2), x])).toString())
            .equals('-sin(2 * x)');
        check(simplifyCos(Mul([IntegerNumber.of(-2), x])).toString())
            .equals('cos(2 * x)');
        check(simplifyTan(Mul([IntegerNumber.of(-2), x])).toString())
            .equals('-tan(2 * x)');

        // matchPiMultiple with pi * (1/2) and pi * 2^(-1)
        check(simplifySin(Mul([Constant.pi, FractionNumber.half])))
            .equals(IntegerNumber.one);
        check(
          simplifySin(
            Mul([
              Constant.pi,
              Pow(IntegerNumber.two, IntegerNumber.negativeOne),
            ]),
          ),
        ).equals(IntegerNumber.one);
        check(simplifySin(Mul([RationalNumber(3, 2), Constant.pi])))
            .equals(IntegerNumber.negativeOne);

        check(simplifyTan(Constant.pi)).equals(IntegerNumber.zero);
        check(simplifyTan(Mul([RationalNumber(3, 4), Constant.pi])))
            .equals(IntegerNumber.negativeOne);
        check(simplifyTan(x)).equals(Tan(x, isSimplified: true));
      },
    );

    test('simplifies asin, acos, and atan boundary values, involutions, and parity', () {
      const x = Variable('x');
      check(simplifyAsin(IntegerNumber.zero)).equals(IntegerNumber.zero);
      check(simplifyAsin(IntegerNumber.one).toString()).equals('1/2 * pi');
      check(simplifyAsin(IntegerNumber.negativeOne).toString())
          .equals('-1/2 * pi');
      check(simplifyAsin(Sin(x))).equals(x);
      check(simplifyAsin(Mul([IntegerNumber.negativeOne, x])).toString())
          .equals('-asin(x)');
      check(simplifyAsin(x)).equals(Asin(x, isSimplified: true));

      check(simplifyAcos(IntegerNumber.one)).equals(IntegerNumber.zero);
      check(simplifyAcos(IntegerNumber.zero).toString()).equals('1/2 * pi');
      check(simplifyAcos(IntegerNumber.negativeOne)).equals(Constant.pi);
      check(simplifyAcos(Cos(x))).equals(x);
      check(simplifyAcos(x)).equals(Acos(x, isSimplified: true));

      check(simplifyAtan(IntegerNumber.zero)).equals(IntegerNumber.zero);
      check(simplifyAtan(IntegerNumber.one).toString()).equals('1/4 * pi');
      check(simplifyAtan(IntegerNumber.negativeOne).toString())
          .equals('-1/4 * pi');
      check(simplifyAtan(Tan(x))).equals(x);
      check(simplifyAtan(Mul([IntegerNumber.negativeOne, x])).toString())
          .equals('-atan(x)');
      check(simplifyAtan(x)).equals(Atan(x, isSimplified: true));
    });
  });

  group('Hyperbolic, inverse hyperbolic, exponential, and logarithmic simplification', () {
    test('simplifies sinh, cosh, tanh, asinh, acosh, and atanh', () {
      const x = Variable('x');
      check(simplifySinh(Mul([IntegerNumber.negativeOne, x])).toString())
          .equals('-sinh(x)');
      check(simplifyCosh(Mul([IntegerNumber.negativeOne, x])).toString())
          .equals('cosh(x)');
      check(simplifyTanh(Mul([IntegerNumber.negativeOne, x])).toString())
          .equals('-tanh(x)');

      check(simplifyAsinh(Sinh(x))).equals(x);
      check(simplifyAsinh(Mul([IntegerNumber.negativeOne, x])).toString())
          .equals('-asinh(x)');
      check(simplifyAcosh(Cosh(x))).equals(x);
      check(simplifyAcosh(x)).equals(Acosh(x, isSimplified: true));
      check(simplifyAtanh(Tanh(x))).equals(x);
      check(simplifyAtanh(Mul([IntegerNumber.negativeOne, x])).toString())
          .equals('-atanh(x)');
    });

    test(
      'simplifies exp, ln, and abs across domains and non-negative trees',
      () {
        const x = Variable('x');
        const p = Variable('p', domain: VariableDomain.positive);

        check(simplifyExp(IntegerNumber.zero)).equals(IntegerNumber.one);
        check(() => simplifyLn(IntegerNumber.zero)).throws<ArgumentError>();
        check(() => simplifyLn(IntegerNumber.of(-3))).throws<ArgumentError>();
        check(simplifyLn(Pow(x, IntegerNumber.of(3))).toString())
            .equals('3 * ln(x)');

        check(simplifyAbs(IntegerNumber.of(-5))).equals(IntegerNumber.of(5));
        check(simplifyAbs(const RealNumber(-2.5)))
            .equals(const RealNumber(2.5));
        check(simplifyAbs(Mul([IntegerNumber.of(-3), x])).toString())
            .equals('abs(3 * x)');
        check(simplifyAbs(Constant.pi)).equals(Constant.pi);
        check(simplifyAbs(Abs(x))).equals(Abs(x));
        check(simplifyAbs(Pow(Constant.e, x))).equals(Pow(Constant.e, x));
        check(simplifyAbs(Pow(p, x))).equals(Pow(p, x));
        check(simplifyAbs(Pow(x, IntegerNumber.two)))
            .equals(Pow(x, IntegerNumber.two));
        check(simplifyAbs(Mul([Constant.pi, p]))).equals(Mul([Constant.pi, p]));
      },
    );
  });

  group('Special functions, relationals, piecewise, and integrals', () {
    test('simplifies LambertW, Erf, Erfc, Gamma, and Beta', () {
      const x = Variable('x');
      const y = Variable('y');

      check(simplifyLambertW(IntegerNumber.zero, 0)).equals(IntegerNumber.zero);
      check(simplifyLambertW(Constant.e, 0)).equals(IntegerNumber.one);
      check(
        simplifyLambertW(
          Mul([
            IntegerNumber.negativeOne,
            Pow(Constant.e, IntegerNumber.negativeOne, isSimplified: true),
          ]),
          0,
        ),
      ).equals(IntegerNumber.negativeOne);
      check(simplifyLambertW(x, -1))
          .equals(LambertW(x, branch: -1, isSimplified: true));

      check(simplifyErf(Constant.infinity)).equals(IntegerNumber.one);
      check(simplifyErf(Mul([IntegerNumber.negativeOne, Constant.infinity])))
          .equals(IntegerNumber.negativeOne);
      check(simplifyErf(x)).equals(Erf(x, isSimplified: true));

      check(simplifyErfc(Constant.infinity)).equals(IntegerNumber.zero);
      check(simplifyErfc(Mul([IntegerNumber.negativeOne, Constant.infinity])))
          .equals(IntegerNumber.two);
      check(simplifyErfc(x)).equals(Erfc(x, isSimplified: true));

      check(simplifyGamma(FractionNumber.half).toString()).equals('sqrt(pi)');
      check(simplifyGamma(x)).equals(Gamma(x, isSimplified: true));

      // Beta symmetry, integer factorial evaluation, unit argument identities, and general form
      check(simplifyBeta(IntegerNumber.of(3), IntegerNumber.of(4)))
          .equals(RationalNumber(1, 60));
      check(simplifyBeta(y, x)).equals(Beta(x, y, isSimplified: true));
      check(simplifyBeta(IntegerNumber.one, x).toString()).equals('1 / x');
      check(simplifyBeta(FractionNumber.half, IntegerNumber.one))
          .equals(IntegerNumber.two);
    });

    test('simplifies RelationalExpr, Piecewise, and Integral', () {
      const x = Variable('x');
      const y = Variable('y');

      // Numeric and symbolic relationals
      check(LessEqual(IntegerNumber.two, IntegerNumber.two).simplify())
          .equals(IntegerNumber.one);
      check(GreaterThan(IntegerNumber.one, IntegerNumber.two).simplify())
          .equals(IntegerNumber.zero);
      check(GreaterEqual(IntegerNumber.two, IntegerNumber.one).simplify())
          .equals(IntegerNumber.one);
      check(Equal(IntegerNumber.two, IntegerNumber.two).simplify())
          .equals(IntegerNumber.one);

      check(LessEqual(x, y).simplify())
          .equals(LessEqual(x, y, isSimplified: true));
      check(GreaterThan(x, y).simplify())
          .equals(GreaterThan(x, y, isSimplified: true));
      check(GreaterEqual(x, y).simplify())
          .equals(GreaterEqual(x, y, isSimplified: true));
      check(Equal(x, y).simplify()).equals(Equal(x, y, isSimplified: true));

      // Piecewise: false branch skipped, true branch after symbolic branch becomes otherwise
      final pwTruncated = Piecewise([
        (
          relation: LessThan(IntegerNumber.two, IntegerNumber.one),
          expr: IntegerNumber.zero,
        ),
        (relation: LessThan(x, IntegerNumber.zero), expr: x),
        (relation: LessThan(IntegerNumber.one, IntegerNumber.two), expr: y),
      ]).simplify();
      check(pwTruncated).equals(
        Piecewise(
          [
            (
              relation: LessThan(x, IntegerNumber.zero, isSimplified: true),
              expr: x,
            ),
          ],
          otherwise: y,
          isSimplified: true,
        ),
      );

      // Piecewise with all false branches falls back to otherwise or 0
      final pwAllFalse = Piecewise([
        (relation: LessThan(IntegerNumber.two, IntegerNumber.one), expr: x),
      ], otherwise: y).simplify();
      check(pwAllFalse).equals(y);

      final pwAllFalseNoOther = Piecewise([
        (relation: LessThan(IntegerNumber.two, IntegerNumber.one), expr: x),
      ]).simplify();
      check(pwAllFalseNoOther).equals(IntegerNumber.zero);

      // Integral: equal bounds -> 0, general integral simplified
      check(
        Integral(
          x,
          'x',
          lower: IntegerNumber.one,
          upper: IntegerNumber.one,
        ).simplify(),
      ).equals(IntegerNumber.zero);
      check(Integral(Add([x, IntegerNumber.zero]), 'x').simplify())
          .equals(Integral(x, 'x', isSimplified: true));
    });
  });
}
