import 'package:checks/checks.dart';
import 'package:data/src/symbolic/algebra/simplify/additive.dart';
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
}
