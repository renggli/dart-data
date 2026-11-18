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
        check(simplifySin(Asin(x), assumptions: Assumptions.none)).equals(x);
        check(simplifyCos(Acos(x), assumptions: Assumptions.none)).equals(x);
        check(simplifyTan(Atan(x), assumptions: Assumptions.none)).equals(x);

        check(
          simplifySin(
            Mul([IntegerNumber.of(-2), x]),
            assumptions: Assumptions.none,
          ).toString(),
        ).equals('-sin(2 * x)');
        check(
          simplifyCos(
            Mul([IntegerNumber.of(-2), x]),
            assumptions: Assumptions.none,
          ).toString(),
        ).equals('cos(2 * x)');
        check(
          simplifyTan(
            Mul([IntegerNumber.of(-2), x]),
            assumptions: Assumptions.none,
          ).toString(),
        ).equals('-tan(2 * x)');

        // matchPiMultiple with pi * (1/2) and pi * 2^(-1)
        check(
          simplifySin(
            Mul([Constant.pi, FractionNumber.half]),
            assumptions: Assumptions.none,
          ),
        ).equals(IntegerNumber.one);
        check(
          simplifySin(
            Mul([
              Constant.pi,
              Pow(IntegerNumber.two, IntegerNumber.negativeOne),
            ]),
            assumptions: Assumptions.none,
          ),
        ).equals(IntegerNumber.one);
        check(
          simplifySin(
            Mul([RationalNumber(3, 2), Constant.pi]),
            assumptions: Assumptions.none,
          ),
        ).equals(IntegerNumber.negativeOne);

        check(simplifyTan(Constant.pi, assumptions: Assumptions.none))
            .equals(IntegerNumber.zero);
        check(
          simplifyTan(
            Mul([RationalNumber(3, 4), Constant.pi]),
            assumptions: Assumptions.none,
          ),
        ).equals(IntegerNumber.negativeOne);
        check(simplifyTan(x, assumptions: Assumptions.none))
            .equals(Tan(x, isSimplified: true));
      },
    );

    test('simplifies asin, acos, and atan boundary values, involutions, and parity', () {
      const x = Variable('x');
      check(simplifyAsin(IntegerNumber.zero, assumptions: Assumptions.none))
          .equals(IntegerNumber.zero);
      check(
        simplifyAsin(
          IntegerNumber.one,
          assumptions: Assumptions.none,
        ).toString(),
      ).equals('1/2 * pi');
      check(
        simplifyAsin(
          IntegerNumber.negativeOne,
          assumptions: Assumptions.none,
        ).toString(),
      ).equals('-1/2 * pi');
      check(simplifyAsin(Sin(x), assumptions: Assumptions.none))
          .equals(Asin(Sin(x), isSimplified: true));
      check(
        simplifyAsin(
          Mul([IntegerNumber.negativeOne, x]),
          assumptions: Assumptions.none,
        ).toString(),
      ).equals('-asin(x)');
      check(simplifyAsin(x, assumptions: Assumptions.none))
          .equals(Asin(x, isSimplified: true));

      check(simplifyAcos(IntegerNumber.one, assumptions: Assumptions.none))
          .equals(IntegerNumber.zero);
      check(
        simplifyAcos(
          IntegerNumber.zero,
          assumptions: Assumptions.none,
        ).toString(),
      ).equals('1/2 * pi');
      check(
        simplifyAcos(IntegerNumber.negativeOne, assumptions: Assumptions.none),
      ).equals(Constant.pi);
      check(simplifyAcos(Cos(x), assumptions: Assumptions.none))
          .equals(Acos(Cos(x), isSimplified: true));
      check(simplifyAcos(x, assumptions: Assumptions.none))
          .equals(Acos(x, isSimplified: true));

      check(simplifyAtan(IntegerNumber.zero, assumptions: Assumptions.none))
          .equals(IntegerNumber.zero);
      check(
        simplifyAtan(
          IntegerNumber.one,
          assumptions: Assumptions.none,
        ).toString(),
      ).equals('1/4 * pi');
      check(
        simplifyAtan(
          IntegerNumber.negativeOne,
          assumptions: Assumptions.none,
        ).toString(),
      ).equals('-1/4 * pi');
      check(simplifyAtan(Tan(x), assumptions: Assumptions.none))
          .equals(Atan(Tan(x), isSimplified: true));
      check(
        simplifyAtan(
          Mul([IntegerNumber.negativeOne, x]),
          assumptions: Assumptions.none,
        ).toString(),
      ).equals('-atan(x)');
      check(simplifyAtan(x, assumptions: Assumptions.none))
          .equals(Atan(x, isSimplified: true));
    });
  });

  group('Hyperbolic, inverse hyperbolic, exponential, and logarithmic simplification', () {
    test('simplifies sinh, cosh, tanh, asinh, acosh, and atanh', () {
      const x = Variable('x');
      check(
        simplifySinh(
          Mul([IntegerNumber.negativeOne, x]),
          assumptions: Assumptions.none,
        ).toString(),
      ).equals('-sinh(x)');
      check(
        simplifyCosh(
          Mul([IntegerNumber.negativeOne, x]),
          assumptions: Assumptions.none,
        ).toString(),
      ).equals('cosh(x)');
      check(
        simplifyTanh(
          Mul([IntegerNumber.negativeOne, x]),
          assumptions: Assumptions.none,
        ).toString(),
      ).equals('-tanh(x)');

      check(simplifyAsinh(Sinh(x), assumptions: Assumptions.none))
          .equals(Asinh(Sinh(x), isSimplified: true));
      check(simplifyAsinh(Sinh(x), assumptions: Assumptions.real)).equals(x);
      check(
        simplifyAsinh(
          Mul([IntegerNumber.negativeOne, x]),
          assumptions: Assumptions.none,
        ).toString(),
      ).equals('-asinh(x)');
      check(simplifyAcosh(Cosh(x), assumptions: Assumptions.none))
          .equals(Acosh(Cosh(x), isSimplified: true));
      check(simplifyAcosh(Cosh(x), assumptions: Assumptions.real))
          .equals(Abs(x, isSimplified: true));
      check(simplifyAcosh(Cosh(x), assumptions: Assumptions.positive))
          .equals(x);
      check(simplifyAcosh(x, assumptions: Assumptions.none))
          .equals(Acosh(x, isSimplified: true));
      check(simplifyAtanh(Tanh(x), assumptions: Assumptions.none))
          .equals(Atanh(Tanh(x), isSimplified: true));
      check(simplifyAtanh(Tanh(x), assumptions: Assumptions.real)).equals(x);
      check(
        simplifyAtanh(
          Mul([IntegerNumber.negativeOne, x]),
          assumptions: Assumptions.none,
        ).toString(),
      ).equals('-atanh(x)');
    });

    test(
      'simplifies exp, ln, and abs across domains and non-negative trees',
      () {
        const x = Variable('x');
        const p = Variable('p');

        check(simplifyExp(IntegerNumber.zero, assumptions: Assumptions.none))
            .equals(IntegerNumber.one);
        check(simplifyLn(IntegerNumber.zero, assumptions: Assumptions.none))
            .equals(-Constant.infinity);
        check(
          simplifyLn(IntegerNumber.negativeOne, assumptions: Assumptions.none),
        ).equals(Mul([ComplexNumber.i, Constant.pi]));
        check(simplifyLn(IntegerNumber.of(-3), assumptions: Assumptions.none))
            .equals(
              simplifyAdd([
                simplifyLn(IntegerNumber.of(3), assumptions: Assumptions.none),
                Mul([ComplexNumber.i, Constant.pi]),
              ], assumptions: Assumptions.none),
            );
        check(
          simplifyLn(
            Pow(x, IntegerNumber.of(3)),
            assumptions: Assumptions.none,
          ).toString(),
        ).equals('ln(x ^ 3)');
        check(
          simplifyLn(
            Pow(x, IntegerNumber.of(3)),
            assumptions: Assumptions.positive,
          ).toString(),
        ).equals('3 * ln(x)');
        check(
          simplifyLn(
            Pow(x, IntegerNumber.negativeOne),
            assumptions: Assumptions.none,
          ).toString(),
        ).equals('ln(1 / x)');
        check(
          simplifyLn(
            Pow(x, IntegerNumber.negativeOne),
            assumptions: Assumptions.positive,
          ).toString(),
        ).equals('-ln(x)');
        check(
          simplifyLn(
            Pow(Constant.e, x),
            assumptions: Assumptions.none,
          ).toString(),
        ).equals('ln(exp(x))');
        check(simplifyLn(Pow(Constant.e, x), assumptions: Assumptions.real))
            .equals(x);

        check(simplifyAbs(IntegerNumber.of(-5), assumptions: Assumptions.none))
            .equals(IntegerNumber.of(5));
        check(
          simplifyAbs(const RealNumber(-2.5), assumptions: Assumptions.none),
        ).equals(const RealNumber(2.5));
        check(
          simplifyAbs(
            Mul([IntegerNumber.of(-3), x]),
            assumptions: Assumptions.none,
          ).toString(),
        ).equals('3 * abs(x)');
        check(Expr.parse('abs(x * y)').simplify().toString())
            .equals('abs(x) * abs(y)');
        check(Expr.parse('log(8, 2)').simplify().toString()).equals('1/3');
        check(Expr.parse('ln(8) - 3 * ln(2)').simplify().toString())
            .equals('0');
        check(simplifyAbs(Constant.pi, assumptions: Assumptions.none))
            .equals(Constant.pi);
        check(simplifyAbs(Abs(x), assumptions: Assumptions.none))
            .equals(Abs(x));
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

        check(
          Expr.parse('asinh(sinh(x))').simplify(assumptions: Assumptions.real),
        ).equals(x);
        check(
          Expr.parse('acosh(cosh(x))').simplify(assumptions: Assumptions.real),
        ).equals(Expr.parse('abs(x)'));
        check(
          Expr.parse('atanh(tanh(x))').simplify(assumptions: Assumptions.real),
        ).equals(x);
        check(Expr.parse('asin(sin(x))').simplify())
            .equals(Expr.parse('asin(sin(x))'));
        check(Expr.parse('asin(sin(1))').simplify()).equals(IntegerNumber.one);
        check(Expr.parse('acos(cos(1))').simplify()).equals(IntegerNumber.one);
        check(Expr.parse('atan(tan(1))').simplify()).equals(IntegerNumber.one);
        check(Expr.parse('sin(acos(x))').simplify())
            .equals(Expr.parse('sqrt(1 - x^2)').simplify());
        check(Expr.parse('cos(asin(x))').simplify())
            .equals(Expr.parse('sqrt(1 - x^2)').simplify());
        check(Expr.parse('sin(atan(x))').simplify())
            .equals(Expr.parse('x * (1 + x^2)^(-1/2)').simplify());
        check(Expr.parse('cos(atan(x))').simplify())
            .equals(Expr.parse('(1 + x^2)^(-1/2)').simplify());
        check(Expr.parse('sinh(asinh(x))').simplify()).equals(x);
        check(Expr.parse('cosh(acosh(x))').simplify()).equals(x);
        check(Expr.parse('tanh(atanh(x))').simplify()).equals(x);
        check(Expr.parse('cosh(asinh(x))').simplify())
            .equals(Expr.parse('sqrt(1 + x^2)').simplify());
      },
    );

    test('preserves branch cuts in ln(u^k) under real and unknown domains', () {
      check(Expr.parse('ln(x^(2/3))').simplify(assumptions: Assumptions.real))
          .equals(
            Expr.parse('2/3 * ln(abs(x))')
                .simplify(assumptions: Assumptions.real),
          );
      check(Expr.parse('ln(x^(-1))').simplify()).equals(
        Ln(
          Pow(const Variable('x'), IntegerNumber.negativeOne),
          isSimplified: true,
        ),
      );
      check(
        Expr.parse('ln(x^(-1))').simplify(assumptions: Assumptions.positive),
      ).equals(
        Expr.parse('-ln(x)').simplify(assumptions: Assumptions.positive),
      );
    });
  });
}
