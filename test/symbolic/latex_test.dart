import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('LaTeX Serialization - Atomic Expressions', () {
    test('variables', () {
      check(const Variable('x').toLatex()).equals('x');
      check(const Variable('theta').toLatex()).equals('theta');
      check(const Variable('alpha_1').toLatex()).equals('alpha_1');
    });

    test('constants', () {
      check(const Constant(0.0).toLatex()).equals('0');
      check(const Constant(42.0).toLatex()).equals('42');
      check(const Constant(-7.0).toLatex()).equals('-7');
      check(const Constant(3.14159).toLatex()).equals('3.14159');
    });
  });

  group('LaTeX Serialization - Arithmetic Operations', () {
    const x = Variable('x');
    const y = Variable('y');
    const z = Variable('z');

    test('addition', () {
      check((x + y).toLatex()).equals('x + y');
      check((x + y + z).toLatex()).equals('x + y + z');
    });

    test('subtraction and right associativity parentheses', () {
      check((x - y).toLatex()).equals('x - y');
      check((x - (y + z)).toLatex()).equals('x - (y + z)');
      check((x - (y - z)).toLatex()).equals('x - (y - z)');
      check(((x - y) - z).toLatex()).equals('x - y - z');
    });

    test('multiplication and precedence parentheses', () {
      check((x * y).toLatex()).equals('x \\cdot y');
      check(((x + y) * z).toLatex()).equals('(x + y) \\cdot z');
      check((x * (y + z)).toLatex()).equals('x \\cdot (y + z)');
      check(((x + y) * (y - z)).toLatex()).equals('(x + y) \\cdot (y - z)');
      check((x * y * z).toLatex()).equals('x \\cdot y \\cdot z');
    });

    test('division formatting as frac', () {
      check((x / y).toLatex()).equals('\\frac{x}{y}');
      check(((x + y) / (x - y)).toLatex()).equals('\\frac{x + y}{x - y}');
      check(((x * y) / (z + const Constant(1.0))).toLatex())
          .equals('\\frac{x \\cdot y}{z + 1}');
    });

    test('power formatting and base wrapping', () {
      check(x.pow(y).toLatex()).equals('{x}^{y}');
      check((x + y).pow(z).toLatex()).equals('{(x + y)}^{z}');
      check((x * y).pow(z).toLatex()).equals('{(x \\cdot y)}^{z}');
      check((x / y).pow(z).toLatex()).equals('{(\\frac{x}{y})}^{z}');
      check((-x).pow(const Constant(2.0)).toLatex()).equals('{(-x)}^{2}');
    });

    test('unary negation', () {
      check((-x).toLatex()).equals('-x');
      check((-(x + y)).toLatex()).equals('-(x + y)');
      check((-(x - y)).toLatex()).equals('-(x - y)');
      check((-(x * y)).toLatex()).equals('-x \\cdot y');
    });
  });

  group('LaTeX Serialization - Transcendentals', () {
    const x = Variable('x');
    const y = Variable('y');

    test('sine and cosine', () {
      check(const Sin(x).toLatex()).equals('\\sin(x)');
      check(const Cos(x).toLatex()).equals('\\cos(x)');
      check(Sin(x + y).toLatex()).equals('\\sin(x + y)');
      check(Cos(x * y).toLatex()).equals('\\cos(x \\cdot y)');
    });

    test('exponential and logarithm', () {
      check(const Exp(x).toLatex()).equals('e^{x}');
      check(Exp(x.pow(const Constant(2.0))).toLatex()).equals('e^{{x}^{2}}');
      check(const Ln(x).toLatex()).equals('\\ln(x)');
      check(Ln(x + const Constant(1.0)).toLatex()).equals('\\ln(x + 1)');
    });

    test('composite calculus expressions', () {
      // f(x) = (x^2 + 1) / (x - 1)
      final f =
          (x.pow(const Constant(2.0)) + const Constant(1.0)) /
          (x - const Constant(1.0));
      check(f.toLatex()).equals('\\frac{{x}^{2} + 1}{x - 1}');

      // g(x) = exp(-x^2)
      final g = Exp(-x.pow(const Constant(2.0)));
      check(g.toLatex()).equals('e^{-{x}^{2}}');
    });
  });
}
