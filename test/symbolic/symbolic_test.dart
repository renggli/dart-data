import 'dart:math' as math;
import 'dart:typed_data';

import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:test/test.dart';

void main() {
  group('Expression AST creation & evaluation', () {
    test('basic arithmetic and evaluation', () {
      const x = Variable('x');
      final expr = (x * 2) + 5;
      check(expr.freeVariables).unorderedEquals({'x'});
      check(expr.dependsOn('x')).isTrue();
      check(expr.dependsOn('y')).isFalse();
      check(expr.evaluate({'x': 3.0})).equals(11.0);
      check(() => expr.evaluate({})).throws<ArgumentError>();
    });

    test('operator overloads and constructors', () {
      const x = Variable('x');
      const y = Variable('y');

      final add = x + y;
      check(add).isA<Add>();
      final sub = x - y;
      check(sub).isA<Sub>();
      final mul = x * y;
      check(mul).isA<Mul>();
      final div = x / y;
      check(div).isA<Div>();
      final neg = -x;
      check(neg).isA<Neg>();
      final pow = x.pow(y);
      check(pow).isA<Pow>();

      // Wrapping numeric scalars
      final addNum = x + 3;
      check(addNum).isA<Add>();
      final subNum = x - 3;
      check(subNum).isA<Sub>();
      final mulNum = x * 3;
      check(mulNum).isA<Mul>();
      final divNum = x / 3;
      check(divNum).isA<Div>();
      final powNum = x.pow(3);
      check(powNum).isA<Pow>();
    });

    test('LaTeX and string formatting for all AST nodes', () {
      const x = Variable('x');
      const y = Variable('y');

      check(x.toLatex()).equals('x');
      check(x.toString()).equals('x');

      check(const Constant(4.0).toLatex()).equals('4');
      check(const Constant(4.5).toLatex()).equals('4.5');

      const add = Add(x, y);
      check(add.toLatex()).equals('x + y');
      check(add.toString()).equals('(x + y)');

      const sub = Sub(x, y);
      check(sub.toLatex()).equals('x - y');
      check(sub.toString()).equals('(x - y)');

      const mul = Mul(x, y);
      check(mul.toLatex()).equals('x \\cdot y');
      check(mul.toString()).equals('(x * y)');

      const div = Div(x, y);
      check(div.toLatex()).equals('\\frac{x}{y}');
      check(div.toString()).equals('(x / y)');

      const pow = Pow(x, y);
      check(pow.toLatex()).equals('{x}^{y}');
      check(pow.toString()).equals('(x ^ y)');

      const neg = Neg(x);
      check(neg.toLatex()).equals('-x');
      check(neg.toString()).equals('(-x)');

      const sin = Sin(x);
      check(sin.toLatex()).equals('\\sin(x)');
      check(sin.toString()).equals('sin(x)');

      const cos = Cos(x);
      check(cos.toLatex()).equals('\\cos(x)');
      check(cos.toString()).equals('cos(x)');

      const exp = Exp(x);
      check(exp.toLatex()).equals('e^{x}');
      check(exp.toString()).equals('exp(x)');

      const ln = Ln(x);
      check(ln.toLatex()).equals('\\ln(x)');
      check(ln.toString()).equals('ln(x)');
    });

    test('Equality and hashCode across AST nodes', () {
      const x = Variable('x');
      const y = Variable('y');

      check(const Variable('x') == x).isTrue();
      check(const Variable('x').hashCode).equals(x.hashCode);
      check(x == y).isFalse();

      check(const Constant(3.0) == const Constant(3.0)).isTrue();
      check(const Constant(3.0).hashCode).equals(const Constant(3.0).hashCode);
      check(const Constant(3.0) == const Constant(4.0)).isFalse();

      check(const Add(x, y) == const Add(x, y)).isTrue();
      check(const Add(x, y).hashCode).equals(const Add(x, y).hashCode);
      check(const Sub(x, y) == const Sub(x, y)).isTrue();
      check(const Sub(x, y).hashCode).equals(const Sub(x, y).hashCode);
      check(const Mul(x, y) == const Mul(x, y)).isTrue();
      check(const Mul(x, y).hashCode).equals(const Mul(x, y).hashCode);
      check(const Div(x, y) == const Div(x, y)).isTrue();
      check(const Div(x, y).hashCode).equals(const Div(x, y).hashCode);
      check(const Pow(x, y) == const Pow(x, y)).isTrue();
      check(const Pow(x, y).hashCode).equals(const Pow(x, y).hashCode);
      check(const Neg(x) == const Neg(x)).isTrue();
      check(const Neg(x).hashCode).equals(const Neg(x).hashCode);
      check(const Sin(x) == const Sin(x)).isTrue();
      check(const Sin(x).hashCode).equals(const Sin(x).hashCode);
      check(const Cos(x) == const Cos(x)).isTrue();
      check(const Cos(x).hashCode).equals(const Cos(x).hashCode);
      check(const Exp(x) == const Exp(x)).isTrue();
      check(const Exp(x).hashCode).equals(const Exp(x).hashCode);
      check(const Ln(x) == const Ln(x)).isTrue();
      check(const Ln(x).hashCode).equals(const Ln(x).hashCode);
    });

    test('Substitution and freeVariables', () {
      const x = Variable('x');
      const y = Variable('y');
      const z = Variable('z');

      final expr =
          (x + y) * (x - y) / const Pow(x, z) +
          const Neg(Sin(x)) -
          const Cos(y) * const Exp(z) / const Ln(x);
      check(expr.freeVariables).unorderedEquals({'x', 'y', 'z'});
      check(expr.dependsOn('x')).isTrue();
      check(expr.dependsOn('w')).isFalse();

      final substituted = expr.substitute('x', const Constant(2.0));
      check(substituted.freeVariables).unorderedEquals({'y', 'z'});
      check(substituted.dependsOn('x')).isFalse();
    });
  });

  group('Exact Analytical Differentiation', () {
    test('polynomial differentiation', () {
      const x = Variable('x');
      final expr = x.pow(3);
      final df = expr.diff('x').simplify();
      final fn = df.compile1D('x');
      check(fn(2.0)).equals(12.0); // 3 * 4 = 12
    });

    test('product and quotient rule', () {
      const x = Variable('x');
      // Product: x^2 * sin(x)
      final expr = (x.pow(2)) * const Sin(x);
      final df = expr.diff('x').simplify();
      final dfCompiled = df.compile1D('x');
      check(dfCompiled(0.0)).equals(0.0);

      // Quotient: (x + 1) / (x - 1)
      final quotient = (x + 1) / (x - 1);
      final dq = quotient.diff('x').simplify();
      // d/dx ((x+1)/(x-1)) = ((x-1) - (x+1))/(x-1)^2 = -2 / (x-1)^2 -> at x = 3: -2 / 4 = -0.5
      final dqCompiled = dq.compile1D('x');
      check(dqCompiled(3.0)).isCloseTo(-0.5, 1e-6);
    });

    test('chain rule: exp(2*x) and cos(x)', () {
      const x = Variable('x');
      final expr = Exp(x * 2);
      final df = expr.diff('x').simplify();
      final dfCompiled = df.compile1D('x');
      check(dfCompiled(0.0)).equals(2.0);

      const cosine = Cos(x);
      final dc = cosine.diff('x').simplify();
      final dcCompiled = dc.compile1D('x');
      check(dcCompiled(0.0)).equals(0.0);
    });

    test('logarithm: ln(x)', () {
      const x = Variable('x');
      const expr = Ln(x);
      final df = expr.diff('x').simplify();
      final dfCompiled = df.compile1D('x');
      check(dfCompiled(2.0)).equals(0.5);
    });

    test('power rule branches', () {
      const x = Variable('x');

      // Neither depends
      check(const Pow(Constant(2.0), Constant(3.0)).diff('x'))
          .equals(const Constant(0.0));

      // Base only depends: x^3
      final bOnly = const Pow(x, Constant(3.0)).diff('x');
      check(bOnly.evaluate({'x': 2.0})).equals(12.0);

      // Exponent only depends: 2^x -> d/dx (2^x) = 2^x * ln(2)
      final eOnly = const Pow(Constant(2.0), x).diff('x');
      check(eOnly.evaluate({'x': 3.0})).isCloseTo(8.0 * math.log(2.0), 1e-6);

      // Both depend: x^x -> d/dx (x^x) = x^x * (ln(x) + 1)
      final both = const Pow(x, x).diff('x');
      check(both.evaluate({'x': 2.0}))
          .isCloseTo(4.0 * (math.log(2.0) + 1.0), 1e-6);
    });
  });

  group('Algebraic Simplification', () {
    test('identity reduction and constant folding', () {
      const x = Variable('x');
      const y = Variable('y');

      // (x * 0) + (1 * y) -> y
      final expr1 = (x * 0) + (y * 1);
      check(expr1.simplify()).equals(y);

      // (4 + 6) -> 10
      final expr2 = const Constant(4.0) + const Constant(6.0);
      check(expr2.simplify()).equals(const Constant(10.0));

      // (10 - 4) -> 6
      final exprSub = const Constant(10.0) - const Constant(4.0);
      check(exprSub.simplify()).equals(const Constant(6.0));

      // x - x -> 0
      final expr3 = x - x;
      check(expr3.simplify()).equals(const Constant(0.0));

      // x - 0 -> x
      check((x - 0).simplify()).equals(x);

      // 0 + x -> x, x + 0 -> x
      check((const Constant(0.0) + x).simplify()).equals(x);
      check((x + const Constant(0.0)).simplify()).equals(x);

      // x * 1 -> x, 1 * x -> x
      check((x * 1).simplify()).equals(x);
      check((const Constant(1.0) * x).simplify()).equals(x);

      // x * -1 -> -x, -1 * x -> -x
      check((x * -1).simplify()).equals(const Neg(x));
      check((const Constant(-1.0) * x).simplify()).equals(const Neg(x));

      // 0 * x -> 0
      check((const Constant(0.0) * x).simplify()).equals(const Constant(0.0));

      // 0 / x -> 0, x / 1 -> x, x / x -> 1
      check((const Constant(0.0) / x).simplify()).equals(const Constant(0.0));
      check((x / 1).simplify()).equals(x);
      check((x / x).simplify()).equals(const Constant(1.0));
      check((const Constant(6.0) / const Constant(2.0)).simplify())
          .equals(const Constant(3.0));
      check(() => (const Constant(6.0) / const Constant(0.0)).simplify())
          .throws<UnsupportedError>();

      // x^0 -> 1, x^1 -> x, 0^x -> 0, 1^x -> 1
      check(x.pow(0).simplify()).equals(const Constant(1.0));
      check(x.pow(1).simplify()).equals(x);
      check(const Constant(0.0).pow(x).simplify()).equals(const Constant(0.0));
      check(const Constant(1.0).pow(x).simplify()).equals(const Constant(1.0));
      check(const Constant(2.0).pow(const Constant(3.0)).simplify())
          .equals(const Constant(8.0));

      // Neg(-(-x)) -> x
      check(const Neg(Neg(x)).simplify()).equals(x);
      check(const Neg(Constant(5.0)).simplify()).equals(const Constant(-5.0));

      // Sin, Cos, Exp, Ln of Constants
      check(const Sin(Constant(0.0)).simplify()).equals(const Constant(0.0));
      check(const Cos(Constant(0.0)).simplify()).equals(const Constant(1.0));
      check(const Exp(Constant(0.0)).simplify()).equals(const Constant(1.0));
      check(const Ln(Constant(1.0)).simplify()).equals(const Constant(0.0));
      check(() => const Ln(Constant(0.0)).simplify()).throws<ArgumentError>();
    });
  });

  group('JIT Compilation & Tensor Kernel', () {
    test('compile1D zero-AST closure execution for all nodes', () {
      const x = Variable('x');
      const y = Variable('y');

      // Unrelated variable in 1D returns 0
      check(y.compile1D('x')(5.0)).equals(0.0);

      const complexExpr = Add(
        Sub(Mul(x, Constant(2.0)), Div(x, Constant(2.0))),
        Add(
          Pow(x, Constant(2.0)),
          Add(Neg(x), Add(Sin(x), Add(Cos(x), Add(Exp(x), Ln(x))))),
        ),
      );

      final fn = complexExpr.compile1D('x');
      final val = fn(2.0);
      check(val).isCloseTo(
        (2.0 * 2.0 - 2.0 / 2.0) +
            4.0 -
            2.0 +
            math.sin(2.0) +
            math.cos(2.0) +
            math.exp(2.0) +
            math.log(2.0),
        1e-6,
      );
    });

    test('compile multi-variable closure', () {
      const x = Variable('x');
      const y = Variable('y');
      final expr =
          (x * 2) +
          (y * 3) +
          const Neg(x) +
          const Sin(y) +
          const Cos(x) +
          const Exp(y) +
          const Ln(x) +
          const Pow(x, y);
      final compiled = expr.compile(['x', 'y']);

      final res = compiled([2.0, 1.0]);
      check(res).isCloseTo(
        4.0 +
            3.0 -
            2.0 +
            math.sin(1.0) +
            math.cos(2.0) +
            math.exp(1.0) +
            math.log(2.0) +
            2.0,
        1e-6,
      );

      // Unbound variable throws
      check(() => expr.compile(['x'])([2.0])).throws<ArgumentError>();
    });

    test('compileTensorKernel vectorized flat loop', () {
      const x = Variable('x');
      const y = Variable('y');
      final expr = (x * 2) + y;
      final kernel = expr.compileTensorKernel(['x', 'y']);

      final xData = Float64List.fromList([1.0, 2.0, 3.0, 4.0]);
      final yData = Float64List.fromList([10.0, 20.0, 30.0, 40.0]);
      final out = Float64List(4);

      kernel([xData, yData], out);
      check(out.toList()).deepEquals([12.0, 24.0, 36.0, 48.0]);
    });
  });

  group('Multivariable Calculus', () {
    test('Gradient and Hessian of f(x, y) = x^2 + 3xy + y^3', () {
      const x = Variable('x');
      const y = Variable('y');
      final expr = x.pow(2) + (x * y * 3) + y.pow(3);

      final grad = Calculus.gradient(expr, ['x', 'y']);
      check(grad.length).equals(2);

      final dfDx = grad[0].compile(['x', 'y']);
      final dfDy = grad[1].compile(['x', 'y']);

      check(dfDx([1.0, 2.0])).equals(8.0);
      check(dfDy([1.0, 2.0])).equals(15.0);

      final hess = Calculus.hessian(expr, ['x', 'y']);
      check(hess.length).equals(2);
      check(hess[0].length).equals(2);
      final d2fDx2 = hess[0][0].compile(['x', 'y']);
      check(d2fDx2([1.0, 2.0])).equals(2.0);
      final d2fDxDy = hess[0][1].compile(['x', 'y']);
      check(d2fDxDy([1.0, 2.0])).equals(3.0);
      final d2fDy2 = hess[1][1].compile(['x', 'y']);
      check(d2fDy2([1.0, 2.0])).equals(12.0);
    });

    test('Jacobian matrix', () {
      const x = Variable('x');
      const y = Variable('y');
      // f1(x, y) = x^2 + y
      // f2(x, y) = 3*x*y
      final f1 = x.pow(2) + y;
      final f2 = x * y * 3;

      final J = Calculus.jacobian([f1, f2], ['x', 'y']);
      check(J.length).equals(2);
      check(J[0].length).equals(2);

      // J[0][0] = 2x, J[0][1] = 1
      check(J[0][0].evaluate({'x': 3.0, 'y': 2.0})).equals(6.0);
      check(J[0][1].evaluate({'x': 3.0, 'y': 2.0})).equals(1.0);

      // J[1][0] = 3y, J[1][1] = 3x
      check(J[1][0].evaluate({'x': 3.0, 'y': 2.0})).equals(6.0);
      check(J[1][1].evaluate({'x': 3.0, 'y': 2.0})).equals(9.0);
    });

    test('Taylor series expansion of exp(x)', () {
      const x = Variable('x');
      const expr = Exp(x);
      final taylor = Calculus.taylorSeries(expr, 'x', point: 0.0, order: 4);

      final fn = taylor.compile1D('x');
      check(fn(0.5)).isCloseTo(1.6484375, 1e-4);
    });

    test('compilePositional with Sub and Div', () {
      const x = Variable('x');
      const y = Variable('y');
      const z = Variable('z');
      final expr = (x - y) / z;
      final fn = expr.compile(['x', 'y', 'z']);
      check(fn([10.0, 4.0, 2.0])).equals(3.0);
    });
  });
}
