import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:test/test.dart';

void main() {
  group('Standard ExprSyntax', () {
    test('parses integers, fractions, and decimals accurately', () {
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
    });

    test('parses built-in constants and functions', () {
      check(Expr.parse('pi')).equals(Constant.pi);
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
      check(Expr.parse('log(2, x)')).equals(Ln(x) / Ln(IntegerNumber.two));
      check(Expr.parse('lambertw(x, -1)')).equals(LambertW(x, branch: -1));
      check(Expr.parse('O(x^3)')).equals(const OrderTerm('x', 3));
    });

    test('precedence of exponentiation and unary negation', () {
      const x = Variable('x');
      // -x^2 is -(x^2), not (-x)^2
      final negSq = Expr.parse('-x^2');
      check(negSq)
          .equals(Mul([IntegerNumber.negativeOne, Pow(x, IntegerNumber.two)]));
      check(negSq.evaluate({'x': 3.0})).equals(-9.0);

      // (-x)^2 is Pow(-x, 2)
      final parenSq = Expr.parse('(-x)^2');
      check(parenSq.evaluate({'x': 3.0})).equals(9.0);

      // Signed exponent: x^-2
      final signedExp = Expr.parse('x^-2');
      check(signedExp).equals(Pow(x, IntegerNumber.of(-2)));

      // Right-associative power: 2^3^2 = 2^(3^2) = 512
      final rightAssoc = Expr.parse('2^3^2').simplify();
      check(rightAssoc).equals(IntegerNumber.of(512));
    });
  });

  group('Custom ExprSyntaxBuilder', () {
    test('custom constants, bound variables, and removing constants', () {
      final builder = ExprSyntax.standard().toBuilder()
        ..removeConstant('e')
        ..removeConstant('i')
        ..defineConstant(
          'phi',
          (IntegerNumber.one + Pow(IntegerNumber.of(5), FractionNumber.half)) /
              IntegerNumber.two,
        )
        ..defineVariable('r0', Expr.parse('x^2 + 1'));
      final syntax = builder.build();

      // e and i now parse as variables
      check(syntax.parse('e')).equals(const Variable('e'));
      check(syntax.parse('i')).equals(const Variable('i'));

      // r0 resolves to bound expression
      final reused = syntax.parse('2 * r0').expand().simplify();
      check(reused.toString()).equals('2 + 2 * x ^ 2');
    });

    test('implicit multiplication and custom functions', () {
      final builder = ExprSyntax.standard().toBuilder()
        ..implicitMultiplication = true
        ..defineBinaryFunction(
          'hypot',
          (a, b) => Pow(
            Pow(a, IntegerNumber.two) + Pow(b, IntegerNumber.two),
            FractionNumber.half,
          ),
        );
      final syntax = builder.build();

      final expr = syntax.parse('2x + 3(x + 1)').expand().simplify();
      check(expr.toString()).equals('3 + 5 * x');

      final h = syntax.parse('hypot(3, 4)').simplify();
      check(h).equals(IntegerNumber.of(5));
    });
  });
}
