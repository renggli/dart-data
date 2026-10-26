import 'package:checks/checks.dart';
import 'package:data/src/symbolic/textualization/formatting.dart';
import 'package:data/symbolic.dart';
import 'package:test/test.dart';

void main() {
  group('String textualization and presentation rules', () {
    test('preserves input order before simplify and sorts in increasing degree after simplify', () {
      final raw = Expr.parse('x^2 - 3*x + 1');
      check(raw.toString()).equals('x ^ 2 - 3 * x + 1');

      final simplified = raw.simplify();
      check(simplified.toString()).equals('1 - 3 * x + x ^ 2');
    });

    test('renders subtraction, negation, division, sqrt, and complex numbers cleanly', () {
      const x = Variable('x');
      const y = Variable('y');

      check(Add(const []).toString()).equals('0');
      check(Add([x]).toString()).equals('x');
      check(Mul(const []).toString()).equals('1');
      check(Mul([x]).toString()).equals('x');
      check(
        Mul([Pow(x, IntegerNumber.negativeOne), Pow(y, IntegerNumber.of(-2))])
            .toString(),
      ).equals('1 / (x * y ^ 2)');
      check(Mul([x, IntegerNumber.negativeOne, y]).toString()).equals('x * -y');

      check(Expr.parse('a - b').toString()).equals('a - b');
      check(Expr.parse('-x').toString()).equals('-x');
      check(Expr.parse('a / b').toString()).equals('a / b');
      check(Expr.parse('sqrt(x)').toString()).equals('sqrt(x)');
      check(Expr.parse('(2 + 3*i)').simplify().toString()).equals('2 + 3 * i');
      check(Expr.parse('(2 - 3*i)').simplify().toString()).equals('2 - 3 * i');
      check(Expr.parse('(2 + i)').simplify().toString()).equals('2 + i');
      check(Expr.parse('(2 - i)').simplify().toString()).equals('2 - i');
      check(Expr.parse('-i').simplify().toString()).equals('-i');
      check(ComplexNumber(IntegerNumber.zero, IntegerNumber.of(3)).toString())
          .equals('3 * i');
    });

    test('renders all elementary, hyperbolic, special, relational, Piecewise, Integral, and OrderTerm nodes', () {
      const x = Variable('x');
      const y = Variable('y');

      check(Tan(x).toString()).equals('tan(x)');
      check(Asin(x).toString()).equals('asin(x)');
      check(Acos(x).toString()).equals('acos(x)');
      check(Sinh(x).toString()).equals('sinh(x)');
      check(Cosh(x).toString()).equals('cosh(x)');
      check(Tanh(x).toString()).equals('tanh(x)');
      check(Asinh(x).toString()).equals('asinh(x)');
      check(Acosh(x).toString()).equals('acosh(x)');
      check(Atanh(x).toString()).equals('atanh(x)');
      check(Abs(x).toString()).equals('abs(x)');

      check(const OrderTerm('x', 0).toString()).equals('O(1)');
      check(const OrderTerm('x', 1).toString()).equals('O(x)');
      check(const OrderTerm('x', 3).toString()).equals('O(x^3)');
      check(const OrderTerm('x', 1, point: IntegerNumber.one).toString())
          .equals('O(x - 1)');
      check(const OrderTerm('x', 3, point: IntegerNumber.one).toString())
          .equals('O((x - 1)^3)');

      check(LessThan(x, y).toString()).equals('x < y');
      check(LessEqual(x, y).toString()).equals('x <= y');
      check(GreaterThan(x, y).toString()).equals('x > y');
      check(GreaterEqual(x, y).toString()).equals('x >= y');
      check(Equal(x, y).toString()).equals('x == y');
      check(NotEqual(x, y).toString()).equals('x != y');

      check(
        Piecewise([
          (relation: LessThan(x, IntegerNumber.zero), expr: -x),
        ], otherwise: x).toString(),
      ).equals('piecewise(x < 0, -x, x)');
      check(
        Piecewise([(relation: LessThan(x, IntegerNumber.zero), expr: -x)])
            .toString(),
      ).equals('piecewise(x < 0, -x)');

      check(Integral(x, 'x').toString()).equals('integrate(x, x)');
      check(
        Integral(
          x,
          'x',
          lower: IntegerNumber.zero,
          upper: IntegerNumber.one,
        ).toString(),
      ).equals('integrate(x, x, 0, 1)');
    });
  });

  group('Round-trip and formatting helpers', () {
    test('round-trip guarantee Expr.parse(e.toString()) == e', () {
      const inputs = [
        '0',
        '1',
        '-42',
        '3 / 7',
        '-5 / 12',
        '0.25',
        'pi',
        'e',
        'i',
        '-i',
        '3 * i',
        '-3 * i',
        '2 + 3 * i',
        '2 - 3 * i',
        '1 - i',
        '1 + i',
        'infinity',
        'x + y - z',
        '2 * x ^ 2 - 3 * x + 1',
        '(x + 1) / (x - 1)',
        'sqrt(1 + x ^ 2)',
        'e ^ (-x ^ 2 / 2)',
        'sin(x) + cos(2 * x)',
        'ln(x) + atan(x)',
        'lambertw(x)',
        'lambertw(x, -1)',
        'erf(x) - erfc(x)',
        'gamma(x) + beta(x, 2)',
        '1 + x + x ^ 2 / 2 + O(x ^ 3)',
        'O(x - 1)',
        'O((x - 1) ^ 3)',
        'O((x + 2) ^ 3)',
        'O(x, 0, 1)',
        'piecewise(x < 0, -x, x >= 0, x)',
        'piecewise(x != 0, 1 / x, 0)',
        'integrate(sin(x ^ 2), x)',
        'integrate(sin(x ^ 2), x, 0, pi)',
        'f(x, y + 1)',
        '1 / x',
        'x * (1/2)',
      ];

      for (final src in inputs) {
        final e1 = Expr.parse(src);
        final rendered1 = e1.toString();
        final reparsed1 = Expr.parse(rendered1);
        check(reparsed1).equals(e1);

        final e2 = e1.simplify();
        final rendered2 = e2.toString();
        final reparsed2 = Expr.parse(rendered2).simplify();
        check(reparsed2).equals(e2);
      }

      // Explicit AST round-tripping
      final directNodes = <Expr>[
        Pow(const Variable('x'), IntegerNumber.negativeOne),
        Mul([const Variable('x'), RationalNumber(1, 2)]),
        Mul([RationalNumber(1, 2), const Variable('x')]),
        Mul([
          const Variable('x'),
          const FractionNumber(Integer.one, Integer.two),
        ]),
        Pow(const Variable('y'), IntegerNumber.of(-2)),
        Mul([
          const Variable('x'),
          Pow(const Variable('y'), IntegerNumber.negativeOne),
        ]),
      ];
      for (final e in directNodes) {
        final rendered = e.toString();
        final reparsed = Expr.parse(rendered);
        check(reparsed).equals(e);
      }
    });

    test('formatting helper functions handle edge cases', () {
      const x = Variable('x');
      const y = Variable('y');
      final nestedMul = Mul([
        Mul([x, y]),
        x,
      ]);
      check(leftmostMulFactor(nestedMul)).equals(x);

      const cFull = ComplexNumber(IntegerNumber.one, IntegerNumber.two);
      check(needsSubRightParens(cFull)).isTrue();
      check(needsSubRightParens(IntegerNumber.of(-2))).isTrue();
      check(needsMulLeftParens(cFull)).isTrue();
      check(needsMulRightParens(cFull)).isTrue();
      check(needsMulRightParens(IntegerNumber.of(-2))).isTrue();
      check(needsNegOperandParens(cFull)).isTrue();
      check(needsNegOperandParens(IntegerNumber.of(-2))).isTrue();
      check(needsPowBaseParens(Pow(x, IntegerNumber.negativeOne))).isTrue();
      check(Pow(x, IntegerNumber.negativeOne).toString()).equals('1 / x');
      check(
        Mul([
          x,
          Mul([y, x]),
        ]).toString(),
      ).equals('x * (y * x)');
      check(
        Add([
          x,
          Mul([IntegerNumber.negativeOne, x, y]),
        ]).toString(),
      ).equals('x - x * y');
      check(Mul([IntegerNumber.negativeOne, x, y]).toString())
          .equals('-(x * y)');
      check(canOmitMulDot(Pow(x, IntegerNumber.two), y)).isTrue();
      check(canOmitMulDot(Pow(x, FractionNumber.half), y)).isTrue();
      check(
        startsWithNumber(
          const ComplexNumber(IntegerNumber.zero, IntegerNumber.two),
        ),
      ).isTrue();
      check(startsWithNumber(Pow(IntegerNumber.two, FractionNumber.half)))
          .isFalse();
      check(canOmitMulDot(x, IntegerNumber.of(-2))).isFalse();
      check(canOmitMulDot(x, Pow(y, IntegerNumber.negativeOne))).isFalse();
      check(Mod(x + y, y).toString()).equals('mod(x + y, y)');
      check((LessThan(x, y) + IntegerNumber.one).toString())
          .equals('(x < y) + 1');
      check(
        Add([
          x,
          Mul([
            IntegerNumber.negativeOne,
            const ComplexNumber(IntegerNumber.one, IntegerNumber.two),
          ]),
        ]).toString(),
      ).equals('x - (1 + 2 * i)');
    });

    test('formats real numbers with decimalPlaces parameter', () {
      const num1 = RealNumber(1.875);
      const num2 = RealNumber(1.0530000000000002);
      const num3 = RealNumber(2.0);

      check(num1.format()).equals('1.875');
      check(num2.format()).equals('1.053');
      check(num3.format()).equals('2.0');

      check(num2.format(decimalPlaces: 2)).equals('1.05');
      check(num2.toString()).equals('1.053');

      final expr = const Variable('x') + num2;
      check(expr.format()).equals('x + 1.053');
      check(expr.format(decimalPlaces: 1)).equals('x + 1.1');
    });
  });
}
