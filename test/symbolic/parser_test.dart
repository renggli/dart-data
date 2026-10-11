import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:petitparser/reflection.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('Expression parser linter', () {
    test('canonical expressionParser is free of linter defects', () {
      check(linter(expressionParser)).isEmpty();
    });

    test('fresh buildExpressionParser is free of linter defects', () {
      final parser = buildExpressionParser();
      check(linter(parser)).isEmpty();
    });
  });

  group('Numeric literal parsing', () {
    test('parses integer literals', () {
      check(Expr.parse('0')).equals(const Constant(0.0));
      check(Expr.parse('42')).equals(const Constant(42.0));
      check(Expr.parse('1000')).equals(const Constant(1000.0));
    });

    test('parses floating point literals', () {
      check(Expr.parse('3.14')).equals(const Constant(3.14));
      check(Expr.parse('0.5')).equals(const Constant(0.5));
      check(Expr.parse('123.456')).equals(const Constant(123.456));
    });

    test('parses leading dot decimal literals', () {
      check(Expr.parse('.5')).equals(const Constant(0.5));
      check(Expr.parse('.125')).equals(const Constant(0.125));
    });

    test('parses scientific notation literals', () {
      check(Expr.parse('1e5')).equals(const Constant(100000.0));
      check(Expr.parse('2.5e-3')).equals(const Constant(0.0025));
      check(Expr.parse('1E+6')).equals(const Constant(1000000.0));
      check(Expr.parse('.5e2')).equals(const Constant(50.0));
      check(Expr.parse('1e0')).equals(const Constant(1.0));
    });
  });

  group('Mathematical constants parsing', () {
    test('parses pi in different representations', () {
      check(Expr.parse('pi')).equals(Constant.pi);
      check(Expr.parse('PI')).equals(Constant.pi);
      check(Expr.parse('Pi')).equals(Constant.pi);
      check(Expr.parse(r'\pi')).equals(Constant.pi);
      check(Expr.parse(r'\PI')).equals(Constant.pi);
      check(Expr.parse(r'\Pi')).equals(Constant.pi);
      check(Expr.parse('π')).equals(Constant.pi);
      check(Expr.parse('Π')).equals(Constant.pi);
    });

    test('parses e in different representations', () {
      check(Expr.parse('e')).equals(Constant.e);
      check(Expr.parse(r'\e')).equals(Constant.e);
      check(Expr.parse('ℯ')).equals(Constant.e);
    });

    test('distinguishes constants from variable prefixes', () {
      check(Expr.parse('pixel')).equals(const Variable('pixel'));
      check(Expr.parse('pin')).equals(const Variable('pin'));
      check(Expr.parse('eigen')).equals(const Variable('eigen'));
      check(Expr.parse('eta')).equals(const Variable('eta'));
      check(Expr.parse('e1')).equals(const Variable('e1'));
      check(Expr.parse('pi_val')).equals(const Variable('pi_val'));
    });

    test(
      'constant expressions have empty free variables and evaluate correctly',
      () {
        final expr = Expr.parse('pi + e');
        check(expr.freeVariables).isEmpty();
        check(expr.evaluate({})).equals(math.pi + math.e);
      },
    );

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
      check(Expr.parse('_leading')).equals(const Variable('_leading'));
    });

    test('parses LaTeX command variable names', () {
      check(Expr.parse(r'\theta')).equals(const Variable('theta'));
      check(Expr.parse(r'\alpha')).equals(const Variable('alpha'));
      check(Expr.parse(r'\beta')).equals(const Variable('beta'));
    });

    test('parses direct Unicode Greek letter variables', () {
      check(Expr.parse('θ')).equals(const Variable('θ'));
      check(Expr.parse('α')).equals(const Variable('α'));
      check(Expr.parse('β')).equals(const Variable('β'));
      check(Expr.parse('θ_0')).equals(const Variable('θ_0'));
      check(Expr.parse('α + β'))
          .equals(const Add(Variable('α'), Variable('β')));
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
          .equals(const Neg(Add(Variable('x'), Constant(1.0))));
    });

    test('parses power operator with right associativity', () {
      const x = Variable('x');
      const y = Variable('y');
      const z = Variable('z');

      check(Expr.parse('x ^ y')).equals(const Pow(x, y));
      check(Expr.parse('x ** y')).equals(const Pow(x, y));

      // Right-associative: x ^ y ^ z = x ^ (y ^ z)
      check(Expr.parse('x ^ y ^ z')).equals(const Pow(x, Pow(y, z)));
      check(Expr.parse('2 ^ 3 ^ 2').evaluate({}))
          .equals(math.pow(2.0, math.pow(3.0, 2.0)).toDouble());
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

    test('parses Unicode and LaTeX multiplication/division operators', () {
      const x = Variable('x');
      const y = Variable('y');

      check(Expr.parse('x · y')).equals(const Mul(x, y));
      check(Expr.parse('x × y')).equals(const Mul(x, y));
      check(Expr.parse(r'x \cdot y')).equals(const Mul(x, y));
      check(Expr.parse(r'x \times y')).equals(const Mul(x, y));

      check(Expr.parse('x ÷ y')).equals(const Div(x, y));
      check(Expr.parse(r'x \div y')).equals(const Div(x, y));
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
      // Multiplication before addition: 1 + 2 * 3 = 7
      check(Expr.parse('1 + 2 * 3').evaluate({})).equals(7.0);
      check(Expr.parse('2 * 3 + 1').evaluate({})).equals(7.0);

      // Exponentiation before multiplication: 2 * 3 ^ 2 = 18
      check(Expr.parse('2 * 3 ^ 2').evaluate({})).equals(18.0);

      // Parentheses override precedence: (1 + 2) * 3 = 9
      check(Expr.parse('(1 + 2) * 3').evaluate({})).equals(9.0);
      check(Expr.parse('(2 * 3) ^ 2').evaluate({})).equals(36.0);
    });
  });

  group('Grouping delimiters', () {
    test('supports parentheses, brackets, and braces', () {
      const x = Variable('x');
      const y = Variable('y');

      check(Expr.parse('(x + y)')).equals(const Add(x, y));
      check(Expr.parse('[x + y]')).equals(const Add(x, y));
      check(Expr.parse('{x + y}')).equals(const Add(x, y));

      final nested = Expr.parse('([x + 1] * {y - 2}) / (x + y)');
      check(nested).isA<Div>();
    });
  });

  group('Function call parsing', () {
    const x = Variable('x');

    test('parses elementary transcendental functions', () {
      check(Expr.parse('sin(x)')).equals(const Sin(x));
      check(Expr.parse('cos(x)')).equals(const Cos(x));
      check(Expr.parse('exp(x)')).equals(const Exp(x));
      check(Expr.parse('ln(x)')).equals(const Ln(x));
      check(Expr.parse('log(x)')).equals(const Ln(x));
      check(Expr.parse('sqrt(x)')).equals(const Pow(x, Constant(0.5)));
    });

    test('supports case-insensitivity in function names', () {
      check(Expr.parse('Sin(x)')).equals(const Sin(x));
      check(Expr.parse('COS(x)')).equals(const Cos(x));
      check(Expr.parse('Exp(x)')).equals(const Exp(x));
      check(Expr.parse('Ln(x)')).equals(const Ln(x));
      check(Expr.parse('Sqrt(x)')).equals(const Pow(x, Constant(0.5)));
    });

    test('supports braces for function arguments', () {
      check(Expr.parse('sin{x}')).equals(const Sin(x));
      check(Expr.parse('cos{x}')).equals(const Cos(x));
      check(Expr.parse('exp{x}')).equals(const Exp(x));
      check(Expr.parse('ln{x}')).equals(const Ln(x));
      check(Expr.parse('sqrt{x}')).equals(const Pow(x, Constant(0.5)));
    });

    test('supports square brackets for function arguments', () {
      check(Expr.parse('sin[x]')).equals(const Sin(x));
      check(Expr.parse('cos[x]')).equals(const Cos(x));
      check(Expr.parse('exp[x]')).equals(const Exp(x));
      check(Expr.parse('ln[x]')).equals(const Ln(x));
      check(Expr.parse('sqrt[x]')).equals(const Pow(x, Constant(0.5)));
    });

    test('supports LaTeX function prefixes', () {
      check(Expr.parse(r'\sin(x)')).equals(const Sin(x));
      check(Expr.parse(r'\cos(x)')).equals(const Cos(x));
      check(Expr.parse(r'\exp(x)')).equals(const Exp(x));
      check(Expr.parse(r'\ln(x)')).equals(const Ln(x));
    });

    test('parses nested function calls and composite arguments', () {
      check(Expr.parse('sin(cos(x))')).equals(const Sin(Cos(x)));
      check(Expr.parse('ln(exp(x))')).equals(const Ln(Exp(x)));
      check(Expr.parse('sin(pi * x + 1)'))
          .equals(const Sin(Add(Mul(Constant.pi, x), Constant(1.0))));
    });

    test('handles whitespace around function parentheses', () {
      check(Expr.parse('sin ( x )')).equals(const Sin(x));
      check(Expr.parse('cos  (  x  )')).equals(const Cos(x));
    });
  });

  group('LaTeX fractions', () {
    test('parses frac and dfrac syntax', () {
      check(Expr.parse(r'\frac{1}{2}'))
          .equals(const Div(Constant(1.0), Constant(2.0)));
      check(Expr.parse(r'\dfrac{1}{2}'))
          .equals(const Div(Constant(1.0), Constant(2.0)));
      check(Expr.parse(r'\frac{x + 1}{x - 1}')).equals(
        const Div(
          Add(Variable('x'), Constant(1.0)),
          Sub(Variable('x'), Constant(1.0)),
        ),
      );
    });

    test('parses nested fractions', () {
      const x = Variable('x');
      const y = Variable('y');
      final expr = Expr.parse(r'\frac{\frac{1}{x}}{y}');
      check(expr).equals(const Div(Div(Constant(1.0), x), y));
    });
  });

  group('Whitespace tolerance', () {
    test('parses expressions with diverse whitespace formatting', () {
      const x = Variable('x');
      check(Expr.parse('   x   ')).equals(x);
      check(Expr.parse('  2   *   x   +   3  '))
          .equals(const Add(Mul(Constant(2.0), x), Constant(3.0)));
      check(Expr.parse('\t2 * x\n+\n5\t'))
          .equals(const Add(Mul(Constant(2.0), x), Constant(5.0)));
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
    });

    test('tryParse succeeds on valid inputs', () {
      check(Expr.tryParse('x + 1'))
          .equals(const Add(Variable('x'), Constant(1.0)));
      check(Expr.tryParse('sin(pi * x)'))
          .equals(const Sin(Mul(Constant.pi, Variable('x'))));
    });
  });

  group('Calculus, simplification & evaluation round-trip', () {
    test('computes analytical derivative from parsed expression', () {
      final expr = Expr.parse('sin(pi * x)');
      final derivative = expr.diff('x').simplify();
      // Derivative of sin(pi*x) with respect to x is cos(pi*x) * pi
      check(derivative.freeVariables).unorderedEquals({'x'});
      // At x = 0: derivative is cos(0) * pi = pi
      check(derivative.evaluate({'x': 0.0})).equals(math.pi);
      // Preserves Constant.pi symbolically in the AST and LaTeX
      check(derivative)
          .equals(const Mul(Cos(Mul(Constant.pi, Variable('x'))), Constant.pi));
      check(derivative.toLatex()).equals(r'\cos(\pi \cdot x) \cdot \pi');
    });

    test('evaluates parsed expressions accurately', () {
      final expr = Expr.parse('sin(pi / 2)');
      check(expr.evaluate({})).equals(1.0);

      final expr2 = Expr.parse('cos(pi)');
      check(expr2.evaluate({})).equals(-1.0);

      final expr3 = Expr.parse('ln(e)');
      check(expr3.evaluate({})).equals(1.0);
    });

    test('round-trips through LaTeX serialization', () {
      final original = Expr.parse(r'\frac{x + 1}{x - 1}');
      final latex = original.toLatex();
      final parsed = Expr.parse(latex);
      check(parsed).equals(original);

      final trig = Expr.parse(r'\sin(\pi \cdot x)');
      final trigLatex = trig.toLatex();
      final trigParsed = Expr.parse(trigLatex);
      check(trigParsed).equals(trig);
    });
  });
}
