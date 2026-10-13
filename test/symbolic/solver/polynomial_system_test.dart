import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('Monomial & MonomialOrder', () {
    test('monomial degrees and arithmetic', () {
      final m1 = Monomial([2, 1]); // x^2 * y
      final m2 = Monomial([1, 2]); // x * y^2

      check(m1.totalDegree).equals(3);
      check(m2.totalDegree).equals(3);

      final prod = m1 * m2;
      check(prod.exponents).deepEquals([3, 3]);
      check(prod.totalDegree).equals(6);

      final lcm = m1.lcm(m2);
      check(lcm.exponents).deepEquals([2, 2]);

      final gcd = m1.gcd(m2);
      check(gcd.exponents).deepEquals([1, 1]);
    });

    test('grevlex vs lex comparison', () {
      final m1 = Monomial([2, 1, 0]); // x^2 * y
      final m2 = Monomial([1, 2, 0]); // x * y^2

      // In grevlex, x^2 * y > x * y^2 because y has smaller power in m1
      check(MonomialOrder.grevlex.compare(m1, m2)).isGreaterThan(0);

      // In lex, x^2 * y > x * y^2 because x has higher power in m1
      check(MonomialOrder.lex.compare(m1, m2)).isGreaterThan(0);

      final m3 = Monomial([1, 0, 2]); // x * z^2 (deg 3)
      final m4 = Monomial([0, 2, 0]); // y^2 (deg 2)
      // Higher total degree wins in grevlex
      check(MonomialOrder.grevlex.compare(m3, m4)).isGreaterThan(0);
      // In lex, x wins over y regardless of degree
      check(MonomialOrder.lex.compare(m3, m4)).isGreaterThan(0);
    });
  });

  group('MultivariatePolynomial arithmetic & reduction', () {
    test('round-trip parsing from and to Expr', () {
      const x = Variable('x');
      const y = Variable('y');
      const expr = Add(Pow(x, RationalNumber(2)), Mul(x, y));
      final poly = MultivariatePolynomial.fromExpr(expr, ['x', 'y']);

      check(poly.totalDegree).equals(2);
      final back = poly.toExpr();
      check(back.evaluate({'x': 2.0, 'y': 3.0}))
          .isCloseTo(expr.evaluate({'x': 2.0, 'y': 3.0}), 1e-12);
    });

    test('multivariate division / reduction', () {
      const x = Variable('x');
      const y = Variable('y');
      // p = x^2 * y + 1, divisor = x * y
      final p = MultivariatePolynomial.fromExpr(
        const Add(Mul(Pow(x, RationalNumber(2)), y), RationalNumber.one),
        ['x', 'y'],
      );
      final d = MultivariatePolynomial.fromExpr(const Mul(x, y), ['x', 'y']);

      final rem = p.reduce([d]);
      check(rem.toExpr().evaluate(const {})).isCloseTo(1.0, 1e-12);
    });
  });

  group('BuchbergerEngine & FglmEngine', () {
    test('computes reduced Gröbner basis for circle and hyperbola', () {
      const x = Variable('x');
      const y = Variable('y');
      // x^2 + y^2 - 5 = 0, x * y - 2 = 0
      final f1 = MultivariatePolynomial.fromExpr(
        const Sub(
          Add(Pow(x, RationalNumber(2)), Pow(y, RationalNumber(2))),
          RationalNumber(5),
        ),
        ['x', 'y'],
      );
      final f2 = MultivariatePolynomial.fromExpr(
        const Sub(Mul(x, y), RationalNumber(2)),
        ['x', 'y'],
      );

      final gbGrevlex = BuchbergerEngine.compute([
        f1,
        f2,
      ], order: MonomialOrder.grevlex);
      check(gbGrevlex.isNotEmpty).isTrue();

      final gbLex = FglmEngine.convert(
        gbGrevlex,
        targetOrder: MonomialOrder.lex,
      );
      check(gbLex.isNotEmpty).isTrue();

      // In lex (x > y), the elimination polynomial in y must be present
      final lastPoly = gbLex.last.toExpr();
      check(lastPoly.dependsOn('x')).isFalse();
      check(lastPoly.dependsOn('y')).isTrue();
    });

    test('computes reduced Gröbner basis for circle and parabola preserving pure powers', () {
      const x = Variable('x');
      const y = Variable('y');
      // x^2 + y^2 - 4 = 0, x^2 - y - 2 = 0
      final f1 = MultivariatePolynomial.fromExpr(
        const Sub(
          Add(Pow(x, RationalNumber(2)), Pow(y, RationalNumber(2))),
          RationalNumber(4),
        ),
        ['x', 'y'],
      );
      final f2 = MultivariatePolynomial.fromExpr(
        const Sub(Sub(Pow(x, RationalNumber(2)), y), RationalNumber(2)),
        ['x', 'y'],
      );

      final gbGrevlex = BuchbergerEngine.compute([
        f1,
        f2,
      ], order: MonomialOrder.grevlex);
      // Both x and y leading terms must be preserved
      check(
        gbGrevlex.any(
          (p) => p.leadingMonomial(MonomialOrder.grevlex).exponents[0] > 0,
        ),
      ).isTrue();
      check(
        gbGrevlex.any(
          (p) => p.leadingMonomial(MonomialOrder.grevlex).exponents[1] > 0,
        ),
      ).isTrue();

      final gbLex = FglmEngine.convert(
        gbGrevlex,
        targetOrder: MonomialOrder.lex,
      );
      check(gbLex.length).equals(2);
    });

    test('FGLM throws UnsupportedError on positive-dimensional ideal', () {
      // Single equation x - y in two variables has dim = 1 (line)
      const x = Variable('x');
      const y = Variable('y');
      final f = MultivariatePolynomial.fromExpr(const Sub(x, y), ['x', 'y']);
      final gb = BuchbergerEngine.compute([f], order: MonomialOrder.grevlex);

      check(() => FglmEngine.convert(gb)).throws<UnsupportedError>();
    });
  });

  group('solvePolynomialSystem solver', () {
    test('circle-hyperbola intersection system', () {
      const x = Variable('x');
      const y = Variable('y');
      const eq1 = Sub(
        Add(Pow(x, RationalNumber(2)), Pow(y, RationalNumber(2))),
        RationalNumber(5),
      );
      const eq2 = Sub(Mul(x, y), RationalNumber(2));

      final solutions = solvePolynomialSystem(
        [eq1, eq2],
        ['x', 'y'],
        method: 'groebner',
      );
      check(solutions.length).equals(4);

      // Verify each solution satisfies both equations
      for (final sol in solutions) {
        final xVal = sol['x']!.evaluate(const {});
        final yVal = sol['y']!.evaluate(const {});

        check(xVal * xVal + yVal * yVal).isCloseTo(5.0, 1e-8);
        check(xVal * yVal).isCloseTo(2.0, 1e-8);
      }
    });

    test('inconsistent system produces empty solution list', () {
      const x = Variable('x');
      const y = Variable('y');
      const eq1 = Sub(
        Add(Pow(x, RationalNumber(2)), Pow(y, RationalNumber(2))),
        RationalNumber.one,
      );
      const eq2 = Sub(
        Add(Pow(x, RationalNumber(2)), Pow(y, RationalNumber(2))),
        RationalNumber(2),
      );

      final solutions = solvePolynomialSystem(
        [eq1, eq2],
        ['x', 'y'],
        method: 'groebner',
      );
      check(solutions).isEmpty();
    });

    test('3-variable symmetric polynomial system', () {
      // x + y + z = 6, x*y + y*z + z*x = 11, x*y*z = 6
      // Roots are permutations of (1, 2, 3)
      const x = Variable('x');
      const y = Variable('y');
      const z = Variable('z');

      const eq1 = Sub(Add(Add(x, y), z), RationalNumber(6));
      const eq2 = Sub(
        Add(Add(Mul(x, y), Mul(y, z)), Mul(z, x)),
        RationalNumber(11),
      );
      const eq3 = Sub(Mul(Mul(x, y), z), RationalNumber(6));

      final solutions = solvePolynomialSystem(
        [eq1, eq2, eq3],
        ['x', 'y', 'z'],
        method: 'groebner',
      );
      check(solutions.length).equals(6); // 3! = 6 permutations

      for (final sol in solutions) {
        final xv = sol['x']!.evaluate(const {});
        final yv = sol['y']!.evaluate(const {});
        final zv = sol['z']!.evaluate(const {});

        check(xv + yv + zv).isCloseTo(6.0, 1e-8);
        check(xv * yv + yv * zv + zv * xv).isCloseTo(11.0, 1e-8);
        check(xv * yv * zv).isCloseTo(6.0, 1e-8);
      }
    });

    test('circle-parabola intersection system via groebner', () {
      const x = Variable('x');
      const y = Variable('y');
      const eq1 = Sub(
        Add(Pow(x, RationalNumber(2)), Pow(y, RationalNumber(2))),
        RationalNumber(4),
      );
      const eq2 = Sub(Sub(Pow(x, RationalNumber(2)), y), RationalNumber(2));

      final solutions = solvePolynomialSystem(
        [eq1, eq2],
        ['x', 'y'],
        method: 'groebner',
      );
      check(solutions.length).equals(3);

      final yValues = solutions.map((s) => s['y']!.evaluate(const {})).toList()
        ..sort();
      check(yValues[0]).isCloseTo(-2.0, 1e-8);
      check(yValues[1]).isCloseTo(1.0, 1e-8);
      check(yValues[2]).isCloseTo(1.0, 1e-8);

      for (final sol in solutions) {
        final xVal = sol['x']!.evaluate(const {});
        final yVal = sol['y']!.evaluate(const {});

        check(xVal * xVal + yVal * yVal).isCloseTo(4.0, 1e-8);
        check(xVal * xVal - yVal - 2.0).isCloseTo(0.0, 1e-8);
      }
    });

    test('3-variable quadratic system with matching leading terms', () {
      // x^2 + y - 1 = 0, x^2 + z - 1 = 0, y + z - 1 = 0
      const x = Variable('x');
      const y = Variable('y');
      const z = Variable('z');

      const eq1 = Sub(Add(Pow(x, RationalNumber(2)), y), RationalNumber.one);
      const eq2 = Sub(Add(Pow(x, RationalNumber(2)), z), RationalNumber.one);
      const eq3 = Sub(Add(y, z), RationalNumber.one);

      final solutions = solvePolynomialSystem(
        [eq1, eq2, eq3],
        ['x', 'y', 'z'],
        method: 'groebner',
      );
      check(solutions.length).equals(2);

      for (final sol in solutions) {
        final xv = sol['x']!.evaluate(const {});
        final yv = sol['y']!.evaluate(const {});
        final zv = sol['z']!.evaluate(const {});

        check(xv * xv + yv - 1.0).isCloseTo(0.0, 1e-8);
        check(xv * xv + zv - 1.0).isCloseTo(0.0, 1e-8);
        check(yv + zv - 1.0).isCloseTo(0.0, 1e-8);
      }
    });
  });
}
