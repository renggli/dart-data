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
        const p = Variable('p');

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
        Assumptions.run(() {
          check(simplifyAbs(Pow(p, x))).equals(Pow(p, x));
          check(simplifyAbs(Mul([Constant.pi, p])))
              .equals(Mul([Constant.pi, p]));
        }, domains: {'p': VariableDomain.positive});
        check(simplifyAbs(Pow(x, IntegerNumber.two)))
            .equals(Pow(x, IntegerNumber.two));
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

      // Derivative and Limit AST simplification
      check(simplifyDerivative(IntegerNumber.of(5), 'x'))
          .equals(IntegerNumber.zero);
      check(simplifyDerivative(Derivative(x, 'x'), 'x'))
          .equals(Derivative(x, 'x', order: 2, isSimplified: true));
      check(
        simplifyDerivative(Sin(x), 'x'),
      ).equals(Derivative(Sin(x, isSimplified: true), 'x', isSimplified: true));
      check(simplifyLimit(IntegerNumber.of(5), 'x', IntegerNumber.zero))
          .equals(IntegerNumber.of(5));
      check(simplifyLimit(Sin(x), 'x', IntegerNumber.zero)).equals(
        Limit(
          Sin(x, isSimplified: true),
          'x',
          IntegerNumber.zero,
          isSimplified: true,
        ),
      );

      // Factorial and Binomial
      check(simplifyFactorial(FractionNumber.negativeHalf).toString())
          .equals('sqrt(pi)');
      check(simplifyBinomial(IntegerNumber.of(5), IntegerNumber.of(-2)))
          .equals(IntegerNumber.zero);
      check(simplifyBinomial(IntegerNumber.of(3), IntegerNumber.of(5)))
          .equals(IntegerNumber.zero);

      // Floor, Ceil, Round, Sign, Mod on RealNumber and constant expressions
      check(simplifyFloor(const RealNumber(3.7))).equals(const RealNumber(3.0));
      check(simplifyFloor(Constant.pi)).equals(IntegerNumber.of(3));
      check(simplifyCeil(const RealNumber(3.2))).equals(const RealNumber(4.0));
      check(simplifyCeil(Constant.pi)).equals(IntegerNumber.of(4));
      check(simplifyRound(const RealNumber(3.6))).equals(const RealNumber(4.0));
      check(simplifyRound(Constant.pi)).equals(IntegerNumber.of(3));
      check(simplifySign(Mul([IntegerNumber.negativeOne, x]))).equals(
        Mul([
          IntegerNumber.negativeOne,
          Sign(x, isSimplified: true),
        ], isSimplified: true),
      );
      check(simplifySign(Constant.pi)).equals(IntegerNumber.one);
      check(simplifyMod(IntegerNumber.of(5), IntegerNumber.zero))
          .equals(Constant.undefined);
      check(simplifyMod(IntegerNumber.zero, IntegerNumber.of(5)))
          .equals(IntegerNumber.zero);
      check(simplifyMod(IntegerNumber.of(5), IntegerNumber.one))
          .equals(IntegerNumber.zero);
      check(simplifyMod(const RealNumber(7.5), const RealNumber(2.0)))
          .equals(const RealNumber(1.5));

      // Complex functions: Re, Im, Arg, Conjugate, toRectangular, toPolar
      const z = Variable('z');
      Assumptions.run(() {
        check(simplifyRe(Add([z, IntegerNumber.two])).toString())
            .equals('2 + re(z)');
        check(simplifyIm(Add([z, ComplexNumber.i])).toString())
            .equals('1 + im(z)');
        check(
          simplifyArg(
            ComplexNumber.of(IntegerNumber.of(-1), IntegerNumber.of(-1)),
          ).toString(),
        ).equals('-3/4 * pi');
        check(
          simplifyArg(
            ComplexNumber.of(IntegerNumber.of(1), IntegerNumber.of(-1)),
          ).toString(),
        ).equals('-1/4 * pi');
        check(
          simplifyArg(
            ComplexNumber.of(IntegerNumber.of(-1), IntegerNumber.of(1)),
          ).toString(),
        ).equals('3/4 * pi');
        check(
          simplifyArg(
            ComplexNumber.of(IntegerNumber.of(-3), IntegerNumber.of(-4)),
          ).toString(),
        ).equals('atan(4/3) - pi');
        check(
          simplifyArg(
            ComplexNumber.of(IntegerNumber.of(-3), IntegerNumber.of(4)),
          ).toString(),
        ).equals('-atan(4/3) + pi');
        check(simplifyArg(Conjugate(z)).toString()).equals('-arg(z)');
        check(simplifyArg(Pow(x, IntegerNumber.two)))
            .equals(IntegerNumber.zero);
        check(simplifyArg(z)).equals(Arg(z, isSimplified: true));

        check(simplifyConjugate(Add([z, IntegerNumber.one])).toString())
            .equals('1 + conj(z)');
        check(simplifyConjugate(Mul([z, IntegerNumber.two])).toString())
            .equals('2 * conj(z)');
        check(simplifyConjugate(Pow(Constant.e, z)).toString())
            .equals('exp(conj(z))');
        check(simplifyConjugate(Pow(z, IntegerNumber.two)).toString())
            .equals('conj(z) ^ 2');
        check(simplifyConjugate(Sin(z)).toString()).equals('sin(conj(z))');
        check(simplifyConjugate(Cos(z)).toString()).equals('cos(conj(z))');
        check(simplifyConjugate(Tan(z)).toString()).equals('tan(conj(z))');
        check(simplifyConjugate(Sinh(z)).toString()).equals('sinh(conj(z))');
        check(simplifyConjugate(Cosh(z)).toString()).equals('cosh(conj(z))');
        check(simplifyConjugate(Tanh(z)).toString()).equals('tanh(conj(z))');

        check(toRectangularExpr(Sin(z)).toString())
            .equals('sin(re(z)) * cosh(im(z)) + i * cos(re(z)) * sinh(im(z))');
        check(toRectangularExpr(Cos(z)).toString())
            .equals('cos(re(z)) * cosh(im(z)) - i * sin(re(z)) * sinh(im(z))');
        check(toRectangularExpr(Sinh(z)).toString())
            .equals('cos(im(z)) * sinh(re(z)) + i * sin(im(z)) * cosh(re(z))');
        check(toRectangularExpr(Cosh(z)).toString())
            .equals('cos(im(z)) * cosh(re(z)) + i * sin(im(z)) * sinh(re(z))');
        check(toRectangularExpr(Tan(z)).toString())
            .equals('re(tan(z)) + i * im(tan(z))');
        check(toRectangularExpr(Re(z))).equals(Re(z, isSimplified: true));
        check(toRectangularExpr(Im(z))).equals(Im(z, isSimplified: true));
      }, domains: {'z': VariableDomain.complex});
    });
  });
}
