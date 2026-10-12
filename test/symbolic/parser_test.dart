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
    test('parses integer literals', () {
      check(Expr.parse('0')).equals(const RationalNumber(0));
      check(Expr.parse('42')).equals(const RationalNumber(42));
      check(Expr.parse('1000')).equals(const RationalNumber(1000));
    });

    test('parses obvious fractions as RationalNumber', () {
      check(Expr.parse('0.5')).equals(const RationalNumber(1, 2));
      check(Expr.parse('0.25')).equals(const RationalNumber(1, 4));
      check(Expr.parse('0.75')).equals(const RationalNumber(3, 4));
      check(Expr.parse('0.8')).equals(const RationalNumber(4, 5));
      check(Expr.parse('0.125')).equals(const RationalNumber(1, 8));
      check(Expr.parse('0.0625')).equals(const RationalNumber(1, 16));
    });

    test('parses non-obvious floating point literals as RealNumber', () {
      check(Expr.parse('3.14159')).equals(const RealNumber(3.14159));
      check(Expr.parse('123.456')).equals(const RealNumber(123.456));
      check(Expr.parse('0.1234567')).equals(const RealNumber(0.1234567));
    });

    test('respects configurable maxDenominator', () {
      // 0.05 = 1/20. With maxDenominator: 10, becomes RealNumber.
      check(Expr.parse('0.05', maxDenominator: 10))
          .equals(const RealNumber(0.05));
      check(Expr.parse('0.05', maxDenominator: 20))
          .equals(const RationalNumber(1, 20));
      check(Expr.parse('0.05', maxDenominator: 64))
          .equals(const RationalNumber(1, 20));
    });

    test('parses scientific notation literals', () {
      check(Expr.parse('1e5')).equals(const RationalNumber(100000));
      check(Expr.parse('2.5e-3')).equals(const RealNumber(0.0025));
      check(Expr.parse('2.5e-3', maxDenominator: 500))
          .equals(const RationalNumber(1, 400));
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
      check(Expr.parse('sqrt(x)')).equals(const Sqrt(x));
    });

    test('parses two-argument functions: log and root', () {
      check(Expr.parse('log(2, x)')).equals(const Log(RationalNumber(2), x));
      check(Expr.parse('log(10, x + 1)'))
          .equals(const Log(RationalNumber(10), Add(x, RationalNumber(1))));
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
}
