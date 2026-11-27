import 'package:checks/checks.dart';
import 'package:data/src/symbolic/algebra/simplify/additive.dart';
import 'package:data/src/symbolic/algebra/simplify/transcendental.dart';
import 'package:data/symbolic.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('Trigonometric and inverse trigonometric simplification', () {
    test(
      'simplifies sin, cos, and tan parity, involutions, and pi multiples',
      () {
        const x = Variable('x');
        check(simplifySin(Fn.asin(x), assumptions: Assumptions.none)).equals(x);
        check(simplifyCos(Fn.acos(x), assumptions: Assumptions.none)).equals(x);
        check(simplifyTan(Fn.atan(x), assumptions: Assumptions.none)).equals(x);

        check(
          simplifySin(
            Mul.of([IntegerNumber.of(-2), x]),
            assumptions: Assumptions.none,
          ).toString(),
        ).equals('-sin(2 * x)');
        check(
          simplifyCos(
            Mul.of([IntegerNumber.of(-2), x]),
            assumptions: Assumptions.none,
          ).toString(),
        ).equals('cos(2 * x)');
        check(
          simplifyTan(
            Mul.of([IntegerNumber.of(-2), x]),
            assumptions: Assumptions.none,
          ).toString(),
        ).equals('-tan(2 * x)');

        // matchPiMultiple with pi * (1/2) and pi * 2^(-1)
        check(
          simplifySin(
            Mul.of([Constant.pi, FractionNumber.half]),
            assumptions: Assumptions.none,
          ),
        ).equals(IntegerNumber.one);
        check(
          simplifySin(
            Mul.of([
              Constant.pi,
              Pow.of(IntegerNumber.two, IntegerNumber.negativeOne),
            ]),
            assumptions: Assumptions.none,
          ),
        ).equals(IntegerNumber.one);
        check(
          simplifySin(
            Mul.of([RationalNumber(3, 2), Constant.pi]),
            assumptions: Assumptions.none,
          ),
        ).equals(IntegerNumber.negativeOne);

        check(simplifyTan(Constant.pi, assumptions: Assumptions.none))
            .equals(IntegerNumber.zero);
        check(
          simplifyTan(
            Mul.of([RationalNumber(3, 4), Constant.pi]),
            assumptions: Assumptions.none,
          ),
        ).equals(IntegerNumber.negativeOne);
        check(simplifyTan(x, assumptions: Assumptions.none)).equals(Fn.tan(x));
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
      check(simplifyAsin(Fn.sin(x), assumptions: Assumptions.none))
          .equals(Fn.asin(Fn.sin(x)));
      check(
        simplifyAsin(
          Mul.of([IntegerNumber.negativeOne, x]),
          assumptions: Assumptions.none,
        ).toString(),
      ).equals('-asin(x)');
      check(simplifyAsin(x, assumptions: Assumptions.none)).equals(Fn.asin(x));

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
      check(simplifyAcos(Fn.cos(x), assumptions: Assumptions.none))
          .equals(Fn.acos(Fn.cos(x)));
      check(simplifyAcos(x, assumptions: Assumptions.none)).equals(Fn.acos(x));

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
      check(simplifyAtan(Fn.tan(x), assumptions: Assumptions.none))
          .equals(Fn.atan(Fn.tan(x)));
      check(
        simplifyAtan(
          Mul.of([IntegerNumber.negativeOne, x]),
          assumptions: Assumptions.none,
        ).toString(),
      ).equals('-atan(x)');
      check(simplifyAtan(x, assumptions: Assumptions.none)).equals(Fn.atan(x));
    });
  });

  group('Hyperbolic, inverse hyperbolic, exponential, and logarithmic simplification', () {
    test('simplifies sinh, cosh, tanh, asinh, acosh, and atanh', () {
      const x = Variable('x');
      check(
        simplifySinh(
          Mul.of([IntegerNumber.negativeOne, x]),
          assumptions: Assumptions.none,
        ).toString(),
      ).equals('-sinh(x)');
      check(
        simplifyCosh(
          Mul.of([IntegerNumber.negativeOne, x]),
          assumptions: Assumptions.none,
        ).toString(),
      ).equals('cosh(x)');
      check(
        simplifyTanh(
          Mul.of([IntegerNumber.negativeOne, x]),
          assumptions: Assumptions.none,
        ).toString(),
      ).equals('-tanh(x)');

      check(simplifyAsinh(Fn.sinh(x), assumptions: Assumptions.none))
          .equals(Fn.asinh(Fn.sinh(x)));
      check(simplifyAsinh(Fn.sinh(x), assumptions: Assumptions.real)).equals(x);
      check(
        simplifyAsinh(
          Mul.of([IntegerNumber.negativeOne, x]),
          assumptions: Assumptions.none,
        ).toString(),
      ).equals('-asinh(x)');
      check(simplifyAcosh(Fn.cosh(x), assumptions: Assumptions.none))
          .equals(Fn.acosh(Fn.cosh(x)));
      check(simplifyAcosh(Fn.cosh(x), assumptions: Assumptions.real))
          .equals(Fn.abs(x));
      check(simplifyAcosh(Fn.cosh(x), assumptions: Assumptions.positive))
          .equals(x);
      check(simplifyAcosh(x, assumptions: Assumptions.none))
          .equals(Fn.acosh(x));
      check(simplifyAtanh(Fn.tanh(x), assumptions: Assumptions.none))
          .equals(Fn.atanh(Fn.tanh(x)));
      check(simplifyAtanh(Fn.tanh(x), assumptions: Assumptions.real)).equals(x);
      check(
        simplifyAtanh(
          Mul.of([IntegerNumber.negativeOne, x]),
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
        ).equals(Mul.of([ComplexNumber.i, Constant.pi]));
        check(simplifyLn(IntegerNumber.of(-3), assumptions: Assumptions.none))
            .equals(
              simplifyAdd([
                simplifyLn(IntegerNumber.of(3), assumptions: Assumptions.none),
                Mul.of([ComplexNumber.i, Constant.pi]),
              ], assumptions: Assumptions.none),
            );
        check(
          simplifyLn(
            Pow.of(x, IntegerNumber.of(3)),
            assumptions: Assumptions.none,
          ).toString(),
        ).equals('ln(x ^ 3)');
        check(
          simplifyLn(
            Pow.of(x, IntegerNumber.of(3)),
            assumptions: Assumptions.positive,
          ).toString(),
        ).equals('3 * ln(x)');
        check(
          simplifyLn(
            Pow.of(x, IntegerNumber.negativeOne),
            assumptions: Assumptions.none,
          ).toString(),
        ).equals('ln(1 / x)');
        check(
          simplifyLn(
            Pow.of(x, IntegerNumber.negativeOne),
            assumptions: Assumptions.positive,
          ).toString(),
        ).equals('-ln(x)');
        check(
          simplifyLn(
            Pow.of(Constant.e, x),
            assumptions: Assumptions.none,
          ).toString(),
        ).equals('ln(exp(x))');
        check(simplifyLn(Pow.of(Constant.e, x), assumptions: Assumptions.real))
            .equals(x);

        check(simplifyAbs(IntegerNumber.of(-5), assumptions: Assumptions.none))
            .equals(IntegerNumber.of(5));
        check(
          simplifyAbs(const RealNumber(-2.5), assumptions: Assumptions.none),
        ).equals(const RealNumber(2.5));
        check(
          simplifyAbs(
            Mul.of([IntegerNumber.of(-3), x]),
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
        check(simplifyAbs(Fn.abs(x), assumptions: Assumptions.none))
            .equals(Fn.abs(x));
        check(simplifyAbs(Pow.of(Constant.e, x), assumptions: Assumptions.real))
            .equals(Pow.of(Constant.e, x));
        const posP = Assumptions(
          domains: {'p': VariableDomain.positive, 'x': VariableDomain.real},
        );
        check(simplifyAbs(Pow.of(p, x), assumptions: posP))
            .equals(Pow.of(p, x));
        check(simplifyAbs(Mul.of([Constant.pi, p]), assumptions: posP))
            .equals(Mul.of([Constant.pi, p]));
        check(
          simplifyAbs(
            Pow.of(x, IntegerNumber.two),
            assumptions: Assumptions.real,
          ),
        ).equals(Pow.of(x, IntegerNumber.two));

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
      check(
        Expr.parse('ln(x^(-1))').simplify(),
      ).equals(Fn.ln(Pow.of(const Variable('x'), IntegerNumber.negativeOne)));
      check(
        Expr.parse('ln(x^(-1))').simplify(assumptions: Assumptions.positive),
      ).equals(
        Expr.parse('-ln(x)').simplify(assumptions: Assumptions.positive),
      );
    });

    test('simplifies integer-pi and half-pi trig argument shifts', () {
      const x = Variable('x');
      check(Expr.parse('sin(x - 2 * pi)').simplify()).equals(Fn.sin(x));
      check(Expr.parse('sin(pi + x)').simplify())
          .equals((-Fn.sin(x)).simplify());
      check(Expr.parse('sin(pi / 2 + x)').simplify()).equals(Fn.cos(x));
      check(Expr.parse('sin(3 * pi / 2 + x)').simplify())
          .equals((-Fn.cos(x)).simplify());
      check(Expr.parse('cos(pi - x)').simplify())
          .equals((-Fn.cos(x)).simplify());
      check(Expr.parse('cos(2 * pi + x)').simplify()).equals(Fn.cos(x));
      check(Expr.parse('cos(pi / 2 - x)').simplify()).equals(Fn.sin(x));
      check(Expr.parse('tan(pi + x)').simplify()).equals(Fn.tan(x));
    });
  });
}
