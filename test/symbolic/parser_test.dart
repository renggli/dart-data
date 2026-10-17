import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:test/test.dart';

void main() {
  group('Standard ExprSyntax', () {
    test('parses integers, fractions, scientific notation, and decimals accurately', () {
      final intExpr = Expr.parse('42');
      check(intExpr).isA<IntegerNumber>();
      check(intExpr).equals(IntegerNumber.of(42));

      final bigIntExpr = Expr.parse('123456789012345678901234567890');
      check(bigIntExpr).isA<IntegerNumber>();
      check((bigIntExpr as IntegerNumber).value.isBig).isTrue();

      final fracExpr = Expr.parse('3 / 6');
      check(fracExpr).isA<FractionNumber>();
      check(fracExpr).equals(FractionNumber.half);

      final realExpr = Expr.parse('0.5');
      check(realExpr).isA<RealNumber>();
      check(realExpr).equals(const RealNumber(0.5));

      check(Expr.parse('.25')).equals(const RealNumber(0.25));
      check(Expr.parse('1.5e-2')).equals(const RealNumber(0.015));
      check(Expr.parse('2E+3')).equals(const RealNumber(2000.0));
    });

    test('parses built-in constants, functions, OrderTerm, and Piecewise', () {
      check(Expr.parse('pi')).equals(Constant.pi);
      check(Expr.parse('PI')).equals(Constant.pi);
      check(Expr.parse('π')).equals(Constant.pi);
      check(Expr.parse('e')).equals(Constant.e);
      check(Expr.parse('i')).equals(ComplexNumber.i);
      check(Expr.parse('infinity')).equals(Constant.infinity);
      check(Expr.parse('∞')).equals(Constant.infinity);
      // Capital I is not treated as imaginary unit by default
      check(Expr.parse('I')).equals(const Variable('I'));

      const x = Variable('x');
      check(Expr.parse('sqrt(x)')).equals(Pow(x, FractionNumber.half));
      check(Expr.parse('exp(x)')).equals(Pow(Constant.e, x));
      check(Expr.parse('ln(x)')).equals(Ln(x));
      check(Expr.parse('SIN(x)')).equals(Sin(x));
      check(Expr.parse('pow(x, 2)')).equals(Pow(x, IntegerNumber.two));
      check(Expr.parse('root(x, 3)'))
          .equals(Pow(x, IntegerNumber.one / IntegerNumber.of(3)));
      check(Expr.parse('log(2, x)')).equals(Ln(x) / Ln(IntegerNumber.two));
      check(Expr.parse('lambertw(x, -1)')).equals(LambertW(x, branch: -1));
      check(Expr.parse('lambertw(x, 0)')).equals(LambertW(x));

      // OrderTerm forms
      check(Expr.parse('O(1)')).equals(const OrderTerm('x', 0));
      check(Expr.parse('O(x)')).equals(const OrderTerm('x', 1));
      check(Expr.parse('O(x^3)')).equals(const OrderTerm('x', 3));
      check(Expr.parse('O(x - 1)'))
          .equals(const OrderTerm('x', 1, point: IntegerNumber.one));
      check(Expr.parse('O((x - 1)^3)'))
          .equals(const OrderTerm('x', 3, point: IntegerNumber.one));

      // Relational operators
      check(Expr.parse('x < 1')).equals(LessThan(x, IntegerNumber.one));
      check(Expr.parse('x <= 1')).equals(LessEqual(x, IntegerNumber.one));
      check(Expr.parse('x > 1')).equals(GreaterThan(x, IntegerNumber.one));
      check(Expr.parse('x >= 1')).equals(GreaterEqual(x, IntegerNumber.one));
      check(Expr.parse('x == 1')).equals(Equal(x, IntegerNumber.one));
      check(Expr.parse('x = 1')).equals(Equal(x, IntegerNumber.one));
    });

    test(
      'precedence of exponentiation, unary + and -, and error diagnostics',
      () {
        const x = Variable('x');
        check(Expr.parse('+x')).equals(x);

        // -x^2 is -(x^2), not (-x)^2
        final negSq = Expr.parse('-x^2');
        check(
          negSq,
        ).equals(Mul([IntegerNumber.negativeOne, Pow(x, IntegerNumber.two)]));
        check(negSq.evaluate({'x': 3.0})).equals(-9.0);

        // (-x)^2 is Pow(-x, 2)
        final parenSq = Expr.parse('(-x)^2');
        check(parenSq.evaluate({'x': 3.0})).equals(9.0);

        // Signed exponent: x^-2 and x^+2
        check(Expr.parse('x^-2')).equals(Pow(x, IntegerNumber.of(-2)));
        check(Expr.parse('x^+2')).equals(Pow(x, IntegerNumber.two));

        // Right-associative power: 2^3^2 = 2^(3^2) = 512
        final rightAssoc = Expr.parse('2^3^2').simplify();
        check(rightAssoc).equals(IntegerNumber.of(512));

        // Syntax and function errors
        final syntax = ExprSyntax.standard();
        check(() => syntax.parse('unknownUnary(x)')).throws<FormatException>();
        check(() => syntax.parse('unknownBinary(x, y)'))
            .throws<FormatException>();
        check(() => syntax.parse('sin(x, y, z)')).throws<FormatException>();
        check(() => syntax.parse('lambertw(x, 2)')).throws<FormatException>();
        check(() => syntax.parse('O(sin(x))')).throws<FormatException>();
        check(() => syntax.parse('piecewise(x < 0)')).throws<FormatException>();
        check(() => syntax.parse('piecewise(x + 1, 2)'))
            .throws<FormatException>();
        check(() => syntax.parse('x +')).throws<FormatException>();
        check(syntax.tryParse('unknownUnary(x)')).isNull();
        check(syntax.tryParse('x +')).isNull();
      },
    );
  });

  group('Custom ExprSyntaxBuilder', () {
    test('custom constants, bound variables, removing, and clearing', () {
      final builder = ExprSyntax.standard().toBuilder()
        ..removeConstant('e')
        ..removeConstant('i')
        ..defineConstant(
          'phi',
          (IntegerNumber.one + Pow(IntegerNumber.of(5), FractionNumber.half)) /
              IntegerNumber.two,
          aliases: const ['golden'],
        )
        ..defineVariable('r0', Expr.parse('x^2 + 1'))
        ..defineVariable('r1', IntegerNumber.two)
        ..removeVariable('r1');
      final syntax = builder.build();

      // e, i, and r1 now parse as variables
      check(syntax.parse('e')).equals(const Variable('e'));
      check(syntax.parse('i')).equals(const Variable('i'));
      check(syntax.parse('r1')).equals(const Variable('r1'));
      check(syntax.parse('golden')).equals(syntax.parse('phi'));

      // r0 resolves to bound expression
      final reused = syntax.parse('2 * r0').expand().simplify();
      check(reused.toString()).equals('2 + 2 * x ^ 2');

      final cleared = syntax.toBuilder()
        ..clearConstants()
        ..clearVariables();
      final clearedSyntax = cleared.build();
      check(clearedSyntax.parse('pi')).equals(const Variable('pi'));
      check(clearedSyntax.parse('r0')).equals(const Variable('r0'));
    });

    test('implicit multiplication, custom functions, removeFunction, and case sensitivity', () {
      final builder = ExprSyntax.standard().toBuilder()
        ..implicitMultiplication = true
        ..caseInsensitiveConstants = false
        ..caseInsensitiveFunctions = false
        ..removeFunction('sin')
        ..defineUnaryFunction(
          'doubleIt',
          (a) => IntegerNumber.two * a,
          aliases: const ['dbl'],
        )
        ..defineBinaryFunction(
          'hypot',
          (a, b) => Pow(
            Pow(a, IntegerNumber.two) + Pow(b, IntegerNumber.two),
            FractionNumber.half,
          ),
          aliases: const ['pythag'],
        )
        ..defineVariadicFunction('sumAll', Add.new, aliases: const ['total']);
      final syntax = builder.build();

      final expr = syntax.parse('2x + 3(x + 1)').expand().simplify();
      check(expr.toString()).equals('3 + 5 * x');

      check(syntax.parse('dbl(3)').simplify()).equals(IntegerNumber.of(6));
      check(syntax.parse('pythag(3, 4)').simplify())
          .equals(IntegerNumber.of(5));
      check(syntax.parse('total(1, 2, 3)').simplify())
          .equals(IntegerNumber.of(6));
      check(() => syntax.parse('sin(x)')).throws<FormatException>();
    });
  });
}
