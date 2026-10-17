import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:test/test.dart';

void main() {
  group('Error functions (Erf and Erfc)', () {
    test('identities, evaluation, substitution, and mapChildren', () {
      const x = Variable('x');
      const y = Variable('y');
      check(Erf(IntegerNumber.zero).simplify()).equals(IntegerNumber.zero);
      check(Erfc(IntegerNumber.zero).simplify()).equals(IntegerNumber.one);
      check(Erf(Constant.infinity).simplify()).equals(IntegerNumber.one);
      check(Erfc(Constant.infinity).simplify()).equals(IntegerNumber.zero);
      check(Erf(-x).simplify()).equals(-Erf(x));

      const v = 0.7;
      check(Erf(x).evaluate({'x': v}) + Erfc(x).evaluate({'x': v}))
          .isCloseTo(1.0, 1e-14);

      check(Erf(x).substitute('x', y)).equals(Erf(y));
      check(Erf(x).mapChildren((_) => y)).equals(Erf(y));
      check(Erfc(x).substitute('x', y)).equals(Erfc(y));
      check(Erfc(x).mapChildren((_) => y)).equals(Erfc(y));
    });
  });

  group('Euler Gamma and Beta functions', () {
    test('exact factorials, half-integers, evaluation, substitution, and mapChildren', () {
      const x = Variable('x');
      const y = Variable('y');
      check(Gamma(IntegerNumber.one).simplify()).equals(IntegerNumber.one);
      check(Gamma(IntegerNumber.of(5)).simplify()).equals(IntegerNumber.of(24));
      check(Gamma(FractionNumber.half).simplify())
          .equals(Pow(Constant.pi, FractionNumber.half, isSimplified: true));
      check(Gamma(x).evaluate({'x': 4.0})).isCloseTo(6.0, 1e-12);
      check(Gamma(x).substitute('x', y)).equals(Gamma(y));
      check(Gamma(x).mapChildren((_) => y)).equals(Gamma(y));

      check(Beta(IntegerNumber.of(2), IntegerNumber.of(3)).simplify())
          .equals(RationalNumber(1, 12));
      check(Beta(x, y).evaluate({'x': 2.0, 'y': 3.0}))
          .isCloseTo(1.0 / 12.0, 1e-12);
      check(Beta(x, y).substitute('x', IntegerNumber.two))
          .equals(Beta(IntegerNumber.two, y));
      check(Beta(x, y).mapChildren((e) => e == x ? IntegerNumber.two : e))
          .equals(Beta(IntegerNumber.two, y));
    });
  });

  group('Inverse hyperbolic functions (Asinh, Acosh, Atanh)', () {
    test('simplification and evaluation', () {
      const x = Variable('x');
      check(Asinh(IntegerNumber.zero).simplify()).equals(IntegerNumber.zero);
      check(Acosh(IntegerNumber.one).simplify()).equals(IntegerNumber.zero);
      check(Atanh(IntegerNumber.zero).simplify()).equals(IntegerNumber.zero);
      check(Asinh(-x).simplify()).equals(-Asinh(x));
      check(Atanh(-x).simplify()).equals(-Atanh(x));

      final sinhVal = Sinh(const RealNumber(1.2)).evaluate();
      final coshVal = Cosh(const RealNumber(1.2)).evaluate();
      final tanhVal = Tanh(const RealNumber(0.6)).evaluate();
      check(Asinh(x).evaluate({'x': sinhVal})).isCloseTo(1.2, 1e-12);
      check(Acosh(x).evaluate({'x': coshVal})).isCloseTo(1.2, 1e-12);
      check(Atanh(x).evaluate({'x': tanhVal})).isCloseTo(0.6, 1e-12);
    });
  });

  group('Combinatorial, rounding, and modular functions', () {
    test('Factorial and postfix ! operator', () {
      check(Expr.parse('5!')).equals(Factorial(IntegerNumber.of(5)));
      check(Expr.parse('5!').simplify()).equals(IntegerNumber.of(120));
      check(Expr.parse('0!').simplify()).equals(IntegerNumber.one);
      check(Expr.parse('(x + 1)!').toString()).equals('(x + 1)!');
      check(Expr.parse('x!').toString()).equals('x!');
      check(Expr.parse('x! != 1'))
          .equals(NotEqual(Factorial(const Variable('x')), IntegerNumber.one));
      check(Expr.parse('x!').toLatex()).equals('x!');
      check(Expr.parse('(x + 1)!').toLatex()).equals('(x + 1)!');
      check(Expr.parse('x!').toMathMl())
          .equals('<math><mrow><mi>x</mi><mo>!</mo></mrow></math>');
      check(Expr.parse('x!').evaluate({'x': 5.0})).isCloseTo(120.0, 1e-12);
      check(Expr.parse('x!').toFunction1D('x')(5.0)).isCloseTo(120.0, 1e-12);
    });

    test('Binomial coefficient', () {
      check(Expr.parse('binomial(5, 2)').simplify())
          .equals(IntegerNumber.of(10));
      check(Expr.parse('nCr(6, 3)').simplify()).equals(IntegerNumber.of(20));
      check(Expr.parse('binomial(x, 0)').simplify()).equals(IntegerNumber.one);
      check(Expr.parse('binomial(x, 1)').simplify())
          .equals(const Variable('x'));
      check(Expr.parse('binomial(x, x)').simplify()).equals(IntegerNumber.one);
      check(Expr.parse('binomial(n, k)').toString()).equals('binomial(n, k)');
      check(Expr.parse('binomial(n, k)').toLatex()).equals(r'\binom{n}{k}');
      check(Expr.parse('binomial(n, k)').evaluate({'n': 5.0, 'k': 2.0}))
          .isCloseTo(10.0, 1e-12);
      check(Expr.parse('binomial(x, 2)').toFunction1D('x')(5.0))
          .isCloseTo(10.0, 1e-12);
    });

    test('Floor, Ceil, Round, Sign, and Mod', () {
      check(Expr.parse('floor(7/2)').simplify()).equals(IntegerNumber.of(3));
      check(Expr.parse('floor(-7/2)').simplify()).equals(IntegerNumber.of(-4));
      check(Expr.parse('ceil(7/2)').simplify()).equals(IntegerNumber.of(4));
      check(Expr.parse('ceil(-7/2)').simplify()).equals(IntegerNumber.of(-3));
      check(Expr.parse('round(5/2)').simplify()).equals(IntegerNumber.of(3));
      check(Expr.parse('round(3/2)').simplify()).equals(IntegerNumber.of(2));
      check(Expr.parse('sign(-5)').simplify())
          .equals(IntegerNumber.negativeOne);
      check(Expr.parse('sgn(0)').simplify()).equals(IntegerNumber.zero);
      check(Expr.parse('sign(5)').simplify()).equals(IntegerNumber.one);
      check(
        Sign(const Variable('x', domain: VariableDomain.positive)).simplify(),
      ).equals(IntegerNumber.one);
      check(Expr.parse('mod(17, 5)').simplify()).equals(IntegerNumber.of(2));
      check(Expr.parse('mod(-7, 5)').simplify()).equals(IntegerNumber.of(3));
      check(Expr.parse('gcd(12, 18)')).equals(IntegerNumber.of(6));
      check(Expr.parse('lcm(12, 18)')).equals(IntegerNumber.of(36));

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

      check(Expr.parse('floor(x)').toFunction1D('x')(3.7)).equals(3.0);
      check(Expr.parse('ceil(x)').toFunction1D('x')(3.2)).equals(4.0);
      check(Expr.parse('round(x)').toFunction1D('x')(3.6)).equals(4.0);
      check(Expr.parse('sign(x)').toFunction1D('x')(-3.6)).equals(-1.0);
      check(Expr.parse('mod(x, 5)').toFunction1D('x')(-7.0)).equals(3.0);
    });
  });
}
