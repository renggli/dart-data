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
      check(Expr.parse('gcd(12, 18)').simplify()).equals(IntegerNumber.of(6));
      check(Expr.parse('lcm(12, 18)').simplify()).equals(IntegerNumber.of(36));

      // First-class Gcd, Lcm, and Tuple AST nodes
      final gcdSym = Expr.parse('gcd(x, 12, 18)').simplify();
      check(gcdSym).equals(Gcd([IntegerNumber.of(6), const Variable('x')]));
      check(gcdSym.substitute('x', IntegerNumber.of(15)).simplify())
          .equals(IntegerNumber.of(3));
      check(gcdSym.evaluate({'x': 15.0})).equals(3.0);
      check(gcdSym.toString()).equals('gcd(6, x)');
      check(gcdSym.toLatex()).equals(r'\gcd\left(6, x\right)');
      check(gcdSym.toMathMl()).equals(
        '<math><mrow><mi>gcd</mi><mo>(</mo><mn>6</mn><mo>,</mo><mi>x</mi><mo>)</mo></mrow></math>',
      );

      final lcmSym = Expr.parse('lcm(x, 4, 6)').simplify();
      check(lcmSym).equals(Lcm([IntegerNumber.of(12), const Variable('x')]));
      check(lcmSym.substitute('x', IntegerNumber.of(8)).simplify())
          .equals(IntegerNumber.of(24));
      check(lcmSym.evaluate({'x': 8.0})).equals(24.0);
      check(Expr.parse('lcm(x, 0)').simplify()).equals(IntegerNumber.zero);
      check(Expr.parse('gcd(x, 0)').simplify()).equals(const Variable('x'));
      check(lcmSym.toString()).equals('lcm(12, x)');
      check(lcmSym.toLatex()).equals(r'\operatorname{lcm}\left(12, x\right)');
      check(lcmSym.toMathMl()).equals(
        '<math><mrow><mi>lcm</mi><mo>(</mo><mn>12</mn><mo>,</mo><mi>x</mi><mo>)</mo></mrow></math>',
      );

      final tup = Expr.parse('[x + x, 6 / 2]').simplify();
      check(tup).equals(
        Tuple([IntegerNumber.two * const Variable('x'), IntegerNumber.of(3)]),
      );
      check(tup.derivative('x'))
          .equals(Tuple([IntegerNumber.two, IntegerNumber.zero]));
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

      const x = Variable('x');
      const y = Variable('y');
      check(Factorial(x).substitute('x', y)).equals(Factorial(y));
      check(Factorial(x).mapChildren((_) => y)).equals(Factorial(y));
      check(Binomial(x, y).substitute('x', IntegerNumber.two))
          .equals(Binomial(IntegerNumber.two, y));
      check(Binomial(x, y).mapChildren((e) => e == x ? IntegerNumber.two : e))
          .equals(Binomial(IntegerNumber.two, y));
      check(Binomial(x, y).evaluate({'x': double.nan, 'y': 2.0})).isNaN;
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
        check(node.evaluate({'x': double.nan})).isNaN;
        check(node.substitute('x', y)).equals(build(y));
        check(node.mapChildren((_) => y)).equals(build(y));
      }
      check(Sign(x).evaluate({'x': 0.0})).equals(0.0);
      check(Sign(x).evaluate({'x': 2.5})).equals(1.0);

      check(Mod(x, y).evaluate({'x': 17.0, 'y': 5.0})).equals(2.0);
      check(Mod(x, y).evaluate({'x': 17.0, 'y': 0.0})).isNaN;
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

  group('Hypergeometric, ExpIntegralE, Hurwitz Zeta, Min, and Max', () {
    test(
      'simplifies, differentiates, evaluates, and formats Hypergeometric',
      () {
        final h = Expr.parse('hyper([1, 2], [3], x)');
        check(h).isA<Hypergeometric>();
        check(h.toString()).equals('hyper([1, 2], [3], x)');
        check(Expr.parse('hyper([1, 2], [3], 0)').simplify())
            .equals(IntegerNumber.one);
        check(Expr.parse('hyper([1, 2], [2, 3], x)').simplify())
            .equals(Expr.parse('hyper([1], [3], x)'));
        check(h.evaluate({'x': 0.5})).isCloseTo(1.5451774444795623, 1e-10);
        final dh = h.derivative('x');
        final fd =
            (h.evaluate({'x': 0.4 + 1e-6}) - h.evaluate({'x': 0.4 - 1e-6})) /
            2e-6;
        check(dh.evaluate({'x': 0.4})).isCloseTo(fd, 1e-6);
      },
    );

    test('simplifies, differentiates, evaluates, and formats ExpIntegralE', () {
      const x = Variable('x');
      final e2 = Expr.parse('expint(2, x)');
      check(e2).isA<ExpIntegralE>();
      check(e2.toString()).equals('expint(2, x)');
      check(Expr.parse('expint(0, x)').simplify())
          .equals(Expr.parse('exp(-x) / x').simplify());
      check(e2.evaluate({'x': 1.0})).isCloseTo(0.14849550677592205, 1e-10);
      check(e2.derivative('x')).equals(-ExpIntegralE(IntegerNumber.one, x));
    });

    test('simplifies, differentiates, and evaluates Hurwitz Zeta', () {
      const x = Variable('x');
      final hz = Expr.parse('zeta(3, x)');
      check(hz).isA<Zeta>();
      check(hz.toString()).equals('zeta(3, x)');
      check(Expr.parse('zeta(3, 1)').simplify())
          .equals(Zeta(IntegerNumber.of(3)));
      check(hz.evaluate({'x': 1.0})).isCloseTo(1.202056903159594, 1e-10);
      check(hz.evaluate({'x': 2.0})).isCloseTo(0.202056903159594, 1e-10);
      check(hz.derivative('x')).equals(
        (-IntegerNumber.of(3) * Zeta(IntegerNumber.of(4), shift: x)).simplify(),
      );
    });

    test('simplifies, differentiates, evaluates, and formats Min and Max', () {
      const x = Variable('x');
      final mn = Expr.parse('min(x, 3, 5)').simplify();
      final mx = Expr.parse('max(x, 3, 5)').simplify();
      check(mn).equals(Min([IntegerNumber.of(3), x]));
      check(mx).equals(Max([IntegerNumber.of(5), x]));
      check(mn.evaluate({'x': 1.0})).equals(1.0);
      check(mn.evaluate({'x': 4.0})).equals(3.0);
      check(mx.evaluate({'x': 1.0})).equals(5.0);
      check(mx.evaluate({'x': 8.0})).equals(8.0);
      check(Min([x, IntegerNumber.two]).derivative('x').evaluate({'x': 1.0}))
          .isCloseTo(1.0, 1e-12);
      check(Max([x, IntegerNumber.two]).derivative('x').evaluate({'x': 1.0}))
          .isCloseTo(0.0, 1e-12);

      // Float & float-complex simplification coverage for special functions
      final zf = ComplexNumber(const RealNumber(1.5), const RealNumber(0.5));
      check(
        Zeta(const RealNumber(2.0), shift: const RealNumber(0.5)).simplify(),
      ).isA<RealNumber>();
      check(Zeta(zf, shift: const RealNumber(1.5)).simplify())
          .isA<ComplexNumber>();
      check(Zeta(zf).simplify()).isA<ComplexNumber>();
      check(Zeta(const RealNumber(2.0)).simplify()).isA<RealNumber>();
      for (final n in [-5, -7, -9, -11, -13, -15]) {
        check(Zeta(IntegerNumber.of(n)).simplify()).isA<RationalNumber>();
      }
      check(Digamma(zf).simplify()).isA<ComplexNumber>();
      check(Polygamma(IntegerNumber.one, zf).simplify()).isA<ComplexNumber>();
      check(BesselJ(IntegerNumber.zero, zf).simplify()).isA<ComplexNumber>();
      check(BesselY(IntegerNumber.zero, zf).simplify()).isA<ComplexNumber>();
      check(BesselI(IntegerNumber.zero, zf).simplify()).isA<ComplexNumber>();
      check(BesselK(IntegerNumber.zero, zf).simplify()).isA<ComplexNumber>();
      check(
        EllipticPi(
          const RealNumber(0.3),
          const RealNumber(0.7),
          const RealNumber(0.5),
        ).simplify(),
      ).isA<RealNumber>();
      check(
        EllipticPi(const RealNumber(0.3), zf, const RealNumber(0.5)).simplify(),
      ).isA<ComplexNumber>();
      check(
        ExpIntegralE(const RealNumber(2.0), const RealNumber(1.5)).simplify(),
      ).isA<RealNumber>();
      check(ExpIntegralE(const RealNumber(2.0), zf).simplify())
          .isA<ComplexNumber>();
      check(
        Hypergeometric(
          [const RealNumber(1.0), const RealNumber(2.0)],
          [const RealNumber(3.0)],
          const RealNumber(0.5),
        ).simplify(),
      ).isA<RealNumber>();
      check(
        Hypergeometric(
          [const RealNumber(1.0), const RealNumber(2.0)],
          [const RealNumber(3.0)],
          ComplexNumber(const RealNumber(0.3), const RealNumber(0.2)),
        ).simplify(),
      ).isA<ComplexNumber>();
    });
  });
}
