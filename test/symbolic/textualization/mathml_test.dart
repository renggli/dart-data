import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:test/test.dart';

void main() {
  group('MathML textualization', () {
    test('renders valid MathML wrapped in <math>...</math>', () {
      final mathml = Expr.parse('sqrt(x) + 1 / (x + 1)').toMathMl();
      check(mathml.startsWith('<math>')).isTrue();
      check(mathml.endsWith('</math>')).isTrue();
      check(mathml.contains('<msqrt>')).isTrue();
      check(mathml.contains('<mfrac>')).isTrue();
    });

    test('renders numbers, constants, variables, and functions to MathML', () {
      check(RationalNumber(2, 5).toMathMl())
          .equals('<math><mfrac><mn>2</mn><mn>5</mn></mfrac></math>');
      check(Constant.pi.toMathMl()).equals('<math><mi>π</mi></math>');
      check(const Variable('x').toMathMl()).equals('<math><mi>x</mi></math>');
      check(Expr.parse('x^2').toMathMl())
          .equals('<math><msup><mi>x</mi><mn>2</mn></msup></math>');
      check(const OrderTerm('x', 4).toMathMl()).contains('<mi>O</mi>');
    });

    test(
      'uses Unicode minus sign (U+2212) and clean radical/fraction structure',
      () {
        check(Expr.parse('sqrt(x)').toMathMl())
            .equals('<math><msqrt><mi>x</mi></msqrt></math>');
        check(Expr.parse('x - 2').toMathMl())
            .equals('<math><mrow><mi>x</mi><mo>−</mo><mn>2</mn></mrow></math>');
        check(IntegerNumber.of(-5).toMathMl())
            .equals('<math><mrow><mo>−</mo><mn>5</mn></mrow></math>');
        check(RationalNumber(-2, 5).toMathMl()).equals(
          '<math><mrow><mo>−</mo><mfrac><mn>2</mn><mn>5</mn></mfrac></mrow></math>',
        );
        check(Expr.parse('-x / 5').simplify().toMathMl()).equals(
          '<math><mrow><mo>−</mo><mfrac><mi>x</mi><mn>5</mn></mfrac></mrow></math>',
        );
        check(Expr.parse('a + b - c').toMathMl()).equals(
          '<math><mrow><mi>a</mi><mo>+</mo><mi>b</mi><mo>−</mo><mi>c</mi></mrow></math>',
        );
      },
    );
  });
}
