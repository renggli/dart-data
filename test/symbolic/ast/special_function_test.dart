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
        Sign(const Variable('x')).simplify(
          assumptions: const Assumptions(
            domains: {'x': VariableDomain.positive},
          ),
        ),
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

      const x = Variable('x');
      const y = Variable('y');
      check(Factorial(x).substitute('x', y)).equals(Factorial(y));
      check(Factorial(x).mapChildren((_) => y)).equals(Factorial(y));
      check(Binomial(x, y).substitute('x', IntegerNumber.two))
          .equals(Binomial(IntegerNumber.two, y));
      check(Binomial(x, y).mapChildren((e) => e == x ? IntegerNumber.two : e))
          .equals(Binomial(IntegerNumber.two, y));
      check(Binomial(x, y).evaluate({'x': double.nan, 'y': 2.0})).isNaN();
      check(Binomial(x, y).evaluate({'x': 5.0, 'y': -1.0})).equals(0.0);
      check(Binomial(x, y).evaluate({'x': 3.0, 'y': 5.0})).equals(0.0);

      for (final (build, val, expected)
          in <(Expr Function(Expr), double, double)>[
            (Floor.new, 3.7, 3.0),
            (Ceil.new, 3.2, 4.0),
            (Round.new, 3.6, 4.0),
            (Sign.new, -3.6, -1.0),
          ]) {
        final node = build(x);
        check(node.evaluate({'x': val})).equals(expected);
        check(node.evaluate({'x': double.nan})).isNaN();
        check(node.substitute('x', y)).equals(build(y));
        check(node.mapChildren((_) => y)).equals(build(y));
      }
      check(Sign(x).evaluate({'x': 0.0})).equals(0.0);
      check(Sign(x).evaluate({'x': 2.5})).equals(1.0);

      check(Mod(x, y).evaluate({'x': 17.0, 'y': 5.0})).equals(2.0);
      check(Mod(x, y).evaluate({'x': 17.0, 'y': 0.0})).isNaN();
      check(Mod(x, y).substitute('x', IntegerNumber.two))
          .equals(Mod(IntegerNumber.two, y));
      check(Mod(x, y).mapChildren((e) => e == x ? IntegerNumber.two : e))
          .equals(Mod(IntegerNumber.two, y));

      check(Expr.parse('floor(x)').toFunction1D('x')(3.7)).equals(3.0);
      check(Expr.parse('ceil(x)').toFunction1D('x')(3.2)).equals(4.0);
      check(Expr.parse('round(x)').toFunction1D('x')(3.6)).equals(4.0);
      check(Expr.parse('sign(x)').toFunction1D('x')(-3.6)).equals(-1.0);
      check(Expr.parse('mod(x, 5)').toFunction1D('x')(-7.0)).equals(3.0);
    });
  });

  group('Riemann Zeta function (Zeta)', () {
    test('exact values, evaluation, substitution, and mapChildren', () {
      const x = Variable('x');
      const y = Variable('y');

      // Exact special values
      check(Zeta(IntegerNumber.zero).simplify())
          .equals(FractionNumber.negativeHalf);
      check(Zeta(IntegerNumber.of(-1)).simplify())
          .equals(RationalNumber(-1, 12));
      check(Zeta(IntegerNumber.of(-2)).simplify()).equals(IntegerNumber.zero);
      check(Zeta(IntegerNumber.of(-3)).simplify())
          .equals(RationalNumber(1, 120));
      check(Zeta(IntegerNumber.of(-4)).simplify()).equals(IntegerNumber.zero);

      check(Zeta(IntegerNumber.two).simplify())
          .equals(RationalNumber(1, 6) * Pow(Constant.pi, IntegerNumber.two));
      check(
        Zeta(IntegerNumber.of(4)).simplify(),
      ).equals(RationalNumber(1, 90) * Pow(Constant.pi, IntegerNumber.of(4)));

      // Evaluation
      check(Zeta(x).evaluate({'x': 2.0})).isCloseTo(1.6449340668482264, 1e-12);
      check(Zeta(x).evaluate({'x': 3.0})).isCloseTo(1.202056903159594, 1e-12);

      // AST substitution and child mapping
      check(Zeta(x).substitute('x', y)).equals(Zeta(y));
      check(Zeta(x).mapChildren((_) => y)).equals(Zeta(y));

      // Parsing and toFunction1D
      check(Expr.parse('zeta(2)').simplify())
          .equals(RationalNumber(1, 6) * Pow(Constant.pi, IntegerNumber.two));
      check(Expr.parse('zeta(x)').toFunction1D('x')(2.0))
          .isCloseTo(1.6449340668482264, 1e-12);
    });
  });

  group('Digamma and Polygamma functions', () {
    test('exact values, evaluation, substitution, and mapChildren', () {
      const x = Variable('x');
      const y = Variable('y');

      // Simplification and exact values
      check(Digamma(IntegerNumber.one).simplify())
          .equals(Digamma(IntegerNumber.one));
      check(Digamma(IntegerNumber.two).simplify())
          .equals(Digamma(IntegerNumber.two));
      check((Digamma(const RealNumber(1.0)).simplify() as RealNumber).value)
          .isCloseTo(-0.5772156649015329, 1e-12);

      check(Polygamma(IntegerNumber.one, IntegerNumber.one).simplify())
          .equals(Polygamma(IntegerNumber.one, IntegerNumber.one));
      check(
        (Polygamma(IntegerNumber.one, const RealNumber(1.0)).simplify()
                as RealNumber)
            .value,
      ).isCloseTo(1.6449340668482264, 1e-12);

      // Evaluation
      check(Digamma(IntegerNumber.one).evaluate())
          .isCloseTo(-0.5772156649015329, 1e-12);
      check(Digamma(x).evaluate({'x': 1.0}))
          .isCloseTo(-0.5772156649015329, 1e-12);
      check(Digamma(x).evaluate({'x': 2.0}))
          .isCloseTo(1.0 - 0.5772156649015329, 1e-12);
      check(Polygamma(IntegerNumber.one, x).evaluate({'x': 1.0}))
          .isCloseTo(1.6449340668482264, 1e-12);

      // AST substitution and child mapping
      check(Digamma(x).substitute('x', y)).equals(Digamma(y));
      check(Digamma(x).mapChildren((_) => y)).equals(Digamma(y));

      check(Polygamma(IntegerNumber.one, x).substitute('x', y))
          .equals(Polygamma(IntegerNumber.one, y));
      check(Polygamma(x, y).mapChildren((e) => e == x ? IntegerNumber.two : e))
          .equals(Polygamma(IntegerNumber.two, y));

      // Parsing and toFunction1D
      check(Expr.parse('digamma(1)').simplify())
          .equals(Digamma(IntegerNumber.one));
      check(Expr.parse('psi(1)').simplify()).equals(Digamma(IntegerNumber.one));
      check(Expr.parse('digamma(x)').toFunction1D('x')(1.0))
          .isCloseTo(-0.5772156649015329, 1e-12);
      check(Expr.parse('polygamma(1, x)').toFunction1D('x')(1.0))
          .isCloseTo(1.6449340668482264, 1e-12);
    });
  });

  group('Bessel functions (BesselJ, BesselY, BesselI, BesselK)', () {
    test('special values, evaluation, substitution, and mapChildren', () {
      const x = Variable('x');
      const y = Variable('y');

      // Exact special values
      check(BesselJ(IntegerNumber.zero, IntegerNumber.zero).simplify())
          .equals(IntegerNumber.one);
      check(BesselJ(IntegerNumber.one, IntegerNumber.zero).simplify())
          .equals(IntegerNumber.zero);
      check(BesselI(IntegerNumber.zero, IntegerNumber.zero).simplify())
          .equals(IntegerNumber.one);
      check(BesselI(IntegerNumber.one, IntegerNumber.zero).simplify())
          .equals(IntegerNumber.zero);

      // Evaluation
      check(BesselJ(IntegerNumber.zero, x).evaluate({'x': 1.0}))
          .isCloseTo(0.7651976865579666, 1e-7);
      check(BesselJ(IntegerNumber.one, x).evaluate({'x': 1.0}))
          .isCloseTo(0.4400505857449335, 1e-7);
      check(BesselY(IntegerNumber.zero, x).evaluate({'x': 1.0}))
          .isCloseTo(0.08825696421567697, 1e-7);
      check(BesselI(IntegerNumber.zero, x).evaluate({'x': 1.0}))
          .isCloseTo(1.2660658777520084, 1e-7);
      check(BesselK(IntegerNumber.zero, x).evaluate({'x': 1.0}))
          .isCloseTo(0.42102443824070834, 1e-7);

      // Substitution and mapping
      for (final (node, expected) in [
        (BesselJ(IntegerNumber.zero, x), BesselJ(IntegerNumber.zero, y)),
        (BesselY(IntegerNumber.zero, x), BesselY(IntegerNumber.zero, y)),
        (BesselI(IntegerNumber.zero, x), BesselI(IntegerNumber.zero, y)),
        (BesselK(IntegerNumber.zero, x), BesselK(IntegerNumber.zero, y)),
      ]) {
        check(node.substitute('x', y)).equals(expected);
        check(node.mapChildren((e) => e == x ? y : e)).equals(expected);
      }

      // Parsing and toFunction1D
      check(Expr.parse('besselj(0, x)').toFunction1D('x')(1.0))
          .isCloseTo(0.7651976865579666, 1e-7);
      check(Expr.parse('besselj0(x)').toFunction1D('x')(1.0))
          .isCloseTo(0.7651976865579666, 1e-7);
      check(Expr.parse('besselj1(x)').toFunction1D('x')(1.0))
          .isCloseTo(0.4400505857449335, 1e-7);
    });
  });

  group('Complete elliptic integrals (EllipticK, EllipticE)', () {
    test('special values, evaluation, substitution, and mapChildren', () {
      const k = Variable('k');
      const m = Variable('m');

      // Special values
      check(EllipticK(IntegerNumber.zero).simplify())
          .equals(FractionNumber.half * Constant.pi);
      check(EllipticE(IntegerNumber.zero).simplify())
          .equals(FractionNumber.half * Constant.pi);
      check(EllipticE(IntegerNumber.one).simplify()).equals(IntegerNumber.one);

      // Evaluation
      check(EllipticK(k).evaluate({'k': 0.5}))
          .isCloseTo(1.685750354812596, 1e-12);
      check(EllipticE(k).evaluate({'k': 0.5}))
          .isCloseTo(1.4674622093394272, 1e-12);

      // Substitution and mapping
      check(EllipticK(k).substitute('k', m)).equals(EllipticK(m));
      check(EllipticK(k).mapChildren((_) => m)).equals(EllipticK(m));
      check(EllipticE(k).substitute('k', m)).equals(EllipticE(m));
      check(EllipticE(k).mapChildren((_) => m)).equals(EllipticE(m));

      // Parsing and toFunction1D
      check(Expr.parse('elliptick(0)').simplify())
          .equals(FractionNumber.half * Constant.pi);
      check(Expr.parse('elliptick(k)').toFunction1D('k')(0.5))
          .isCloseTo(1.685750354812596, 1e-12);
      check(Expr.parse('elliptice(k)').toFunction1D('k')(0.5))
          .isCloseTo(1.4674622093394272, 1e-12);
    });
  });
}
