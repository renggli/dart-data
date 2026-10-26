import 'package:checks/checks.dart';
import 'package:data/src/symbolic/solver/resultant.dart';
import 'package:data/symbolic.dart';
import 'package:test/test.dart';

void main() {
  group('Sylvester matrix construction and resultant', () {
    test('constructs Sylvester matrix for positive and zero-degree cases', () {
      final p = Expr.parse('x^2 + y^2 - 1');
      final q = Expr.parse('x - y');
      final res = SylvesterResultantSolver.resultant(p, q, 'x').simplify();
      check(res.toString()).equals('-1 + 2 * y ^ 2');

      // degF == 0 && degG == 0
      final m00 = SylvesterResultantSolver.sylvesterMatrix(
        Expr.parse('y + 1'),
        Expr.parse('y - 1'),
        'x',
      );
      check(m00.rowCount).equals(1);
      check(m00.get(0, 0)).equals(IntegerNumber.one);

      // degF == 0 && degG > 0
      final m02 = SylvesterResultantSolver.sylvesterMatrix(
        Expr.parse('y + 2'),
        Expr.parse('x^2 - 1'),
        'x',
      );
      check(m02.rowCount).equals(2);
      check(m02.get(0, 0)).equals(Expr.parse('y + 2').simplify());

      // degF > 0 && degG == 0
      final m20 = SylvesterResultantSolver.sylvesterMatrix(
        Expr.parse('x^2 - 1'),
        Expr.parse('y + 3'),
        'x',
      );
      check(m20.rowCount).equals(2);
      check(m20.get(0, 0)).equals(Expr.parse('y + 3').simplify());

      // Non-polynomial inputs throw ArgumentError
      check(
        () => SylvesterResultantSolver.sylvesterMatrix(
          Expr.parse('sin(x)'),
          q,
          'x',
        ),
      ).throws<ArgumentError>();
      check(
        () => SylvesterResultantSolver.sylvesterMatrix(
          p,
          Expr.parse('1 / x'),
          'x',
        ),
      ).throws<ArgumentError>();
    });
  });

  group('SylvesterResultantSolver.solve', () {
    test('solves bivariate systems and validates variable count', () {
      final p = Expr.parse('x^2 + y^2 - 1');
      final q = Expr.parse('x - y');
      final solutions = SylvesterResultantSolver.solve(p, q, ['x', 'y']);
      check(solutions.length).equals(2);

      // System where first equation does not depend on x
      final f = Expr.parse('y - 2');
      final g = Expr.parse('x - y - 1');
      final sol2 = SylvesterResultantSolver.solve(f, g, ['x', 'y']);
      check(sol2.length).equals(1);
      check(sol2.first['x']).equals(IntegerNumber.of(3));
      check(sol2.first['y']).equals(IntegerNumber.two);

      // System where fAtY vanishes identically at y = 1 while gAtY determines x
      final f3 = Expr.parse('(y - 1) * (x - 5)');
      final g3 = Expr.parse('x^2 + y - 2');
      final sol3 = SylvesterResultantSolver.solve(f3, g3, ['x', 'y']);
      // At y = 1: x^2 - 1 = 0 -> x = ±1; at x = 5: 25 + y - 2 = 0 -> y = -23
      check(sol3.length).equals(3);

      check(() => SylvesterResultantSolver.solve(p, q, ['x']))
          .throws<ArgumentError>();
    });
  });
}
