import 'package:checks/checks.dart';
import 'package:data/src/symbolic/algebra/simplify/complex.dart';
import 'package:data/src/symbolic/algebra/simplify/discrete.dart';
import 'package:data/src/symbolic/algebra/simplify/special.dart';
import 'package:data/symbolic.dart';
import 'package:test/test.dart';

void main() {
  group('Discrete, relational, piecewise, and calculus simplification', () {
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
      check(simplifyRound(FractionNumber.half)).equals(IntegerNumber.one);
      check(simplifyRound(FractionNumber.negativeHalf))
          .equals(IntegerNumber.negativeOne);
      check(simplifyRound(RationalNumber(1, 3))).equals(IntegerNumber.zero);
      check(simplifyRound(RationalNumber(2, 3))).equals(IntegerNumber.one);
      final big = BigInt.from(10).pow(400);
      final bigHalf = FractionNumber(
        Integer.big(big * BigInt.two + BigInt.one),
        Integer.two,
      );
      check(simplifyRound(bigHalf))
          .equals(IntegerNumber(Integer.big(big + BigInt.one)));
      check(simplifyRound(-bigHalf))
          .equals(IntegerNumber(Integer.big(-(big + BigInt.one))));
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
      ).equals('-pi + atan(4/3)');
      check(
        simplifyArg(
          ComplexNumber.of(IntegerNumber.of(-3), IntegerNumber.of(4)),
          assumptions: complexZ,
        ).toString(),
      ).equals('pi - atan(4/3)');
      final posArg = simplifyArg(
        ComplexNumber.of(IntegerNumber.two, IntegerNumber.of(3)),
      );
      check(posArg).isA<Atan>();
      check(posArg.toString()).equals('atan(3/2)');
      check(posArg.anyNode((n) => n is Add)).isFalse();
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
      check(simplifyConjugate(Erf(z), assumptions: complexZ).toString())
          .equals('erf(conj(z))');
      check(simplifyConjugate(Erfc(z), assumptions: complexZ).toString())
          .equals('erfc(conj(z))');
      check(simplifyConjugate(Atan(z), assumptions: complexZ).toString())
          .equals('atan(conj(z))');
      check(simplifyConjugate(Asinh(z), assumptions: complexZ).toString())
          .equals('asinh(conj(z))');
      const posA = Variable('a');
      const assumptionsPosA = Assumptions(
        domains: {'a': VariableDomain.positive, 'z': VariableDomain.complex},
      );
      check(
        simplifyConjugate(
          Pow(posA, z),
          assumptions: assumptionsPosA,
        ).toString(),
      ).equals('a ^ conj(z)');

      check(toRectangularExpr(Sin(z), assumptions: complexZ).toString())
          .equals('i * cos(re(z)) * sinh(im(z)) + sin(re(z)) * cosh(im(z))');
      check(toRectangularExpr(Cos(z), assumptions: complexZ).toString())
          .equals('cos(re(z)) * cosh(im(z)) - i * sin(re(z)) * sinh(im(z))');
      check(toRectangularExpr(Sinh(z), assumptions: complexZ).toString())
          .equals('cos(im(z)) * sinh(re(z)) + i * sin(im(z)) * cosh(re(z))');
      check(toRectangularExpr(Cosh(z), assumptions: complexZ).toString())
          .equals('cos(im(z)) * cosh(re(z)) + i * sin(im(z)) * sinh(re(z))');
      check(toRectangularExpr(Tan(z), assumptions: complexZ).toString())
          .equals('re(tan(z)) + i * im(tan(z))');
      check(toRectangularExpr(Ln(z), assumptions: complexZ).toString())
          .equals('ln(abs(z)) + i * arg(z)');
      check(toRectangularExpr(Ln(ComplexNumber.i))).equals(
        Mul([
          ComplexNumber(IntegerNumber.zero, FractionNumber.half),
          Constant.pi,
        ], isSimplified: true),
      );
      check(simplifyRe(Ln(ComplexNumber.i))).equals(IntegerNumber.zero);
      check(simplifyIm(Ln(ComplexNumber.i)))
          .equals(Mul([FractionNumber.half, Constant.pi]));
      check(simplifyRe(Ln(z), assumptions: complexZ)).equals(Ln(Abs(z)));
      check(simplifyIm(Ln(z), assumptions: complexZ)).equals(Arg(z));
      check(toRectangularExpr(Re(z), assumptions: complexZ))
          .equals(Re(z, isSimplified: true));
      check(toRectangularExpr(Im(z), assumptions: complexZ))
          .equals(Im(z, isSimplified: true));
    });
  });
}
