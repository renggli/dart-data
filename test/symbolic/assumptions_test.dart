import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:test/test.dart';

void main() {
  group('Assumptions with positive domain', () {
    test(
      'simplifies radicals, abs, sign, and arg under positive assumptions',
      () {
        const posX = Assumptions(domains: {'x': VariableDomain.positive});
        final sqrtSq = Expr.parse('sqrt(x^2)');
        check(sqrtSq.simplify().toString()).equals('abs(x)');

        final simplified = sqrtSq.simplify(assumptions: posX);
        check(simplified).equals(const Variable('x'));

        // Re-simplifying an already-simplified Abs(x) with positive assumptions
        final alreadySimplified = sqrtSq.simplify();
        check(alreadySimplified.simplify(assumptions: posX))
            .equals(const Variable('x'));

        check(Expr.parse('sign(x)').simplify(assumptions: posX))
            .equals(IntegerNumber.one);

        check(Expr.parse('arg(x)').simplify(assumptions: posX))
            .equals(IntegerNumber.zero);

        check(Expr.parse('(x^y)^z').simplify(assumptions: posX).toString())
            .equals('x ^ (y * z)');
      },
    );
  });

  group('Assumptions with real and complex domains and copyWith chaining', () {
    test(
      'controls conjugate, re, im, radical reductions, and parent chaining',
      () {
        const z = Variable('z');
        const complexZ = Assumptions(domains: {'z': VariableDomain.complex});
        check(Conjugate(z).simplify(assumptions: complexZ))
            .equals(Conjugate(z, isSimplified: true));
        check(Re(z).simplify(assumptions: complexZ))
            .equals(Re(z, isSimplified: true));
        check(Im(z).simplify(assumptions: complexZ))
            .equals(Im(z, isSimplified: true));

        // For complex z, sqrt(z^2) does not collapse to abs(z)
        check(
          Expr.parse('sqrt(z^2)').simplify(assumptions: complexZ).toString(),
        ).equals('sqrt(z ^ 2)');

        // Chained assumptions via copyWith overriding parent defaultDomain
        check(Assumptions.none.isEmpty).isTrue();
        check(Assumptions.complex.isEmpty).isFalse();
        check(Conjugate(z).simplify(assumptions: Assumptions.complex))
            .equals(Conjugate(z, isSimplified: true));
        final chained = Assumptions.complex.copyWith(
          domains: {'z': VariableDomain.real},
        );
        check(chained.isEmpty).isFalse();
        check(chained.domainOf('z')).equals(VariableDomain.real);
        check(chained.domainOf('w')).equals(VariableDomain.complex);
        check(Conjugate(z).simplify(assumptions: chained)).equals(z);
      },
    );
  });

  group('Assumptions with integer domain', () {
    test('simplifies rounding, modulo, and integer multiples of pi', () {
      const intN = Assumptions(domains: {'n': VariableDomain.integer});
      check(Expr.parse('floor(n)').simplify(assumptions: intN))
          .equals(const Variable('n'));
      check(
        Expr.parse('ceil(2 * n + 1)').simplify(assumptions: intN).toString(),
      ).equals('1 + 2 * n');
      check(Expr.parse('round(n^2)').simplify(assumptions: intN).toString())
          .equals('n ^ 2');
      check(Expr.parse('mod(n, 1)').simplify(assumptions: intN))
          .equals(IntegerNumber.zero);
      check(Expr.parse('sin(n * pi)').simplify(assumptions: intN))
          .equals(IntegerNumber.zero);
      check(Expr.parse('tan(n * pi)').simplify(assumptions: intN))
          .equals(IntegerNumber.zero);
      check(Expr.parse('cos(2 * n * pi)').simplify(assumptions: intN))
          .equals(IntegerNumber.one);
      check(Expr.parse('cos(n * pi)').simplify(assumptions: intN).toString())
          .equals('(-1) ^ n');
      check(Expr.parse('(-1)^(2 * n)').simplify(assumptions: intN))
          .equals(IntegerNumber.one);
    });
  });

  group('Assumptions with equation solver', () {
    test('filters equation roots according to passed domain assumptions', () {
      final eq1 = Expr.parse('x^2 - 4');
      check(eq1.solve('x', assumptions: Assumptions.positive))
          .deepEquals([IntegerNumber.two]);

      final eq2 = Expr.parse('x^2 + 1');
      check(eq2.solve('x', assumptions: Assumptions.real)).isEmpty();

      final eq3 = Expr.parse('(2 * x - 1) * (x - 3)');
      check(
        eq3.solve(
          'x',
          assumptions: const Assumptions(
            domains: {'x': VariableDomain.integer},
          ),
        ),
      ).deepEquals([IntegerNumber.of(3)]);
    });
  });
}
