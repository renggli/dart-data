import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('Combinatorial and integer functions', () {
    test('Factorial and postfix ! operator', () {
      check(Expr.parse('5!')).equals(Fn.factorial(IntegerNumber.of(5)));
      check(Expr.parse('5!').simplify()).equals(IntegerNumber.of(120));
      check(Expr.parse('0!').simplify()).equals(IntegerNumber.one);
      check(Expr.parse('(x + 1)!').toString()).equals('(1 + x)!');
      check(Expr.parse('x!').toString()).equals('x!');
      check(Expr.parse('x! != 1')).equals(
        Relational.notEqual(
          Fn.factorial(const Variable('x')),
          IntegerNumber.one,
        ),
      );
      check(Expr.parse('x!').toLatex()).equals('x!');
      check(Expr.parse('(x + 1)!').toLatex()).equals('(1 + x)!');
      check(Expr.parse('x!').toMathMl())
          .equals('<math><mrow><mi>x</mi><mo>!</mo></mrow></math>');
      check(Expr.parse('x!').evaluate({'x': 5.0})).isCloseTo(120.0, 1e-12);
      check(Expr.parse('x!').toFunction1D('x')(5.0)).isCloseTo(120.0, 1e-12);
    });

    test('Binomial coefficient', () {
      const x = Variable('x');
      const y = Variable('y');
      check(Expr.parse('binomial(5, 2)').simplify())
          .equals(IntegerNumber.of(10));
      check(Expr.parse('binomial(x, 0)').simplify()).equals(IntegerNumber.one);
      check(Expr.parse('binomial(x, 1)').simplify()).equals(x);
      check(Expr.parse('binomial(x, x)').simplify()).equals(IntegerNumber.one);
      check(Expr.parse('binomial(n, k)').toString()).equals('binomial(n, k)');
      check(Expr.parse('binomial(n, k)').toLatex()).equals(r'\binom{n}{k}');
      check(Expr.parse('binomial(n, k)').evaluate({'n': 5.0, 'k': 2.0}))
          .isCloseTo(10.0, 1e-12);
      check(Expr.parse('binomial(x, 2)').toFunction1D('x')(5.0))
          .isCloseTo(10.0, 1e-12);
      check(Fn.binomial(x, y).substitute('x', IntegerNumber.two))
          .equals(Fn.binomial(IntegerNumber.two, y));
      check(
        Fn.binomial(x, y).mapChildren((e) => e == x ? IntegerNumber.two : e),
      ).equals(Fn.binomial(IntegerNumber.two, y));
      check(Fn.binomial(x, y).evaluate({'x': double.nan, 'y': 2.0})).isNaN;
      check(Fn.binomial(x, y).evaluate({'x': 5.0, 'y': -1.0})).equals(0.0);
      check(Fn.binomial(x, y).evaluate({'x': 3.0, 'y': 5.0})).equals(0.0);
    });
  });

  group('Rounding, Sign, Mod, Gcd, Lcm, Min, Max, and Tuple', () {
    test('Floor, Ceil, Round, Sign, Mod, Gcd, Lcm, and Tuple', () {
      const x = Variable('x');
      const y = Variable('y');

      check(Expr.parse('floor(7/2)').simplify()).equals(IntegerNumber.of(3));
      check(Expr.parse('floor(-7/2)').simplify()).equals(IntegerNumber.of(-4));
      check(Expr.parse('ceil(7/2)').simplify()).equals(IntegerNumber.of(4));
      check(Expr.parse('ceil(-7/2)').simplify()).equals(IntegerNumber.of(-3));
      check(Expr.parse('round(5/2)').simplify()).equals(IntegerNumber.of(3));
      check(Expr.parse('round(3/2)').simplify()).equals(IntegerNumber.of(2));
      check(Expr.parse('sign(-5)').simplify())
          .equals(IntegerNumber.negativeOne);
      check(Expr.parse('sign(0)').simplify()).equals(IntegerNumber.zero);
      check(Expr.parse('sign(5)').simplify()).equals(IntegerNumber.one);
      check(
        Fn.sign(x).simplify(
          assumptions: const Assumptions(
            domains: {'x': VariableDomain.positive},
          ),
        ),
      ).equals(IntegerNumber.one);
      check(Expr.parse('mod(17, 5)').simplify()).equals(IntegerNumber.of(2));
      check(Expr.parse('mod(-7, 5)').simplify()).equals(IntegerNumber.of(3));
      check(Expr.parse('gcd(12, 18)').simplify()).equals(IntegerNumber.of(6));
      check(Expr.parse('lcm(12, 18)').simplify()).equals(IntegerNumber.of(36));

      final gcdSym = Expr.parse('gcd(x, 12, 18)').simplify();
      check(gcdSym).equals(Fn.gcd([IntegerNumber.of(6), x]));
      check(gcdSym.substitute('x', IntegerNumber.of(15)).simplify())
          .equals(IntegerNumber.of(3));
      check(gcdSym.evaluate({'x': 15.0})).equals(3.0);
      check(gcdSym.toString()).equals('gcd(6, x)');
      check(gcdSym.toLatex()).equals(r'\gcd\left(6, x\right)');
      check(gcdSym.toMathMl()).equals(
        '<math><mrow><mi>gcd</mi><mo>(</mo><mn>6</mn><mo>,</mo><mi>x</mi><mo>)</mo></mrow></math>',
      );

      final lcmSym = Expr.parse('lcm(x, 4, 6)').simplify();
      check(lcmSym).equals(Fn.lcm([IntegerNumber.of(12), x]));
      check(lcmSym.substitute('x', IntegerNumber.of(8)).simplify())
          .equals(IntegerNumber.of(24));
      check(lcmSym.evaluate({'x': 8.0})).equals(24.0);
      check(Expr.parse('lcm(x, 0)').simplify()).equals(IntegerNumber.zero);
      check(Expr.parse('gcd(x, 0)').simplify()).equals(Fn.abs(x));
      check(
        Expr.parse('gcd(x, 0)').simplify(
          assumptions: const Assumptions(
            domains: {'x': VariableDomain.positive},
          ),
        ),
      ).equals(x);
      check(lcmSym.toString()).equals('lcm(12, x)');
      check(lcmSym.toLatex()).equals(r'\operatorname{lcm}\left(12, x\right)');
      check(lcmSym.toMathMl()).equals(
        '<math><mrow><mi>lcm</mi><mo>(</mo><mn>12</mn><mo>,</mo><mi>x</mi><mo>)</mo></mrow></math>',
      );

      final tup = Expr.parse('[x + x, 6 / 2]').simplify();
      check(tup).equals(Fn.tuple([IntegerNumber.two * x, IntegerNumber.of(3)]));
      check(tup.derivative('x'))
          .equals(Fn.tuple([IntegerNumber.two, IntegerNumber.zero]));
      check(tup.toString()).equals('[2 * x, 3]');
      check(tup.toLatex()).equals(r'\left[2 x, 3\right]');
      check(tup.toMathMl()).equals(
        '<math><mrow><mo>[</mo><mrow><mn>2</mn><mi>x</mi></mrow><mo>,</mo><mn>3</mn><mo>]</mo></mrow></math>',
      );

      for (final source in [
        'floor(x)',
        'ceil(x)',
        'round(x)',
        'sign(x)',
        'mod(x, 3)',
      ]) {
        final expr = Expr.parse(source);
        check(Expr.parse(expr.toString())).equals(expr);
      }
      check(Expr.parse('floor(x)').toLatex()).equals(r'\lfloor x \rfloor');
      check(Expr.parse('ceil(x)').toLatex()).equals(r'\lceil x \rceil');
      check(Expr.parse('round(x)').toLatex())
          .equals(r'\operatorname{round}(x)');
      check(Expr.parse('sign(x)').toLatex()).equals(r'\operatorname{sgn}(x)');
      check(Expr.parse('mod(x, y)').toLatex()).equals(r'x \bmod y');

      check(Fn.factorial(x).substitute('x', y)).equals(Fn.factorial(y));
      check(Fn.factorial(x).mapChildren((_) => y)).equals(Fn.factorial(y));

      for (final (build, val, expected)
          in <(Expr Function(Expr), double, double)>[
            (Fn.floor.call, 3.7, 3.0),
            (Fn.ceil.call, 3.2, 4.0),
            (Fn.round.call, 3.6, 4.0),
            (Fn.sign.call, -3.6, -1.0),
          ]) {
        final node = build(x);
        check(node.evaluate({'x': val})).equals(expected);
        check(node.evaluate({'x': double.nan})).isNaN;
        check(node.substitute('x', y)).equals(build(y));
        check(node.mapChildren((_) => y)).equals(build(y));
      }
      check(Fn.sign(x).evaluate({'x': 0.0})).equals(0.0);
      check(Fn.sign(x).evaluate({'x': 2.5})).equals(1.0);

      check(Fn.mod(x, y).evaluate({'x': 17.0, 'y': 5.0})).equals(2.0);
      check(Fn.mod(x, y).evaluate({'x': 17.0, 'y': 0.0})).isNaN;
      check(Fn.mod(x, y).substitute('x', IntegerNumber.two))
          .equals(Fn.mod(IntegerNumber.two, y));
      check(Fn.mod(x, y).mapChildren((e) => e == x ? IntegerNumber.two : e))
          .equals(Fn.mod(IntegerNumber.two, y));

      final mn = Expr.parse('min(x, 3, 5)').simplify();
      final mx = Expr.parse('max(x, 3, 5)').simplify();
      check(mn).equals(Fn.min([IntegerNumber.of(3), x]));
      check(mx).equals(Fn.max([IntegerNumber.of(5), x]));
      check(mn.evaluate({'x': 1.0})).equals(1.0);
      check(mn.evaluate({'x': 4.0})).equals(3.0);
      check(mx.evaluate({'x': 1.0})).equals(5.0);
      check(mx.evaluate({'x': 8.0})).equals(8.0);
      check(Fn.min([x, IntegerNumber.two]).derivative('x').evaluate({'x': 1.0}))
          .isCloseTo(1.0, 1e-12);
      check(Fn.max([x, IntegerNumber.two]).derivative('x').evaluate({'x': 1.0}))
          .isCloseTo(0.0, 1e-12);
      check(Fn.min([x, y]).anyNode((n) => n == x)).isTrue;
      check(Fn.max([x, y]).anyNode((n) => n == y)).isTrue;
      check(Fn.gcd([x, y]).anyNode((n) => n == x)).isTrue;
      check(Fn.lcm([x, y]).anyNode((n) => n == y)).isTrue;

      check(Expr.parse('floor(x)').toFunction1D('x')(3.7)).equals(3.0);
      check(Expr.parse('ceil(x)').toFunction1D('x')(3.2)).equals(4.0);
      check(Expr.parse('round(x)').toFunction1D('x')(3.6)).equals(4.0);
      check(Expr.parse('sign(x)').toFunction1D('x')(-3.6)).equals(-1.0);
      check(Expr.parse('mod(x, 5)').toFunction1D('x')(-7.0)).equals(3.0);

      check(Fn.factorial(Fn.factorial(x)).toLatex()).contains('!');
      check(Fn.min([x, y]).toLatex()).contains(r'\min');
      check(Fn.max([x, y]).toLatex()).contains(r'\max');
      check(
        Fn.binomial(
          const RealNumber(-2.0),
          IntegerNumber.of(3),
        ).evaluate(const {}),
      ).isCloseTo(-4.0, 1e-12);
      check(
        Fn.binomial(
          const RealNumber(5.0),
          IntegerNumber.two,
        ).evaluate(const {}),
      ).isCloseTo(10.0, 1e-12);
      check(Fn.factorial(Constant.infinity).evaluate(const {}))
          .equals(double.infinity);
      check(Fn.binomial(x, y).derivative('y').anyNode((n) => n is Derivative))
          .isFalse;
    });
  });
}
