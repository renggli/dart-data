import 'dart:typed_data';

import 'package:data/symbolic.dart';
import 'package:test/test.dart';

void main() {
  group('Expression AST creation & evaluation', () {
    test('basic arithmetic and evaluation', () {
      const x = Variable('x');
      final expr = (x * 2) + 5;
      expect(expr.freeVariables, {'x'});
      expect(expr.dependsOn('x'), isTrue);
      expect(expr.dependsOn('y'), isFalse);
      expect(expr.evaluate({'x': 3.0}), 11.0);
    });

    test('LaTeX formatting', () {
      const x = Variable('x');
      final expr = (x * x) / (x + 1);
      expect(expr.toLatex(), '\\frac{x \\cdot x}{x + 1}');
    });
  });

  group('Exact Analytical Differentiation', () {
    test('polynomial differentiation', () {
      const x = Variable('x');
      // f(x) = x^3
      final f = x.pow(3);
      final df = f.diff('x').simplify();
      // f'(x) = 3 * x^2
      final fn = df.compile1D('x');
      expect(fn(2.0), 12.0); // 3 * 4 = 12
    });

    test('product rule: x^2 * sin(x)', () {
      const x = Variable('x');
      final f = (x.pow(2)) * const Sin(x);
      final df = f.diff('x').simplify();
      // At x = 0, df = 2*0*sin(0) + 0^2*cos(0) = 0
      final dfCompiled = df.compile1D('x');
      expect(dfCompiled(0.0), 0.0);
    });

    test('chain rule: exp(2*x)', () {
      const x = Variable('x');
      final f = Exp(x * 2);
      final df = f.diff('x').simplify();
      // d/dx exp(2x) = 2 * exp(2x)
      final dfCompiled = df.compile1D('x');
      expect(dfCompiled(0.0), 2.0);
    });

    test('logarithm: ln(x)', () {
      const x = Variable('x');
      const f = Ln(x);
      final df = f.diff('x').simplify();
      final dfCompiled = df.compile1D('x');
      expect(dfCompiled(2.0), 0.5);
    });
  });

  group('Algebraic Simplification', () {
    test('identity reduction and constant folding', () {
      const x = Variable('x');
      const y = Variable('y');

      // (x * 0) + (1 * y) -> y
      final expr1 = (x * 0) + (y * 1);
      expect(expr1.simplify(), y);

      // (4 + 6) -> 10
      final expr2 = const Constant(4.0) + const Constant(6.0);
      expect(expr2.simplify(), const Constant(10.0));

      // x - x -> 0
      final expr3 = x - x;
      expect(expr3.simplify(), const Constant(0.0));

      // x^0 -> 1, x^1 -> x
      expect(x.pow(0).simplify(), const Constant(1.0));
      expect(x.pow(1).simplify(), x);
    });
  });

  group('JIT Compilation & Tensor Kernel', () {
    test('compile1D zero-AST closure execution', () {
      const x = Variable('x');
      final f = (x * x) + (x * 3) + 2; // x^2 + 3x + 2
      final compiled = f.compile1D('x');

      expect(compiled(0.0), 2.0);
      expect(compiled(1.0), 6.0);
      expect(compiled(2.0), 12.0);
    });

    test('compile multi-variable closure', () {
      const x = Variable('x');
      const y = Variable('y');
      final f = (x * 2) + (y * 3);
      final compiled = f.compile(['x', 'y']);

      expect(compiled([4.0, 5.0]), 23.0); // 8 + 15 = 23
    });

    test('compileTensorKernel vectorized flat loop', () {
      const x = Variable('x');
      const y = Variable('y');
      final f = (x * 2) + y;
      final kernel = f.compileTensorKernel(['x', 'y']);

      final xData = Float64List.fromList([1.0, 2.0, 3.0, 4.0]);
      final yData = Float64List.fromList([10.0, 20.0, 30.0, 40.0]);
      final out = Float64List(4);

      kernel([xData, yData], out);
      expect(out, [12.0, 24.0, 36.0, 48.0]);
    });
  });

  group('Multivariable Calculus', () {
    test('Gradient and Hessian of f(x, y) = x^2 + 3xy + y^3', () {
      const x = Variable('x');
      const y = Variable('y');
      final f = x.pow(2) + (x * y * 3) + y.pow(3);

      final grad = Calculus.gradient(f, ['x', 'y']);
      expect(grad.length, 2);

      final dfDx = grad[0].compile(['x', 'y']);
      final dfDy = grad[1].compile(['x', 'y']);

      // df/dx = 2x + 3y -> at (1, 2): 2(1) + 3(2) = 8
      expect(dfDx([1.0, 2.0]), 8.0);
      // df/dy = 3x + 3y^2 -> at (1, 2): 3(1) + 3(4) = 15
      expect(dfDy([1.0, 2.0]), 15.0);

      final hess = Calculus.hessian(f, ['x', 'y']);
      expect(hess.length, 2);
      expect(hess[0].length, 2);
      // d^2f / dx^2 = 2
      final d2fDx2 = hess[0][0].compile(['x', 'y']);
      expect(d2fDx2([1.0, 2.0]), 2.0);
      // d^2f / (dx dy) = 3
      final d2fDxDy = hess[0][1].compile(['x', 'y']);
      expect(d2fDxDy([1.0, 2.0]), 3.0);
      // d^2f / dy^2 = 6y -> at (1, 2): 12
      final d2fDy2 = hess[1][1].compile(['x', 'y']);
      expect(d2fDy2([1.0, 2.0]), 12.0);
    });

    test('Taylor series expansion of exp(x)', () {
      const x = Variable('x');
      const f = Exp(x);
      final taylor = Calculus.taylorSeries(f, 'x', point: 0.0, order: 4);

      final fn = taylor.compile1D('x');
      // At x = 0.5: exp(0.5) ~ 1.64872127
      // 1 + 0.5 + 0.5^2/2 + 0.5^3/6 + 0.5^4/24 ~ 1 + 0.5 + 0.125 + 0.0208333 + 0.00260416 = 1.6484375
      expect(fn(0.5), closeTo(1.6484375, 1e-4));
    });
  });
}
