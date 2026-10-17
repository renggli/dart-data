import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:test/test.dart';

void main() {
  group('MathML textualization', () {
    test('renders valid MathML wrapped in <math>...</math>', () {
      final mathml = Expr.parse('sqrt(x) + 1 / (x + 1)').toMathMl();
      check(mathml.startsWith('<math>')).isTrue();
      check(mathml.endsWith('</math>')).isTrue();
      check(mathml.contains('<mroot><mrow>')).isTrue();
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

    test('uses &minus; (with form="prefix" in prefix context) and <mroot><mrow>...</mrow>...</mroot>', () {
      check(Expr.parse('sqrt(x)').toMathMl())
          .equals('<math><mroot><mrow><mi>x</mi></mrow></mroot></math>');
      check(
        Expr.parse('x^(1/3)').toMathMl(),
      ).equals('<math><mroot><mrow><mi>x</mi></mrow><mn>3</mn></mroot></math>');
      check(Expr.parse('x - 2').toMathMl()).equals(
        '<math><mrow><mi>x</mi><mo>&minus;</mo><mn>2</mn></mrow></math>',
      );
      check(IntegerNumber.of(-5).toMathMl()).equals(
        '<math><mrow><mo form="prefix">&minus;</mo><mn>5</mn></mrow></math>',
      );
      check(RationalNumber(-2, 5).toMathMl()).equals(
        '<math><mrow><mo form="prefix">&minus;</mo><mfrac><mn>2</mn><mn>5</mn></mfrac></mrow></math>',
      );
      check(Expr.parse('-x / 5').simplify().toMathMl()).equals(
        '<math><mrow><mo form="prefix">&minus;</mo><mfrac><mi>x</mi><mn>5</mn></mfrac></mrow></math>',
      );
      check(Expr.parse('a + b - c').toMathMl()).equals(
        '<math><mrow><mi>a</mi><mo>+</mo><mi>b</mi><mo>&minus;</mo><mi>c</mi></mrow></math>',
      );
    });

    test(
      'renders function powers, partitioned product fractions, and integrals',
      () {
        check(Expr.parse('sin(x)^2').toMathMl()).equals(
          '<math><mrow><msup><mi>sin</mi><mn>2</mn></msup><mo>(</mo><mi>x</mi><mo>)</mo></mrow></math>',
        );
        check(Expr.parse('(1 / 2) * x').simplify().toMathMl())
            .equals('<math><mfrac><mi>x</mi><mn>2</mn></mfrac></math>');
        check(Integral(const Variable('x'), 'x').toMathMl()).equals(
          '<math><mrow><mo>&#x222B;</mo><mi>x</mi><mspace width="thinmathspace"/><mi>d</mi><mi>x</mi></mrow></math>',
        );
        check(
          Integral(
            const Variable('t'),
            't',
            lower: IntegerNumber.zero,
            upper: IntegerNumber.one,
          ).toMathMl(),
        ).equals(
          '<math><mrow><msubsup><mo>&#x222B;</mo><mn>0</mn><mn>1</mn></msubsup><mi>t</mi><mspace width="thinmathspace"/><mi>d</mi><mi>t</mi></mrow></math>',
        );
      },
    );
  });
}
