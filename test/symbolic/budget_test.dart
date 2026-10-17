import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:test/test.dart';

void main() {
  group('ComputationBudget step limits', () {
    test('allows computation within step budget', () {
      const x = Variable('x');
      final expr = (x + IntegerNumber.one).pow(2);
      final result = ComputationBudget.run(
        () => expr.expand().simplify(),
        maxSteps: 1000,
      );
      check(result).equals(Expr.parse('1 + 2 * x + x^2'));
    });

    test('throws ComputationLimitException when step budget exceeded', () {
      const x = Variable('x');
      const y = Variable('y');
      final expr = (x + y + IntegerNumber.one).pow(12);
      check(() => ComputationBudget.run(expr.expand, maxSteps: 5))
          .throws<ComputationLimitException>()
        ..has((e) => e.steps, 'steps').isNotNull()
        ..has((e) => e.message, 'message').contains('steps');
    });

    test('throws ComputationLimitException in simplify, factor, series, integrate, and limit', () {
      const x = Variable('x');
      final nested = Sin(Cos(Tan(Sin(Cos(x + IntegerNumber.one)))));

      check(() => ComputationBudget.run(nested.simplify, maxSteps: 2))
          .throws<ComputationLimitException>();

      check(
        () => ComputationBudget.run(
          (x.pow(4) - IntegerNumber.one).factor,
          maxSteps: 2,
        ),
      ).throws<ComputationLimitException>();

      check(
        () => ComputationBudget.run(
          () => Sin(x).series('x', order: 10),
          maxSteps: 1,
        ),
      ).throws<ComputationLimitException>();

      check(
        () => ComputationBudget.run(
          () => (x * Sin(x)).integrate('x'),
          maxSteps: 2,
        ),
      ).throws<ComputationLimitException>();

      check(
        () => ComputationBudget.run(
          () => (Sin(x) / x).limit('x', 0),
          maxSteps: 2,
        ),
      ).throws<ComputationLimitException>();
    });

    test('enforces outer and inner budgets when nested', () {
      const x = Variable('x');
      final expr = (x + IntegerNumber.one).pow(6);
      check(
        () => ComputationBudget.run(
          () => ComputationBudget.run(expr.expand, maxSteps: 10000),
          maxSteps: 3,
        ),
      ).throws<ComputationLimitException>();
    });

    test('validates non-negative budget arguments', () {
      check(() => ComputationBudget.run(() => 1, maxSteps: -1))
          .throws<ArgumentError>();
      check(
        () => ComputationBudget.run(
          () => 1,
          timeout: const Duration(milliseconds: -1),
        ),
      ).throws<ArgumentError>();
    });
  });

  group('ComputationBudget timeout limits', () {
    test('throws ComputationLimitException when timeout exceeded', () {
      const x = Variable('x');
      const y = Variable('y');
      const z = Variable('z');
      final expr = (x + y + z + IntegerNumber.one).pow(20);
      check(
          () => ComputationBudget.run(() {
            var acc = expr;
            for (var i = 0; i < 50; i++) {
              acc = acc.expand();
            }
            return acc;
          }, timeout: Duration.zero),
        ).throws<ComputationLimitException>()
        ..has((e) => e.elapsed, 'elapsed').isNotNull()
        ..has(
          (e) => e.toString(),
          'toString',
        ).contains('ComputationLimitException');
    });
  });
}
