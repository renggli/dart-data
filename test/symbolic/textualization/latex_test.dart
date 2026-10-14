import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('LaTeX - Atomic Expressions', () {
    test('variables', () {
      check(const Variable('x').toLatex()).equals('x');
      check(const Variable('theta').toLatex()).equals('theta');
      check(const Variable('alpha_1').toLatex()).equals('alpha_1');
    });

    test('numbers', () {
      check(const RationalNumber(0).toLatex()).equals('0');
      check(const RationalNumber(42).toLatex()).equals('42');
      check(const RationalNumber(-7).toLatex()).equals('-7');
      check(const RationalNumber(1, 2).toLatex()).equals(r'\frac{1}{2}');
      check(const RationalNumber(-1, 2).toLatex()).equals(r'-\frac{1}{2}');
      check(const RealNumber(3.14159).toLatex()).equals('3.14159');
      check(ConstantNumber.pi.toLatex()).equals(r'\pi');
      check(ConstantNumber.e.toLatex()).equals('e');
    });
  });

  group('LaTeX - Arithmetic Operations', () {
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
      check((const RationalNumber(12) * x).toLatex()).equals('12 x');
      check((const RationalNumber(1, 2) * x).toLatex())
          .equals(r'\frac{1}{2} x');
      check((const RationalNumber(12) * x * y).toLatex())
          .equals(r'12 x \cdot y');
      check(const Mul(RationalNumber(2), RationalNumber(3)).toLatex())
          .equals(r'2 \cdot 3');
      check(
        (const RationalNumber(2) * const RationalNumber(3).pow(x)).toLatex(),
      ).equals(r'2 \cdot {3}^{x}');
      check(
        (const RationalNumber(2) *
                const RationalNumber(3).pow(const RationalNumber(1, 2)))
            .toLatex(),
      ).equals(r'2 \sqrt{3}');
      check(((x + y) * z).toLatex()).equals('(x + y) \\cdot z');
      check((x * (y + z)).toLatex()).equals('x \\cdot (y + z)');
      check(((x + y) * (y - z)).toLatex()).equals('(x + y) \\cdot (y - z)');
      check((x * y * z).toLatex()).equals('x \\cdot y \\cdot z');
      check(Expr.parse('1 + -2 * x ^ 3').toLatex()).equals('1 + -2 {x}^{3}');
      check(
        Add(
          const RationalNumber(1),
          Mul(const RationalNumber(-2), x.pow(const RationalNumber(3))),
        ).toLatex(),
      ).equals('1 + -2 {x}^{3}');
    });

    test('division formatting as frac', () {
      check((x / y).toLatex()).equals('\\frac{x}{y}');
      check(((x + y) / (x - y)).toLatex()).equals('\\frac{x + y}{x - y}');
      check(((x * y) / (z + const RationalNumber(1))).toLatex())
          .equals('\\frac{x \\cdot y}{z + 1}');
    });

    test('power formatting and base wrapping', () {
      check(x.pow(y).toLatex()).equals('{x}^{y}');
      check((x + y).pow(z).toLatex()).equals('{(x + y)}^{z}');
      check((x * y).pow(z).toLatex()).equals('{(x \\cdot y)}^{z}');
      check((x / y).pow(z).toLatex()).equals('{(\\frac{x}{y})}^{z}');
      check((-x).pow(const RationalNumber(2)).toLatex()).equals('{(-x)}^{2}');
    });

    test('root formatting for fractional powers', () {
      check(x.pow(const RationalNumber(1, 2)).toLatex()).equals(r'\sqrt{x}');
      check((x + y).pow(const RationalNumber(1, 2)).toLatex())
          .equals(r'\sqrt{x + y}');
      check(x.pow(const RationalNumber(1, 3)).toLatex()).equals(r'\sqrt[3]{x}');
      check(x.pow(const RationalNumber(1, 5)).toLatex()).equals(r'\sqrt[5]{x}');
      check(x.pow(const RationalNumber(2, 3)).toLatex())
          .equals(r'{x}^{\frac{2}{3}}');
      check(x.pow(const RationalNumber(-1, 2)).toLatex())
          .equals(r'{x}^{-\frac{1}{2}}');
    });

    test('unary negation', () {
      check((-x).toLatex()).equals('-x');
      check((-(x + y)).toLatex()).equals('-(x + y)');
      check((-(x - y)).toLatex()).equals('-(x - y)');
      check((-(x * y)).toLatex()).equals('-x \\cdot y');
    });
  });

  group('LaTeX - Transcendentals', () {
    const x = Variable('x');
    const y = Variable('y');

    test('sine and cosine', () {
      check(const Sin(x).toLatex()).equals('\\sin(x)');
      check(const Cos(x).toLatex()).equals('\\cos(x)');
      check(Sin(x + y).toLatex()).equals('\\sin(x + y)');
      check(Cos(x * y).toLatex()).equals('\\cos(x \\cdot y)');
    });

    test('trigonometric, hyperbolic, and special functions', () {
      check(const Tan(x).toLatex()).equals('\\tan(x)');
      check(const Asin(x).toLatex()).equals('\\arcsin(x)');
      check(const Acos(x).toLatex()).equals('\\arccos(x)');
      check(const Atan(x).toLatex()).equals('\\arctan(x)');
      check(const Sinh(x).toLatex()).equals('\\sinh(x)');
      check(const Cosh(x).toLatex()).equals('\\cosh(x)');
      check(const Tanh(x).toLatex()).equals('\\tanh(x)');
      check(const Abs(x).toLatex()).equals('\\left|x\\right|');
      check(const Pow(x, RationalNumber(1, 2)).toLatex()).equals('\\sqrt{x}');
    });

    test('exponential and logarithm', () {
      check(const Exp(x).toLatex()).equals('e^{x}');
      check(Exp(x.pow(const RationalNumber(2))).toLatex())
          .equals('e^{{x}^{2}}');
      check(const Ln(x).toLatex()).equals('\\ln(x)');
      check(Ln(x + const RationalNumber(1)).toLatex()).equals('\\ln(x + 1)');
      check(
        const Add(
          RationalNumber(3),
          Mul(RationalNumber(4), ConstantNumber.i),
        ).toLatex(),
      ).equals('3 + 4 i');
      check(ConstantNumber.i.toLatex()).equals('i');
    });

    test('composite calculus expressions', () {
      final f =
          (x.pow(const RationalNumber(2)) + const RationalNumber(1)) /
          (x - const RationalNumber(1));
      check(f.toLatex()).equals('\\frac{{x}^{2} + 1}{x - 1}');

      final g = Exp(-x.pow(const RationalNumber(2)));
      check(g.toLatex()).equals('e^{-{x}^{2}}');

      check(ConstantNumber.infinity.toLatex()).equals(r'\infty');
      check(const Pow(Neg(ConstantNumber.i), RationalNumber(2)).toLatex())
          .equals('{(-i)}^{2}');
      check(
        const Mul(
          Add(RationalNumber(1), Mul(RationalNumber(2), ConstantNumber.i)),
          Variable('x'),
        ).toLatex(),
      ).equals(r'(1 + 2 i) \cdot x');
      check(
        const OrderTerm(
          'x',
          2,
          point: Add(Variable('a'), Variable('b')),
        ).toLatex(),
      ).equals('O((x - (a + b))^{2})');
    });
  });
}
