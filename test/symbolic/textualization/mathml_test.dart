import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('MathML - Atomic Expressions', () {
    test('variables', () {
      check(const Variable('x').toMathMl()).equals('<math><mi>x</mi></math>');
      check(const Variable('theta').toMathMl())
          .equals('<math><mi>theta</mi></math>');
      check(const Variable('a&b').toMathMl())
          .equals('<math><mi>a&amp;b</mi></math>');
    });

    test('numbers', () {
      check(const RationalNumber(0).toMathMl())
          .equals('<math><mn>0</mn></math>');
      check(const RationalNumber(42).toMathMl())
          .equals('<math><mn>42</mn></math>');
      check(const RationalNumber(-7).toMathMl())
          .equals('<math><mn>-7</mn></math>');
      check(const RationalNumber(1, 2).toMathMl())
          .equals('<math><mfrac><mn>1</mn><mn>2</mn></mfrac></math>');
      check(const RealNumber(3.14).toMathMl())
          .equals('<math><mn>3.14</mn></math>');
      check(ConstantNumber.pi.toMathMl()).equals('<math><mi>π</mi></math>');
      check(ConstantNumber.e.toMathMl()).equals('<math><mi>e</mi></math>');
    });

    test('display and root configuration', () {
      const x = Variable('x');
      check(x.toMathMl(display: true))
          .equals('<math display="block"><mi>x</mi></math>');
      check(x.toMathMl(root: false)).equals('<mi>x</mi>');
    });
  });

  group('MathML - Arithmetic Operations', () {
    const x = Variable('x');
    const y = Variable('y');
    const z = Variable('z');

    test('addition', () {
      check((x + y).toMathMl())
          .equals('<math><mrow><mi>x</mi><mo>+</mo><mi>y</mi></mrow></math>');
      check((x + y + z).toMathMl()).equals(
        '<math><mrow><mrow><mi>x</mi><mo>+</mo><mi>y</mi></mrow><mo>+</mo><mi>z</mi></mrow></math>',
      );
    });

    test('subtraction and right associativity parentheses', () {
      check((x - y).toMathMl())
          .equals('<math><mrow><mi>x</mi><mo>-</mo><mi>y</mi></mrow></math>');
      check((x - (y + z)).toMathMl()).equals(
        '<math><mrow><mi>x</mi><mo>-</mo><mrow><mo>(</mo><mrow><mi>y</mi><mo>+</mo><mi>z</mi></mrow><mo>)</mo></mrow></mrow></math>',
      );
      check((x - (y - z)).toMathMl()).equals(
        '<math><mrow><mi>x</mi><mo>-</mo><mrow><mo>(</mo><mrow><mi>y</mi><mo>-</mo><mi>z</mi></mrow><mo>)</mo></mrow></mrow></math>',
      );
      check(((x - y) - z).toMathMl()).equals(
        '<math><mrow><mrow><mi>x</mi><mo>-</mo><mi>y</mi></mrow><mo>-</mo><mi>z</mi></mrow></math>',
      );
    });

    test('multiplication and precedence parentheses', () {
      check((x * y).toMathMl()).equals(
        '<math><mrow><mi>x</mi><mo>&#x22c5;</mo><mi>y</mi></mrow></math>',
      );
      check(((x + y) * z).toMathMl()).equals(
        '<math><mrow><mrow><mo>(</mo><mrow><mi>x</mi><mo>+</mo><mi>y</mi></mrow><mo>)</mo></mrow><mo>&#x22c5;</mo><mi>z</mi></mrow></math>',
      );
      check((x * (y + z)).toMathMl()).equals(
        '<math><mrow><mi>x</mi><mo>&#x22c5;</mo><mrow><mo>(</mo><mrow><mi>y</mi><mo>+</mo><mi>z</mi></mrow><mo>)</mo></mrow></mrow></math>',
      );
    });

    test('division formatting as mfrac', () {
      check((x / y).toMathMl())
          .equals('<math><mfrac><mi>x</mi><mi>y</mi></mfrac></math>');
      check(((x + y) / (x - y)).toMathMl()).equals(
        '<math><mfrac><mrow><mi>x</mi><mo>+</mo><mi>y</mi></mrow><mrow><mi>x</mi><mo>-</mo><mi>y</mi></mrow></mfrac></math>',
      );
    });

    test('power formatting and base wrapping', () {
      check(x.pow(y).toMathMl())
          .equals('<math><msup><mi>x</mi><mi>y</mi></msup></math>');
      check((x + y).pow(z).toMathMl()).equals(
        '<math><msup><mrow><mo>(</mo><mrow><mi>x</mi><mo>+</mo><mi>y</mi></mrow><mo>)</mo></mrow><mi>z</mi></msup></math>',
      );
      check((x * y).pow(z).toMathMl()).equals(
        '<math><msup><mrow><mo>(</mo><mrow><mi>x</mi><mo>&#x22c5;</mo><mi>y</mi></mrow><mo>)</mo></mrow><mi>z</mi></msup></math>',
      );
      check((-x).pow(const RationalNumber(2)).toMathMl()).equals(
        '<math><msup><mrow><mo>(</mo><mrow><mo>-</mo><mi>x</mi></mrow><mo>)</mo></mrow><mn>2</mn></msup></math>',
      );
    });

    test('root formatting with msqrt and mroot', () {
      check(x.pow(const RationalNumber(1, 2)).toMathMl())
          .equals('<math><msqrt><mrow><mi>x</mi></mrow></msqrt></math>');
      check((x + y).pow(const RationalNumber(1, 2)).toMathMl()).equals(
        '<math><msqrt><mrow><mi>x</mi><mo>+</mo><mi>y</mi></mrow></msqrt></math>',
      );
      check(x.pow(const RationalNumber(1, 3)).toMathMl()).equals(
        '<math><mroot><mrow><mi>x</mi></mrow><mrow><mn>3</mn></mrow></mroot></math>',
      );
      check(x.pow(const RationalNumber(1, 5)).toMathMl()).equals(
        '<math><mroot><mrow><mi>x</mi></mrow><mrow><mn>5</mn></mrow></mroot></math>',
      );
      check(x.pow(const RationalNumber(2, 3)).toMathMl()).equals(
        '<math><msup><mi>x</mi><mfrac><mn>2</mn><mn>3</mn></mfrac></msup></math>',
      );
      check(x.pow(const RationalNumber(-1, 2)).toMathMl()).equals(
        '<math><msup><mi>x</mi><mrow><mo>-</mo><mfrac><mn>1</mn><mn>2</mn></mfrac></mrow></msup></math>',
      );
    });

    test('unary negation', () {
      check((-x).toMathMl())
          .equals('<math><mrow><mo>-</mo><mi>x</mi></mrow></math>');
      check((-(x + y)).toMathMl()).equals(
        '<math><mrow><mo>-</mo><mrow><mo>(</mo><mrow><mi>x</mi><mo>+</mo><mi>y</mi></mrow><mo>)</mo></mrow></mrow></math>',
      );
      check((-(x - y)).toMathMl()).equals(
        '<math><mrow><mo>-</mo><mrow><mo>(</mo><mrow><mi>x</mi><mo>-</mo><mi>y</mi></mrow><mo>)</mo></mrow></mrow></math>',
      );
    });
  });

  group('MathML - Transcendentals', () {
    const x = Variable('x');
    const y = Variable('y');

    test('trigonometric and logarithm', () {
      check(const Sin(x).toMathMl()).equals(
        '<math><mrow><mi>sin</mi><mo>(</mo><mi>x</mi><mo>)</mo></mrow></math>',
      );
      check(const Cos(x).toMathMl()).equals(
        '<math><mrow><mi>cos</mi><mo>(</mo><mi>x</mi><mo>)</mo></mrow></math>',
      );
      check(const Tan(x).toMathMl()).equals(
        '<math><mrow><mi>tan</mi><mo>(</mo><mi>x</mi><mo>)</mo></mrow></math>',
      );
      check(const Asin(x).toMathMl()).equals(
        '<math><mrow><mi>arcsin</mi><mo>(</mo><mi>x</mi><mo>)</mo></mrow></math>',
      );
      check(const Acos(x).toMathMl()).equals(
        '<math><mrow><mi>arccos</mi><mo>(</mo><mi>x</mi><mo>)</mo></mrow></math>',
      );
      check(const Atan(x).toMathMl()).equals(
        '<math><mrow><mi>arctan</mi><mo>(</mo><mi>x</mi><mo>)</mo></mrow></math>',
      );
      check(const Sinh(x).toMathMl()).equals(
        '<math><mrow><mi>sinh</mi><mo>(</mo><mi>x</mi><mo>)</mo></mrow></math>',
      );
      check(const Cosh(x).toMathMl()).equals(
        '<math><mrow><mi>cosh</mi><mo>(</mo><mi>x</mi><mo>)</mo></mrow></math>',
      );
      check(const Tanh(x).toMathMl()).equals(
        '<math><mrow><mi>tanh</mi><mo>(</mo><mi>x</mi><mo>)</mo></mrow></math>',
      );
      check(const Abs(x).toMathMl())
          .equals('<math><mrow><mo>|</mo><mi>x</mi><mo>|</mo></mrow></math>');
      check(const Pow(x, RationalNumber(1, 2)).toMathMl())
          .equals('<math><msqrt><mrow><mi>x</mi></mrow></msqrt></math>');
      check(const Exp(x).toMathMl())
          .equals('<math><msup><mi>e</mi><mi>x</mi></msup></math>');
      check(const Ln(x).toMathMl()).equals(
        '<math><mrow><mi>ln</mi><mo>(</mo><mi>x</mi><mo>)</mo></mrow></math>',
      );
      check(const Log(RationalNumber(2), x).toMathMl()).equals(
        '<math><mrow><msub><mi>log</mi><mn>2</mn></msub><mo>(</mo><mi>x</mi><mo>)</mo></mrow></math>',
      );
      check(Sin(x + y).toMathMl()).equals(
        '<math><mrow><mi>sin</mi><mo>(</mo><mrow><mi>x</mi><mo>+</mo><mi>y</mi></mrow><mo>)</mo></mrow></math>',
      );
    });

    test('composite calculus expressions', () {
      final f =
          (x.pow(const RationalNumber(2)) + const RationalNumber(1)) /
          (x - const RationalNumber(1));
      check(f.toMathMl()).equals(
        '<math><mfrac><mrow><msup><mi>x</mi><mn>2</mn></msup><mo>+</mo><mn>1</mn></mrow><mrow><mi>x</mi><mo>-</mo><mn>1</mn></mrow></mfrac></math>',
      );

      final g = Exp(-x.pow(const RationalNumber(2)));
      check(g.toMathMl()).equals(
        '<math><msup><mi>e</mi><mrow><mo>-</mo><msup><mi>x</mi><mn>2</mn></msup></mrow></msup></math>',
      );
    });
  });
}
