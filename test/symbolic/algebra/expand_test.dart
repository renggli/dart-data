import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:test/test.dart';

void main() {
  group('Polynomial and multivariate product expansion', () {
    test('distributes products over sums and expands integer powers', () {
      final e1 = Expr.parse('(x + 1)^3').expand();
      check(e1.toString()).equals('1 + 3 * x + 3 * x ^ 2 + x ^ 3');

      final e2 = Expr.parse('(x - y) * (x + y)').expand();
      check(e2.toString()).equals('x ^ 2 - y ^ 2');

      final e3 = Expr.parse('(x + y + 1)^2').expand();
      check(e3.evaluate({'x': 2.0, 'y': 3.0})).equals(36.0);

      final e4 = Expr.parse('(x + 1)^5').expand();
      check(e4.toString())
          .equals('1 + 5 * x + 10 * x ^ 2 + 10 * x ^ 3 + 5 * x ^ 4 + x ^ 5');
    });

    test(
      'merges multivariate monomial factors and handles unsorted variables',
      () {
        // Unsorted variable factors in Mul and multi-variable merging
        const x = Variable('x');
        const y = Variable('y');
        const z = Variable('z');
        final unsortedLeft = Add([
          Mul([IntegerNumber.two, y, x]),
          IntegerNumber.of(3),
        ]);
        final unsortedRight = Add([
          Mul([z, Pow(x, IntegerNumber.two)]),
          Mul([y, z]),
          IntegerNumber.of(4),
        ]);
        final expanded = Mul([unsortedLeft, unsortedRight]).expand();
        check(expanded.evaluate({'x': 2.0, 'y': 3.0, 'z': 5.0}))
            .equals((2 * 3 * 2 + 3) * (5 * 4 + 3 * 5 + 4));

        // Merging opposite exponents in polynomial expansion: x * x^(-1) -> 1
        // and x^2 * x^(-1) -> x
        final laurent = Mul([
          Add([x, Pow(x, IntegerNumber.two)]),
          Add([Pow(x, IntegerNumber.negativeOne), IntegerNumber.one]),
        ]).expand();
        check(laurent.toString()).equals('1 + 2 * x + x ^ 2');
      },
    );

    test(
      'expands empty products, single-term products, and non-polynomial terms',
      () {
        check(Mul(const []).expand()).equals(IntegerNumber.one);
        check(
          Mul([const Variable('x'), const Variable('y')]).expand().toString(),
        ).equals('x * y');

        // Non-polynomial factors in _parsePolyMonomial (functions, fractional powers)
        final nonPoly = Expr.parse(
          '(sin(x) + sqrt(x) + 2 * x * cos(x)) * (x + 1)',
        ).expand();
        check(nonPoly.evaluate({'x': 1.0})).isCloseTo(
          (1.0 + 2.0 * 0.5403023058681398 + 0.8414709848078965) * 2.0,
          1e-12,
        );
      },
    );
  });

  group('Power and nested function expansion', () {
    test('handles zero, unit, negative, and RealNumber integer exponents', () {
      final base = Expr.parse('x + 1');
      check(Pow(base, IntegerNumber.zero).expand()).equals(IntegerNumber.one);
      check(Pow(base, IntegerNumber.one).expand().toString()).equals('1 + x');
      check(Pow(base, const RealNumber(2.0)).expand().toString())
          .equals('(1 + x) ^ 2.0');

      final negPow = Expr.parse('(x + 1)^(-2)').expand();
      check(negPow.evaluate({'x': 1.0})).equals(0.25);

      final fracPow = Expr.parse('((x + 1)^2)^(1/2)').expand();
      check(fracPow.evaluate({'x': 3.0})).equals(4.0);

      check(() => Pow(IntegerNumber.zero, IntegerNumber.negativeOne).expand())
          .throws<UnsupportedError>();
    });

    test('recursively expands inside sums and function arguments', () {
      final sumExpanded = Expr.parse('(x + 1)^2 + (x - 1)^2').expand();
      check(sumExpanded.toString()).equals('2 + 2 * x ^ 2');

      final trig = Expr.parse('sin((x + 1)^2)').expand();
      check(trig.toString()).equals('sin(1 + 2 * x + x ^ 2)');
    });
  });
}
