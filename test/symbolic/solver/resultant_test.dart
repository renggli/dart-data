import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:test/test.dart';

void main() {
  group('Sylvester resultant elimination', () {
    test('eliminates variable between two bivariate polynomials', () {
      final p = Expr.parse('x^2 + y^2 - 1');
      final q = Expr.parse('x - y');
      final res = SylvesterResultantSolver.resultant(p, q, 'x').simplify();
      check(res.toString()).equals('-1 + 2 * y ^ 2');

      final solutions = SylvesterResultantSolver.solve(p, q, ['x', 'y']);
      check(solutions.length).equals(2);
    });
  });
}
