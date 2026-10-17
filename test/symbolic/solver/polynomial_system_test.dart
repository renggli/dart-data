import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:test/test.dart';

void main() {
  group('Multivariate polynomial system solver (Buchberger + FGLM)', () {
    test('solves bivariate and trivariate polynomial systems', () {
      final solutions = solvePolynomialSystem(
        [Expr.parse('x + y - 3'), Expr.parse('x * y - 2')],
        ['x', 'y'],
      );
      check(solutions.length).equals(2);
      final xValues = solutions.map((s) => s['x']!).toList();
      check(xValues).unorderedEquals([IntegerNumber.one, IntegerNumber.two]);
    });

    test('solves Katsura-2 and Katsura-3 systems without integer overflow', () {
      final k2 = [
        'a + 2*b + 2*c - 1',
        'a^2 + 2*b^2 + 2*c^2 - a',
        '2*a*b + 2*b*c - b',
      ].map(Expr.parse).toList();
      final sol2 = solvePolynomialSystem(k2, ['a', 'b', 'c']);
      check(sol2.length).equals(4);

      final k3 = [
        'a + 2*b + 2*c + 2*d - 1',
        'a^2 + 2*b^2 + 2*c^2 + 2*d^2 - a',
        '2*a*b + 2*b*c + 2*c*d - b',
        'b^2 + 2*a*c + 2*b*d - c',
      ].map(Expr.parse).toList();
      final sol3 = solvePolynomialSystem(k3, ['a', 'b', 'c', 'd']);
      check(sol3.length).equals(2);
      final dValues = sol3.map((s) => s['d']!).toList();
      check(dValues)
          .unorderedEquals([IntegerNumber.zero, FractionNumber.third]);
    });
  });
}
