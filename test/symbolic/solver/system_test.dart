import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:test/test.dart';

void main() {
  group('Unified equation system solver (linear systems)', () {
    test(
      'solves determined 2x2 and 3x3 linear systems including row pivoting',
      () {
        const y = Variable('y');
        // First equation has 0 coefficient for x, requiring row swap
        final sol2 = [
          Equal(y, IntegerNumber.one),
          Expr.parse('2*x + y - 5'),
        ].solve(['x', 'y']);
        check(sol2.length).equals(1);
        check(sol2.first['x']).equals(IntegerNumber.two);
        check(sol2.first['y']).equals(IntegerNumber.one);

        final sol3 = [
          Expr.parse('x + y + z - 6'),
          Expr.parse('2*x - y + z - 3'),
          Expr.parse('x + 2*y - z - 2'),
        ].solve(['x', 'y', 'z']);
        check(sol3.length).equals(1);
        check(sol3.first['x']).equals(IntegerNumber.one);
        check(sol3.first['y']).equals(IntegerNumber.two);
        check(sol3.first['z']).equals(IntegerNumber.of(3));
      },
    );
  });

  group('Unified equation system solver (nonlinear, rational, and single equations)', () {
    test('dispatches nonlinear polynomial systems and single equations', () {
      // Nonlinear system: x^2 + y - 1 = 0, x - y - 1 = 0 -> x^2 + x - 2 = 0 -> x = 1, -2
      final nonLinear = [
        Expr.parse('x^2 + y - 1'),
        Expr.parse('x - y - 1'),
      ].solve(['x', 'y']);
      check(nonLinear.length).equals(2);
      final xVals = nonLinear.map((s) => s['x']!).toList();
      check(xVals).unorderedEquals([IntegerNumber.one, IntegerNumber.of(-2)]);

      // Single equation in Iterable<Expr>
      final single = [Expr.parse('sin(x) - 1')].solve(['x']);
      check(single.length).equals(1);
      check(single.first['x'].toString()).equals('1/2 * pi');
    });

    test(
      'clears rational denominators and excludes poles from solution set',
      () {
        // (x^2 - 1) / (x - 1) = 0, y - x - 3 = 0 -> x = 1 is a pole, only x = -1, y = 2 is valid
        final rationalPole = [
          Expr.parse('(x^2 - 1) / (x - 1)'),
          Expr.parse('y - x - 3'),
        ].solve(['x', 'y']);
        check(rationalPole.length).equals(1);
        check(rationalPole.first['x']).equals(IntegerNumber.negativeOne);
        check(rationalPole.first['y']).equals(IntegerNumber.two);

        // 1 / x + 1 / y = 3 / 2, x + y = 3 -> (x, y) = (1, 2) or (2, 1)
        final rationalSys = [
          Expr.parse('1 / x + 1 / y - 3 / 2'),
          Expr.parse('x + y - 3'),
        ].solve(['x', 'y']);
        check(rationalSys.length).equals(2);
        final xs = rationalSys.map((s) => s['x']!).toList();
        check(xs).unorderedEquals([IntegerNumber.one, IntegerNumber.two]);
      },
    );
  });

  group('Unified equation system solver (singular and empty cases)', () {
    test('returns empty list for empty, mismatched, or singular systems', () {
      check(<Expr>[].solve([])).isEmpty();
      check([Expr.parse('x - 1')].solve(['x', 'y'])).isEmpty();

      // Singular inconsistent linear system
      final singular = [
        Expr.parse('x + y - 1'),
        Expr.parse('2*x + 2*y - 3'),
      ].solve(['x', 'y']);
      check(singular).isEmpty();
    });

    test('filters multivariate system solutions by Assumptions', () {
      // x^2 + y - 1 = 0, x - y - 1 = 0 -> (1, 0) and (-2, -3)
      final posSols = [Expr.parse('x^2 + y - 1'), Expr.parse('x - y - 1')]
          .solve(
            ['x', 'y'],
            assumptions: const Assumptions(
              domains: {'x': VariableDomain.positive},
            ),
          );
      check(posSols.length).equals(1);
      check(posSols.first['x']).equals(IntegerNumber.one);
      check(posSols.first['y']).equals(IntegerNumber.zero);

      // Complex roots filtered out under Assumptions.real
      final realSols = [
        Expr.parse('x^2 + 1'),
        Expr.parse('y - 2'),
      ].solve(['x', 'y'], assumptions: Assumptions.real);
      check(realSols).isEmpty();
    });
  });
}
