import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:test/test.dart';

void main() {
  group('MathML root, display, numbers, and complex literals', () {
    test('renders valid MathML with display and root options', () {
      const x = Variable('x');
      check(x.toMathMl()).equals('<math><mi>x</mi></math>');
      check(x.toMathMl(display: true))
          .equals('<math display="block"><mi>x</mi></math>');
      check(x.toMathMl(root: false)).equals('<mi>x</mi>');
      check(const Variable('a<b&c>"\'').toMathMl(root: false))
          .equals('<mi>a&lt;b&amp;c&gt;&quot;&apos;</mi>');
    });

    test(
      'renders integers, reals, fractions, and complex numbers to MathML',
      () {
        check(RationalNumber(2, 5).toMathMl())
            .equals('<math><mfrac><mn>2</mn><mn>5</mn></mfrac></math>');
        check(RationalNumber(-2, 5).toMathMl()).equals(
          '<math><mrow><mo form="prefix">&minus;</mo><mfrac><mn>2</mn><mn>5</mn></mfrac></mrow></math>',
        );
        check(const RealNumber(1.5).toMathMl(root: false))
            .equals('<mn>1.5</mn>');
        check(const RealNumber(-1.5).toMathMl(root: false))
            .equals('<mrow><mo form="prefix">&minus;</mo><mn>1.5</mn></mrow>');
        check(Constant.pi.toMathMl()).equals('<math><mi>π</mi></math>');

        check(ComplexNumber.i.toMathMl(root: false)).equals('<mi>i</mi>');
        check(ComplexNumber.negativeI.toMathMl(root: false))
            .equals('<mrow><mo form="prefix">&minus;</mo><mi>i</mi></mrow>');
        check(
          ComplexNumber(
            IntegerNumber.zero,
            IntegerNumber.of(-3),
          ).toMathMl(root: false),
        ).equals(
          '<mrow><mo form="prefix">&minus;</mo><mn>3</mn><mi>i</mi></mrow>',
        );
        check(
          ComplexNumber(
            IntegerNumber.zero,
            IntegerNumber.of(3),
          ).toMathMl(root: false),
        ).equals('<mrow><mn>3</mn><mi>i</mi></mrow>');
        check(
          const ComplexNumber(
            IntegerNumber.two,
            IntegerNumber.one,
          ).toMathMl(root: false),
        ).equals('<mrow><mn>2</mn><mo>+</mo><mi>i</mi></mrow>');
        check(
          const ComplexNumber(
            IntegerNumber.two,
            IntegerNumber.negativeOne,
          ).toMathMl(root: false),
        ).equals('<mrow><mn>2</mn><mo>&minus;</mo><mi>i</mi></mrow>');
        check(
          ComplexNumber(
            IntegerNumber.two,
            IntegerNumber.of(-3),
          ).toMathMl(root: false),
        ).equals(
          '<mrow><mn>2</mn><mo>&minus;</mo><mrow><mn>3</mn><mi>i</mi></mrow></mrow>',
        );
        check(
          ComplexNumber(
            IntegerNumber.two,
            IntegerNumber.of(3),
          ).toMathMl(root: false),
        ).equals(
          '<mrow><mn>2</mn><mo>+</mo><mrow><mn>3</mn><mi>i</mi></mrow></mrow>',
        );
      },
    );
  });

  group('MathML operators, functions, OrderTerm, Piecewise, and Integral', () {
    test(
      'renders roots, sums, products, and all elementary and special functions',
      () {
        const x = Variable('x');
        const y = Variable('y');

        check(Add(const []).toMathMl(root: false)).equals('<mn>0</mn>');
        check(Add([x]).toMathMl(root: false)).equals('<mi>x</mi>');
        check(Mul(const []).toMathMl(root: false)).equals('<mn>1</mn>');
        check(Mul([x]).toMathMl(root: false)).equals('<mi>x</mi>');
        check(Mul([IntegerNumber.of(-2), x]).toMathMl(root: false)).equals(
          '<mrow><mo form="prefix">&minus;</mo><mn>2</mn><mspace width="0.167em"/><mi>x</mi></mrow>',
        );
        check(Mul([IntegerNumber.negativeOne, x + y]).toMathMl(root: false))
            .equals(
              '<mrow><mo form="prefix">&minus;</mo><mrow><mo>(</mo><mrow><mi>x</mi><mo>+</mo><mi>y</mi></mrow><mo>)</mo></mrow></mrow>',
            );

        check(Expr.parse('sqrt(x)').toMathMl())
            .equals('<math><mroot><mrow><mi>x</mi></mrow></mroot></math>');
        check(Expr.parse('x^(1/3)').toMathMl()).equals(
          '<math><mroot><mrow><mi>x</mi></mrow><mn>3</mn></mroot></math>',
        );
        check(Pow(Constant.e, x).toMathMl(root: false))
            .equals('<msup><mi>e</mi><mi>x</mi></msup>');
        check(Pow(x, IntegerNumber.negativeOne).toMathMl(root: false))
            .equals('<mfrac><mn>1</mn><mi>x</mi></mfrac>');
        check(Pow(x + y, IntegerNumber.two).toMathMl(root: false)).equals(
          '<msup><mrow><mo>(</mo><mrow><mi>x</mi><mo>+</mo><mi>y</mi></mrow><mo>)</mo></mrow><mn>2</mn></msup>',
        );

        check(Sin(x).toMathMl(root: false))
            .equals('<mrow><mi>sin</mi><mo>(</mo><mi>x</mi><mo>)</mo></mrow>');
        check(Cos(x).toMathMl(root: false))
            .equals('<mrow><mi>cos</mi><mo>(</mo><mi>x</mi><mo>)</mo></mrow>');
        check(Tan(x).toMathMl(root: false))
            .equals('<mrow><mi>tan</mi><mo>(</mo><mi>x</mi><mo>)</mo></mrow>');
        check(
          Asin(x).toMathMl(root: false),
        ).equals('<mrow><mi>arcsin</mi><mo>(</mo><mi>x</mi><mo>)</mo></mrow>');
        check(
          Acos(x).toMathMl(root: false),
        ).equals('<mrow><mi>arccos</mi><mo>(</mo><mi>x</mi><mo>)</mo></mrow>');
        check(
          Atan(x).toMathMl(root: false),
        ).equals('<mrow><mi>arctan</mi><mo>(</mo><mi>x</mi><mo>)</mo></mrow>');
        check(Sinh(x).toMathMl(root: false))
            .equals('<mrow><mi>sinh</mi><mo>(</mo><mi>x</mi><mo>)</mo></mrow>');
        check(Cosh(x).toMathMl(root: false))
            .equals('<mrow><mi>cosh</mi><mo>(</mo><mi>x</mi><mo>)</mo></mrow>');
        check(Tanh(x).toMathMl(root: false))
            .equals('<mrow><mi>tanh</mi><mo>(</mo><mi>x</mi><mo>)</mo></mrow>');
        check(
          Asinh(x).toMathMl(root: false),
        ).equals('<mrow><mi>asinh</mi><mo>(</mo><mi>x</mi><mo>)</mo></mrow>');
        check(
          Acosh(x).toMathMl(root: false),
        ).equals('<mrow><mi>acosh</mi><mo>(</mo><mi>x</mi><mo>)</mo></mrow>');
        check(
          Atanh(x).toMathMl(root: false),
        ).equals('<mrow><mi>atanh</mi><mo>(</mo><mi>x</mi><mo>)</mo></mrow>');
        check(Abs(x).toMathMl(root: false))
            .equals('<mrow><mo>|</mo><mi>x</mi><mo>|</mo></mrow>');
        check(Ln(x).toMathMl(root: false))
            .equals('<mrow><mi>ln</mi><mo>(</mo><mi>x</mi><mo>)</mo></mrow>');
        check(LambertW(x).toMathMl(root: false))
            .equals('<mrow><mi>W</mi><mo>(</mo><mi>x</mi><mo>)</mo></mrow>');
        check(LambertW(x, branch: -1).toMathMl(root: false))
            .contains('<msub><mi>W</mi>');
        check(Erf(x).toMathMl(root: false))
            .equals('<mrow><mi>erf</mi><mo>(</mo><mi>x</mi><mo>)</mo></mrow>');
        check(Erfc(x).toMathMl(root: false))
            .equals('<mrow><mi>erfc</mi><mo>(</mo><mi>x</mi><mo>)</mo></mrow>');
        check(Gamma(x).toMathMl(root: false))
            .equals('<mrow><mi>Γ</mi><mo>(</mo><mi>x</mi><mo>)</mo></mrow>');
        check(Beta(x, y).toMathMl(root: false)).equals(
          '<mrow><mi>B</mi><mo>(</mo><mi>x</mi><mo>,</mo><mi>y</mi><mo>)</mo></mrow>',
        );
      },
    );

    test('renders OrderTerm, RelationalExpr, Piecewise, Integral, and multiplication spacing', () {
      const x = Variable('x');
      check(const OrderTerm('x', 0).toMathMl(root: false))
          .equals('<mrow><mi>O</mi><mo>(</mo><mn>1</mn><mo>)</mo></mrow>');
      check(const OrderTerm('x', 1).toMathMl(root: false))
          .equals('<mrow><mi>O</mi><mo>(</mo><mi>x</mi><mo>)</mo></mrow>');
      check(const OrderTerm('x', 4).toMathMl()).contains('<mi>O</mi>');
      check(
        const OrderTerm('x', 1, point: IntegerNumber.one).toMathMl(root: false),
      ).contains('<mo>&minus;</mo>');
      check(
        const OrderTerm('x', 3, point: IntegerNumber.one).toMathMl(root: false),
      ).contains('<msup>');

      check(LessThan(x, IntegerNumber.zero).toMathMl(root: false))
          .equals('<mrow><mi>x</mi><mo>&lt;</mo><mn>0</mn></mrow>');
      check(LessEqual(x, IntegerNumber.zero).toMathMl(root: false))
          .equals('<mrow><mi>x</mi><mo>&#x2264;</mo><mn>0</mn></mrow>');
      check(GreaterThan(x, IntegerNumber.zero).toMathMl(root: false))
          .equals('<mrow><mi>x</mi><mo>&gt;</mo><mn>0</mn></mrow>');
      check(GreaterEqual(x, IntegerNumber.zero).toMathMl(root: false))
          .equals('<mrow><mi>x</mi><mo>&#x2265;</mo><mn>0</mn></mrow>');
      check(Equal(x, IntegerNumber.zero).toMathMl(root: false))
          .equals('<mrow><mi>x</mi><mo>=</mo><mn>0</mn></mrow>');

      check(Expr.parse('piecewise(x < 0, -x, x)').toMathMl(root: false))
          .contains('<mtable>');
      check(
        Piecewise([(LessThan(x, IntegerNumber.zero), -x)])
            .toMathMl(root: false),
      ).contains('<mtable>');

      check(Expr.parse('sin(x)^2').toMathMl()).equals(
        '<math><mrow><msup><mi>sin</mi><mn>2</mn></msup><mo>(</mo><mi>x</mi><mo>)</mo></mrow></math>',
      );
      check(Expr.parse('(1 / 2) * x').simplify().toMathMl())
          .equals('<math><mfrac><mi>x</mi><mn>2</mn></mfrac></math>');
      check(Mul([Pow(x, IntegerNumber.of(-2))]).toMathMl(root: false)).equals(
        '<msup><mi>x</mi><mrow><mo form="prefix">&minus;</mo><mn>2</mn></mrow></msup>',
      );
      check(
        Mul([IntegerNumber.one, Pow(x, IntegerNumber.of(-2))])
            .toMathMl(root: false),
      ).equals('<mfrac><mn>1</mn><msup><mi>x</mi><mn>2</mn></msup></mfrac>');

      check(Integral(x, 'x').toMathMl()).equals(
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

      check(Expr.parse('2 * x').toMathMl()).equals(
        '<math><mrow><mn>2</mn><mspace width="0.167em"/><mi>x</mi></mrow></math>',
      );
      check(Mul([FractionNumber.negativeHalf, x]).toMathMl()).equals(
        '<math><mrow><mo form="prefix">&minus;</mo><mfrac><mi>x</mi><mn>2</mn></mfrac></mrow></math>',
      );
      check(
        Add([
          x,
          Mul([IntegerNumber.negativeOne, x + const Variable('y')]),
        ]).toMathMl(root: false),
      ).equals(
        '<mrow><mi>x</mi><mo>&minus;</mo><mrow><mo>(</mo><mrow><mi>x</mi><mo>+</mo><mi>y</mi></mrow><mo>)</mo></mrow></mrow>',
      );
      check(Expr.parse('2 * x * y').toMathMl()).equals(
        '<math><mrow><mn>2</mn><mspace width="0.167em"/><mi>x</mi><mspace width="0.167em"/><mi>y</mi></mrow></math>',
      );
      check(Expr.parse('ab * c').toMathMl()).equals(
        '<math><mrow><mi>ab</mi><mspace width="0.167em"/><mi>c</mi></mrow></math>',
      );
      check(Mul([IntegerNumber.two, IntegerNumber.of(3)]).toMathMl()).equals(
        '<math><mrow><mn>2</mn><mo>&#x22c5;</mo><mn>3</mn></mrow></math>',
      );
      check(Expr.parse('(x - 1) * (x + 1)').toMathMl()).equals(
        '<math><mrow><mrow><mo>(</mo><mrow><mi>x</mi><mo>&minus;</mo><mn>1</mn></mrow><mo>)</mo></mrow><mspace width="0.167em"/><mrow><mo>(</mo><mrow><mi>x</mi><mo>+</mo><mn>1</mn></mrow><mo>)</mo></mrow></mrow></math>',
      );
      check(Mul([IntegerNumber.negativeOne, x, const Variable('y')]).toMathMl())
          .equals(
            '<math><mrow><mo form="prefix">&minus;</mo><mrow><mi>x</mi><mspace width="0.167em"/><mi>y</mi></mrow></mrow></math>',
          );
    });
  });
}
