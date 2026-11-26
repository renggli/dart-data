import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/src/symbolic/algebra/simplify/power.dart';
import 'package:data/symbolic.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('Trivial and exponential base power identities', () {
    test('simplifies zero/unit exponents and zero/unit bases', () {
      const x = Variable('x');
      check(simplifyPow(x, IntegerNumber.zero, assumptions: Assumptions.none))
          .equals(IntegerNumber.one);
      check(simplifyPow(x, RealNumber.zero, assumptions: Assumptions.none))
          .equals(const RealNumber(1.0));
      check(simplifyPow(x, IntegerNumber.one, assumptions: Assumptions.none))
          .equals(x);
      check(simplifyPow(IntegerNumber.one, x, assumptions: Assumptions.none))
          .equals(IntegerNumber.one);
      check(
        simplifyPow(const RealNumber(1.0), x, assumptions: Assumptions.none),
      ).equals(const RealNumber(1.0));
      check(
        simplifyPow(
          IntegerNumber.zero,
          IntegerNumber.two,
          assumptions: Assumptions.none,
        ),
      ).equals(IntegerNumber.zero);
      check(
        simplifyPow(
          RealNumber.zero,
          IntegerNumber.two,
          assumptions: Assumptions.none,
        ),
      ).equals(RealNumber.zero);

      check(
        simplifyPow(
          IntegerNumber.zero,
          IntegerNumber.negativeOne,
          assumptions: Assumptions.none,
        ),
      ).equals(Constant.undefined);
      check(
        simplifyPow(
          IntegerNumber.zero,
          Mul([IntegerNumber.of(-2), x]),
          assumptions: Assumptions.positive,
        ),
      ).equals(Constant.undefined);
      check(
        simplifyPow(
          IntegerNumber.zero,
          Mul([IntegerNumber.of(-2), x]),
          assumptions: Assumptions.none,
        ),
      ).equals(
        Pow(
          IntegerNumber.zero,
          Mul([IntegerNumber.of(-2), x]),
          isSimplified: true,
        ),
      );

      check(simplifyPow(IntegerNumber.zero, x, assumptions: Assumptions.none))
          .equals(Pow(IntegerNumber.zero, x, isSimplified: true));
      check(
        simplifyPow(IntegerNumber.zero, x, assumptions: Assumptions.positive),
      ).equals(IntegerNumber.zero);
    });

    test('simplifies natural exponential powers of logarithms', () {
      const x = Variable('x');
      const y = Variable('y');
      check(simplifyPow(Constant.e, Ln(x), assumptions: Assumptions.none))
          .equals(x);
      check(
        simplifyPow(
          Constant.e,
          Mul([IntegerNumber.of(3), Ln(x)]),
          assumptions: Assumptions.none,
        ),
      ).equals(Pow(x, IntegerNumber.of(3), isSimplified: true));
      check(
        simplifyPow(
          Constant.e,
          Mul([IntegerNumber.two, y, Ln(x)]),
          assumptions: Assumptions.none,
        ).toString(),
      ).equals('x ^ (2 * y)');
    });
  });

  group('Numeric and radical power simplification', () {
    test(
      'evaluates rational, complex, and negative-base fractional powers',
      () {
        check(
          simplifyPow(
            IntegerNumber.of(-4),
            FractionNumber.half,
            assumptions: Assumptions.none,
          ).toString(),
        ).equals('2 * i');
        check(
          simplifyPow(
            IntegerNumber.of(-4),
            FractionNumber.negativeHalf,
            assumptions: Assumptions.none,
          ).toString(),
        ).equals('-1/2 * i');
        check(Expr.parse('(-27)^(1/3) + (-1)^(1/2)').simplify())
            .equals(ComplexNumber(IntegerNumber.of(-3), IntegerNumber.one));
        check(Expr.parse('(-8)^(2/3)').simplify()).equals(IntegerNumber.of(4));
        check(Expr.parse('(-54)^(1/3)').simplify())
            .equals(Expr.parse('-3 * 2^(1/3)').simplify());
        check(
          simplifyPow(
            IntegerNumber.of(-2),
            FractionNumber.third,
            assumptions: Assumptions.none,
          ).toString(),
        ).equals('(-2) ^ (1/3)');

        check(
          simplifyPow(
            ComplexNumber.i,
            IntegerNumber.two,
            assumptions: Assumptions.none,
          ),
        ).equals(IntegerNumber.negativeOne);
        check(
          simplifyPow(
            ComplexNumber.i,
            FractionNumber.half,
            assumptions: Assumptions.none,
          ).toString(),
        ).equals('sqrt(i)');
        check(
          simplifyPow(
            const RealNumber(2.5),
            const RealNumber(3.5),
            assumptions: Assumptions.none,
          ),
        ).equals(RealNumber(math.pow(2.5, 3.5).toDouble()));
        check(
          simplifyPow(
            const RealNumber(2.5),
            const IntegerNumber(Integer(2)),
            assumptions: Assumptions.none,
          ),
        ).equals(const RealNumber(6.25));
        check(
          simplifyPow(
            const IntegerNumber(Integer(2)),
            const RealNumber(0.5),
            assumptions: Assumptions.none,
          ),
        ).equals(RealNumber(math.sqrt(2)));

        check(
          simplifyPow(
            RationalNumber(2, 3),
            IntegerNumber.two,
            assumptions: Assumptions.none,
          ),
        ).equals(RationalNumber(4, 9));
        check(
          simplifyPow(
            RationalNumber(2, 3),
            IntegerNumber.of(70000),
            assumptions: Assumptions.none,
          ),
        ).isA<Pow>();
      },
    );

    test('extracts integer and rational q-th power radicals', () {
      check(Expr.parse('sqrt(12)').simplify().toString()).equals('2 * sqrt(3)');
      check(Expr.parse('sqrt(72 / 25)').simplify().toString())
          .equals('6/5 * sqrt(2)');
      check(Expr.parse('2^(5/2)').simplify().toString()).equals('4 * sqrt(2)');
      check(Expr.parse('(54 / 125)^(1/3)').simplify().toString())
          .equals('3/5 * 2 ^ (1/3)');
      check(Expr.parse('(16 / 81)^(1/3)').simplify().toString())
          .equals('2/9 * 2 ^ (1/3) * 3 ^ (2/3)');
      check((Expr.parse('sin(pi/4)') - Expr.parse('1/sqrt(2)')).simplify())
          .equals(IntegerNumber.zero);
      check((Expr.parse('sqrt(1/2)') - Expr.parse('sqrt(2)/2')).simplify())
          .equals(IntegerNumber.zero);
      check((Expr.parse('tan(pi/6)') - Expr.parse('1/sqrt(3)')).simplify())
          .equals(IntegerNumber.zero);
      check(Expr.parse('2^(5/2)').simplify())
          .equals(Expr.parse('4 * sqrt(2)').simplify());
      check(
        Pow(IntegerNumber.of(2 * 1009 * 1009), FractionNumber.half).simplify(),
      ).equals(Expr.parse('1009 * sqrt(2)').simplify());

      // Large denominator > 64 stays unextracted
      final largeRoot = simplifyPow(
        IntegerNumber.of(4),
        RationalNumber(1, 100),
        assumptions: Assumptions.none,
      );
      check(largeRoot).isA<Pow>();
    });
  });

  group('Composite base power rules', () {
    test('simplifies nested powers, products, abs squares, and OrderTerms', () {
      const x = Variable('x');
      const y = Variable('y');

      // (u^2)^(1/2) -> |u| under real assumptions, stays (x^2)^(1/2) under none
      check(
        simplifyPow(
          Pow(x, IntegerNumber.two),
          FractionNumber.half,
          assumptions: Assumptions.none,
        ),
      ).equals(
        Pow(Pow(x, IntegerNumber.two), FractionNumber.half, isSimplified: true),
      );
      check(
        simplifyPow(
          Pow(x, IntegerNumber.two),
          FractionNumber.half,
          assumptions: Assumptions.real,
        ),
      ).equals(Abs(x));

      // Real numbers are not inferred to exact powers
      check(
        simplifyPow(
          Pow(x, const RealNumber(2.0)),
          const RealNumber(0.5),
          assumptions: Assumptions.real,
        ),
      ).equals(
        Pow(
          Pow(x, const RealNumber(2.0)),
          const RealNumber(0.5),
          isSimplified: true,
        ),
      );

      // Nested powers: (e^x)^y -> e^(x*y) under real assumptions or integer exponent
      check(simplifyPow(Pow(Constant.e, x), y, assumptions: Assumptions.none))
          .equals(Pow(Pow(Constant.e, x), y, isSimplified: true));
      check(
        simplifyPow(
          Pow(Constant.e, x),
          y,
          assumptions: Assumptions.real,
        ).toString(),
      ).equals('exp(x * y)');
      check(
        simplifyPow(
          Pow(Constant.e, x),
          IntegerNumber.two,
          assumptions: Assumptions.none,
        ).toString(),
      ).equals('exp(2 * x)');
      check(
        simplifyPow(
          Pow(Constant.e, Mul([IntegerNumber.of(4), ComplexNumber.i])),
          FractionNumber.half,
          assumptions: Assumptions.none,
        ),
      ).equals(
        Pow(
          Pow(Constant.e, Mul([IntegerNumber.of(4), ComplexNumber.i])),
          FractionNumber.half,
          isSimplified: true,
        ),
      );
      check(
        simplifyPow(
          Pow(x, FractionNumber.third),
          RationalNumber(3, 2),
          assumptions: Assumptions.none,
        ).toString(),
      ).equals('sqrt(x)');
      check(
        simplifyPow(
          Pow(x, y),
          IntegerNumber.two,
          assumptions: Assumptions.none,
        ).toString(),
      ).equals('x ^ (2 * y)');

      // (x^3)^(1/3) and (x^2)^(1/3) do not fold without non-negative assumptions
      check(
        simplifyPow(
          Pow(x, IntegerNumber.of(3)),
          FractionNumber.third,
          assumptions: Assumptions.none,
        ),
      ).equals(
        Pow(
          Pow(x, IntegerNumber.of(3)),
          FractionNumber.third,
          isSimplified: true,
        ),
      );
      check(
        simplifyPow(
          Pow(x, IntegerNumber.of(3)),
          FractionNumber.third,
          assumptions: Assumptions.positive,
        ),
      ).equals(x);
      check(
        simplifyPow(
          Pow(x, IntegerNumber.two),
          FractionNumber.third,
          assumptions: Assumptions.none,
        ),
      ).equals(
        Pow(
          Pow(x, IntegerNumber.two),
          FractionNumber.third,
          isSimplified: true,
        ),
      );
      check(
        simplifyPow(
          Pow(x, IntegerNumber.two),
          FractionNumber.third,
          assumptions: Assumptions.positive,
        ).toString(),
      ).equals('x ^ (2/3)');

      // Product raised to integer power: (2 * x)^3 -> 8 * x^3
      check(
        simplifyPow(
          Mul([IntegerNumber.two, x]),
          IntegerNumber.of(3),
          assumptions: Assumptions.none,
        ).toString(),
      ).equals('8 * x ^ 3');

      // Product raised to fractional power: sqrt(4 * pi^2) -> 2 * pi
      check(Expr.parse('sqrt(4 * pi^2)').simplify().toString())
          .equals('2 * pi');
      check(
        Expr.parse('sqrt(12 * x^2)')
            .simplify(assumptions: Assumptions.real)
            .toString(),
      ).equals('2 * sqrt(3) * abs(x)');
      check(Expr.parse('sqrt(12 * x^2)').simplify().toString())
          .equals('2 * sqrt(3 * x ^ 2)');
      check(
        Expr.parse('sqrt(4 * exp(2 * x))')
            .simplify(assumptions: Assumptions.real)
            .toString(),
      ).equals('2 * exp(x)');
      check(Expr.parse('sqrt(4 * exp(2 * x))').simplify().toString())
          .equals('2 * sqrt(exp(2 * x))');

      // Odd powers in product fractional roots require non-negative base
      check(
        Expr.parse('(x^3 * y)^(1/3)')
            .simplify(assumptions: Assumptions.real)
            .toString(),
      ).equals('(x ^ 3 * y) ^ (1/3)');
      check(
        Expr.parse('(x^3 * y)^(1/3)')
            .simplify(assumptions: Assumptions.positive)
            .toString(),
      ).equals('x * y ^ (1/3)');

      // Tangent of f(x) = sqrt(x^2) + abs(x) at x0 = -2 * pi simplifies to -2 * x
      final f = Expr.parse('sqrt(x^2) + abs(x)');
      final x0 = Expr.parse('-2 * pi').simplify();
      final fx0 = f.substitute('x', x0).simplify();
      final dfx0 = f.derivative('x').simplify().substitute('x', x0).simplify();
      final tangent = (fx0 + dfx0 * (x - x0)).expand().simplify();
      check(tangent.toString()).equals('-2 * x');

      // |x|^2 -> x^2 under real assumptions, stays abs(x)^2 under none
      check(
        simplifyPow(
          Abs(x),
          IntegerNumber.two,
          assumptions: Assumptions.none,
        ).toString(),
      ).equals('abs(x) ^ 2');
      check(
        simplifyPow(
          Abs(x),
          IntegerNumber.two,
          assumptions: Assumptions.real,
        ).toString(),
      ).equals('x ^ 2');

      // OrderTerm^k -> OrderTerm(var, order * k)
      check(
        simplifyPow(
          const OrderTerm('x', 2),
          IntegerNumber.of(3),
          assumptions: Assumptions.none,
        ),
      ).equals(const OrderTerm('x', 6));

      // ComplexNumber with RealNumber component raised to 0 -> RealNumber(1.0)
      check(
        simplifyPow(
          ComplexNumber(const RealNumber(1.0), const RealNumber(2.0)),
          IntegerNumber.zero,
          assumptions: Assumptions.none,
        ),
      ).equals(const RealNumber(1.0));

      // Constant.infinity raised to negative, negative Mul, and positive exponents
      check(
        simplifyPow(
          Constant.infinity,
          IntegerNumber.negativeOne,
          assumptions: Assumptions.none,
        ),
      ).equals(IntegerNumber.zero);
      check(
        simplifyPow(
          Constant.infinity,
          Mul([IntegerNumber.negativeOne, x]),
          assumptions: Assumptions.positive,
        ),
      ).equals(IntegerNumber.zero);
      check(
        simplifyPow(
          Constant.infinity,
          Mul([IntegerNumber.negativeOne, x]),
          assumptions: Assumptions.none,
        ),
      ).equals(
        Pow(
          Constant.infinity,
          Mul([IntegerNumber.negativeOne, x]),
          isSimplified: true,
        ),
      );
      check(
        simplifyPow(
          Constant.infinity,
          IntegerNumber.two,
          assumptions: Assumptions.none,
        ),
      ).equals(Constant.infinity);

      // Higher even root involution: (x^4)^(1/4) -> |x| and (x^4)^(1/2) -> x^2 under real assumptions
      check(
        simplifyPow(
          Pow(x, IntegerNumber.of(4)),
          RationalNumber(1, 4),
          assumptions: Assumptions.real,
        ).toString(),
      ).equals('abs(x)');
      check(
        simplifyPow(
          Pow(x, IntegerNumber.of(4)),
          FractionNumber.half,
          assumptions: Assumptions.real,
        ).toString(),
      ).equals('x ^ 2');
    });

    test(
      'folds large integer powers and extracts large prime square factors',
      () {
        check(Pow(IntegerNumber.two, IntegerNumber.of(1024)).simplify())
            .equals(IntegerNumber(Integer.two.pow(1024)!));
        check(
          Pow(
            IntegerNumber.of(2 * 1009 * 1009),
            FractionNumber.half,
          ).simplify(),
        ).equals(Expr.parse('1009 * sqrt(2)').simplify());
        // Big square factor beyond small trial division limit
        check(
          Pow(
            IntegerNumber.of(3 * 1000003 * 1000003),
            FractionNumber.half,
          ).simplify(),
        ).equals(Expr.parse('1000003 * sqrt(3)').simplify());
      },
    );

    test(
      'preserves branch cuts for nested even-numerator fractional powers',
      () {
        check(
          Expr.parse('((x^(2/3))^(3/2))')
              .simplify(assumptions: Assumptions.real),
        ).equals(Abs(const Variable('x'), isSimplified: true));
        check(Expr.parse('((x^(2/3))^(3/2))').simplify()).isA<Pow>();
      },
    );
  });
}
