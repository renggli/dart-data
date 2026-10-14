import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/src/symbolic/parser.dart';
import 'package:data/symbolic.dart';
import 'package:petitparser/reflection.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('Expression parser linter', () {
    test('parser is free of linter defects', () {
      check(linter(parser)).isEmpty();
    });
  });

  group('Numeric literal parsing', () {
    test('parses integer and rational literals', () {
      check(Expr.parse('0')).equals(const RationalNumber(0));
      check(Expr.parse('1')).equals(const RationalNumber(1));
      check(Expr.parse('42')).equals(const RationalNumber(42));
      check(Expr.parse('1000')).equals(const RationalNumber(1000));
      check(Expr.parse('1/2').simplify()).equals(const RationalNumber(1, 2));
    });

    test('parses floating point literals with a dot as RealNumber', () {
      check(Expr.parse('1.')).equals(const RealNumber(1.0));
      check(Expr.parse('0.')).equals(const RealNumber(0.0));
      check(Expr.parse('0.5')).equals(const RealNumber(0.5));
      check(Expr.parse('0.25')).equals(const RealNumber(0.25));
      check(Expr.parse('0.75')).equals(const RealNumber(0.75));
      check(Expr.parse('0.8')).equals(const RealNumber(0.8));
      check(Expr.parse('0.125')).equals(const RealNumber(0.125));
      check(Expr.parse('0.0625')).equals(const RealNumber(0.0625));
      check(Expr.parse('0.05')).equals(const RealNumber(0.05));
      check(Expr.parse('1.0')).equals(const RealNumber(1.0));
      check(Expr.parse('3.14159')).equals(const RealNumber(3.14159));
      check(Expr.parse('123.456')).equals(const RealNumber(123.456));
      check(Expr.parse('0.1234567')).equals(const RealNumber(0.1234567));
      check(Expr.parse('2.5e-3')).equals(const RealNumber(0.0025));
    });

    test('parses scientific notation literals', () {
      check(Expr.parse('1e5')).equals(const RationalNumber(100000));
      check(Expr.parse('1E+6')).equals(const RationalNumber(1000000));
      check(Expr.parse('1e0')).equals(const RationalNumber(1));
    });
  });

  group('Mathematical constants parsing', () {
    test('parses pi', () {
      check(Expr.parse('pi')).equals(ConstantNumber.pi);
      check(Expr.parse('PI')).equals(ConstantNumber.pi);
      check(Expr.parse('Pi')).equals(ConstantNumber.pi);
    });

    test('parses e', () {
      check(Expr.parse('e')).equals(ConstantNumber.e);
    });

    test('distinguishes constants from variable prefixes', () {
      check(Expr.parse('pixel')).equals(const Variable('pixel'));
      check(Expr.parse('pin')).equals(const Variable('pin'));
      check(Expr.parse('eigen')).equals(const Variable('eigen'));
      check(Expr.parse('eta')).equals(const Variable('eta'));
      check(Expr.parse('e1')).equals(const Variable('e1'));
      check(Expr.parse('pi_val')).equals(const Variable('pi_val'));
    });

    test('evaluates constant expressions accurately', () {
      final expr = Expr.parse('pi + e');
      check(expr.freeVariables).isEmpty();
      check(expr.evaluate({})).equals(math.pi + math.e);
    });

    test('parses constants in arithmetic expressions', () {
      final expr1 = Expr.parse('2 * pi');
      check(expr1).isA<Mul>();
      check(expr1.evaluate({})).equals(2.0 * math.pi);

      final expr2 = Expr.parse('pi / 2');
      check(expr2).isA<Div>();
      check(expr2.evaluate({})).equals(math.pi / 2.0);

      final expr3 = Expr.parse('e ^ 2');
      check(expr3).isA<Pow>();
      check(expr3.evaluate({})).equals(math.pow(math.e, 2.0).toDouble());
    });
  });

  group('Variable parsing', () {
    test('parses simple and alphanumeric variables', () {
      check(Expr.parse('x')).equals(const Variable('x'));
      check(Expr.parse('y')).equals(const Variable('y'));
      check(Expr.parse('z')).equals(const Variable('z'));
      check(Expr.parse('x1')).equals(const Variable('x1'));
      check(Expr.parse('var_2')).equals(const Variable('var_2'));
    });

    test('tracks free variables properly', () {
      final expr = Expr.parse('x * y + z - pi');
      check(expr.freeVariables).unorderedEquals({'x', 'y', 'z'});
    });
  });

  group('Arithmetic operators and precedence', () {
    test('parses unary negation and plus', () {
      check(Expr.parse('-x')).equals(const Neg(Variable('x')));
      check(Expr.parse('+x')).equals(const Variable('x'));
      check(Expr.parse('- -x')).equals(const Neg(Neg(Variable('x'))));
      check(Expr.parse('-(x + 1)'))
          .equals(const Neg(Add(Variable('x'), RationalNumber(1))));
    });

    test('parses power operator with right associativity', () {
      const x = Variable('x');
      const y = Variable('y');
      const z = Variable('z');

      check(Expr.parse('x ^ y')).equals(const Pow(x, y));

      // Right-associative: x ^ y ^ z = x ^ (y ^ z)
      check(Expr.parse('x ^ y ^ z')).equals(const Pow(x, Pow(y, z)));
      check(Expr.parse('2 ^ 3 ^ 2').evaluate({}))
          .equals(math.pow(2.0, math.pow(3.0, 2.0)).toDouble());
      check(Expr.parse('2 ^ (-3)').evaluate({})).equals(0.125);
    });

    test('parses multiplication and division with left associativity', () {
      const x = Variable('x');
      const y = Variable('y');
      const z = Variable('z');

      check(Expr.parse('x * y')).equals(const Mul(x, y));
      check(Expr.parse('x / y')).equals(const Div(x, y));

      // Left-associative: x / y / z = (x / y) / z
      check(Expr.parse('x / y / z')).equals(const Div(Div(x, y), z));
      check(Expr.parse('8 / 4 / 2').evaluate({})).equals(1.0);
    });

    test('parses addition and subtraction with left associativity', () {
      const x = Variable('x');
      const y = Variable('y');
      const z = Variable('z');

      check(Expr.parse('x + y')).equals(const Add(x, y));
      check(Expr.parse('x - y')).equals(const Sub(x, y));

      // Left-associative: x - y - z = (x - y) - z
      check(Expr.parse('x - y - z')).equals(const Sub(Sub(x, y), z));
      check(Expr.parse('10 - 3 - 2').evaluate({})).equals(5.0);
    });

    test('respects standard algebraic operator precedence', () {
      const x = Variable('x');

      // Multiplication before addition: 1 + 2 * 3 = 7
      check(Expr.parse('1 + 2 * 3').evaluate({})).equals(7.0);
      check(Expr.parse('2 * 3 + 1').evaluate({})).equals(7.0);

      // Exponentiation before multiplication: 2 * 3 ^ 2 = 18
      check(Expr.parse('2 * 3 ^ 2').evaluate({})).equals(18.0);

      // Exponentiation before unary negation: -x^2 = -(x^2)
      check(Expr.parse('-x^2')).equals(const Neg(Pow(x, RationalNumber(2))));
      check(Expr.parse('(-x)^2')).equals(const Pow(Neg(x), RationalNumber(2)));
      check(Expr.parse('-3^2').evaluate({})).equals(-9.0);
      check(Expr.parse('(-3)^2').evaluate({})).equals(9.0);

      // Parentheses override precedence: (1 + 2) * 3 = 9
      check(Expr.parse('(1 + 2) * 3').evaluate({})).equals(9.0);
      check(Expr.parse('(2 * 3) ^ 2').evaluate({})).equals(36.0);
    });
  });

  group('Parentheses', () {
    test('supports parentheses grouping', () {
      const x = Variable('x');
      const y = Variable('y');

      check(Expr.parse('(x + y)')).equals(const Add(x, y));
      final nested = Expr.parse('((x + 1) * (y - 2)) / (x + y)');
      check(nested).isA<Div>();
    });
  });

  group('Function call parsing', () {
    const x = Variable('x');

    test('parses elementary functions', () {
      check(Expr.parse('sin(x)')).equals(const Sin(x));
      check(Expr.parse('cos(x)')).equals(const Cos(x));
      check(Expr.parse('tan(x)')).equals(const Tan(x));
      check(Expr.parse('asin(x)')).equals(const Asin(x));
      check(Expr.parse('arcsin(x)')).equals(const Asin(x));
      check(Expr.parse('acos(x)')).equals(const Acos(x));
      check(Expr.parse('arccos(x)')).equals(const Acos(x));
      check(Expr.parse('atan(x)')).equals(const Atan(x));
      check(Expr.parse('arctan(x)')).equals(const Atan(x));
      check(Expr.parse('sinh(x)')).equals(const Sinh(x));
      check(Expr.parse('cosh(x)')).equals(const Cosh(x));
      check(Expr.parse('tanh(x)')).equals(const Tanh(x));
      check(Expr.parse('abs(x)')).equals(const Abs(x));
      check(Expr.parse('exp(x)')).equals(const Exp(x));
      check(Expr.parse('ln(x)')).equals(const Ln(x));
      check(Expr.parse('log(x)')).equals(const Ln(x));
      check(Expr.parse('sqrt(x)')).equals(const Pow(x, RationalNumber(1, 2)));
    });

    test('parses sqrt and pow function call syntax to Pow', () {
      const x = Variable('x');
      const y = Variable('y');
      check(Expr.parse('sqrt(x)')).equals(const Pow(x, RationalNumber(1, 2)));
      check(Expr.parse('sqrt(x + 1)'))
          .equals(const Pow(Add(x, RationalNumber(1)), RationalNumber(1, 2)));
      check(Expr.parse('pow(x, y)')).equals(const Pow(x, y));
      check(Expr.parse('pow(x, 2)')).equals(const Pow(x, RationalNumber(2)));
      check(Expr.parse('pow(sqrt(x), 2)'))
          .equals(const Pow(Pow(x, RationalNumber(1, 2)), RationalNumber(2)));
      check(Expr.tryParse('pow(x, y)')).equals(const Pow(x, y));
      check(Expr.tryParse('sqrt(x)'))
          .equals(const Pow(x, RationalNumber(1, 2)));
      check(() => Expr.parse('pow(x)')).throws<FormatException>();
      check(() => Expr.parse('sqrt(x, y)')).throws<FormatException>();
      check(Expr.tryParse('pow(x)')).isNull();
      check(Expr.tryParse('sqrt(x, y)')).isNull();
    });

    test('parses two-argument functions: log and root', () {
      check(Expr.parse('log(2, x)'))
          .equals(const Div(Ln(x), Ln(RationalNumber(2))));
      check(Expr.parse('log(10, x + 1)')).equals(
        const Div(Ln(Add(x, RationalNumber(1))), Ln(RationalNumber(10))),
      );
      check(Expr.parse('root(3, x)'))
          .equals(const Pow(x, Div(RationalNumber.one, RationalNumber(3))));
      check(Expr.parse('root(2, x)'))
          .equals(const Pow(x, Div(RationalNumber.one, RationalNumber(2))));
    });

    test('parses nested function calls and composite arguments', () {
      check(Expr.parse('sin(cos(x))')).equals(const Sin(Cos(x)));
      check(Expr.parse('ln(exp(x))')).equals(const Ln(Exp(x)));
      check(Expr.parse('sin(pi * x + 1)'))
          .equals(const Sin(Add(Mul(ConstantNumber.pi, x), RationalNumber(1))));
    });

    test('handles whitespace around function parentheses', () {
      check(Expr.parse('sin ( x )')).equals(const Sin(x));
      check(Expr.parse('cos  (  x  )')).equals(const Cos(x));
    });

    test('throws on unknown functions', () {
      check(() => Expr.parse('foo(x)')).throws<FormatException>();
      check(() => Expr.parse('bar(1, 2)')).throws<FormatException>();
    });
  });

  group('Whitespace tolerance', () {
    test('parses expressions with diverse whitespace formatting', () {
      const x = Variable('x');
      check(Expr.parse('   x   ')).equals(x);
      check(Expr.parse('  2   *   x   +   3  '))
          .equals(const Add(Mul(RationalNumber(2), x), RationalNumber(3)));
      check(Expr.parse('\t2 * x\n+\n5\t'))
          .equals(const Add(Mul(RationalNumber(2), x), RationalNumber(5)));
    });
  });

  group('Error handling & tryParse', () {
    test('throws FormatException on invalid inputs in parse', () {
      check(() => Expr.parse('')).throws<FormatException>();
      check(() => Expr.parse('   ')).throws<FormatException>();
      check(() => Expr.parse('1 +')).throws<FormatException>();
      check(() => Expr.parse('(1 + 2')).throws<FormatException>();
      check(() => Expr.parse('1 @ 2')).throws<FormatException>();
      check(() => Expr.parse('1 + 2 trailing_junk')).throws<FormatException>();
    });

    test('returns null on invalid inputs in tryParse', () {
      check(Expr.tryParse('')).isNull();
      check(Expr.tryParse('   ')).isNull();
      check(Expr.tryParse('1 +')).isNull();
      check(Expr.tryParse('(1 + 2')).isNull();
      check(Expr.tryParse('1 @ 2')).isNull();
      check(Expr.tryParse('1 + 2 trailing_junk')).isNull();
      check(Expr.tryParse('unknown(1)')).isNull();
    });

    test('tryParse succeeds on valid inputs', () {
      check(Expr.tryParse('x + 1'))
          .equals(const Add(Variable('x'), RationalNumber(1)));
      check(Expr.tryParse('sin(pi * x)'))
          .equals(const Sin(Mul(ConstantNumber.pi, Variable('x'))));
    });
  });

  group('Calculus, simplification & evaluation round-trip', () {
    test('computes analytical derivative from parsed expression', () {
      final expr = Expr.parse('sin(pi * x)');
      final derivative = expr.derivative('x').simplify();
      check(derivative.freeVariables).unorderedEquals({'x'});
      check(derivative.evaluate({'x': 0.0})).equals(math.pi);
      check(derivative).equals(
        const Mul(
          ConstantNumber.pi,
          Cos(Mul(ConstantNumber.pi, Variable('x'))),
        ),
      );
    });

    test('evaluates parsed expressions accurately', () {
      final expr = Expr.parse('sin(pi / 2)');
      check(expr.evaluate({})).equals(1.0);

      final expr2 = Expr.parse('cos(pi)');
      check(expr2.evaluate({})).equals(-1.0);

      final expr3 = Expr.parse('ln(e)');
      check(expr3.evaluate({})).equals(1.0);
    });
  });

  group('Parser stress and radical/composite powers', () {
    const x = Variable('x');
    const y = Variable('y');

    test('nested radicals and composite powers', () {
      final sqrtSqrtX = Expr.parse('sqrt(sqrt(x))');
      check(
        sqrtSqrtX,
      ).equals(const Pow(Pow(x, RationalNumber(1, 2)), RationalNumber(1, 2)));
      check(Expr.tryParse('sqrt(sqrt(x))')).equals(sqrtSqrtX);

      final sqrtPowX2 = Expr.parse('sqrt(pow(x, 2))');
      check(sqrtPowX2)
          .equals(const Pow(Pow(x, RationalNumber(2)), RationalNumber(1, 2)));
      check(Expr.tryParse('sqrt(pow(x, 2))')).equals(sqrtPowX2);

      final powSqrtX2 = Expr.parse('pow(sqrt(x), 2)');
      check(powSqrtX2)
          .equals(const Pow(Pow(x, RationalNumber(1, 2)), RationalNumber(2)));

      final deepSqrt = Expr.parse('sqrt(sqrt(sqrt(16)))');
      check(deepSqrt.evaluate({})).isCloseTo(math.pow(16.0, 1.0 / 8.0), 1e-12);

      final nestedPow = Expr.parse('pow(pow(x, 2), 3)');
      check(nestedPow)
          .equals(const Pow(Pow(x, RationalNumber(2)), RationalNumber(3)));
      check(nestedPow.evaluate({'x': 2.0})).equals(64.0);

      final compositeRadical = Expr.parse('sqrt(1 / (1 - x ^ 2))');
      check(compositeRadical).equals(
        const Pow(
          Div(
            RationalNumber(1),
            Sub(RationalNumber(1), Pow(x, RationalNumber(2))),
          ),
          RationalNumber(1, 2),
        ),
      );
    });

    test('multi-argument expressions: pow, root, log', () {
      check(Expr.parse('pow(x, y)')).equals(const Pow(x, y));
      check(Expr.tryParse('pow(x, y)')).equals(const Pow(x, y));

      check(
        Expr.parse('pow(x + 1, y - 1)'),
      ).equals(const Pow(Add(x, RationalNumber(1)), Sub(y, RationalNumber(1))));

      check(Expr.parse('pow(sin(x), cos(y))'))
          .equals(const Pow(Sin(x), Cos(y)));

      final root3 = Expr.parse('root(3, x)');
      check(root3)
          .equals(const Pow(x, Div(RationalNumber.one, RationalNumber(3))));
      check(root3.evaluate({'x': 27.0})).isCloseTo(3.0, 1e-9);

      final log2 = Expr.parse('log(2, x)');
      check(log2).equals(const Div(Ln(x), Ln(RationalNumber(2))));
      check(log2.evaluate({'x': 8.0})).isCloseTo(3.0, 1e-9);
    });

    test('negative powers and fractional exponents', () {
      final powNeg2 = Expr.parse('pow(x, -2)');
      check(powNeg2).equals(const Pow(x, Neg(RationalNumber(2))));
      check(powNeg2.evaluate({'x': 2.0})).equals(0.25);

      final xPowNeg2 = Expr.parse('x ^ (-2)');
      check(xPowNeg2).equals(const Pow(x, Neg(RationalNumber(2))));
      check(xPowNeg2.evaluate({'x': 4.0})).equals(1.0 / 16.0);

      check(() => Expr.parse('x ^ -2')).throws<FormatException>();
      check(Expr.tryParse('x ^ -2')).isNull();

      final sqrtPowNeg = Expr.parse('sqrt(x ^ (-2))');
      check(
        sqrtPowNeg,
      ).equals(const Pow(Pow(x, Neg(RationalNumber(2))), RationalNumber(1, 2)));
      check(sqrtPowNeg.evaluate({'x': 4.0})).equals(0.25);

      final powNegFrac = Expr.parse('pow(x, -1 / 2)');
      check(powNegFrac)
          .equals(const Pow(x, Div(Neg(RationalNumber(1)), RationalNumber(2))));
      check(powNegFrac.evaluate({'x': 4.0})).equals(0.5);
    });

    test('whitespace variations in function calls', () {
      check(Expr.parse('  sqrt  (  x  )  '))
          .equals(const Pow(x, RationalNumber(1, 2)));
      check(Expr.parse('pow  (  x  ,  y  )  ')).equals(const Pow(x, y));
      check(Expr.parse('sqrt ( pow ( x , 2 ) )'))
          .equals(const Pow(Pow(x, RationalNumber(2)), RationalNumber(1, 2)));
      check(Expr.parse('pow( x , - 2 )'))
          .equals(const Pow(x, Neg(RationalNumber(2))));
    });

    test(
      'malformed syntax throws FormatException or returns null in tryParse',
      () {
        check(() => Expr.parse('sqrt(x, y)')).throws<FormatException>();
        check(Expr.tryParse('sqrt(x, y)')).isNull();
        check(() => Expr.parse('sqrt(x, y, z)')).throws<FormatException>();
        check(Expr.tryParse('sqrt(x, y, z)')).isNull();

        check(() => Expr.parse('pow(x)')).throws<FormatException>();
        check(Expr.tryParse('pow(x)')).isNull();
        check(() => Expr.parse('pow(x, y, z)')).throws<FormatException>();
        check(Expr.tryParse('pow(x, y, z)')).isNull();

        check(() => Expr.parse('sqrt(x')).throws<FormatException>();
        check(Expr.tryParse('sqrt(x')).isNull();
        check(() => Expr.parse('pow(x, y')).throws<FormatException>();
        check(Expr.tryParse('pow(x, y')).isNull();

        check(() => Expr.parse('sqrt)x(')).throws<FormatException>();
        check(Expr.tryParse('sqrt)x(')).isNull();

        check(() => Expr.parse('pow(,)')).throws<FormatException>();
        check(Expr.tryParse('pow(,)')).isNull();
        check(() => Expr.parse('sqrt(,)')).throws<FormatException>();
        check(Expr.tryParse('sqrt(,)')).isNull();
        check(() => Expr.parse('pow(x, )')).throws<FormatException>();
        check(Expr.tryParse('pow(x, )')).isNull();
        check(() => Expr.parse('pow(, y)')).throws<FormatException>();
        check(Expr.tryParse('pow(, y)')).isNull();

        check(Expr.parse('sqrt()')).equals(const Variable('sqrt'));
        check(Expr.parse('pow()')).equals(const Variable('pow'));
      },
    );
  });

  group('Parser & textualization round-trip battery', () {
    test('parses complex expression containing all operations', () {
      const input =
          'tan(x + 1) + sinh(2 * y) * cosh(z) / tanh(w) - abs(acos(u)) + sqrt(asin(v)) + log(2, atan(t)) + root(3, s)';
      final parsed = Expr.parse(input);
      check(parsed).isA<Expr>();

      check(parsed.freeVariables)
          .unorderedEquals({'x', 'y', 'z', 'w', 'u', 'v', 't', 's'});

      final latex = parsed.toLatex();
      check(latex).contains(r'\tan(x + 1)');
      check(latex).contains(r'\sinh(2 y)');
      check(latex).contains(r'\cosh(z)');
      check(latex).contains(r'\tanh(w)');
      check(latex).contains(r'\left|\arccos(u)\right|');
      check(latex).contains(r'\sqrt{\arcsin(v)}');
      check(latex).contains(r'\frac{\ln(\arctan(t))}{\ln(2)}');
      check(latex).contains(r'{s}^{\frac{1}{3}}');

      final simplifiedLatex = parsed.simplify().toLatex();
      check(simplifiedLatex).contains(r'\sqrt[3]{s}');

      final mathml = parsed.toMathMl();
      check(mathml).startsWith('<math>');
      check(mathml).endsWith('</math>');
      check(mathml).contains('<mi>tan</mi>');
      check(mathml).contains('<mi>sinh</mi>');
      check(mathml).contains('<mi>cosh</mi>');
      check(mathml).contains('<mi>tanh</mi>');
      check(mathml).contains('<mo>|</mo>');
      check(mathml).contains('<mi>arccos</mi>');
      check(mathml).contains('<msqrt>');
      check(mathml).contains('<mi>arcsin</mi>');
      check(mathml).contains('<mi>ln</mi>');
      check(mathml).contains('<mi>arctan</mi>');

      final simplifiedMathMl = parsed.simplify().toMathMl();
      check(simplifiedMathMl).contains(
        '<mroot><mrow><mi>s</mi></mrow><mrow><mn>3</mn></mrow></mroot>',
      );

      final str = parsed.toString();
      final reparsed = Expr.parse(str);
      check(reparsed.freeVariables).unorderedEquals(parsed.freeVariables);

      final testEnv = {
        'x': 0.1,
        'y': 0.2,
        'z': 0.3,
        'w': 0.4,
        'u': 0.5,
        'v': 0.6,
        't': 0.7,
        's': 8.0,
      };
      final valOriginal = parsed.evaluate(testEnv);
      final valReparsed = reparsed.evaluate(testEnv);
      check((valOriginal - valReparsed).abs()).isLessThan(1e-12);
    });

    test(
      'LaTeX and MathML formatting for all 10 operations with nested arguments',
      () {
        final tests = <String, (String, String)>{
          'tan(x)': (
            r'\tan(x)',
            '<mrow><mi>tan</mi><mo>(</mo><mi>x</mi><mo>)</mo></mrow>',
          ),
          'asin(x)': (
            r'\arcsin(x)',
            '<mrow><mi>arcsin</mi><mo>(</mo><mi>x</mi><mo>)</mo></mrow>',
          ),
          'acos(x)': (
            r'\arccos(x)',
            '<mrow><mi>arccos</mi><mo>(</mo><mi>x</mi><mo>)</mo></mrow>',
          ),
          'atan(x)': (
            r'\arctan(x)',
            '<mrow><mi>arctan</mi><mo>(</mo><mi>x</mi><mo>)</mo></mrow>',
          ),
          'sinh(x)': (
            r'\sinh(x)',
            '<mrow><mi>sinh</mi><mo>(</mo><mi>x</mi><mo>)</mo></mrow>',
          ),
          'cosh(x)': (
            r'\cosh(x)',
            '<mrow><mi>cosh</mi><mo>(</mo><mi>x</mi><mo>)</mo></mrow>',
          ),
          'tanh(x)': (
            r'\tanh(x)',
            '<mrow><mi>tanh</mi><mo>(</mo><mi>x</mi><mo>)</mo></mrow>',
          ),
          'abs(x)': (
            r'\left|x\right|',
            '<mrow><mo>|</mo><mi>x</mi><mo>|</mo></mrow>',
          ),
          'sqrt(x)': (r'\sqrt{x}', '<msqrt><mrow><mi>x</mi></mrow></msqrt>'),
          'log(10, x)': (
            r'\frac{\ln(x)}{\ln(10)}',
            '<mfrac><mrow><mi>ln</mi><mo>(</mo><mi>x</mi><mo>)</mo></mrow><mrow><mi>ln</mi><mo>(</mo><mn>10</mn><mo>)</mo></mrow></mfrac>',
          ),
        };

        for (final entry in tests.entries) {
          final parsed = Expr.parse(entry.key);
          final (expectedLatex, expectedMathMlInner) = entry.value;
          check(parsed.toLatex()).equals(expectedLatex);
          check(parsed.toMathMl(root: false)).equals(expectedMathMlInner);
        }
      },
    );

    test(
      'String formatting round-trip invariance across variety of functions',
      () {
        final expressions = [
          'tan(2 * x + 1)',
          'sinh(x) / cosh(x)',
          'asin(x / 2) + acos(x / 2)',
          'atan(x) * tanh(y)',
          'abs(x - y) + sqrt(x^2 + y^2)',
          'log(2, x + 1) - log(10, y + 1)',
          'exp(-x^2) * sin(pi * x)',
        ];

        for (final exprStr in expressions) {
          final parsed = Expr.parse(exprStr);
          final formatted = parsed.toString();
          final reparsed = Expr.parse(formatted);

          final env = {'x': 0.3, 'y': 0.7};
          final originalVal = parsed.evaluate(env);
          final reparsedVal = reparsed.evaluate(env);
          check((originalVal - reparsedVal).abs()).isLessThan(1e-12);
        }
      },
    );

    test('Parser arity validation', () {
      check(() => Expr.parse('tan(x, y)')).throws<FormatException>();
      check(() => Expr.parse('sin(x, y)')).throws<FormatException>();
      check(() => Expr.parse('cosh(x, y)')).throws<FormatException>();
      check(() => Expr.parse('abs(x, y)')).throws<FormatException>();
      check(() => Expr.parse('sqrt(x, y)')).throws<FormatException>();
      check(() => Expr.parse('log(2, 3, 4)')).throws<FormatException>();
      check(() => Expr.parse('root(2, 3, 4)')).throws<FormatException>();
      check(() => Expr.parse('root(2)')).throws<FormatException>();
    });
  });

  group('Log parsing, equivalence and arity', () {
    const x = Variable('x');
    const y = Variable('y');

    test('single-argument log(x) dispatches to Ln(x)', () {
      check(Expr.parse('log(x)')).equals(const Ln(x));
      check(Expr.parse('log(2)')).equals(const Ln(RationalNumber(2)));
      check(Expr.parse('log(e)')).equals(const Ln(ConstantNumber.e));
      check(Expr.parse('log(x + y)')).equals(const Ln(Add(x, y)));
    });

    test('two-argument log(b, x) produces canonical Div(Ln(x), Ln(b))', () {
      check(Expr.parse('log(2, x)'))
          .equals(const Div(Ln(x), Ln(RationalNumber(2))));
      check(Expr.parse('log(10, x)'))
          .equals(const Div(Ln(x), Ln(RationalNumber(10))));
      check(Expr.parse('log(e, x)'))
          .equals(const Div(Ln(x), Ln(ConstantNumber.e)));
      check(Expr.parse('log(x, y)')).equals(const Div(Ln(y), Ln(x)));
      check(Expr.parse('log(x + 1, x^2 + 1)')).equals(
        const Div(
          Ln(Add(Pow(x, RationalNumber(2)), RationalNumber(1))),
          Ln(Add(x, RationalNumber(1))),
        ),
      );
    });

    test('nested logarithms parse and evaluate accurately', () {
      final nested = Expr.parse('log(2, log(10, x))');
      check(nested).equals(
        const Div(
          Ln(Div(Ln(x), Ln(RationalNumber(10)))),
          Ln(RationalNumber(2)),
        ),
      );
      // For x = 100, log(10, 100) = 2, log(2, 2) = 1
      final val = nested.evaluate({'x': 100.0});
      check((val - 1.0).abs()).isLessThan(1e-12);
    });

    test('log parsing error rejection and 0-argument bug observation', () {
      // 0-argument function calls currently fall through to Variable due to grammar unification
      check(Expr.parse('log()')).equals(const Variable('log'));
      check(() => Expr.parse('log(1, 2, 3)')).throws<FormatException>();
      check(() => Expr.parse('log(1, 2, 3, 4)')).throws<FormatException>();
    });
  });

  group('Special functions and Piecewise parsing', () {
    const x = Variable('x');

    test('parses lambertw with principal and secondary branches', () {
      check(Expr.parse('lambertw(x)')).equals(const LambertW(x));
      check(Expr.parse('lambertw(x, 0)')).equals(const LambertW(x));
      check(Expr.parse('lambertw(x, -1)'))
          .equals(const LambertW(x, branch: -1));
      check(Expr.parse('w(x, -1)')).equals(const LambertW(x, branch: -1));
      check(() => Expr.parse('lambertw(x, 2)')).throws<FormatException>();
    });

    test('parses infinity constants', () {
      check(Expr.parse('∞')).equals(ConstantNumber.infinity);
      check(Expr.parse('infinity')).equals(ConstantNumber.infinity);
      check(ConstantNumber.infinity.toString()).equals('∞');
    });

    test('parses special functions', () {
      check(Expr.parse('erf(x)')).equals(const Erf(x));
      check(Expr.parse('erfc(x)')).equals(const Erfc(x));
      check(Expr.parse('gamma(x)')).equals(const Gamma(x));
      check(Expr.parse('beta(x, 2)')).equals(const Beta(x, RationalNumber(2)));
      check(Expr.parse('asinh(x)')).equals(const Asinh(x));
      check(Expr.parse('acosh(x)')).equals(const Acosh(x));
      check(Expr.parse('atanh(x)')).equals(const Atanh(x));
    });

    test('parses piecewise functions', () {
      final pw2 = Expr.parse('piecewise(x < 0, -x, x)');
      check(pw2).isA<Piecewise>();
      final pw4 = Expr.parse('piecewise(x < -1, -1, x > 1, 1, 0)');
      check(pw4).isA<Piecewise>();
      check((pw4 as Piecewise).branches.length).equals(2);
      check(pw4.otherwise).equals(RationalNumber.zero);
    });
  });
}
