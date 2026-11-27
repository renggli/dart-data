import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:more/number.dart' show Complex;
import 'package:test/scaffolding.dart';

void main() {
  group('Error functions (erf, erfc)', () {
    test('identities, evaluation, substitution, and mapChildren', () {
      const x = Variable('x');
      const y = Variable('y');
      check(Fn.erf(IntegerNumber.zero).simplify()).equals(IntegerNumber.zero);
      check(Fn.erfc(IntegerNumber.zero).simplify()).equals(IntegerNumber.one);
      check(Fn.erf(Constant.infinity).simplify()).equals(IntegerNumber.one);
      check(Fn.erfc(Constant.infinity).simplify()).equals(IntegerNumber.zero);
      check(Fn.erf(-x).simplify()).equals(-Fn.erf(x));

      const v = 0.7;
      check(Fn.erf(x).evaluate({'x': v}) + Fn.erfc(x).evaluate({'x': v}))
          .isCloseTo(1.0, 1e-14);

      check(Fn.erf(x).substitute('x', y)).equals(Fn.erf(y));
      check(Fn.erf(x).mapChildren((_) => y)).equals(Fn.erf(y));
      check(Fn.erfc(x).substitute('x', y)).equals(Fn.erfc(y));
      check(Fn.erfc(x).mapChildren((_) => y)).equals(Fn.erfc(y));
    });
  });

  group('Euler Gamma and Beta functions', () {
    test('exact factorials, half-integers, evaluation, substitution, and mapChildren', () {
      const x = Variable('x');
      const y = Variable('y');
      check(Fn.gamma(IntegerNumber.one).simplify()).equals(IntegerNumber.one);
      check(Fn.gamma(IntegerNumber.of(5)).simplify())
          .equals(IntegerNumber.of(24));
      check(Fn.gamma(FractionNumber.half).simplify())
          .equals(Pow.of(Constant.pi, FractionNumber.half));
      check(Fn.gamma(x).evaluate({'x': 4.0})).isCloseTo(6.0, 1e-12);
      check(Fn.gamma(x).substitute('x', y)).equals(Fn.gamma(y));
      check(Fn.gamma(x).mapChildren((_) => y)).equals(Fn.gamma(y));

      check(Fn.beta(IntegerNumber.of(2), IntegerNumber.of(3)).simplify())
          .equals(RationalNumber(1, 12));
      check(Fn.beta(x, y).evaluate({'x': 2.0, 'y': 3.0}))
          .isCloseTo(1.0 / 12.0, 1e-12);
      check(Fn.beta(x, y).substitute('x', IntegerNumber.two))
          .equals(Fn.beta(IntegerNumber.two, y));
      check(Fn.beta(x, y).mapChildren((e) => e == x ? IntegerNumber.two : e))
          .equals(Fn.beta(IntegerNumber.two, y));
    });
  });

  group('Lambert W function', () {
    test(
      'symbolic construction, branch selection, identities, and evaluation',
      () {
        const x = Variable('x');
        const y = Variable('y');
        final w0 = Fn.lambertW(x);
        final wm1 = Fn.lambertW(x, IntegerNumber.negativeOne);

        check(w0.args.length).equals(1);
        check(wm1.args.last).equals(IntegerNumber.negativeOne);
        check(w0.freeVariables).unorderedEquals(['x']);
        check(w0.dependsOn('x')).isTrue;
        check(w0.dependsOn('y')).isFalse;
        check(w0.substitute('x', y)).equals(Fn.lambertW(y));
        check(wm1.substitute('x', y))
            .equals(Fn.lambertW(y, IntegerNumber.negativeOne));
        check(w0.mapChildren((_) => y)).equals(Fn.lambertW(y));
        check(wm1.mapChildren((e) => e == x ? y : e))
            .equals(Fn.lambertW(y, IntegerNumber.negativeOne));
        check(w0.anyNode((e) => e == x)).isTrue;
        check(w0 == wm1).isFalse;
        check(w0).equals(Fn.lambertW(x));
        check(w0.hashCode).equals(Fn.lambertW(x).hashCode);
        check(wm1.hashCode)
            .equals(Fn.lambertW(x, IntegerNumber.negativeOne).hashCode);

        check(Fn.lambertW(IntegerNumber.zero).simplify())
            .equals(IntegerNumber.zero);
        check(Fn.lambertW(Constant.e).simplify()).equals(IntegerNumber.one);
        final negInvE = -Pow.of(Constant.e, IntegerNumber.negativeOne);
        check(Fn.lambertW(negInvE).simplify())
            .equals(IntegerNumber.negativeOne);
        check(Fn.lambertW(negInvE, IntegerNumber.negativeOne).simplify())
            .equals(IntegerNumber.negativeOne);

        check(w0.evaluate({'x': 0.0})).equals(0.0);
        check(w0.evaluate({'x': math.e})).isCloseTo(1.0, 1e-14);
        final w1 = w0.evaluate({'x': 1.0});
        check(w1 * math.exp(w1)).isCloseTo(1.0, 1e-14);
        final w2 = w0.evaluate({'x': 2.0});
        check(w2 * math.exp(w2)).isCloseTo(2.0, 1e-14);
        final wm1Val = wm1.evaluate({'x': -0.2});
        check(wm1Val).isLessThan(-1.0);
        check(wm1Val * math.exp(wm1Val)).isCloseTo(-0.2, 1e-13);
        check(w0.evaluate({'x': -0.5}).isNaN).isTrue;
        check(wm1.evaluate({'x': 0.5}).isNaN).isTrue;

        const z = Complex(1.0);
        final wC = Fn.lambertW(x).evaluateComplex({'x': z});
        final checkZ = wC * wC.exp();
        check(checkZ.a).isCloseTo(z.a, 1e-12);
        check(checkZ.b).isCloseTo(0.0, 1e-12);
      },
    );
  });

  group('Zeta, Digamma, Polygamma, Bessel, and Elliptic functions', () {
    test(
      'Zeta, Digamma, and Polygamma exact values, evaluation, and parsing',
      () {
        const x = Variable('x');
        const y = Variable('y');

        check(Fn.zeta(IntegerNumber.zero).simplify())
            .equals(FractionNumber.negativeHalf);
        check(Fn.zeta(IntegerNumber.negativeOne).simplify())
            .equals(RationalNumber(-1, 12));
        check(Fn.zeta(IntegerNumber.of(-2)).simplify())
            .equals(IntegerNumber.zero);
        check(Fn.zeta(IntegerNumber.of(-3)).simplify())
            .equals(RationalNumber(1, 120));
        check(Fn.zeta(IntegerNumber.of(-4)).simplify())
            .equals(IntegerNumber.zero);
        check(
          Fn.zeta(IntegerNumber.two).simplify(),
        ).equals(RationalNumber(1, 6) * Pow.of(Constant.pi, IntegerNumber.two));
        check(Fn.zeta(IntegerNumber.of(4)).simplify()).equals(
          RationalNumber(1, 90) * Pow.of(Constant.pi, IntegerNumber.of(4)),
        );
        check(Fn.zeta(x).evaluate({'x': 2.0}))
            .isCloseTo(1.6449340668482264, 1e-12);
        check(Fn.zeta(x).evaluate({'x': 3.0}))
            .isCloseTo(1.202056903159594, 1e-12);
        check(Fn.zeta(x).substitute('x', y)).equals(Fn.zeta(y));
        check(Fn.zeta(x).mapChildren((_) => y)).equals(Fn.zeta(y));
        check(
          Expr.parse('zeta(2)').simplify(),
        ).equals(RationalNumber(1, 6) * Pow.of(Constant.pi, IntegerNumber.two));
        check(Expr.parse('zeta(x)').toFunction1D('x')(2.0))
            .isCloseTo(1.6449340668482264, 1e-12);

        check(Fn.digamma(IntegerNumber.one).simplify())
            .equals(Fn.digamma(IntegerNumber.one));
        check(Fn.digamma(IntegerNumber.two).simplify())
            .equals(Fn.digamma(IntegerNumber.two));
        check(
          (Fn.digamma(const RealNumber(1.0)).simplify() as RealNumber).value,
        ).isCloseTo(-0.5772156649015329, 1e-12);
        check(Fn.polygamma(IntegerNumber.one, IntegerNumber.one).simplify())
            .equals(Fn.polygamma(IntegerNumber.one, IntegerNumber.one));
        check(
          (Fn.polygamma(IntegerNumber.one, const RealNumber(1.0)).simplify()
                  as RealNumber)
              .value,
        ).isCloseTo(1.6449340668482264, 1e-12);

        check(Fn.digamma(IntegerNumber.one).evaluate())
            .isCloseTo(-0.5772156649015329, 1e-12);
        check(Fn.digamma(x).evaluate({'x': 1.0}))
            .isCloseTo(-0.5772156649015329, 1e-12);
        check(Fn.digamma(x).evaluate({'x': 2.0}))
            .isCloseTo(1.0 - 0.5772156649015329, 1e-12);
        check(Fn.polygamma(IntegerNumber.one, x).evaluate({'x': 1.0}))
            .isCloseTo(1.6449340668482264, 1e-12);
        check(Fn.digamma(x).substitute('x', y)).equals(Fn.digamma(y));
        check(Fn.digamma(x).mapChildren((_) => y)).equals(Fn.digamma(y));
        check(Fn.polygamma(IntegerNumber.one, x).substitute('x', y))
            .equals(Fn.polygamma(IntegerNumber.one, y));
        check(
          Fn.polygamma(x, y).mapChildren((e) => e == x ? IntegerNumber.two : e),
        ).equals(Fn.polygamma(IntegerNumber.two, y));
        check(Expr.parse('digamma(x)').toFunction1D('x')(1.0))
            .isCloseTo(-0.5772156649015329, 1e-12);
        check(Expr.parse('polygamma(1, x)').toFunction1D('x')(1.0))
            .isCloseTo(1.6449340668482264, 1e-12);
      },
    );

    test('Bessel and complete Elliptic functions', () {
      const x = Variable('x');
      const y = Variable('y');
      const k = Variable('k');
      const m = Variable('m');

      check(Fn.besselJ(IntegerNumber.zero, IntegerNumber.zero).simplify())
          .equals(IntegerNumber.one);
      check(Fn.besselJ(IntegerNumber.one, IntegerNumber.zero).simplify())
          .equals(IntegerNumber.zero);
      check(Fn.besselI(IntegerNumber.zero, IntegerNumber.zero).simplify())
          .equals(IntegerNumber.one);
      check(Fn.besselI(IntegerNumber.one, IntegerNumber.zero).simplify())
          .equals(IntegerNumber.zero);

      check(Fn.besselJ(IntegerNumber.zero, x).evaluate({'x': 1.0}))
          .isCloseTo(0.7651976865579666, 1e-7);
      check(Fn.besselJ(IntegerNumber.one, x).evaluate({'x': 1.0}))
          .isCloseTo(0.4400505857449335, 1e-7);
      check(Fn.besselY(IntegerNumber.zero, x).evaluate({'x': 1.0}))
          .isCloseTo(0.08825696421567697, 1e-7);
      check(Fn.besselI(IntegerNumber.zero, x).evaluate({'x': 1.0}))
          .isCloseTo(1.2660658777520084, 1e-7);
      check(Fn.besselK(IntegerNumber.zero, x).evaluate({'x': 1.0}))
          .isCloseTo(0.42102443824070834, 1e-7);

      for (final (node, expected) in [
        (Fn.besselJ(IntegerNumber.zero, x), Fn.besselJ(IntegerNumber.zero, y)),
        (Fn.besselY(IntegerNumber.zero, x), Fn.besselY(IntegerNumber.zero, y)),
        (Fn.besselI(IntegerNumber.zero, x), Fn.besselI(IntegerNumber.zero, y)),
        (Fn.besselK(IntegerNumber.zero, x), Fn.besselK(IntegerNumber.zero, y)),
      ]) {
        check(node.substitute('x', y)).equals(expected);
        check(node.mapChildren((e) => e == x ? y : e)).equals(expected);
      }
      check(Expr.parse('besselJ(0, x)').toFunction1D('x')(1.0))
          .isCloseTo(0.7651976865579666, 1e-7);

      check(Fn.ellipticK(IntegerNumber.zero).simplify())
          .equals(FractionNumber.half * Constant.pi);
      check(Fn.ellipticE(IntegerNumber.zero).simplify())
          .equals(FractionNumber.half * Constant.pi);
      check(Fn.ellipticE(IntegerNumber.one).simplify())
          .equals(IntegerNumber.one);
      check(Fn.ellipticK(k).evaluate({'k': 0.5}))
          .isCloseTo(1.685750354812596, 1e-12);
      check(Fn.ellipticE(k).evaluate({'k': 0.5}))
          .isCloseTo(1.4674622093394272, 1e-12);
      check(Fn.ellipticK(k).substitute('k', m)).equals(Fn.ellipticK(m));
      check(Fn.ellipticK(k).mapChildren((_) => m)).equals(Fn.ellipticK(m));
      check(Fn.ellipticE(k).substitute('k', m)).equals(Fn.ellipticE(m));
      check(Fn.ellipticE(k).mapChildren((_) => m)).equals(Fn.ellipticE(m));
      check(Expr.parse('ellipticK(0)').simplify())
          .equals(FractionNumber.half * Constant.pi);
      check(Expr.parse('ellipticK(k)').toFunction1D('k')(0.5))
          .isCloseTo(1.685750354812596, 1e-12);
      check(Expr.parse('ellipticE(k)').toFunction1D('k')(0.5))
          .isCloseTo(1.4674622093394272, 1e-12);
    });
  });

  group('Hypergeometric, ExpIntegralE, Hurwitz Zeta, LogGamma, AppellF1', () {
    test('simplifies, differentiates, evaluates, and formats Hypergeometric and ExpIntegralE', () {
      const x = Variable('x');
      final h = Expr.parse('hypergeometric([1, 2], [3], x)');
      check((h as Call).id).equals(FunctionId.hypergeometric);
      check(h.toString()).equals('hypergeometric([1, 2], [3], x)');
      check(Expr.parse('hypergeometric([1, 2], [3], 0)').simplify())
          .equals(IntegerNumber.one);
      check(Expr.parse('hypergeometric([1, 2], [2, 3], x)').simplify())
          .equals(Expr.parse('hypergeometric([1], [3], x)'));
      check(h.evaluate({'x': 0.5})).isCloseTo(1.5451774444795623, 1e-10);
      final dh = h.derivative('x');
      final fd =
          (h.evaluate({'x': 0.4 + 1e-6}) - h.evaluate({'x': 0.4 - 1e-6})) /
          2e-6;
      check(dh.evaluate({'x': 0.4})).isCloseTo(fd, 1e-6);

      final hyp = Fn.hypergeometric(
        Fn.tuple([x]),
        Fn.tuple([IntegerNumber.two]),
        const Variable('y'),
      );
      check(hyp.anyNode((n) => n == x)).isTrue;
      check(hyp.anyNode((n) => n == const Variable('y'))).isTrue;
      check(hyp.anyNode((n) => n == const Variable('z'))).isFalse;
      check(hyp).equals(
        Fn.hypergeometric(
          Fn.tuple([x]),
          Fn.tuple([IntegerNumber.two]),
          const Variable('y'),
        ),
      );

      final e2 = Expr.parse('expIntegralE(2, x)');
      check((e2 as Call).id).equals(FunctionId.expIntegralE);
      check(e2.toString()).equals('expIntegralE(2, x)');
      check(Expr.parse('expIntegralE(0, x)').simplify())
          .equals(Expr.parse('exp(-x) / x').simplify());
      check(e2.evaluate({'x': 1.0})).isCloseTo(0.14849550677592205, 1e-10);
      check(e2.derivative('x')).equals(-Fn.expIntegralE(IntegerNumber.one, x));
    });

    test('Hurwitz Zeta, LogGamma, AppellF1, and complex numeric folding', () {
      const x = Variable('x');
      final hz = Expr.parse('zeta(3, x)');
      check((hz as Call).id).equals(FunctionId.zeta);
      check(hz.toString()).equals('zeta(3, x)');
      check(Expr.parse('zeta(3, 1)').simplify())
          .equals(Fn.zeta(IntegerNumber.of(3)));
      check(hz.evaluate({'x': 1.0})).isCloseTo(1.202056903159594, 1e-10);
      check(hz.evaluate({'x': 2.0})).isCloseTo(0.202056903159594, 1e-10);
      check(hz.derivative('x')).equals(
        (-IntegerNumber.of(3) * Fn.zeta(IntegerNumber.of(4), x)).simplify(),
      );

      final zf = ComplexNumber(const RealNumber(1.5), const RealNumber(0.5));
      check(Fn.zeta(const RealNumber(2.0), const RealNumber(0.5)).simplify())
          .isA<RealNumber>();
      check(Fn.zeta(zf, const RealNumber(1.5)).simplify()).isA<ComplexNumber>();
      check(Fn.zeta(zf).simplify()).isA<ComplexNumber>();
      check(Fn.zeta(const RealNumber(2.0)).simplify()).isA<RealNumber>();
      for (final n in [-5, -7, -9, -11, -13, -15]) {
        check(Fn.zeta(IntegerNumber.of(n)).simplify()).isA<RationalNumber>();
      }
      check(Fn.digamma(zf).simplify()).isA<ComplexNumber>();
      check(Fn.polygamma(IntegerNumber.one, zf).simplify())
          .isA<ComplexNumber>();
      check(Fn.besselJ(IntegerNumber.zero, zf).simplify()).isA<ComplexNumber>();
      check(Fn.besselY(IntegerNumber.zero, zf).simplify()).isA<ComplexNumber>();
      check(Fn.besselI(IntegerNumber.zero, zf).simplify()).isA<ComplexNumber>();
      check(Fn.besselK(IntegerNumber.zero, zf).simplify()).isA<ComplexNumber>();
      check(
        Fn.ellipticPi(
          const RealNumber(0.3),
          const RealNumber(0.7),
          const RealNumber(0.5),
        ).simplify(),
      ).isA<RealNumber>();
      check(
        Fn.ellipticPi(
          const RealNumber(0.3),
          zf,
          const RealNumber(0.5),
        ).simplify(),
      ).isA<ComplexNumber>();
      check(
        Fn.expIntegralE(
          const RealNumber(2.0),
          const RealNumber(1.5),
        ).simplify(),
      ).isA<RealNumber>();
      check(Fn.expIntegralE(const RealNumber(2.0), zf).simplify())
          .isA<ComplexNumber>();
      check(
        Fn.hypergeometric(
          Fn.tuple([const RealNumber(1.0), const RealNumber(2.0)]),
          Fn.tuple([const RealNumber(3.0)]),
          const RealNumber(0.5),
        ).simplify(),
      ).isA<RealNumber>();
      check(
        Fn.hypergeometric(
          Fn.tuple([const RealNumber(1.0), const RealNumber(2.0)]),
          Fn.tuple([const RealNumber(3.0)]),
          ComplexNumber(const RealNumber(0.3), const RealNumber(0.2)),
        ).simplify(),
      ).isA<ComplexNumber>();

      final erfcC = Fn.erfc(
        ComplexNumber(const RealNumber(1.0), const RealNumber(1.0)),
      ).simplify();
      check(erfcC).isA<ComplexNumber>();

      final hurwitz = Fn.zeta(
        IntegerNumber.two,
        IntegerNumber.of(3),
      ).simplify();
      check(hurwitz is Call && hurwitz.id == FunctionId.zeta).isFalse;

      check(Fn.besselJ(const RealNumber(0.5), const RealNumber(1.2)).simplify())
          .isA<RealNumber>();
      check(Fn.besselY(const RealNumber(0.5), const RealNumber(1.2)).simplify())
          .isA<RealNumber>();
      check(Fn.besselI(const RealNumber(0.5), const RealNumber(1.2)).simplify())
          .isA<RealNumber>();
      check(Fn.besselK(const RealNumber(0.5), const RealNumber(1.2)).simplify())
          .isA<RealNumber>();

      for (final node in <Expr>[
        Fn.ei(const RealNumber(1.2)),
        Fn.li(const RealNumber(2.5)),
        Fn.si(const RealNumber(1.2)),
        Fn.ci(const RealNumber(1.2)),
        Fn.shi(const RealNumber(1.2)),
        Fn.chi(const RealNumber(1.2)),
        Fn.fresnelS(const RealNumber(1.2)),
        Fn.fresnelC(const RealNumber(1.2)),
        Fn.polylog(IntegerNumber.two, const RealNumber(0.5)),
      ]) {
        check(node.simplify()).isA<RealNumber>();
      }

      check(Expr.parse('cbrt(x)')).equals(Pow.of(x, FractionNumber.third));
      check(Expr.parse('cbrt(-27)').simplify()).equals(IntegerNumber.of(-3));

      final lg = Expr.parse('logGamma(x)');
      check((lg as Call).id).equals(FunctionId.logGamma);
      check(Expr.parse(lg.toString())).equals(lg);
      check(lg.toLatex()).equals(r'\ln\Gamma(x)');
      check(lg.toMathMl()).contains('ln');
      check(Expr.parse('logGamma(1)').simplify()).equals(IntegerNumber.zero);
      check(Expr.parse('logGamma(2)').simplify()).equals(IntegerNumber.zero);
      check(Expr.parse('polygamma(-1, x)').simplify()).equals(Fn.logGamma(x));
      check(lg.derivative('x').simplify()).equals(Fn.digamma(x));
      check(
        Fn.logGamma(const RealNumber(2.5))
            .toBytecode(variables: const <String>[])
            .evaluate1D(0.0),
      ).isCloseTo(Fn.logGamma(const RealNumber(2.5)).evaluate(), 1e-12);
      check(Fn.logGamma(const RealNumber(-0.5)).simplify())
          .isA<ComplexNumber>();
      final lgNeg = Fn.logGamma(const RealNumber(-0.5)).evaluateComplex();
      check(lgNeg.a).isCloseTo(math.log(2 * math.sqrt(math.pi)), 1e-12);
      check(lgNeg.b.abs()).isCloseTo(math.pi, 1e-12);

      final f1 = Expr.parse('appellF1(1/2, 1, 2, 3/2, -2*x, -3*x)');
      check((f1 as Call).id).equals(FunctionId.appellF1);
      check(Expr.parse(f1.toString())).equals(f1);
      check(f1.toLatex()).contains(r'F_1\left(');
      check(f1.toMathMl()).contains('<msub><mi>F</mi><mn>1</mn></msub>');
      check(Expr.parse('appellF1(a, b1, b2, c, 0, 0)').simplify())
          .equals(IntegerNumber.one);
      check(Expr.parse('appellF1(a, b1, b2, a, x, y)').simplify()).equals(
        ((IntegerNumber.one - x).pow(-const Variable('b1')) *
                (IntegerNumber.one - const Variable('y')).pow(
                  -const Variable('b2'),
                ))
            .simplify(),
      );

      final rubiAnti = Expr.parse(
        '(2*x)^(1/2) * appellF1(1/2, 1, 2, 3/2, -2*x, -3*x) / 1',
      );
      final df = rubiAnti.derivative('x');
      final diffAtPt =
          (df - Expr.parse('1 / (sqrt(2*x) * (1 + 2*x) * (1 + 3*x)^2)'))
              .evaluateComplex(const {'x': Complex(0.15, 0.05)});
      check(diffAtPt.abs()).isLessThan(1e-12);

      final bc = Expr.parse('appellF1(1/2, 1, -1/2, 3/2, x, 2*x)')
          .toBytecode(variables: const ['x']);
      final directC = Expr.parse('appellF1(1/2, 1, -1/2, 3/2, x, 2*x)')
          .evaluateComplex(const {'x': Complex(0.2, 0.1)});
      check((bc.evaluateComplex1D(const Complex(0.2, 0.1)) - directC).abs())
          .isLessThan(1e-12);

      // Additional coverage: Hurwitz zeta complex, polygamma error, polylog(1, x)',
      // AppellF1 full derivative in both x and y, and special LaTeX/MathML rendering
      check(
        Fn.zeta(
          const RealNumber(2.0),
          const RealNumber(1.5),
        ).evaluateComplex(const {}).a,
      ).isCloseTo(0.9348022005446793, 1e-12);
      check(
        () => Fn.polygamma(
          ComplexNumber.i,
          IntegerNumber.two,
        ).evaluateComplex(const {}),
      ).throws<UnsupportedError>();
      check(Fn.polylog(IntegerNumber.one, x).derivative('x').simplify())
          .equals((IntegerNumber.one / (IntegerNumber.one - x)).simplify());
      final f1Both = Fn.appellF1([
        FractionNumber.half,
        IntegerNumber.one,
        IntegerNumber.two,
        IntegerNumber.of(3),
        x,
        x * IntegerNumber.two,
      ]).derivative('x');
      check(f1Both.anyNode((n) => n is Derivative)).isFalse;

      for (final expr in [
        Fn.expIntegralE(IntegerNumber.two, x),
        Fn.besselY(IntegerNumber.zero, x),
        Fn.besselI(IntegerNumber.zero, x),
        Fn.besselK(IntegerNumber.zero, x),
        Fn.hypergeometric(
          Fn.tuple([IntegerNumber.one]),
          Fn.tuple([IntegerNumber.two]),
          x,
        ),
      ]) {
        check(expr.toLatex()).isNotEmpty;
        check(expr.toMathMl()).contains('<');
      }
    });
  });
}
