import 'package:checks/checks.dart';
import 'package:data/src/symbolic/textualization/formatting.dart';
import 'package:data/symbolic.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('String textualization and presentation rules', () {
    test('canonicalizes and sorts terms deterministically', () {
      final raw = Expr.parse('x^2 - 3*x + 1');
      check(raw.toString()).equals('1 - 3 * x + x ^ 2');

      final simplified = raw.simplify();
      check(simplified.toString()).equals('1 - 3 * x + x ^ 2');
    });

    test('renders subtraction, negation, division, sqrt, and complex numbers cleanly', () {
      const x = Variable('x');
      const y = Variable('y');

      check(Add.of(const []).toString()).equals('0');
      check(Add.of([x]).toString()).equals('x');
      check(Mul.of(const []).toString()).equals('1');
      check(Mul.of([x]).toString()).equals('x');
      check(
        Mul.of([
          Pow.of(x, IntegerNumber.negativeOne),
          Pow.of(y, IntegerNumber.of(-2)),
        ]).toString(),
      ).equals('1 / (x * y ^ 2)');
      check(Mul.of([x, IntegerNumber.negativeOne, y]).toString())
          .equals('-x * y');

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

      check(Fn.tan(x).toString()).equals('tan(x)');
      check(Fn.asin(x).toString()).equals('asin(x)');
      check(Fn.acos(x).toString()).equals('acos(x)');
      check(Fn.sinh(x).toString()).equals('sinh(x)');
      check(Fn.cosh(x).toString()).equals('cosh(x)');
      check(Fn.tanh(x).toString()).equals('tanh(x)');
      check(Fn.asinh(x).toString()).equals('asinh(x)');
      check(Fn.acosh(x).toString()).equals('acosh(x)');
      check(Fn.atanh(x).toString()).equals('atanh(x)');
      check(Fn.abs(x).toString()).equals('abs(x)');
      check(Fn.zeta(x).toString()).equals('zeta(x)');
      check(Fn.digamma(x).toString()).equals('digamma(x)');
      check(Fn.polygamma(IntegerNumber.one, x).toString())
          .equals('polygamma(1, x)');
      check(Fn.besselJ(IntegerNumber.zero, x).toString())
          .equals('besselJ(0, x)');
      check(Fn.besselY(IntegerNumber.one, x).toString())
          .equals('besselY(1, x)');
      check(Fn.besselI(IntegerNumber.zero, x).toString())
          .equals('besselI(0, x)');
      check(Fn.besselK(IntegerNumber.one, x).toString())
          .equals('besselK(1, x)');
      check(Fn.ellipticK(x).toString()).equals('ellipticK(x)');
      check(Fn.ellipticE(x).toString()).equals('ellipticE(x)');

      check(OrderTerm('x', 0).toString()).equals('O(1)');
      check(OrderTerm('x', 1).toString()).equals('O(x)');
      check(OrderTerm('x', 3).toString()).equals('O(x^3)');
      check(OrderTerm('x', 1, point: IntegerNumber.one).toString())
          .equals('O(x - 1)');
      check(OrderTerm('x', 3, point: IntegerNumber.one).toString())
          .equals('O((x - 1)^3)');
      check(OrderTerm('x', 2, point: -const Variable('a')).toString())
          .equals('O((x + a)^2)');
      check(OrderTerm('x', 2, point: IntegerNumber.negativeOne).toString())
          .equals('O((x + 1)^2)');

      check(Relational.lessThan(x, y).toString()).equals('x < y');
      check(Relational.lessEqual(x, y).toString()).equals('x <= y');
      check(Relational.greaterThan(x, y).toString()).equals('x > y');
      check(Relational.greaterEqual(x, y).toString()).equals('x >= y');
      check(Relational.equal(x, y).toString()).equals('x == y');
      check(Relational.notEqual(x, y).toString()).equals('x != y');

      check(
        Piecewise([
          (relation: Relational.lessThan(x, IntegerNumber.zero), expr: -x),
        ], otherwise: x).toString(),
      ).equals('piecewise(x < 0, -x, x)');
      check(
        Piecewise([
          (relation: Relational.lessThan(x, IntegerNumber.zero), expr: -x),
        ]).toString(),
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
        'lambertW(x)',
        'lambertW(x, -1)',
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
        Pow.of(const Variable('x'), IntegerNumber.negativeOne),
        Mul.of([const Variable('x'), RationalNumber(1, 2)]),
        Mul.of([RationalNumber(1, 2), const Variable('x')]),
        Mul.of([const Variable('x'), FractionNumber(BigInt.one, BigInt.two)]),
        Pow.of(const Variable('y'), IntegerNumber.of(-2)),
        Mul.of([
          const Variable('x'),
          Pow.of(const Variable('y'), IntegerNumber.negativeOne),
        ]),
        Derivative(
          Fn.symbolic('f', const [Variable('x')]),
          'x',
          point: IntegerNumber.two,
        ),
        Derivative(
          Fn.symbolic('f', const [Variable('x')]),
          'x',
          order: 2,
          point: const Variable('a'),
        ),
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
      final mulXY = Mul.of([x, y]);
      check(leftmostMulFactor(mulXY)).equals(x);

      final cFull = ComplexNumber(IntegerNumber.one, IntegerNumber.two);
      check(needsSubRightParens(cFull)).isTrue;
      check(needsSubRightParens(IntegerNumber.of(-2))).isTrue;
      check(needsMulLeftParens(cFull)).isTrue;
      check(needsMulRightParens(cFull)).isTrue;
      check(needsMulRightParens(IntegerNumber.of(-2))).isTrue;
      check(needsNegOperandParens(cFull)).isTrue;
      check(needsNegOperandParens(IntegerNumber.of(-2))).isTrue;
      check(needsPowBaseParens(Pow.of(x, IntegerNumber.negativeOne))).isTrue;
      check(Pow.of(x, IntegerNumber.negativeOne).toString()).equals('1 / x');
      check(
        Add.of([
          x,
          Mul.of([IntegerNumber.negativeOne, x, y]),
        ]).toString(),
      ).equals('x - x * y');
      check(Mul.of([IntegerNumber.negativeOne, x, y]).toString())
          .equals('-x * y');
      for (final e in [
        Mul.of([IntegerNumber.negativeOne, x, y]),
        Expr.parse('-x * z / y'),
        Expr.parse('-(a + b)'),
      ]) {
        check(Expr.parse(e.toString())).equals(e);
      }
      check(Expr.parse('-x * z / y').toString()).equals('-x * z / y');
      check(Expr.parse('-(a + b)').toString()).equals('-a - b');
      check(canOmitMulDot(Pow.of(x, IntegerNumber.two), y)).isTrue;
      check(canOmitMulDot(Pow.of(x, FractionNumber.half), y)).isTrue;
      check(
        startsWithNumber(ComplexNumber(IntegerNumber.zero, IntegerNumber.two)),
      ).isTrue;
      check(startsWithNumber(Pow.of(IntegerNumber.two, FractionNumber.half)))
          .isFalse;
      check(canOmitMulDot(x, IntegerNumber.of(-2))).isFalse;
      check(canOmitMulDot(x, Pow.of(y, IntegerNumber.negativeOne))).isFalse;
      check(Fn.mod(x + y, y).toString()).equals('mod(x + y, y)');
      check((Relational.lessThan(x, y) + IntegerNumber.one).toString())
          .equals('1 + (x < y)');
      check(
        Add.of([
          x,
          Mul.of([
            IntegerNumber.negativeOne,
            ComplexNumber(IntegerNumber.one, IntegerNumber.two),
          ]),
        ]).toString(),
      ).equals('-1 - 2 * i + x');
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
      check(expr.format()).equals('1.053 + x');
      check(expr.format(decimalPlaces: 1)).equals('1.1 + x');
    });

    test('formats and parses special integral and polylogarithm functions', () {
      const x = Variable('x');
      const k = Variable('k');
      check(Fn.erfi(x).toString()).equals('erfi(x)');
      check(Fn.fresnelS(x).toString()).equals('fresnelS(x)');
      check(Fn.fresnelC(x).toString()).equals('fresnelC(x)');
      check(Fn.ei(x).toString()).equals('Ei(x)');
      check(Fn.li(x).toString()).equals('li(x)');
      check(Fn.si(x).toString()).equals('Si(x)');
      check(Fn.ci(x).toString()).equals('Ci(x)');
      check(Fn.shi(x).toString()).equals('Shi(x)');
      check(Fn.chi(x).toString()).equals('Chi(x)');
      check(Fn.upperGamma(IntegerNumber.two, x).toString())
          .equals('upperGamma(2, x)');
      check(Fn.lowerGamma(IntegerNumber.two, x).toString())
          .equals('lowerGamma(2, x)');
      check(Fn.polylog(IntegerNumber.two, x).toString())
          .equals('polylog(2, x)');
      check(Fn.ellipticF(x, k).toString()).equals('ellipticF(x, k)');
      check(Fn.ellipticE(x, k).toString()).equals('ellipticE(x, k)');

      // Canonical parsing and optional explicit aliases
      check(Expr.parse('Ei(x)')).equals(Fn.ei(x));
      check(Expr.parse('li(x)')).equals(Fn.li(x));
      check(Expr.parse('polylog(2, x)'))
          .equals(Fn.polylog(IntegerNumber.two, x));
      check(Expr.parse('ellipticE(x)')).equals(Fn.ellipticE(x));
      check(Expr.parse('ellipticE(x, k)')).equals(Fn.ellipticE(x, k));
      check(Expr.parse('ellipticF(x, k)')).equals(Fn.ellipticF(x, k));
      check(Expr.parse('upperGamma(2, x)'))
          .equals(Fn.upperGamma(IntegerNumber.two, x));
      check(Expr.parse('lowerGamma(2, x)'))
          .equals(Fn.lowerGamma(IntegerNumber.two, x));

      final aliasSyntax = ExprSyntax(
        aliases: {
          'expIntegralEi': Fn.ei,
          'Li': Fn.li,
          'elliptic_e': Fn.ellipticE,
        },
        binaryFunctions: {'Li': Fn.polylog.call},
      );
      check(aliasSyntax.parse('expIntegralEi(x)')).equals(Fn.ei(x));
      check(aliasSyntax.parse('Li(x)')).equals(Fn.li(x));
      check(aliasSyntax.parse('Li(2, x)'))
          .equals(Fn.polylog(IntegerNumber.two, x));
      check(aliasSyntax.parse('elliptic_e(x)')).equals(Fn.ellipticE(x));
      check(aliasSyntax.parse('elliptic_e(x, k)')).equals(Fn.ellipticE(x, k));
    });
  });
}
