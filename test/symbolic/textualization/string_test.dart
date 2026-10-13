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

    test('numbers', () {
      check(const RationalNumber(0).toString()).equals('0');
      check(const RationalNumber(42).toString()).equals('42');
      check(const RationalNumber(-7).toString()).equals('-7');
      check(const RationalNumber(1, 2).toString()).equals('1/2');
      check(const RealNumber(3.14).toString()).equals('3.14');
      check(ConstantNumber.pi.toString()).equals('pi');
      check(ConstantNumber.e.toString()).equals('e');
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
      check((-x).pow(const RationalNumber(2)).toString()).equals('(-x) ^ 2');
      check((-x.pow(const RationalNumber(2))).toString()).equals('-x ^ 2');
      check(x.pow(const RationalNumber(-2)).toString()).equals('x ^ (-2)');
      check(x.pow(y).pow(z).toString()).equals('(x ^ y) ^ z');
      check(x.pow(y.pow(z)).toString()).equals('x ^ y ^ z');
    });

    test('sqrt formatting for half powers', () {
      check(x.pow(const RationalNumber(1, 2)).toString()).equals('sqrt(x)');
      check((x + y).pow(const RationalNumber(1, 2)).toString())
          .equals('sqrt(x + y)');
      check((x * y).pow(const RationalNumber(1, 2)).toString())
          .equals('sqrt(x * y)');
      check(x.pow(const RationalNumber(1, 3)).toString()).equals('x ^ (1/3)');
      check(x.pow(const RationalNumber(-1, 2)).toString()).equals('x ^ (-1/2)');
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

    test('trigonometric, hyperbolic, and special functions', () {
      check(const Sin(x).toString()).equals('sin(x)');
      check(const Cos(x).toString()).equals('cos(x)');
      check(const Tan(x).toString()).equals('tan(x)');
      check(const Asin(x).toString()).equals('asin(x)');
      check(const Acos(x).toString()).equals('acos(x)');
      check(const Atan(x).toString()).equals('atan(x)');
      check(const Sinh(x).toString()).equals('sinh(x)');
      check(const Cosh(x).toString()).equals('cosh(x)');
      check(const Tanh(x).toString()).equals('tanh(x)');
      check(const Abs(x).toString()).equals('abs(x)');
      check(const Pow(x, RationalNumber(1, 2)).toString()).equals('sqrt(x)');
      check(Sin(x + y).toString()).equals('sin(x + y)');
      check(Cos(x * y).toString()).equals('cos(x * y)');
      check(const Exp(x).toString()).equals('exp(x)');
      check(const Ln(x).toString()).equals('ln(x)');
      check(const ComplexNumber(3.0, 4.0).toString()).equals('3.0 + 4.0i');
      check(ComplexNumber.i.toString()).equals('i');
    });

    test('compound mathematical expressions without redundant parens', () {
      final dampedOscillator =
          Exp(const RationalNumber(-1, 5) * x) *
          Cos(const RationalNumber(3) * x);
      check(dampedOscillator.toString()).equals('exp(-1/5 * x) * cos(3 * x)');

      final cubic =
          x.pow(const RationalNumber(3)) -
          const RationalNumber(3) * x +
          const RationalNumber(1);
      check(cubic.toString()).equals('x ^ 3 - 3 * x + 1');

      final factored =
          (x + const RationalNumber(1)) * (x - const RationalNumber(1));
      check(factored.toString()).equals('(x + 1) * (x - 1)');

      final rational =
          const RationalNumber(1) /
          (const RationalNumber(1) + x.pow(const RationalNumber(2)));
      check(rational.toString()).equals('1 / (1 + x ^ 2)');
    });
  });

  group('Operator Precedence', () {
    const x = Variable('x');
    const y = Variable('y');

    test('relative precedence values', () {
      check(precedence(x + y)).equals(1);
      check(precedence(x - y)).equals(1);
      check(precedence(x * y)).equals(2);
      check(precedence(x / y)).equals(2);
      check(precedence(-x)).equals(3);
      check(precedence(const RationalNumber(-5))).equals(3);
      check(precedence(x.pow(y))).equals(4);
      check(precedence(x)).equals(5);
      check(precedence(const RationalNumber(5))).equals(5);
      check(precedence(const RealNumber(5.5))).equals(5);
      check(precedence(ConstantNumber.pi)).equals(5);
    });
  });
}
