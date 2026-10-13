import 'dart:math' as math;
import 'dart:typed_data';

import 'package:checks/checks.dart';
import 'package:data/numeric.dart';
import 'package:data/symbolic.dart';
import 'package:data/type.dart' show Complex;
import 'package:test/scaffolding.dart';

void main() {
  group('Symbolic differentiation order & aliases', () {
    const x = Variable('x');

    test('derivative higher orders', () {
      final poly = x.pow(const RationalNumber(4)); // x^4

      final d0 = poly.derivative('x', order: 0);
      check(d0).equals(poly);

      final d1 = poly.derivative('x', order: 1).simplify();
      check(d1.evaluate({'x': 2.0})).isCloseTo(32.0, 1e-9); // 4 * 2^3

      final d2 = poly.derivative('x', order: 2).simplify();
      check(d2.evaluate({'x': 2.0})).isCloseTo(48.0, 1e-9); // 12 * 2^2

      final d3 = poly.derivative('x', order: 3).simplify();
      check(d3.evaluate({'x': 2.0})).isCloseTo(48.0, 1e-9); // 24 * 2

      final d4 = poly.derivative('x', order: 4).simplify();
      check(d4.evaluate({'x': 2.0})).isCloseTo(24.0, 1e-9); // 24

      final d5 = poly.derivative('x', order: 5).simplify();
      check(d5.evaluate({'x': 2.0})).isCloseTo(0.0, 1e-9); // 0
    });

    test('invalid derivative order throws RangeError', () {
      check(() => x.derivative('x', order: -1)).throws<RangeError>();
    });
  });

  group('JIT compilation bridges', () {
    const x = Variable('x');
    const y = Variable('y');

    test('toFunction1D', () {
      final expr =
          x * x + const RationalNumber(3) * x + const RationalNumber(2);
      final fn1 = expr.toFunction1D('x');

      for (final testX in [-2.0, 0.0, 1.5, 3.0]) {
        final expected = testX * testX + 3.0 * testX + 2.0;
        check(fn1(testX)).isCloseTo(expected, 1e-9);
      }
    });

    test('toVectorFunction on Expr', () {
      final expr = x * x + const RationalNumber(2) * y;
      final vecFn = expr.toVectorFunction(['x', 'y']);

      final pt = Vector<double>.fromList([3.0, 4.0]);
      // 3^2 + 2 * 4 = 9 + 8 = 17
      check(vecFn(pt)).isCloseTo(17.0, 1e-9);
    });

    test('toVectorFunction on Iterable<Expr>', () {
      final system = [x + y, x * y, x - y];
      final compiled = system.toVectorFunction(['x', 'y']);

      final pt = Vector<double>.fromList([4.0, 2.0]);
      final out = compiled(pt);
      check(out.length).equals(3);
      check(out[0]).isCloseTo(6.0, 1e-9); // 4 + 2
      check(out[1]).isCloseTo(8.0, 1e-9); // 4 * 2
      check(out[2]).isCloseTo(2.0, 1e-9); // 4 - 2
    });
  });

  group('Numerical solveSystem', () {
    test('linear 2x2 system', () {
      // x + y - 10 = 0
      // x - y - 2 = 0
      // Solution: x = 6, y = 4
      final equations = <double Function(Vector<double>)>[
        (v) => v[0] + v[1] - 10.0,
        (v) => v[0] - v[1] - 2.0,
      ];
      final guess = Vector<double>.fromList([0.0, 0.0]);
      final sol = solveSystem(equations, guess);

      check(sol[0]).isCloseTo(6.0, 1e-8);
      check(sol[1]).isCloseTo(4.0, 1e-8);
    });

    test('linear 3x3 system', () {
      // 2x + y - z = 8
      // -3x - y + 2z = -11
      // -2x + y + 2z = -3
      // Exact solution: x = 2, y = 3, z = -1
      final equations = <double Function(Vector<double>)>[
        (v) => 2.0 * v[0] + v[1] - v[2] - 8.0,
        (v) => -3.0 * v[0] - v[1] + 2.0 * v[2] + 11.0,
        (v) => -2.0 * v[0] + v[1] + 2.0 * v[2] + 3.0,
      ];
      final guess = Vector<double>.fromList([0.0, 0.0, 0.0]);
      final sol = solveSystem(equations, guess);

      check(sol[0]).isCloseTo(2.0, 1e-7);
      check(sol[1]).isCloseTo(3.0, 1e-7);
      check(sol[2]).isCloseTo(-1.0, 1e-7);
    });

    test('nonlinear 2x2 system with analytical jacobian', () {
      // x^2 + y^2 - 25 = 0
      // x^2 - y - 5 = 0
      // Near (3, 4): 3^2 + 4^2 = 25, 3^2 - 4 - 5 = 0.
      final equations = <double Function(Vector<double>)>[
        (v) => v[0] * v[0] + v[1] * v[1] - 25.0,
        (v) => v[0] * v[0] - v[1] - 5.0,
      ];
      final guess = Vector<double>.fromList([2.5, 3.5]);

      // Numerical jacobian
      final solNum = solveSystem(equations, guess);
      check(solNum[0]).isCloseTo(3.0, 1e-6);
      check(solNum[1]).isCloseTo(4.0, 1e-6);

      // Analytical jacobian:
      // J = [ [2x, 2y],
      //       [2x, -1] ]
      Matrix<double> analyticalJac(Vector<double> v) => Matrix<double>.generate(
        2,
        2,
        (r, c) => switch ((r, c)) {
          (0, 0) => 2.0 * v[0],
          (0, 1) => 2.0 * v[1],
          (1, 0) => 2.0 * v[0],
          (1, 1) => -1.0,
          _ => 0.0,
        },
      );

      final solAna = solveSystem(equations, guess, jacobian: analyticalJac);
      check(solAna[0]).isCloseTo(3.0, 1e-8);
      check(solAna[1]).isCloseTo(4.0, 1e-8);
    });

    test('dimension mismatch throws ArgumentError', () {
      final equations = <double Function(Vector<double>)>[(v) => v[0] + 1.0];
      final guess = Vector<double>.fromList([0.0, 0.0]);
      check(() => solveSystem(equations, guess)).throws<ArgumentError>();
    });

    test('non-converging system throws StateError', () {
      // x^2 + 1 = 0 has no real roots
      final equations = <double Function(Vector<double>)>[
        (v) => v[0] * v[0] + 1.0,
      ];
      final guess = Vector<double>.fromList([1.0]);
      check(() => solveSystem(equations, guess, maxIterations: 10))
          .throws<StateError>();
    });
  });

  group('Symbolic vs Numeric side-by-side parity', () {
    const x = Variable('x');
    const y = Variable('y');

    test('univariate equation solving', () {
      // f(x) = x^2 - 4 = 0 -> x = 2
      final expr = x * x - const RationalNumber(4);
      final symRoots = expr.solve('x');
      final posSymRoot = symRoots
          .map((r) => r.evaluate(const {}))
          .firstWhere((v) => v > 0.0);

      final numRoot = solve(expr.toFunction1D('x'), 0.0, b: 5.0);

      check(numRoot).isCloseTo(posSymRoot, 1e-9);
      check(numRoot).isCloseTo(2.0, 1e-9);
    });

    test('linear system solving parity', () {
      // x + 2y - 7 = 0
      // 3x - y - 7 = 0
      // Solution: x = 3, y = 2
      final eq1 = x + const RationalNumber(2) * y - const RationalNumber(7);
      final eq2 = const RationalNumber(3) * x - y - const RationalNumber(7);

      final symSol = [eq1, eq2].solveSystem(['x', 'y']);
      check(symSol).isNotNull();
      final symX = symSol!['x']!.evaluate(const {});
      final symY = symSol['y']!.evaluate(const {});

      final numSol = solveSystem([
        eq1.toVectorFunction(['x', 'y']),
        eq2.toVectorFunction(['x', 'y']),
      ], Vector<double>.fromList([0.0, 0.0]));

      check(numSol[0]).isCloseTo(symX, 1e-8);
      check(numSol[1]).isCloseTo(symY, 1e-8);
      check(numSol[0]).isCloseTo(3.0, 1e-8);
      check(numSol[1]).isCloseTo(2.0, 1e-8);
    });

    test('first and second order derivative parity', () {
      // f(x) = sin(x) + x^3
      // f'(x) = cos(x) + 3x^2
      // f''(x) = -sin(x) + 6x
      final expr = const Sin(x) + x.pow(const RationalNumber(3));
      const testX = 1.25;

      final symD1 = expr.derivative('x', order: 1).toFunction1D('x')(testX);
      final numD1 = derivative(expr.toFunction1D('x'), testX, order: 1);
      check(numD1).isCloseTo(symD1, 1e-5);
      check(symD1).isCloseTo(math.cos(testX) + 3.0 * testX * testX, 1e-9);

      final symD2 = expr.derivative('x', order: 2).toFunction1D('x')(testX);
      final numD2 = derivative(expr.toFunction1D('x'), testX, order: 2);
      check(numD2).isCloseTo(symD2, 1e-3);
      check(symD2).isCloseTo(-math.sin(testX) + 6.0 * testX, 1e-9);
    });

    test('multivariable gradient parity', () {
      // f(x, y) = x^2 * y + 3 * y^2
      // grad = [2xy, x^2 + 6y]
      final expr = x * x * y + const RationalNumber(3) * y * y;
      final symGradExprs = expr.gradient(['x', 'y']);
      final pt = Vector<double>.fromList([2.0, 3.0]);

      final symGradVals = [
        symGradExprs[0].toVectorFunction(['x', 'y'])(pt),
        symGradExprs[1].toVectorFunction(['x', 'y'])(pt),
      ];

      final numGrad = gradient(expr.toVectorFunction(['x', 'y']), pt);

      check(numGrad[0]).isCloseTo(symGradVals[0], 1e-5);
      check(numGrad[1]).isCloseTo(symGradVals[1], 1e-5);
      check(symGradVals[0]).isCloseTo(12.0, 1e-9); // 2 * 2 * 3 = 12
      check(symGradVals[1]).isCloseTo(22.0, 1e-9); // 4 + 18 = 22
    });

    test('multivariable hessian parity', () {
      // f(x, y) = x^3 + x * y^2
      // H = [ [6x, 2y],
      //       [2y, 2x] ]
      final expr = x.pow(const RationalNumber(3)) + x * y * y;
      final symHessExprs = expr.hessian(['x', 'y']);
      final pt = Vector<double>.fromList([1.5, 2.5]);

      final symHess = Matrix<double>.generate(
        2,
        2,
        (r, c) => symHessExprs[r][c].toVectorFunction(['x', 'y'])(pt),
      );

      final numHess = hessian(expr.toVectorFunction(['x', 'y']), pt);

      check(numHess.get(0, 0)).isCloseTo(symHess.get(0, 0), 1e-4);
      check(numHess.get(0, 1)).isCloseTo(symHess.get(0, 1), 1e-4);
      check(numHess.get(1, 0)).isCloseTo(symHess.get(1, 0), 1e-4);
      check(numHess.get(1, 1)).isCloseTo(symHess.get(1, 1), 1e-4);
    });

    test('vector function jacobian parity', () {
      // F(x, y) = [x^2 + y, sin(x) + y^2]
      // J = [ [2x, 1],
      //       [cos(x), 2y] ]
      final system = [x * x + y, const Sin(x) + y * y];
      final symJacExprs = system.jacobian(['x', 'y']);
      final pt = Vector<double>.fromList([1.0, 2.0]);

      final symJac = Matrix<double>.generate(
        2,
        2,
        (r, c) => symJacExprs[r][c].toVectorFunction(['x', 'y'])(pt),
      );

      final numJac = jacobian(system.toVectorFunction(['x', 'y']), pt);

      check(numJac.get(0, 0)).isCloseTo(symJac.get(0, 0), 1e-5);
      check(numJac.get(0, 1)).isCloseTo(symJac.get(0, 1), 1e-5);
      check(numJac.get(1, 0)).isCloseTo(symJac.get(1, 0), 1e-5);
      check(numJac.get(1, 1)).isCloseTo(symJac.get(1, 1), 1e-5);
    });

    test('definite integration parity', () {
      // \int_0^2 (3x^2 + 2x + 1) dx = [x^3 + x^2 + x]_0^2 = 8 + 4 + 2 = 14
      final expr =
          const RationalNumber(3) * x * x +
          const RationalNumber(2) * x +
          const RationalNumber(1);

      final symIntegral = expr.integrate('x', from: 0, to: 2);
      final symVal = symIntegral.evaluate(const {});

      final numVal = integrate(expr.toFunction1D('x'), 0.0, 2.0);

      check(symVal).isCloseTo(14.0, 1e-9);
      check(numVal).isCloseTo(symVal, 1e-9);
    });

    test('expanded functions derivative parity', () {
      // Tan(x): d/dx tan(x) = 1 + tan(x)^2
      const exprTan = Tan(x);
      final symDTan = exprTan.derivative('x').toFunction1D('x')(0.5);
      final numDTan = derivative(exprTan.toFunction1D('x'), 0.5, order: 1);
      check(numDTan).isCloseTo(symDTan, 1e-4);

      // Atan(x): d/dx atan(x) = 1 / (1 + x^2)
      const exprAtan = Atan(x);
      final symDAtan = exprAtan.derivative('x').toFunction1D('x')(0.8);
      final numDAtan = derivative(exprAtan.toFunction1D('x'), 0.8, order: 1);
      check(numDAtan).isCloseTo(symDAtan, 1e-5);

      // Sinh(x): d/dx sinh(x) = cosh(x)
      const exprSinh = Sinh(x);
      final symDSinh = exprSinh.derivative('x').toFunction1D('x')(1.0);
      final numDSinh = derivative(exprSinh.toFunction1D('x'), 1.0, order: 1);
      check(numDSinh).isCloseTo(symDSinh, 1e-5);

      // Cosh(x): d/dx cosh(x) = sinh(x)
      const exprCosh = Cosh(x);
      final symDCosh = exprCosh.derivative('x').toFunction1D('x')(1.0);
      final numDCosh = derivative(exprCosh.toFunction1D('x'), 1.0, order: 1);
      check(numDCosh).isCloseTo(symDCosh, 1e-5);

      // Tanh(x): d/dx tanh(x) = 1 - tanh(x)^2
      const exprTanh = Tanh(x);
      final symDTanh = exprTanh.derivative('x').toFunction1D('x')(0.6);
      final numDTanh = derivative(exprTanh.toFunction1D('x'), 0.6, order: 1);
      check(numDTanh).isCloseTo(symDTanh, 1e-5);

      // Pow(x, 1/2): d/dx sqrt(x) = 1 / (2 * sqrt(x))
      const exprSqrt = Pow(x, RationalNumber(1, 2));
      final symDSqrt = exprSqrt.derivative('x').toFunction1D('x')(4.0);
      final numDSqrt = derivative(exprSqrt.toFunction1D('x'), 4.0, order: 1);
      check(numDSqrt).isCloseTo(symDSqrt, 1e-5);
    });

    test('expanded functions definite integration parity', () {
      // \int_0^1 sinh(x) dx = cosh(1) - cosh(0)
      const exprSinh = Sinh(x);
      final symSinh = exprSinh
          .integrate('x', from: 0, to: 1)
          .evaluate(const {});
      final numSinh = integrate(exprSinh.toFunction1D('x'), 0.0, 1.0);
      check(numSinh).isCloseTo(symSinh, 1e-6);

      // \int_0^1 cosh(x) dx = sinh(1)
      const exprCosh = Cosh(x);
      final symCosh = exprCosh
          .integrate('x', from: 0, to: 1)
          .evaluate(const {});
      final numCosh = integrate(exprCosh.toFunction1D('x'), 0.0, 1.0);
      check(numCosh).isCloseTo(symCosh, 1e-6);

      // \int_0^0.8 tan(x) dx
      const exprTan = Tan(x);
      final symTan = exprTan
          .integrate('x', from: 0, to: 0.8)
          .evaluate(const {});
      final numTan = integrate(exprTan.toFunction1D('x'), 0.0, 0.8);
      check(numTan).isCloseTo(symTan, 1e-6);

      // \int_0^1 atan(x) dx
      const exprAtan = Atan(x);
      final symAtan = exprAtan
          .integrate('x', from: 0, to: 1)
          .evaluate(const {});
      final numAtan = integrate(exprAtan.toFunction1D('x'), 0.0, 1.0);
      check(numAtan).isCloseTo(symAtan, 1e-6);

      // \int_0^1 tanh(x) dx
      const exprTanh = Tanh(x);
      final symTanh = exprTanh
          .integrate('x', from: 0, to: 1)
          .evaluate(const {});
      final numTanh = integrate(exprTanh.toFunction1D('x'), 0.0, 1.0);
      check(numTanh).isCloseTo(symTanh, 1e-6);
    });
  });

  group('End-to-End Pipeline & Numeric Parity', () {
    test(
      'End-to-End: Parse -> Expand -> Derivative -> Factor -> Solve -> Compile',
      () {
        final parsed = Expr.parse('(x - 1) * (x - 2) * (x - 3)');

        final expanded = parsed.expand();
        check(expanded.evaluate({'x': 4.0})).equals(6.0);

        final deriv = expanded.derivative('x').simplify();

        final fn = expanded.toFunction1D('x');
        final dfn = deriv.toFunction1D('x');
        for (final testX in [0.0, 1.5, 2.5, 5.0]) {
          final numDeriv = derivative(fn, testX);
          final symDeriv = dfn(testX);
          check(symDeriv).isCloseTo(numDeriv, 1e-4);
        }

        final roots = expanded.solve('x');
        check(roots.length).equals(3);
        check(roots).contains(const RationalNumber(1));
        check(roots).contains(const RationalNumber(2));
        check(roots).contains(const RationalNumber(3));

        final integral = expanded.integrate('x', from: 0, to: 1);
        final numInt = integrate(fn, 0.0, 1.0);
        check(integral.evaluate({})).isCloseTo(numInt, 1e-5);
      },
    );

    test('Analytical vs Numerical Derivative across transcendental suite', () {
      const x = Variable('x');
      final testCases = <({Expr expr, double point, double tol})>[
        (expr: const Sin(x) * const Cos(x), point: 0.7, tol: 1e-4),
        (expr: Exp(-x * x), point: 0.5, tol: 1e-4),
        (expr: Ln(x * x + 1), point: 1.2, tol: 1e-4),
        (expr: const Tanh(x), point: 0.8, tol: 1e-4),
        (expr: x / (x * x + 1), point: 1.5, tol: 1e-4),
        (
          expr: Pow(x * x + 1, const RationalNumber(1, 2)),
          point: 2.0,
          tol: 1e-4,
        ),
        (expr: const Atan(x), point: 0.6, tol: 1e-4),
        (expr: const Asin(x), point: 0.4, tol: 1e-4),
        (expr: x * x * x - x * x * 5 + x * 2 - 7, point: 3.0, tol: 1e-3),
      ];

      for (final tc in testCases) {
        final analyticalDeriv = tc.expr.derivative('x').simplify();
        final symFn = analyticalDeriv.toFunction1D('x');
        final baseFn = tc.expr.toFunction1D('x');
        final numVal = derivative(baseFn, tc.point);
        final symVal = symFn(tc.point);
        check(symVal).isCloseTo(numVal, tc.tol);
      }
    });

    test('Real vs Complex Evaluation Consistency on Real Axis', () {
      const x = Variable('x');
      final expressions = <Expr>[
        x + 2,
        x * 3 - 5,
        x.pow(2) + x - 1,
        const Sin(x),
        const Cos(x),
        const Tan(x),
        const Sinh(x),
        const Cosh(x),
        const Tanh(x),
        const Exp(x),
        const Ln(x),
        const Atan(x),
        Abs(x - 2),
      ];

      for (final expr in expressions) {
        for (final val in [0.2, 0.7, 1.3, 2.5]) {
          final realVal = expr.evaluate({'x': val});
          final complexVal = expr.evaluateComplex({'x': Complex(val, 0)});
          check(complexVal.a).isCloseTo(realVal, 1e-10);
          check(complexVal.b).isCloseTo(0.0, 1e-10);
        }
      }
    });
  });

  group('Public API Doc Examples Parity', () {
    test('lib/symbolic.dart library example', () {
      final f = Expr.parse('x^3 + 2 * x');
      final df = f.derivative('x').simplify();
      check(df.toString()).isNotEmpty();
      check(df.toLatex().isNotEmpty).isTrue();
      final fn = df.toFunction1D('x');
      check(fn(2.0)).isCloseTo(14.0, 1e-6);
    });

    test('Expr evaluation, parse, and tryParse', () {
      const x = Variable('x');
      final expr = x * x + x * 2 + 1;
      final val = expr.evaluate({'x': 3.0});
      check(val).equals(16.0);

      final str = formatExpr(x * x + 1);
      check(str).equals('x * x + 1');

      final f = Expr.parse('sin(pi * x) + 2 * x');
      check(f.evaluate({'x': 0.5})).isCloseTo(2.0, 1e-6);

      final expr2 = Expr.tryParse('2 * x + 1');
      check(expr2).isNotNull();
    });

    test('Vector and tensor compilation doc examples', () {
      const x = Variable('x');
      const y = Variable('y');

      final fVec = (x + y * 2).toVectorFunction(['x', 'y']);
      check(fVec(Vector.fromList([3.0, 4.0]))).equals(11.0);

      final fPos = (x + y * 2).compile(['x', 'y']);
      check(fPos([3.0, 4.0])).equals(11.0);

      final kernel = (x * 2).compileTensorKernel(['x']);
      final input = Float64List.fromList([1.0, 2.0, 3.0]);
      final output = Float64List(3);
      kernel([input], output);
      check(output[0]).equals(2.0);
      check(output[1]).equals(4.0);
      check(output[2]).equals(6.0);
    });

    test('Complex doc examples', () {
      final z = const RationalNumber(3) + const RationalNumber(4) * i;
      check(z.evaluateComplex()).equals(const Complex(3, 4));

      const x = Variable('x');
      final expr = x * x + 1;
      final result = expr.evaluateComplex({'x': const Complex(0, 1)});
      check(result.a).isCloseTo(0.0, 1e-12);
      check(result.b).isCloseTo(0.0, 1e-12);

      final f = (x * x + 1).toComplexFunction1D('x');
      final y = f(const Complex(0, 1));
      check(y.a).isCloseTo(0.0, 1e-12);
      check(y.b).isCloseTo(0.0, 1e-12);
    });

    test('Structural order doc example', () {
      const x = Variable('x');
      final cmp = compareStructural(const RationalNumber(1), x);
      check(cmp).isA<int>();
      check(cmp < 0).isTrue();
    });

    test('Linear form and multivariable doc examples', () {
      const x = Variable('x');
      const y = Variable('y');

      final lin = (x * 2 + 5).matchLinear('x');
      check(lin).isNotNull();
      check(lin!.a).equals(const RationalNumber(2));
      check(lin.b).equals(const RationalNumber(5));

      final k = (x * 6).matchScalarMultiple(x * 2, 'x');
      check(k).equals(const RationalNumber(3));

      final scaled = (x + 2).scale(const RationalNumber(3));
      check(scaled.evaluate({'x': 1.0})).equals(9.0);

      final grad = (x * x + y * y).gradient(['x', 'y']);
      check(grad.length).equals(2);

      final h = (x * x + x * y * 3).hessian(['x', 'y']);
      check(h.rowCount).equals(2);
      check(h.colCount).equals(2);
      check(h[0].length).equals(2);

      final jac = [x * y, x + y].jacobian(['x', 'y']);
      check(jac.rowCount).equals(2);
      check(jac.colCount).equals(2);
    });
  });
}
