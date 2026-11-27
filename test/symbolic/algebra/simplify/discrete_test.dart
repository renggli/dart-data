import 'package:checks/checks.dart';
import 'package:data/src/symbolic/algebra/simplify/complex.dart';
import 'package:data/src/symbolic/algebra/simplify/discrete.dart';
import 'package:data/src/symbolic/algebra/simplify/special.dart';
import 'package:data/symbolic.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('Discrete, relational, piecewise, and calculus simplification', () {
    test('simplifies RelationalExpr, Piecewise, and Integral', () {
      const x = Variable('x');
      const y = Variable('y');

      // Numeric and symbolic relationals
      check(
        Relational.lessEqual(IntegerNumber.two, IntegerNumber.two).simplify(),
      ).equals(IntegerNumber.one);
      check(
        Relational.greaterThan(IntegerNumber.one, IntegerNumber.two).simplify(),
      ).equals(IntegerNumber.zero);
      check(
        Relational.greaterEqual(
          IntegerNumber.two,
          IntegerNumber.one,
        ).simplify(),
      ).equals(IntegerNumber.one);
      check(Relational.equal(IntegerNumber.two, IntegerNumber.two).simplify())
          .equals(IntegerNumber.one);

      check(Relational.lessEqual(x, y).simplify())
          .equals(Relational.lessEqual(x, y));
      check(Relational.greaterThan(x, y).simplify())
          .equals(Relational.greaterThan(x, y));
      check(Relational.greaterEqual(x, y).simplify())
          .equals(Relational.greaterEqual(x, y));
      check(Relational.equal(x, y).simplify()).equals(Relational.equal(x, y));

      // Piecewise: false branch skipped, true branch after symbolic branch becomes otherwise
      final pwTruncated = Piecewise([
        (
          relation: Relational.lessThan(IntegerNumber.two, IntegerNumber.one),
          expr: IntegerNumber.zero,
        ),
        (relation: Relational.lessThan(x, IntegerNumber.zero), expr: x),
        (
          relation: Relational.lessThan(IntegerNumber.one, IntegerNumber.two),
          expr: y,
        ),
      ]).simplify();
      check(pwTruncated).equals(
        Piecewise([
          (relation: Relational.lessThan(x, IntegerNumber.zero), expr: x),
        ], otherwise: y),
      );

      // Piecewise with all false branches falls back to otherwise or 0
      final pwAllFalse = Piecewise([
        (
          relation: Relational.lessThan(IntegerNumber.two, IntegerNumber.one),
          expr: x,
        ),
      ], otherwise: y).simplify();
      check(pwAllFalse).equals(y);

      final pwAllFalseNoOther = Piecewise([
        (
          relation: Relational.lessThan(IntegerNumber.two, IntegerNumber.one),
          expr: x,
        ),
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
      check(Integral(Add.of([x, IntegerNumber.zero]), 'x').simplify())
          .equals(Integral(x, 'x'));

      // Derivative and Limit AST simplification
      check(
        simplifyDerivative(
          IntegerNumber.of(5),
          'x',
          assumptions: Assumptions.none,
        ),
      ).equals(IntegerNumber.zero);
      check(
        simplifyDerivative(
          Derivative(x, 'x'),
          'x',
          assumptions: Assumptions.none,
        ),
      ).equals(Derivative(x, 'x', order: 2));
      check(simplifyDerivative(Fn.sin(x), 'x', assumptions: Assumptions.none))
          .equals(Derivative(Fn.sin(x), 'x'));
      check(
        simplifyLimit(
          IntegerNumber.of(5),
          'x',
          IntegerNumber.zero,
          assumptions: Assumptions.none,
        ),
      ).equals(IntegerNumber.of(5));
      check(
        simplifyLimit(
          Fn.sin(x),
          'x',
          IntegerNumber.zero,
          assumptions: Assumptions.none,
        ),
      ).equals(Limit(Fn.sin(x), 'x', IntegerNumber.zero));

      // Factorial and Binomial
      check(
        simplifyFactorial(
          FractionNumber.negativeHalf,
          assumptions: Assumptions.none,
        ).toString(),
      ).equals('sqrt(pi)');
      check(
        simplifyBinomial(
          IntegerNumber.of(5),
          IntegerNumber.of(-2),
          assumptions: Assumptions.none,
        ),
      ).equals(IntegerNumber.zero);
      check(
        simplifyBinomial(
          IntegerNumber.of(3),
          IntegerNumber.of(5),
          assumptions: Assumptions.none,
        ),
      ).equals(IntegerNumber.zero);

      // Floor, Ceil, Round, Sign, Mod on RealNumber and constant expressions
      check(simplifyFloor(const RealNumber(3.7), assumptions: Assumptions.none))
          .equals(const RealNumber(3.0));
      check(simplifyFloor(Constant.pi, assumptions: Assumptions.none))
          .equals(IntegerNumber.of(3));
      check(simplifyCeil(const RealNumber(3.2), assumptions: Assumptions.none))
          .equals(const RealNumber(4.0));
      check(simplifyCeil(Constant.pi, assumptions: Assumptions.none))
          .equals(IntegerNumber.of(4));
      check(simplifyRound(const RealNumber(3.6), assumptions: Assumptions.none))
          .equals(const RealNumber(4.0));
      check(simplifyRound(Constant.pi, assumptions: Assumptions.none))
          .equals(IntegerNumber.of(3));
      check(simplifyRound(FractionNumber.half, assumptions: Assumptions.none))
          .equals(IntegerNumber.one);
      check(
        simplifyRound(
          FractionNumber.negativeHalf,
          assumptions: Assumptions.none,
        ),
      ).equals(IntegerNumber.negativeOne);
      check(simplifyRound(RationalNumber(1, 3), assumptions: Assumptions.none))
          .equals(IntegerNumber.zero);
      check(simplifyRound(RationalNumber(2, 3), assumptions: Assumptions.none))
          .equals(IntegerNumber.one);
      final big = BigInt.from(10).pow(400);
      final bigHalf = RationalNumber.of(
        big * BigInt.two + BigInt.one,
        BigInt.two,
      );
      check(simplifyRound(bigHalf, assumptions: Assumptions.none))
          .equals(IntegerNumber(big + BigInt.one));
      check(simplifyRound(-bigHalf, assumptions: Assumptions.none))
          .equals(IntegerNumber(-(big + BigInt.one)));
      check(
        simplifySign(
          Mul.of([IntegerNumber.negativeOne, x]),
          assumptions: Assumptions.none,
        ),
      ).equals(Mul.of([IntegerNumber.negativeOne, Fn.sign(x)]));
      check(simplifySign(Constant.pi, assumptions: Assumptions.none))
          .equals(IntegerNumber.one);
      check(
        simplifyMod(
          IntegerNumber.of(5),
          IntegerNumber.zero,
          assumptions: Assumptions.none,
        ),
      ).equals(Constant.undefined);
      check(
        simplifyMod(
          IntegerNumber.zero,
          IntegerNumber.of(5),
          assumptions: Assumptions.none,
        ),
      ).equals(IntegerNumber.zero);
      check(
        simplifyMod(
          IntegerNumber.of(5),
          IntegerNumber.one,
          assumptions: Assumptions.none,
        ),
      ).equals(IntegerNumber.zero);
      check(
        simplifyMod(
          const RealNumber(7.5),
          const RealNumber(2.0),
          assumptions: Assumptions.none,
        ),
      ).equals(const RealNumber(1.5));

      // Complex functions: Re, Im, Arg, Conjugate, toRectangular, toPolar
      const z = Variable('z');
      const complexZ = Assumptions(domains: {'z': VariableDomain.complex});
      check(
        simplifyRe(
          Add.of([z, IntegerNumber.two]),
          assumptions: complexZ,
        ).toString(),
      ).equals('2 + re(z)');
      check(
        simplifyIm(
          Add.of([z, ComplexNumber.i]),
          assumptions: complexZ,
        ).toString(),
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
        assumptions: Assumptions.none,
      );
      check(posArg)
          .isA<Call>()
          .has('id', (Call c) => c.id)
          .equals(FunctionId.atan);
      check(posArg.toString()).equals('atan(3/2)');
      check(posArg.anyNode((n) => n is Add)).isFalse;
      check(simplifyArg(Fn.conj(z), assumptions: complexZ))
          .equals(Fn.arg(Fn.conj(z)));
      check(
        simplifyArg(
          Fn.conj(z),
          assumptions: const Assumptions(
            domains: {'z': VariableDomain.positive},
          ),
        ),
      ).equals(IntegerNumber.zero);
      check(
        simplifyArg(
          Pow.of(x, IntegerNumber.two),
          assumptions: Assumptions.real,
        ),
      ).equals(IntegerNumber.zero);
      check(simplifyArg(z, assumptions: complexZ)).equals(Fn.arg(z));

      check(
        simplifyConjugate(
          Add.of([z, IntegerNumber.one]),
          assumptions: complexZ,
        ).toString(),
      ).equals('1 + conj(z)');
      check(
        simplifyConjugate(
          Mul.of([z, IntegerNumber.two]),
          assumptions: complexZ,
        ).toString(),
      ).equals('2 * conj(z)');
      check(
        simplifyConjugate(
          Pow.of(Constant.e, z),
          assumptions: complexZ,
        ).toString(),
      ).equals('exp(conj(z))');
      check(
        simplifyConjugate(
          Pow.of(z, IntegerNumber.two),
          assumptions: complexZ,
        ).toString(),
      ).equals('conj(z) ^ 2');
      check(simplifyConjugate(Fn.sin(z), assumptions: complexZ).toString())
          .equals('sin(conj(z))');
      check(simplifyConjugate(Fn.cos(z), assumptions: complexZ).toString())
          .equals('cos(conj(z))');
      check(simplifyConjugate(Fn.tan(z), assumptions: complexZ).toString())
          .equals('tan(conj(z))');
      check(simplifyConjugate(Fn.sinh(z), assumptions: complexZ).toString())
          .equals('sinh(conj(z))');
      check(simplifyConjugate(Fn.cosh(z), assumptions: complexZ).toString())
          .equals('cosh(conj(z))');
      check(simplifyConjugate(Fn.tanh(z), assumptions: complexZ).toString())
          .equals('tanh(conj(z))');
      check(simplifyConjugate(Fn.erf(z), assumptions: complexZ).toString())
          .equals('erf(conj(z))');
      check(simplifyConjugate(Fn.erfc(z), assumptions: complexZ).toString())
          .equals('erfc(conj(z))');
      check(simplifyConjugate(Fn.atan(z), assumptions: complexZ).toString())
          .equals('conj(atan(z))');
      check(simplifyConjugate(Fn.asinh(z), assumptions: complexZ).toString())
          .equals('conj(asinh(z))');
      const posA = Variable('a');
      const assumptionsPosA = Assumptions(
        domains: {'a': VariableDomain.positive, 'z': VariableDomain.complex},
      );
      check(
        simplifyConjugate(
          Pow.of(posA, z),
          assumptions: assumptionsPosA,
        ).toString(),
      ).equals('a ^ conj(z)');

      check(toRectangularExpr(Fn.sin(z), assumptions: complexZ).toString())
          .equals('i * cos(re(z)) * sinh(im(z)) + sin(re(z)) * cosh(im(z))');
      check(toRectangularExpr(Fn.cos(z), assumptions: complexZ).toString())
          .equals('cos(re(z)) * cosh(im(z)) - i * sin(re(z)) * sinh(im(z))');
      check(toRectangularExpr(Fn.sinh(z), assumptions: complexZ).toString())
          .equals('cos(im(z)) * sinh(re(z)) + i * sin(im(z)) * cosh(re(z))');
      check(toRectangularExpr(Fn.cosh(z), assumptions: complexZ).toString())
          .equals('cos(im(z)) * cosh(re(z)) + i * sin(im(z)) * sinh(re(z))');
      check(toRectangularExpr(Fn.tan(z), assumptions: complexZ).toString())
          .equals('re(tan(z)) + i * im(tan(z))');
      check(toRectangularExpr(Fn.ln(z), assumptions: complexZ).toString())
          .equals('ln(abs(z)) + i * arg(z)');
      check(
        toRectangularExpr(
          Fn.ln(ComplexNumber.i),
          assumptions: Assumptions.none,
        ),
      ).equals(
        Mul.of([
          ComplexNumber(IntegerNumber.zero, FractionNumber.half),
          Constant.pi,
        ]),
      );
      check(simplifyRe(Fn.ln(ComplexNumber.i), assumptions: Assumptions.none))
          .equals(IntegerNumber.zero);
      check(simplifyIm(Fn.ln(ComplexNumber.i), assumptions: Assumptions.none))
          .equals(Mul.of([FractionNumber.half, Constant.pi]));
      check(simplifyRe(Fn.ln(z), assumptions: complexZ))
          .equals(Fn.ln(Fn.abs(z)));
      check(simplifyIm(Fn.ln(z), assumptions: complexZ)).equals(Fn.arg(z));
      check(toRectangularExpr(Fn.re(z), assumptions: complexZ))
          .equals(Fn.re(z));
      check(toRectangularExpr(Fn.im(z), assumptions: complexZ))
          .equals(Fn.im(z));
    });

    test('simplifies float relational inequalities directly', () {
      const one = RealNumber(1.0);
      const two = RealNumber(2.0);
      check(Relational.lessThan(one, two).simplify()).equals(IntegerNumber.one);
      check(Relational.lessThan(two, one).simplify())
          .equals(IntegerNumber.zero);
      check(Relational.lessEqual(two, two).simplify())
          .equals(IntegerNumber.one);
      check(Relational.greaterThan(two, one).simplify())
          .equals(IntegerNumber.one);
      check(Relational.greaterEqual(one, two).simplify())
          .equals(IntegerNumber.zero);
      check(Relational.equal(two, two).simplify()).equals(IntegerNumber.one);
      check(Relational.notEqual(one, two).simplify()).equals(IntegerNumber.one);
      check(Fn.sign(two).simplify()).equals(RealNumber.one);
      check(Fn.sign(const RealNumber(-3.0)).simplify())
          .equals(const RealNumber(-1.0));
      check(Fn.sign(IntegerNumber.zero).simplify()).equals(IntegerNumber.zero);
    });
  });
}
