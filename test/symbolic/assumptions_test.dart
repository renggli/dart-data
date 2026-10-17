import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:test/test.dart';

void main() {
  group('Assumptions.run with positive domain', () {
    test(
      'simplifies radicals, abs, sign, and arg under positive assumptions',
      () {
        final sqrtSq = Expr.parse('sqrt(x^2)');
        check(sqrtSq.simplify().toString()).equals('abs(x)');

        final simplified = Assumptions.run(
          sqrtSq.simplify,
          domains: {'x': VariableDomain.positive},
        );
        check(simplified).equals(const Variable('x'));

        // Re-simplifying an already-simplified Abs(x) inside Assumptions.run
        final alreadySimplified = sqrtSq.simplify();
        check(
          Assumptions.run(
            alreadySimplified.simplify,
            domains: {'x': VariableDomain.positive},
          ),
        ).equals(const Variable('x'));

        check(
          Assumptions.run(
            () => Expr.parse('sign(x)').simplify(),
            domains: {'x': VariableDomain.positive},
          ),
        ).equals(IntegerNumber.one);

        check(
          Assumptions.run(
            () => Expr.parse('arg(x)').simplify(),
            domains: {'x': VariableDomain.positive},
          ),
        ).equals(IntegerNumber.zero);

        check(
          Assumptions.run(
            () => Expr.parse('(x^y)^z').simplify().toString(),
            domains: {'x': VariableDomain.positive},
          ),
        ).equals('x ^ (y * z)');
      },
    );
  });

  group('Assumptions.run with real and complex domains', () {
    test('controls conjugate, re, im, and radical reductions', () {
      const z = Variable('z');
      check(
        Assumptions.run(
          () => Conjugate(z).simplify(),
          domains: {'z': VariableDomain.complex},
        ),
      ).equals(Conjugate(z, isSimplified: true));
      check(
        Assumptions.run(
          () => Re(z).simplify(),
          domains: {'z': VariableDomain.complex},
        ),
      ).equals(Re(z, isSimplified: true));
      check(
        Assumptions.run(
          () => Im(z).simplify(),
          domains: {'z': VariableDomain.complex},
        ),
      ).equals(Im(z, isSimplified: true));

      // For complex z, sqrt(z^2) does not collapse to abs(z)
      check(
        Assumptions.run(
          () => Expr.parse('sqrt(z^2)').simplify().toString(),
          domains: {'z': VariableDomain.complex},
        ),
      ).equals('sqrt(z ^ 2)');

      // Nested zone overriding defaultDomain
      Assumptions.run(() {
        check(Conjugate(z).simplify()).equals(Conjugate(z, isSimplified: true));
        final inner = Assumptions.run(
          () => Conjugate(z).simplify(),
          domains: {'z': VariableDomain.real},
        );
        check(inner).equals(z);
      }, defaultDomain: VariableDomain.complex);
    });
  });

  group('Assumptions.run with integer domain', () {
    test('simplifies rounding, modulo, and integer multiples of pi', () {
      const domains = {'n': VariableDomain.integer};
      check(
        Assumptions.run(
          () => Expr.parse('floor(n)').simplify(),
          domains: domains,
        ),
      ).equals(const Variable('n'));
      check(
        Assumptions.run(
          () => Expr.parse('ceil(2 * n + 1)').simplify().toString(),
          domains: domains,
        ),
      ).equals('1 + 2 * n');
      check(
        Assumptions.run(
          () => Expr.parse('round(n^2)').simplify().toString(),
          domains: domains,
        ),
      ).equals('n ^ 2');
      check(
        Assumptions.run(
          () => Expr.parse('mod(n, 1)').simplify(),
          domains: domains,
        ),
      ).equals(IntegerNumber.zero);
      check(
        Assumptions.run(
          () => Expr.parse('sin(n * pi)').simplify(),
          domains: domains,
        ),
      ).equals(IntegerNumber.zero);
      check(
        Assumptions.run(
          () => Expr.parse('tan(n * pi)').simplify(),
          domains: domains,
        ),
      ).equals(IntegerNumber.zero);
      check(
        Assumptions.run(
          () => Expr.parse('cos(2 * n * pi)').simplify(),
          domains: domains,
        ),
      ).equals(IntegerNumber.one);
      check(
        Assumptions.run(
          () => Expr.parse('cos(n * pi)').simplify().toString(),
          domains: domains,
        ),
      ).equals('(-1) ^ n');
      check(
        Assumptions.run(
          () => Expr.parse('(-1)^(2 * n)').simplify(),
          domains: domains,
        ),
      ).equals(IntegerNumber.one);
    });
  });

  group('Assumptions.run with equation solver', () {
    test(
      'filters equation roots according to active zone domain assumptions',
      () {
        final eq1 = Expr.parse('x^2 - 4');
        check(
          Assumptions.run(
            () => eq1.solve('x'),
            domains: {'x': VariableDomain.positive},
          ),
        ).deepEquals([IntegerNumber.two]);

        final eq2 = Expr.parse('x^2 + 1');
        check(
          Assumptions.run(
            () => eq2.solve('x'),
            domains: {'x': VariableDomain.real},
          ),
        ).isEmpty();

        final eq3 = Expr.parse('(2 * x - 1) * (x - 3)');
        check(
          Assumptions.run(
            () => eq3.solve('x'),
            domains: {'x': VariableDomain.integer},
          ),
        ).deepEquals([IntegerNumber.of(3)]);
      },
    );
  });
}
