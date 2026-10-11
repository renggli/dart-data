import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('String Textualization - Atomic Expressions', () {
    test('variables', () {
      check(const Variable('x').toString()).equals('x');
      check(formatExpr(const Variable('theta'))).equals('theta');
      check(const Variable('alpha_1').toString()).equals('alpha_1');
    });

    test('constants', () {
      check(const Constant(0.0).toString()).equals('0');
      check(const Constant(42.0).toString()).equals('42');
      check(const Constant(-7.0).toString()).equals('-7');
      check(const Constant(3.14159).toString()).equals('3.14159');
      check(Constant.pi.toString()).equals('pi');
      check(Constant.e.toString()).equals('e');
    });
  });

  group('String Textualization - Arithmetic Operations', () {
    const x = Variable('x');
    const y = Variable('y');
    const z = Variable('z');

    test('addition', () {
      check((x + y).toString()).equals('x + y');
      check((x + y + z).toString()).equals('x + y + z');
    });

    test('subtraction associativity', () {
      check((x - y).toString()).equals('x - y');
      check((x - (y + z)).toString()).equals('x - (y + z)');
      check((x - (y - z)).toString()).equals('x - (y - z)');
      check(((x - y) - z).toString()).equals('x - y - z');
    });

    test('multiplication and addition precedence', () {
      check((x * y).toString()).equals('x * y');
      check(((x + y) * z).toString()).equals('(x + y) * z');
      check((x * (y + z)).toString()).equals('x * (y + z)');
      check(((x + y) * (y - z)).toString()).equals('(x + y) * (y - z)');
      check((x * y * z).toString()).equals('x * y * z');
    });

    test('division and parentheses', () {
      check((x / y).toString()).equals('x / y');
      check(((x + y) / (x - y)).toString()).equals('(x + y) / (x - y)');
      check((x / (y * z)).toString()).equals('x / (y * z)');
      check((x / (y / z)).toString()).equals('x / (y / z)');
      check(((x * y) / z).toString()).equals('x * y / z');
    });

    test('power formatting and base wrapping', () {
      check(x.pow(y).toString()).equals('x ^ y');
      check((x + y).pow(z).toString()).equals('(x + y) ^ z');
      check((x * y).pow(z).toString()).equals('(x * y) ^ z');
      check((x / y).pow(z).toString()).equals('(x / y) ^ z');
      check((-x).pow(const Constant(2.0)).toString()).equals('(-x) ^ 2');
      check(x.pow(const Constant(-2.0)).toString()).equals('x ^ (-2)');
    });

    test('unary negation', () {
      check((-x).toString()).equals('-x');
      check((-(x + y)).toString()).equals('-(x + y)');
      check((-(x - y)).toString()).equals('-(x - y)');
      check((-(x * y)).toString()).equals('-(x * y)');
      check((x * -y).toString()).equals('x * -y');
    });
  });

  group('String Textualization - Transcendentals & Functions', () {
    const x = Variable('x');
    const y = Variable('y');

    test('trigonometric and logarithm', () {
      check(const Sin(x).toString()).equals('sin(x)');
      check(const Cos(x).toString()).equals('cos(x)');
      check(Sin(x + y).toString()).equals('sin(x + y)');
      check(Cos(x * y).toString()).equals('cos(x * y)');
      check(const Exp(x).toString()).equals('exp(x)');
      check(const Ln(x).toString()).equals('ln(x)');
    });

    test('compound mathematical expressions without redundant parens', () {
      final dampedOscillator =
          Exp(const Constant(-0.2) * x) * Cos(const Constant(3.0) * x);
      check(dampedOscillator.toString()).equals('exp(-0.2 * x) * cos(3 * x)');

      final cubic =
          x.pow(const Constant(3.0)) -
          const Constant(3.0) * x +
          const Constant(1.0);
      check(cubic.toString()).equals('x ^ 3 - 3 * x + 1');

      final factored = (x + const Constant(1.0)) * (x - const Constant(1.0));
      check(factored.toString()).equals('(x + 1) * (x - 1)');

      final rational =
          const Constant(1.0) /
          (const Constant(1.0) + x.pow(const Constant(2.0)));
      check(rational.toString()).equals('1 / (1 + x ^ 2)');
    });
  });

  group('Operator Precedence', () {
    const x = Variable('x');
    const y = Variable('y');

    test('relative precedence values', () {
      check(precedence(x + y)).equals(10);
      check(precedence(x - y)).equals(10);
      check(precedence(x * y)).equals(20);
      check(precedence(x / y)).equals(20);
      check(precedence(x.pow(y))).equals(30);
      check(precedence(-x)).equals(40);
      check(precedence(const Constant(-5.0))).equals(40);
      check(precedence(x)).equals(50);
      check(precedence(const Constant(5.0))).equals(50);
    });
  });
}
