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

    test('parses built-in constants, functions, OrderTerm, Piecewise, Integral, and case-sensitive identifiers', () {
      check(Expr.parse('pi')).equals(Constant.pi);
      check(Expr.parse('π')).equals(Constant.pi);
      check(Expr.parse('e')).equals(Constant.e);
      check(Expr.parse('i')).equals(ComplexNumber.i);
      check(Expr.parse('infinity')).equals(Constant.infinity);
      check(Expr.parse('∞')).equals(Constant.infinity);

      // Identifiers are strictly case-sensitive; uppercase PI, E, I parse as Variables
      check(Expr.parse('PI')).equals(const Variable('PI'));
      check(Expr.parse('E')).equals(const Variable('E'));
      check(Expr.parse('I')).equals(const Variable('I'));

      // Unicode identifiers (non-whitespace, non-number, non-math-symbol)
      check(Expr.parse('α + β'))
          .equals(const Variable('α') + const Variable('β'));
      check(Expr.parse('ℏ * ω'))
          .equals(const Variable('ℏ') * const Variable('ω'));

      const x = Variable('x');
      check(Expr.parse('sqrt(x)')).equals(Pow(x, FractionNumber.half));
      check(Expr.parse('exp(x)')).equals(Pow(Constant.e, x));
      check(Expr.parse('ln(x)')).equals(Ln(x));
      check(Expr.parse('log2(x)')).equals(Ln(x) / Ln(IntegerNumber.two));
      check(Expr.parse('log10(x)')).equals(Ln(x) / Ln(IntegerNumber.of(10)));
      check(Expr.parse('sin(x)')).equals(Sin(x));
      check(Expr.parse('sec(x)'))
          .equals(Pow(Cos(x), IntegerNumber.negativeOne));
      check(Expr.parse('csc(x)'))
          .equals(Pow(Sin(x), IntegerNumber.negativeOne));
      check(Expr.parse('cot(x)')).equals(Cos(x) / Sin(x));
      check(Expr.parse('asec(x)'))
          .equals(Acos(Pow(x, IntegerNumber.negativeOne)));
      check(Expr.parse('arcsec(x)'))
          .equals(Acos(Pow(x, IntegerNumber.negativeOne)));
      check(Expr.parse('acsc(x)'))
          .equals(Asin(Pow(x, IntegerNumber.negativeOne)));
      check(Expr.parse('arccsc(x)'))
          .equals(Asin(Pow(x, IntegerNumber.negativeOne)));
      check(Expr.parse('acot(x)'))
          .equals(Atan(Pow(x, IntegerNumber.negativeOne)));
      check(Expr.parse('arccot(x)'))
          .equals(Atan(Pow(x, IntegerNumber.negativeOne)));
      check(Expr.parse('sech(x)'))
          .equals(Pow(Cosh(x), IntegerNumber.negativeOne));
      check(Expr.parse('csch(x)'))
          .equals(Pow(Sinh(x), IntegerNumber.negativeOne));
      check(Expr.parse('coth(x)')).equals(Cosh(x) / Sinh(x));
      check(Expr.parse('asech(x)'))
          .equals(Acosh(Pow(x, IntegerNumber.negativeOne)));
      check(Expr.parse('arcsech(x)'))
          .equals(Acosh(Pow(x, IntegerNumber.negativeOne)));
      check(Expr.parse('acsch(x)'))
          .equals(Asinh(Pow(x, IntegerNumber.negativeOne)));
      check(Expr.parse('arccsch(x)'))
          .equals(Asinh(Pow(x, IntegerNumber.negativeOne)));
      check(Expr.parse('acoth(x)'))
          .equals(Atanh(Pow(x, IntegerNumber.negativeOne)));
      check(Expr.parse('arccoth(x)'))
          .equals(Atanh(Pow(x, IntegerNumber.negativeOne)));
      check(Expr.parse('pow(x, 2)')).equals(Pow(x, IntegerNumber.two));
      check(Expr.parse('root(x, 3)'))
          .equals(Pow(x, IntegerNumber.one / IntegerNumber.of(3)));
      check(Expr.parse('log(2, x)')).equals(Ln(x) / Ln(IntegerNumber.two));
      check(Expr.parse('lambertw(x, -1)')).equals(LambertW(x, branch: -1));
      check(Expr.parse('lambertw(x, 0)')).equals(LambertW(x));
      check(Expr.parse('LambertW(x)')).equals(LambertW(x));

      // 2-argument and 4-argument integrate
      check(Expr.parse('integrate(sin(x), x)')).equals(Integral(Sin(x), 'x'));
      check(Expr.parse('integrate(sin(x), x, 0, pi)')).equals(
        Integral(Sin(x), 'x', lower: IntegerNumber.zero, upper: Constant.pi),
      );

      // OrderTerm forms
      check(Expr.parse('O(1)')).equals(const OrderTerm('x', 0));
      check(Expr.parse('O(x)')).equals(const OrderTerm('x', 1));
      check(Expr.parse('O(x^3)')).equals(const OrderTerm('x', 3));
      check(Expr.parse('O(x - 1)'))
          .equals(const OrderTerm('x', 1, point: IntegerNumber.one));
      check(Expr.parse('O((x - 1)^3)'))
          .equals(const OrderTerm('x', 3, point: IntegerNumber.one));
      check(Expr.parse('O(x, 3)')).equals(const OrderTerm('x', 3));
      check(Expr.parse('O(x, 3, 1)'))
          .equals(const OrderTerm('x', 3, point: IntegerNumber.one));

      // Relational operators
      check(Expr.parse('x < 1')).equals(LessThan(x, IntegerNumber.one));
      check(Expr.parse('x <= 1')).equals(LessEqual(x, IntegerNumber.one));
      check(Expr.parse('x > 1')).equals(GreaterThan(x, IntegerNumber.one));
      check(Expr.parse('x >= 1')).equals(GreaterEqual(x, IntegerNumber.one));
      check(Expr.parse('x == 1')).equals(Equal(x, IntegerNumber.one));
      check(Expr.parse('x = 1')).equals(Equal(x, IntegerNumber.one));
      check(Expr.parse('x != 1')).equals(NotEqual(x, IntegerNumber.one));
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

        // Syntax and function errors (including case sensitivity and arity mismatch)
        final syntax = ExprSyntax.standard;
        check(syntax.parse('SIN(x)'))
            .equals(VariableFunction('SIN', const [Variable('x')]));
        check(syntax.parse('unknownUnary(x)'))
            .equals(VariableFunction('unknownUnary', const [Variable('x')]));
        check(syntax.parse('unknownBinary(x, y)')).equals(
          VariableFunction('unknownBinary', const [
            Variable('x'),
            Variable('y'),
          ]),
        );
        check(syntax.parse('sin(x, y, z)')).equals(
          VariableFunction('sin', const [
            Variable('x'),
            Variable('y'),
            Variable('z'),
          ]),
        );
        check(() => syntax.parse('lambertw(x, 2)')).throws<FormatException>();
        check(() => syntax.parse('O(sin(x))')).throws<FormatException>();
        check(() => syntax.parse('O(1, 2)')).throws<FormatException>();
        check(() => syntax.parse('piecewise(x < 0)')).throws<FormatException>();
        check(() => syntax.parse('piecewise(x + 1, 2)'))
            .throws<FormatException>();
        check(() => syntax.parse('integrate(x, 2)')).throws<FormatException>();
        check(() => syntax.parse('integrate(x, y, 0)'))
            .throws<FormatException>();
        check(syntax.parse('integral(x, x)')).equals(Integral(x, 'x'));
        check(syntax.parse('diff(x^2, x)'))
            .equals(Derivative(Pow(x, IntegerNumber.two), 'x'));
        check(syntax.parse('derivative(x^3, x, 2)'))
            .equals(Derivative(Pow(x, IntegerNumber.of(3)), 'x', order: 2));
        check(() => syntax.parse('diff(x, x, 0)')).throws<FormatException>();
        check(() => syntax.parse('diff(x, 2)')).throws<FormatException>();
        check(() => syntax.parse('diff(x)')).throws<FormatException>();

        check(syntax.parse('limit(x, x, 0)'))
            .equals(Limit(x, 'x', IntegerNumber.zero));
        check(syntax.parse('limit(x, x, 0, both)'))
            .equals(Limit(x, 'x', IntegerNumber.zero));
        check(syntax.parse('limit(x, x, 0, 1)')).equals(
          Limit(
            x,
            'x',
            IntegerNumber.zero,
            direction: LimitDirection.fromAbove,
          ),
        );
        check(syntax.parse('limit(x, x, 0, -1)')).equals(
          Limit(
            x,
            'x',
            IntegerNumber.zero,
            direction: LimitDirection.fromBelow,
          ),
        );
        check(() => syntax.parse('limit(x, x, 0, 2)'))
            .throws<FormatException>();
        check(() => syntax.parse('limit(x, 2, 0)')).throws<FormatException>();
        check(() => syntax.parse('limit(x, x)')).throws<FormatException>();
        check(() => syntax.parse('sum(x, 2, 1, n)')).throws<FormatException>();
        check(() => syntax.parse('sum(x, x, 1)')).throws<FormatException>();
        check(() => syntax.parse('product(x, 2, 1, n)'))
            .throws<FormatException>();
        check(() => syntax.parse('product(x, x, 1)')).throws<FormatException>();

        check(syntax.parse('gcd(12, 18, 24)')).equals(IntegerNumber.of(6));
        check(syntax.parse('lcm(4, 6, 8)')).equals(IntegerNumber.of(24));
        check(syntax.parse('gcd(x, 12)'))
            .equals(VariableFunction('gcd', [x, IntegerNumber.of(12)]));
        check(syntax.parse('lcm(x, 12)'))
            .equals(VariableFunction('lcm', [x, IntegerNumber.of(12)]));
        check(syntax.parse('gcd(12, x, 18)')).equals(
          VariableFunction('gcd', [
            IntegerNumber.of(12),
            x,
            IntegerNumber.of(18),
          ]),
        );
        check(syntax.parse('lcm(12, x, 18)')).equals(
          VariableFunction('lcm', [
            IntegerNumber.of(12),
            x,
            IntegerNumber.of(18),
          ]),
        );
        check(syntax.parse('gcd(x, 12, 18)')).equals(
          VariableFunction('gcd', [
            x,
            IntegerNumber.of(12),
            IntegerNumber.of(18),
          ]),
        );
        check(syntax.parse('lcm(x, 12, 18)')).equals(
          VariableFunction('lcm', [
            x,
            IntegerNumber.of(12),
            IntegerNumber.of(18),
          ]),
        );

        final vec = syntax.parseVector('[1, x, 2]');
        check(vec.length).equals(3);
        check(syntax.tryParseVector('[1, x]')!.length).equals(2);
        check(syntax.tryParseVector('[1, +]')).isNull();
        check(syntax.tryParseVector('[diff(x)]')).isNull();
        check(() => syntax.parseVector('[1, +]')).throws<FormatException>();

        final mat = syntax.parseMatrix('[[1, 2], [3, 4]]');
        check(mat.rowCount).equals(2);
        check(syntax.tryParseMatrix('[[1, 2], [3, 4]]')!.colCount).equals(2);
        check(syntax.tryParseMatrix('[[1, 2], [3]]')).isNull();
        check(syntax.tryParseMatrix('[1, 2]')).isNull();
        check(() => syntax.parseMatrix('[[1, 2], [3]]'))
            .throws<FormatException>();
        check(() => syntax.parseMatrix('[1, 2]')).throws<FormatException>();

        check(() => syntax.parse('x +')).throws<FormatException>();
        check(syntax.tryParse('x +')).isNull();
        check(syntax.tryParse('diff(x)')).isNull();
      },
    );
  });

  group('Custom ExprSyntax and ExprSyntax.empty', () {
    test('custom constants and empty syntax', () {
      final phi =
          (IntegerNumber.one + Pow(IntegerNumber.of(5), FractionNumber.half)) /
          IntegerNumber.two;
      final syntax = ExprSyntax(
        constants: {
          'phi': phi,
          'golden': phi,
          'φ': phi,
          'r0': Expr.parse('x^2 + 1'),
        },
      );

      check(syntax.parse('golden')).equals(syntax.parse('phi'));
      check(syntax.parse('φ')).equals(syntax.parse('phi'));
      check(syntax.parse('PHI')).equals(const Variable('PHI'));

      // r0 resolves to bound expression
      final reused = syntax.parse('2 * r0').expand().simplify();
      check(reused.toString()).equals('2 + 2 * x ^ 2');

      final emptySyntax = ExprSyntax.empty();
      check(emptySyntax.parse('pi')).equals(const Variable('pi'));
      check(emptySyntax.parse('e')).equals(const Variable('e'));
      check(emptySyntax.parse('i')).equals(const Variable('i'));
      check(emptySyntax.parse('r0')).equals(const Variable('r0'));
      check(emptySyntax.parse('cos(x)'))
          .equals(VariableFunction('cos', const [Variable('x')]));
    });

    test('custom unary, binary, and variadic functions', () {
      final syntax = ExprSyntax(
        unaryFunctions: {
          'doubleIt': (a) => IntegerNumber.two * a,
          'dbl': (a) => IntegerNumber.two * a,
        },
        binaryFunctions: {
          'hypot': (a, b) => Pow(
            Pow(a, IntegerNumber.two) + Pow(b, IntegerNumber.two),
            FractionNumber.half,
          ),
          'pythag': (a, b) => Pow(
            Pow(a, IntegerNumber.two) + Pow(b, IntegerNumber.two),
            FractionNumber.half,
          ),
        },
        variadicFunctions: {
          'fma': (args) => args[0] * args[1] + args[2],
          'sumAll': Add.new,
          'total': Add.new,
        },
      );

      check(syntax.parse('dbl(3)').simplify()).equals(IntegerNumber.of(6));
      check(syntax.parse('pythag(3, 4)').simplify())
          .equals(IntegerNumber.of(5));
      check(syntax.parse('fma(2, 3, 4)').simplify())
          .equals(IntegerNumber.of(10));
      check(syntax.parse('total(1, 2, 3)').simplify())
          .equals(IntegerNumber.of(6));

      // Built-in functions remain available in ExprSyntax(...)
      check(syntax.parse('log(x)')).equals(Ln(const Variable('x')));
      check(syntax.parse('DBL(3)'))
          .equals(VariableFunction('DBL', [IntegerNumber.of(3)]));
    });
  });
}
