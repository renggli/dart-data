import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:test/test.dart';

void main() {
  group('Multivariate polynomial system solver', () {
    test('solves bivariate and trivariate systems across all methods', () {
      const x = Variable('x');
      const y = Variable('y');
      final eqs = [
        Equal(x + y, IntegerNumber.of(3)),
        x * y - IntegerNumber.two,
      ];

      for (final method in PolynomialSystemMethod.values) {
        final solutions = eqs.solve(['x', 'y'], method: method);
        check(solutions.length).equals(2);
        final xValues = solutions.map((s) => s['x']!).toList();
        check(xValues).unorderedEquals([IntegerNumber.one, IntegerNumber.two]);
      }
    });

    test('solves Katsura-2 and Katsura-3 systems without integer overflow', () {
      final k2 = [
        'a + 2*b + 2*c - 1',
        'a^2 + 2*b^2 + 2*c^2 - a',
        '2*a*b + 2*b*c - b',
      ].map(Expr.parse).toList();
      final sol2 = k2.solve(['a', 'b', 'c']);
      check(sol2.length).equals(4);

      final k3 = [
        'a + 2*b + 2*c + 2*d - 1',
        'a^2 + 2*b^2 + 2*c^2 + 2*d^2 - a',
        '2*a*b + 2*b*c + 2*c*d - b',
        'b^2 + 2*a*c + 2*b*d - c',
      ].map(Expr.parse).toList();
      final sol3 = k3.solve(['a', 'b', 'c', 'd']);
      check(sol3.length).equals(2);
      final dValues = sol3.map((s) => s['d']!).toList();
      check(dValues)
          .unorderedEquals([IntegerNumber.zero, FractionNumber.third]);

      // System where a lex basis polynomial vanishes identically on one branch (z = 0)
      final degSys = [
        Expr.parse('x - y - z'),
        Expr.parse('z * (y - 1)'),
        Expr.parse('y^2 - 1'),
        Expr.parse('z^2 - z'),
      ];
      final degSol = degSys.solve([
        'x',
        'y',
        'z',
      ], method: PolynomialSystemMethod.groebner);
      // Solutions: (z=0, y=1, x=1), (z=0, y=-1, x=-1), (z=1, y=1, x=2)
      check(degSol.length).equals(3);
    });
  });

  group('Multivariate polynomial system edge cases', () {
    test('handles empty, inconsistent, and invalid method arguments', () {
      check(<Expr>[].solve(['x'])).isEmpty();
      check([Expr.parse('x - 1')].solve([])).isEmpty();

      // Inconsistent 2x2 system
      final inc = [
        Expr.parse('x + y - 1'),
        Expr.parse('x + y - 2'),
      ].solve(['x', 'y']);
      check(inc).isEmpty();

      // Resultant method requires exactly 2 equations and 2 variables
      check(
        () =>
            [Expr.parse('x - 1')]
                .solve(['x'], method: PolynomialSystemMethod.resultant),
      ).throws<ArgumentError>();
    });
  });
}
