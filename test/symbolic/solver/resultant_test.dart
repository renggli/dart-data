import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:test/scaffolding.dart';

void main() {
  const x = Variable('x');
  const y = Variable('y');

  group('Sylvester resultant matrix & determinant', () {
    test('resultant of circle and line', () {
      // f = x^2 + y^2 - 1
      // g = x - y
      const f = Sub(
        Add(Pow(x, RationalNumber(2)), Pow(y, RationalNumber(2))),
        RationalNumber.one,
      );
      const g = Sub(x, y);

      final res = SylvesterResultantSolver.resultant(f, g, 'x');
      check(res.dependsOn('x')).isFalse();
      check(res.dependsOn('y')).isTrue();

      // At y = 0, res = -1
      check(res.evaluate({'y': 0.0})).isCloseTo(-1.0, 1e-12);
      // At y = 1/sqrt(2), 2y^2 - 1 = 0
      final y0 = 1.0 / math.sqrt(2.0);
      check(res.evaluate({'y': y0})).isCloseTo(0.0, 1e-12);
    });

    test('resultant of circle and hyperbola', () {
      // f = x^2 + y^2 - 5
      // g = x * y - 2
      const f = Sub(
        Add(Pow(x, RationalNumber(2)), Pow(y, RationalNumber(2))),
        RationalNumber(5),
      );
      const g = Sub(Mul(x, y), RationalNumber(2));

      final res = SylvesterResultantSolver.resultant(f, g, 'x');
      // Res = y^4 - 5y^2 + 4, roots are +/-1, +/-2
      for (final root in [1.0, -1.0, 2.0, -2.0]) {
        check(res.evaluate({'y': root})).isCloseTo(0.0, 1e-12);
      }
    });
  });

  group('SylvesterResultantSolver.solve', () {
    test('solves circle-line intersection', () {
      const f = Sub(
        Add(Pow(x, RationalNumber(2)), Pow(y, RationalNumber(2))),
        RationalNumber.one,
      );
      const g = Sub(x, y);

      final solutions = SylvesterResultantSolver.solve(f, g, ['x', 'y']);
      check(solutions.length).equals(2);

      for (final sol in solutions) {
        final xv = sol['x']!.evaluate(const {});
        final yv = sol['y']!.evaluate(const {});

        check(xv * xv + yv * yv).isCloseTo(1.0, 1e-8);
        check(xv - yv).isCloseTo(0.0, 1e-8);
      }
    });

    test('solves two intersecting circles', () {
      // x^2 + y^2 = 1
      // (x - 1)^2 + y^2 = 1 -> x^2 - 2x + 1 + y^2 = 1 -> x^2 - 2x + y^2 = 0
      const f = Sub(
        Add(Pow(x, RationalNumber(2)), Pow(y, RationalNumber(2))),
        RationalNumber.one,
      );
      const g = Add(
        Sub(Pow(x, RationalNumber(2)), Mul(RationalNumber(2), x)),
        Pow(y, RationalNumber(2)),
      );

      final solutions = SylvesterResultantSolver.solve(f, g, ['x', 'y']);
      check(solutions.length).equals(2);

      for (final sol in solutions) {
        final xv = sol['x']!.evaluate(const {});
        final yv = sol['y']!.evaluate(const {});

        check(xv).isCloseTo(0.5, 1e-8);
        check(yv.abs()).isCloseTo(math.sqrt(3.0) / 2.0, 1e-8);
      }
    });

    test('solvePolynomialSystem auto dispatches to resultant for bivariate systems', () {
      const f = Sub(
        Add(Pow(x, RationalNumber(2)), Pow(y, RationalNumber(2))),
        RationalNumber(5),
      );
      const g = Sub(Mul(x, y), RationalNumber(2));

      final solutions = solvePolynomialSystem(
        [f, g],
        ['x', 'y'],
        method: PolynomialSystemMethod.auto,
      );
      check(solutions.length).equals(4);
    });

    test('solves triangular system independent of equation ordering', () {
      // y - 1 = 0, x + y - 2 = 0 -> unique solution (x = 1, y = 1)
      const f = Sub(y, RationalNumber.one);
      const g = Sub(Add(x, y), RationalNumber(2));

      final solFG = SylvesterResultantSolver.solve(f, g, ['x', 'y']);
      check(solFG.length).equals(1);
      check(solFG.first['x']!.evaluate(const {})).isCloseTo(1.0, 1e-8);
      check(solFG.first['y']!.evaluate(const {})).isCloseTo(1.0, 1e-8);

      final solGF = SylvesterResultantSolver.solve(g, f, ['x', 'y']);
      check(solGF.length).equals(1);
      check(solGF.first['x']!.evaluate(const {})).isCloseTo(1.0, 1e-8);
      check(solGF.first['y']!.evaluate(const {})).isCloseTo(1.0, 1e-8);

      final solAutoFG = solvePolynomialSystem(
        [f, g],
        ['x', 'y'],
        method: PolynomialSystemMethod.auto,
      );
      check(solAutoFG.length).equals(1);
      check(solAutoFG.first['x']!.evaluate(const {})).isCloseTo(1.0, 1e-8);
      check(solAutoFG.first['y']!.evaluate(const {})).isCloseTo(1.0, 1e-8);

      final solAutoGF = solvePolynomialSystem(
        [g, f],
        ['x', 'y'],
        method: PolynomialSystemMethod.auto,
      );
      check(solAutoGF.length).equals(1);
      check(solAutoGF.first['x']!.evaluate(const {})).isCloseTo(1.0, 1e-8);
      check(solAutoGF.first['y']!.evaluate(const {})).isCloseTo(1.0, 1e-8);
    });
  });
}
