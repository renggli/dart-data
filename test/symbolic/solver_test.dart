import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:test/test.dart';

void main() {
  group('Symbolic Equation Solver', () {
    const x = Variable('x');
    const y = Variable('y');
    const z = Variable('z');

    test('linear equations', () {
      // 2x - 6 = 0 -> x = 3
      final eq1 = const Constant(2.0) * x - const Constant(6.0);
      final sol1 = eq1.solve('x');
      check(sol1.length).equals(1);
      check(sol1.first.evaluate(const {})).equals(3.0);

      // 5 - x = 0 -> x = 5
      final eq2 = const Constant(5.0) - x;
      final sol2 = eq2.solve('x');
      check(sol2.length).equals(1);
      check(sol2.first.evaluate(const {})).equals(5.0);

      // Symbolic linear: 2x + y - 4 = 0 -> x = (4 - y) / 2
      final eq3 = const Constant(2.0) * x + y - const Constant(4.0);
      final sol3 = eq3.solve('x');
      check(sol3.length).equals(1);
      check(sol3.first.evaluate({'y': 2.0})).equals(1.0);
      check(sol3.first.evaluate({'y': 0.0})).equals(2.0);
    });

    test('quadratic equations', () {
      // x^2 - 5x + 6 = 0 -> x = 2, 3
      final eq1 =
          x.pow(const Constant(2.0)) -
          const Constant(5.0) * x +
          const Constant(6.0);
      final sol1 = eq1.solve('x');
      check(sol1.length).equals(2);
      final vals1 = sol1.map((s) => s.evaluate(const {})).toList()..sort();
      check(vals1[0]).isCloseTo(2.0, 1e-9);
      check(vals1[1]).isCloseTo(3.0, 1e-9);

      // x^2 - 4 = 0 -> x = -2, 2
      final eq2 = x.pow(const Constant(2.0)) - const Constant(4.0);
      final sol2 = eq2.solve('x');
      check(sol2.length).equals(2);
      final vals2 = sol2.map((s) => s.evaluate(const {})).toList()..sort();
      check(vals2[0]).isCloseTo(-2.0, 1e-9);
      check(vals2[1]).isCloseTo(2.0, 1e-9);

      // Double root: (x - 3)^2 = x^2 - 6x + 9 = 0 -> x = 3
      final eq3 =
          x.pow(const Constant(2.0)) -
          const Constant(6.0) * x +
          const Constant(9.0);
      final sol3 = eq3.solve('x');
      check(sol3.length).equals(1);
      check(sol3.first.evaluate(const {})).isCloseTo(3.0, 1e-9);

      // No real roots: x^2 + 1 = 0
      final eq4 = x.pow(const Constant(2.0)) + const Constant(1.0);
      final sol4 = eq4.solve('x');
      check(sol4).isEmpty();
    });

    test('factored product equations', () {
      // (x - 1) * (x - 4) = 0 -> x = 1, 4
      final eq = (x - const Constant(1.0)) * (x - const Constant(4.0));
      final sol = eq.solve('x');
      check(sol.length).equals(2);
      final vals = sol.map((s) => s.evaluate(const {})).toList()..sort();
      check(vals[0]).equals(1.0);
      check(vals[1]).equals(4.0);
    });

    test('transcendental equations', () {
      // exp(2x - 4) - 1 = 0 -> 2x - 4 = 0 -> x = 2
      final eqExp =
          Exp(const Constant(2.0) * x - const Constant(4.0)) -
          const Constant(1.0);
      final solExp = eqExp.solve('x');
      check(solExp.length).equals(1);
      check(solExp.first.evaluate(const {})).isCloseTo(2.0, 1e-9);

      // ln(x + 1) - 2 = 0 -> x = e^2 - 1
      final eqLn = Ln(x + const Constant(1.0)) - const Constant(2.0);
      final solLn = eqLn.solve('x');
      check(solLn.length).equals(1);
      check(solLn.first.evaluate(const {}))
          .isCloseTo(7.38905609893065 - 1.0, 1e-9);

      // (x - 2)^3 - 8 = 0 -> x - 2 = 2 -> x = 4
      final eqPow =
          (x - const Constant(2.0)).pow(const Constant(3.0)) -
          const Constant(8.0);
      final solPow = eqPow.solve('x');
      check(solPow.length).equals(1);
      check(solPow.first.evaluate(const {})).isCloseTo(4.0, 1e-9);

      // (x + 1)^2 - 9 = 0 -> x + 1 = +/- 3 -> x = 2, -4
      final eqPowEven =
          (x + const Constant(1.0)).pow(const Constant(2.0)) -
          const Constant(9.0);
      final solPowEven = eqPowEven.solve('x');
      check(solPowEven.length).equals(2);
      final vals = solPowEven.map((s) => s.evaluate(const {})).toList()..sort();
      check(vals[0]).isCloseTo(-4.0, 1e-9);
      check(vals[1]).isCloseTo(2.0, 1e-9);
    });

    test('2x2 linear system solving', () {
      // 2x + y - 5 = 0
      // x - y - 1 = 0
      // Solution: x = 2, y = 1
      final eq1 = const Constant(2.0) * x + y - const Constant(5.0);
      final eq2 = x - y - const Constant(1.0);

      final sol = [eq1, eq2].solveSystem(['x', 'y']);
      check(sol).isNotNull();
      check(sol!['x']!.evaluate(const {})).isCloseTo(2.0, 1e-9);
      check(sol['y']!.evaluate(const {})).isCloseTo(1.0, 1e-9);
    });

    test('3x3 linear system solving', () {
      // x + y + z - 6 = 0
      // 2y + 5z - 19 = 0
      // 2x + 4y - 3z - 1 = 0
      // Solution: x = 1, y = 2, z = 3
      final eq1 = x + y + z - const Constant(6.0);
      final eq2 =
          const Constant(2.0) * y +
          const Constant(5.0) * z -
          const Constant(19.0);
      final eq3 =
          const Constant(2.0) * x +
          const Constant(4.0) * y -
          const Constant(3.0) * z -
          const Constant(1.0);

      final sol = [eq1, eq2, eq3].solveSystem(['x', 'y', 'z']);
      check(sol).isNotNull();
      check(sol!['x']!.evaluate(const {})).isCloseTo(1.0, 1e-9);
      check(sol['y']!.evaluate(const {})).isCloseTo(2.0, 1e-9);
      check(sol['z']!.evaluate(const {})).isCloseTo(3.0, 1e-9);
    });

    test('singular system returns null', () {
      // Parallel lines: x + y - 1 = 0 and x + y - 2 = 0
      final eq1 = x + y - const Constant(1.0);
      final eq2 = x + y - const Constant(2.0);

      final sol = [eq1, eq2].solveSystem(['x', 'y']);
      check(sol).isNull();
    });
  });
}
