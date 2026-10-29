import 'package:checks/checks.dart';
import 'package:data/src/symbolic/algebra/simplify/additive.dart';
import 'package:data/src/symbolic/algebra/simplify/transcendental.dart';
import 'package:data/src/symbolic/algebra/structural_order.dart';
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
      check(simplifyAsin(Sin(x))).equals(Asin(Sin(x), isSimplified: true));
      check(simplifyAsin(Mul([IntegerNumber.negativeOne, x])).toString())
          .equals('-asin(x)');
      check(simplifyAsin(x)).equals(Asin(x, isSimplified: true));

      check(simplifyAcos(IntegerNumber.one)).equals(IntegerNumber.zero);
      check(simplifyAcos(IntegerNumber.zero).toString()).equals('1/2 * pi');
      check(simplifyAcos(IntegerNumber.negativeOne)).equals(Constant.pi);
      check(simplifyAcos(Cos(x))).equals(Acos(Cos(x), isSimplified: true));
      check(simplifyAcos(x)).equals(Acos(x, isSimplified: true));

      check(simplifyAtan(IntegerNumber.zero)).equals(IntegerNumber.zero);
      check(simplifyAtan(IntegerNumber.one).toString()).equals('1/4 * pi');
      check(simplifyAtan(IntegerNumber.negativeOne).toString())
          .equals('-1/4 * pi');
      check(simplifyAtan(Tan(x))).equals(Atan(Tan(x), isSimplified: true));
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

      check(simplifyAsinh(Sinh(x))).equals(Asinh(Sinh(x), isSimplified: true));
      check(simplifyAsinh(Sinh(x), assumptions: Assumptions.real)).equals(x);
      check(simplifyAsinh(Mul([IntegerNumber.negativeOne, x])).toString())
          .equals('-asinh(x)');
      check(simplifyAcosh(Cosh(x))).equals(Acosh(Cosh(x), isSimplified: true));
      check(simplifyAcosh(Cosh(x), assumptions: Assumptions.real))
          .equals(Abs(x, isSimplified: true));
      check(simplifyAcosh(Cosh(x), assumptions: Assumptions.positive))
          .equals(x);
      check(simplifyAcosh(x)).equals(Acosh(x, isSimplified: true));
      check(simplifyAtanh(Tanh(x))).equals(Atanh(Tanh(x), isSimplified: true));
      check(simplifyAtanh(Tanh(x), assumptions: Assumptions.real)).equals(x);
      check(simplifyAtanh(Mul([IntegerNumber.negativeOne, x])).toString())
          .equals('-atanh(x)');
    });

    test(
      'simplifies exp, ln, and abs across domains and non-negative trees',
      () {
        const x = Variable('x');
        const p = Variable('p');

        check(simplifyExp(IntegerNumber.zero)).equals(IntegerNumber.one);
        check(simplifyLn(IntegerNumber.zero)).equals(-Constant.infinity);
        check(simplifyLn(IntegerNumber.negativeOne))
            .equals(Mul([ComplexNumber.i, Constant.pi]));
        check(simplifyLn(IntegerNumber.of(-3))).equals(
          simplifyAdd([
            simplifyLn(IntegerNumber.of(3)),
            Mul([ComplexNumber.i, Constant.pi]),
          ]),
        );
        check(simplifyLn(Pow(x, IntegerNumber.of(3))).toString())
            .equals('ln(x ^ 3)');
        check(
          simplifyLn(
            Pow(x, IntegerNumber.of(3)),
            assumptions: Assumptions.positive,
          ).toString(),
        ).equals('3 * ln(x)');
        check(simplifyLn(Pow(x, IntegerNumber.negativeOne)).toString())
            .equals('ln(1 / x)');
        check(
          simplifyLn(
            Pow(x, IntegerNumber.negativeOne),
            assumptions: Assumptions.positive,
          ).toString(),
        ).equals('-ln(x)');
        check(simplifyLn(Pow(Constant.e, x)).toString()).equals('ln(exp(x))');
        check(simplifyLn(Pow(Constant.e, x), assumptions: Assumptions.real))
            .equals(x);

        check(simplifyAbs(IntegerNumber.of(-5))).equals(IntegerNumber.of(5));
        check(simplifyAbs(const RealNumber(-2.5)))
            .equals(const RealNumber(2.5));
        check(simplifyAbs(Mul([IntegerNumber.of(-3), x])).toString())
            .equals('3 * abs(x)');
        check(Expr.parse('abs(x * y)').simplify().toString())
            .equals('abs(x) * abs(y)');
        check(Expr.parse('log(8, 2)').simplify().toString()).equals('1/3');
        check(Expr.parse('ln(8) - 3 * ln(2)').simplify().toString())
            .equals('0');
        check(simplifyAbs(Constant.pi)).equals(Constant.pi);
        check(simplifyAbs(Abs(x))).equals(Abs(x));
        check(simplifyAbs(Pow(Constant.e, x), assumptions: Assumptions.real))
            .equals(Pow(Constant.e, x));
        const posP = Assumptions(
          domains: {'p': VariableDomain.positive, 'x': VariableDomain.real},
        );
        check(simplifyAbs(Pow(p, x), assumptions: posP)).equals(Pow(p, x));
        check(simplifyAbs(Mul([Constant.pi, p]), assumptions: posP))
            .equals(Mul([Constant.pi, p]));
        check(
          simplifyAbs(Pow(x, IntegerNumber.two), assumptions: Assumptions.real),
        ).equals(Pow(x, IntegerNumber.two));
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
      const complexZ = Assumptions(domains: {'z': VariableDomain.complex});
      check(
        simplifyRe(
          Add([z, IntegerNumber.two]),
          assumptions: complexZ,
        ).toString(),
      ).equals('2 + re(z)');
      check(
        simplifyIm(Add([z, ComplexNumber.i]), assumptions: complexZ).toString(),
      ).equals('1 + im(z)');
      check(
        simplifyArg(
          ComplexNumber.of(IntegerNumber.of(-1), IntegerNumber.of(-1)),
          assumptions: complexZ,
        ).toString(),
      ).equals('-3/4 * pi');
      check(
        simplifyArg(
          ComplexNumber.of(IntegerNumber.of(1), IntegerNumber.of(-1)),
          assumptions: complexZ,
        ).toString(),
      ).equals('-1/4 * pi');
      check(
        simplifyArg(
          ComplexNumber.of(IntegerNumber.of(-1), IntegerNumber.of(1)),
          assumptions: complexZ,
        ).toString(),
      ).equals('3/4 * pi');
      check(
        simplifyArg(
          ComplexNumber.of(IntegerNumber.of(-3), IntegerNumber.of(-4)),
          assumptions: complexZ,
        ).toString(),
      ).equals('atan(4/3) - pi');
      check(
        simplifyArg(
          ComplexNumber.of(IntegerNumber.of(-3), IntegerNumber.of(4)),
          assumptions: complexZ,
        ).toString(),
      ).equals('-atan(4/3) + pi');
      check(simplifyArg(Conjugate(z), assumptions: complexZ))
          .equals(Arg(Conjugate(z), isSimplified: true));
      check(
        simplifyArg(
          Conjugate(z),
          assumptions: const Assumptions(
            domains: {'z': VariableDomain.positive},
          ),
        ),
      ).equals(IntegerNumber.zero);
      check(
        simplifyArg(Pow(x, IntegerNumber.two), assumptions: Assumptions.real),
      ).equals(IntegerNumber.zero);
      check(simplifyArg(z, assumptions: complexZ))
          .equals(Arg(z, isSimplified: true));

      check(
        simplifyConjugate(
          Add([z, IntegerNumber.one]),
          assumptions: complexZ,
        ).toString(),
      ).equals('1 + conj(z)');
      check(
        simplifyConjugate(
          Mul([z, IntegerNumber.two]),
          assumptions: complexZ,
        ).toString(),
      ).equals('2 * conj(z)');
      check(
        simplifyConjugate(Pow(Constant.e, z), assumptions: complexZ).toString(),
      ).equals('exp(conj(z))');
      check(
        simplifyConjugate(
          Pow(z, IntegerNumber.two),
          assumptions: complexZ,
        ).toString(),
      ).equals('conj(z) ^ 2');
      check(simplifyConjugate(Sin(z), assumptions: complexZ).toString())
          .equals('sin(conj(z))');
      check(simplifyConjugate(Cos(z), assumptions: complexZ).toString())
          .equals('cos(conj(z))');
      check(simplifyConjugate(Tan(z), assumptions: complexZ).toString())
          .equals('tan(conj(z))');
      check(simplifyConjugate(Sinh(z), assumptions: complexZ).toString())
          .equals('sinh(conj(z))');
      check(simplifyConjugate(Cosh(z), assumptions: complexZ).toString())
          .equals('cosh(conj(z))');
      check(simplifyConjugate(Tanh(z), assumptions: complexZ).toString())
          .equals('tanh(conj(z))');

      check(toRectangularExpr(Sin(z), assumptions: complexZ).toString())
          .equals('sin(re(z)) * cosh(im(z)) + i * cos(re(z)) * sinh(im(z))');
      check(toRectangularExpr(Cos(z), assumptions: complexZ).toString())
          .equals('cos(re(z)) * cosh(im(z)) - i * sin(re(z)) * sinh(im(z))');
      check(toRectangularExpr(Sinh(z), assumptions: complexZ).toString())
          .equals('cos(im(z)) * sinh(re(z)) + i * sin(im(z)) * cosh(re(z))');
      check(toRectangularExpr(Cosh(z), assumptions: complexZ).toString())
          .equals('cos(im(z)) * cosh(re(z)) + i * sin(im(z)) * sinh(re(z))');
      check(toRectangularExpr(Tan(z), assumptions: complexZ).toString())
          .equals('re(tan(z)) + i * im(tan(z))');
      check(toRectangularExpr(Re(z), assumptions: complexZ))
          .equals(Re(z, isSimplified: true));
      check(toRectangularExpr(Im(z), assumptions: complexZ))
          .equals(Im(z, isSimplified: true));
    });

    test('complex decomposition and syntactic real simplification', () {
      const realAssumptions = Assumptions(
        domains: {'x': VariableDomain.real, 'y': VariableDomain.real},
      );
      const x = Variable('x');
      const y = Variable('y');
      const w = Variable('w');

      const complexW = Assumptions(domains: {'w': VariableDomain.complex});
      // Complex variable without decomposition returns Re(w) and Im(w)
      check(simplifyRe(w, assumptions: complexW))
          .equals(Re(w, isSimplified: true));
      check(simplifyIm(w, assumptions: complexW))
          .equals(Im(w, isSimplified: true));

      // Syntactically real expressions: Tanh, Asinh, Erf, Erfc, Gamma, Ln, Binomial, Beta, Mod
      check(simplifyIm(Tanh(x), assumptions: realAssumptions))
          .equals(IntegerNumber.zero);
      check(simplifyIm(Asinh(x), assumptions: realAssumptions))
          .equals(IntegerNumber.zero);
      check(simplifyIm(Erf(x), assumptions: realAssumptions))
          .equals(IntegerNumber.zero);
      check(simplifyIm(Erfc(x), assumptions: realAssumptions))
          .equals(IntegerNumber.zero);
      check(simplifyIm(Gamma(x), assumptions: realAssumptions))
          .equals(IntegerNumber.zero);
      check(simplifyIm(Binomial(x, y), assumptions: realAssumptions))
          .equals(IntegerNumber.zero);
      check(simplifyIm(Beta(x, y), assumptions: realAssumptions))
          .equals(IntegerNumber.zero);
      check(simplifyIm(Mod(x, y), assumptions: realAssumptions))
          .equals(IntegerNumber.zero);

      // Decompose Conjugate, Re, Im via toRectangularExpr
      final expr = Add([
        x,
        Mul([ComplexNumber.i, y]),
      ]);
      check(
        toRectangularExpr(
          Conjugate(expr),
          assumptions: realAssumptions,
        ).toString(),
      ).equals('x - i * y');
      check(toRectangularExpr(Re(expr), assumptions: realAssumptions))
          .equals(x);
      check(toRectangularExpr(Im(expr), assumptions: realAssumptions))
          .equals(y);

      // NotEqual simplification
      check(Expr.parse('1 != 2').simplify()).equals(IntegerNumber.one);
      check(Expr.parse('2 != 2').simplify()).equals(IntegerNumber.zero);

      // Polar and rectangular decompositions for unconstrained and constant expressions
      const z = Variable('z');
      const complexZ = Assumptions(domains: {'z': VariableDomain.complex});
      final polarZ = toPolarExpr(z, assumptions: complexZ);
      check(polarZ is Mul).isTrue();

      final rectC = toRectangularExpr(Constant.pi);
      check(rectC).equals(Constant.pi);
      check(toRectangularExpr(Conjugate(z), assumptions: complexZ).toString())
          .equals('re(z) - i * im(z)');
      check(toRectangularExpr(Re(z), assumptions: complexZ))
          .equals(Re(z, isSimplified: true));
      check(toRectangularExpr(Im(z), assumptions: complexZ))
          .equals(Im(z, isSimplified: true));

      // Abs of exp with complex exponent: |exp(3 + 4i)| = exp(3)
      final expComp = Pow(
        Constant.e,
        Add([
          IntegerNumber.of(3),
          Mul([ComplexNumber.i, IntegerNumber.of(4)]),
        ]),
      );
      check(simplifyAbs(expComp))
          .equals(Pow(Constant.e, IntegerNumber.of(3), isSimplified: true));

      // isEvenIntegerExpr on Add and Pow
      check(isEvenIntegerExpr(Add([IntegerNumber.of(2), IntegerNumber.of(4)])))
          .isTrue();
      check(isEvenIntegerExpr(Pow(IntegerNumber.of(2), IntegerNumber.of(3))))
          .isTrue();

      // isIntegerExpr guards non-integer Factorial, Binomial, and complex Sign
      check(isIntegerExpr(Factorial(FractionNumber.half))).isFalse();
      check(isIntegerExpr(Binomial(FractionNumber.half, IntegerNumber.two)))
          .isFalse();
      check(isIntegerExpr(Sign(z), assumptions: complexZ)).isFalse();
      check(isIntegerExpr(Sign(x), assumptions: realAssumptions)).isTrue();
      check(Floor(Factorial(x)).simplify()).isA<Floor>();

      // RealNumber contagion in Mod, Re, Im, Arg, and toPolarExpr
      check(simplifyMod(const RealNumber(0.0), IntegerNumber.of(3)))
          .equals(const RealNumber(0.0));
      check(simplifyRe(const ComplexNumber(IntegerNumber.two, RealNumber(1.0))))
          .equals(const RealNumber(2.0));
      check(simplifyIm(const RealNumber(3.5))).equals(const RealNumber(0.0));
      check(simplifyArg(const RealNumber(-2.0))).isA<RealNumber>();
      check(toPolarExpr(const RealNumber(0.0))).equals(const RealNumber(0.0));

      // Exact quadrant multiples of pi/6, pi/4, pi/3, pi/2 across sin, cos, tan
      for (final numVal in [1, 2, 3, 4, 5, 7, 11]) {
        for (final denVal in [2, 3, 4, 6]) {
          final angle = Mul([
            RationalNumber.of(Integer(numVal), Integer(denVal)),
            Constant.pi,
          ]);
          check(simplifySin(angle).evaluate())
              .isCloseTo(Sin(angle).evaluate(), 1e-12);
          check(simplifyCos(angle).evaluate())
              .isCloseTo(Cos(angle).evaluate(), 1e-12);
          if ((numVal * 12 ~/ denVal) % 12 != 6) {
            check(simplifyTan(angle).evaluate())
                .isCloseTo(Tan(angle).evaluate(), 1e-12);
          } else {
            check(simplifyTan(angle)).equals(Constant.undefined);
          }
        }
      }

      // Complex decomposition of Sin, Cos, Sinh, Cosh, Pow
      final cArg = Add([
        x,
        Mul([ComplexNumber.i, y]),
      ]);
      check(toRectangularExpr(Sin(cArg), assumptions: realAssumptions))
          .isA<Add>();
      check(toRectangularExpr(Cos(cArg), assumptions: realAssumptions))
          .isA<Add>();
      check(toRectangularExpr(Sinh(cArg), assumptions: realAssumptions))
          .isA<Add>();
      check(toRectangularExpr(Cosh(cArg), assumptions: realAssumptions))
          .isA<Add>();
      check(
        toRectangularExpr(
          Pow(cArg, IntegerNumber.two),
          assumptions: realAssumptions,
        ),
      ).isA<Add>();

      // RealNumber branches across special functions, rounding, and sign
      check(simplifyLambertW(const RealNumber(0.5), 0)).isA<RealNumber>();
      check(simplifyLambertW(const RealNumber(-0.2), -1)).isA<RealNumber>();
      check(simplifyLambertW(const RealNumber(-1.0), 0))
          .equals(Constant.undefined);
      check(simplifyErf(const RealNumber(0.5))).isA<RealNumber>();
      check(simplifyErfc(const RealNumber(0.5))).isA<RealNumber>();
      check(simplifyGamma(const RealNumber(2.5))).isA<RealNumber>();
      check(simplifyGamma(const RealNumber(-1.0))).equals(Constant.undefined);
      check(simplifyBeta(const RealNumber(2.0), const RealNumber(3.0)))
          .isA<RealNumber>();
      check(simplifyBeta(const RealNumber(-1.0), const RealNumber(2.0)))
          .equals(Constant.undefined);
      check(simplifyAsinh(const RealNumber(1.0))).isA<RealNumber>();
      check(simplifyAcosh(const RealNumber(2.0))).isA<RealNumber>();
      check(simplifyAcosh(const RealNumber(0.5))).equals(Constant.undefined);
      check(simplifyAtanh(const RealNumber(0.5))).isA<RealNumber>();
      check(simplifyAtanh(const RealNumber(2.0))).equals(Constant.undefined);
      check(simplifyFactorial(const RealNumber(2.5))).isA<RealNumber>();
      check(simplifyBinomial(const RealNumber(4.0), const RealNumber(2.0)))
          .isA<RealNumber>();
      check(simplifyBinomial(x, const RealNumber(1.0))).equals(x);
      check(simplifyFloor(Add([const RealNumber(1.2), Constant.pi])))
          .equals(const RealNumber(4.0));
      check(simplifyCeil(Add([const RealNumber(1.2), Constant.pi])))
          .equals(const RealNumber(5.0));
      check(simplifyRound(Add([const RealNumber(1.2), Constant.pi])))
          .equals(const RealNumber(4.0));
      check(simplifySign(const RealNumber(2.5))).equals(const RealNumber(1.0));
      check(simplifySign(Add([const RealNumber(1.0), Constant.pi])))
          .equals(const RealNumber(1.0));
      check(simplifyArg(const ComplexNumber(RealNumber(1.0), RealNumber(1.0))))
          .isA<RealNumber>();
      check(simplifyRe(z, assumptions: complexZ))
          .equals(Re(z, isSimplified: true));
      check(simplifyIm(z, assumptions: complexZ))
          .equals(Im(z, isSimplified: true));
      check(simplifySinh(const RealNumber(1.0))).isA<RealNumber>();
      check(simplifyCosh(const RealNumber(1.0))).isA<RealNumber>();
      check(simplifyTanh(const RealNumber(1.0))).isA<RealNumber>();
      check(simplifyExp(const RealNumber(1.0))).isA<RealNumber>();
      check(simplifyLn(Pow(x, FractionNumber.half))).isA<Mul>();
      check(toRectangularExpr(ComplexNumber.i)).equals(ComplexNumber.i);
      check(toPolarExpr(const RealNumber(-1.0))).isA<Mul>();
      check(simplifyIm(const ComplexNumber(RealNumber(1.0), IntegerNumber.two)))
          .equals(const RealNumber(2.0));

      // Propagation of Constant.undefined across simplify* functions
      check(simplifySin(Constant.undefined)).equals(Constant.undefined);
      check(simplifyCos(Constant.undefined)).equals(Constant.undefined);
      check(simplifyTan(Constant.undefined)).equals(Constant.undefined);
      check(simplifyAsin(Constant.undefined)).equals(Constant.undefined);
      check(simplifyAcos(Constant.undefined)).equals(Constant.undefined);
      check(simplifyAtan(Constant.undefined)).equals(Constant.undefined);
      check(simplifySinh(Constant.undefined)).equals(Constant.undefined);
      check(simplifyCosh(Constant.undefined)).equals(Constant.undefined);
      check(simplifyTanh(Constant.undefined)).equals(Constant.undefined);
      check(simplifyAbs(Constant.undefined)).equals(Constant.undefined);
      check(simplifyExp(Constant.undefined)).equals(Constant.undefined);
      check(simplifyLn(Constant.undefined)).equals(Constant.undefined);
      check(simplifyLambertW(Constant.undefined, 0)).equals(Constant.undefined);
      check(simplifyErf(Constant.undefined)).equals(Constant.undefined);
      check(simplifyErfc(Constant.undefined)).equals(Constant.undefined);
      check(simplifyGamma(Constant.undefined)).equals(Constant.undefined);
      check(simplifyBeta(Constant.undefined, IntegerNumber.one))
          .equals(Constant.undefined);
      check(simplifyBeta(IntegerNumber.one, Constant.undefined))
          .equals(Constant.undefined);
      check(simplifyAsinh(Constant.undefined)).equals(Constant.undefined);
      check(simplifyAcosh(Constant.undefined)).equals(Constant.undefined);
      check(simplifyAtanh(Constant.undefined)).equals(Constant.undefined);
      check(simplifyFactorial(Constant.undefined)).equals(Constant.undefined);
      check(simplifyBinomial(Constant.undefined, IntegerNumber.one))
          .equals(Constant.undefined);
      check(simplifyBinomial(IntegerNumber.one, Constant.undefined))
          .equals(Constant.undefined);
      check(simplifyFloor(Constant.undefined)).equals(Constant.undefined);
      check(simplifyCeil(Constant.undefined)).equals(Constant.undefined);
      check(simplifyRound(Constant.undefined)).equals(Constant.undefined);
      check(simplifySign(Constant.undefined)).equals(Constant.undefined);
      check(simplifyMod(Constant.undefined, IntegerNumber.one))
          .equals(Constant.undefined);
      check(simplifyMod(IntegerNumber.one, Constant.undefined))
          .equals(Constant.undefined);
      check(Sin(Asin(const RealNumber(2.0))).simplify())
          .equals(Constant.undefined);

      // isProvenReal on non-negative base with real exponent, and isIntegerExpr on Factorial and Binomial
      check(isProvenReal(Pow(Abs(x), y), realAssumptions)).isTrue();
      check(isProvenReal(Factorial(ComplexNumber.i))).isFalse();
      check(isProvenReal(Binomial(ComplexNumber.i, IntegerNumber.one)))
          .isFalse();
      check(isProvenReal(Floor(ComplexNumber.i))).isFalse();
      check(isProvenReal(Ceil(ComplexNumber.i))).isFalse();
      check(isProvenReal(Round(ComplexNumber.i))).isFalse();
      check(isProvenReal(Sign(ComplexNumber.i))).isFalse();
      check(Im(Factorial(ComplexNumber.i)).simplify())
          .not((it) => it.equals(IntegerNumber.zero));
      check(isProvenReal(LambertW(IntegerNumber.of(-1)))).isFalse();
      check(isProvenReal(LambertW(IntegerNumber.one, branch: -1))).isFalse();
      check(isProvenReal(LambertW(IntegerNumber.one))).isTrue();
      check(isProvenReal(Asin(Constant.pi))).isFalse();
      check(isProvenReal(Acos(Constant.pi))).isFalse();
      check(isProvenReal(Atanh(Constant.e))).isFalse();
      check(isProvenReal(Acosh(IntegerNumber.zero))).isFalse();
      const intAssumptions = Assumptions(
        domains: {'x': VariableDomain.positive, 'y': VariableDomain.integer},
      );
      check(
        isIntegerExpr(
          Factorial(IntegerNumber.of(3)),
          assumptions: intAssumptions,
        ),
      ).isTrue();
      check(isIntegerExpr(Binomial(y, y), assumptions: intAssumptions))
          .isTrue();

      // Derivative structural comparison with point
      final d0 = Derivative(x, 'x');
      final d1 = Derivative(x, 'x', point: IntegerNumber.zero);
      final d2 = Derivative(x, 'x', point: IntegerNumber.one);
      check(compareStructural(d0, d0)).equals(0);
      check(compareStructural(d0, d1)).isLessThan(0);
      check(compareStructural(d1, d0)).isGreaterThan(0);
      check(compareStructural(d1, d2)).isLessThan(0);
    });
  });
}
