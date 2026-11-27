import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:test/scaffolding.dart';

void main() {
  const x = Variable('x');

  group('Finite and directional limits', () {
    test('evaluates continuous and classic indeterminate limits', () {
      check(IntegerNumber.of(5).limit('x', IntegerNumber.zero))
          .equals(IntegerNumber.of(5));
      check(
        (Pow.of(x, IntegerNumber.two) +
                Fn.sinh(x) +
                Fn.cosh(x) +
                Pow.of(Constant.e, x))
            .limit('x', IntegerNumber.zero),
      ).equals(IntegerNumber.two);

      check(Expr.parse('sin(x) / x').limit('x', IntegerNumber.zero))
          .equals(IntegerNumber.one);
      check(Expr.parse('(1 - cos(x)) / x').limit('x', IntegerNumber.zero))
          .equals(IntegerNumber.zero);
      check(Expr.parse('(1 - cos(x)) / x^2').limit('x', IntegerNumber.zero))
          .equals(FractionNumber.half);
      check(Expr.parse('(exp(x) - 1 - x) / x^2').limit('x', IntegerNumber.zero))
          .equals(FractionNumber.half);
      check(Expr.parse('(x^2 - 4) / (x - 2)').limit('x', IntegerNumber.two))
          .equals(IntegerNumber.of(4));
      check(Expr.parse('(sqrt(x + 1) - 1) / x').limit('x', IntegerNumber.zero))
          .equals(FractionNumber.half);
    });

    test('evaluates higher-order Laurent expansions (order > 6)', () {
      final highQuot = Expr.parse('(sin(x) - x + x^3 / 6 - x^5 / 120) / x^7');
      check(highQuot.limit('x', IntegerNumber.zero))
          .equals(RationalNumber(-1, 5040));

      final highNonQuot = Expr.parse('tan(x) - x - x^3 / 3 - 2 * x^5 / 15');
      check(highNonQuot.limit('x', IntegerNumber.zero))
          .equals(IntegerNumber.zero);

      final veryHigh = Pow.of(x, IntegerNumber.of(20)) * Fn.tan(x);
      check(veryHigh.limit('x', IntegerNumber.zero)).equals(IntegerNumber.zero);
    });

    test('evaluates poles and directional limits', () {
      check(
        (IntegerNumber.one / x).limit(
          'x',
          IntegerNumber.zero,
          direction: LimitDirection.fromAbove,
        ),
      ).equals(Constant.infinity);
      check(
        (IntegerNumber.one / x).limit(
          'x',
          IntegerNumber.zero,
          direction: LimitDirection.fromBelow,
        ),
      ).equals(-Constant.infinity);
      check(
        (-IntegerNumber.one / x).limit(
          'x',
          IntegerNumber.zero,
          direction: LimitDirection.fromAbove,
        ),
      ).equals(-Constant.infinity);
      check(
        (-IntegerNumber.one / x).limit(
          'x',
          IntegerNumber.zero,
          direction: LimitDirection.fromBelow,
        ),
      ).equals(Constant.infinity);
      check(() => (IntegerNumber.one / x).limit('x', IntegerNumber.zero))
          .throws<UnsupportedError>();

      check(
        (IntegerNumber.one / Pow.of(x, IntegerNumber.two)).limit(
          'x',
          IntegerNumber.zero,
        ),
      ).equals(Constant.infinity);
      check(
        (-Constant.pi / Pow.of(x, IntegerNumber.two)).limit(
          'x',
          IntegerNumber.zero,
        ),
      ).equals(-Constant.infinity);
      check(
        ((-IntegerNumber.two * Constant.pi * Constant.e) /
                Pow.of(x, IntegerNumber.two))
            .limit('x', IntegerNumber.zero),
      ).equals(-Constant.infinity);
      check(
        (Constant.pi / Pow.of(x, IntegerNumber.two)).limit(
          'x',
          IntegerNumber.zero,
        ),
      ).equals(Constant.infinity);
    });

    test(
      'evaluates non-analytic finite limits via reciprocal transformation',
      () {
        check(
          (x * Fn.ln(x)).limit(
            'x',
            IntegerNumber.zero,
            direction: LimitDirection.fromAbove,
          ),
        ).equals(IntegerNumber.zero);
        check(
          (x * Fn.ln(-x)).limit(
            'x',
            IntegerNumber.zero,
            direction: LimitDirection.fromBelow,
          ),
        ).equals(IntegerNumber.zero);
        check(Fn.abs(x).limit('x', IntegerNumber.zero))
            .equals(IntegerNumber.zero);
        check(() => (Fn.abs(x) / x).limit('x', IntegerNumber.zero))
            .throws<UnsupportedError>();
        check(
          () => Pow.of(
            Constant.e,
            IntegerNumber.one / x,
          ).limit('x', IntegerNumber.zero),
        ).throws<UnsupportedError>();
      },
    );
  });

  group('Limits of elementary functions at finite and infinite points', () {
    test('evaluates exponential, power, and logarithmic limits', () {
      check(Expr.parse('(1 + 1 / x)^x').limit('x', Constant.infinity))
          .equals(Constant.e);
      check(Expr.parse('(-2 + x)^(3 + x)').limit('x', IntegerNumber.zero))
          .equals(IntegerNumber.of(-8));
      check(
        Expr.parse('((x + _h + _t)^2 - (_h + _t)^2) / x')
            .limit('x', IntegerNumber.zero),
      ).equals(
        (IntegerNumber.two * const Variable('_h') +
                IntegerNumber.two * const Variable('_t'))
            .simplify(),
      );
      check(Pow.of(x, x).limit('x', Constant.infinity))
          .equals(Constant.infinity);
      check(Pow.of(x, -x).limit('x', Constant.infinity))
          .equals(IntegerNumber.zero);

      check(Pow.of(Constant.e, x).limit('x', IntegerNumber.one))
          .equals(Constant.e);
      check(Pow.of(Constant.e, x).limit('x', Constant.infinity))
          .equals(Constant.infinity);
      check(Pow.of(Constant.e, -x).limit('x', Constant.infinity))
          .equals(IntegerNumber.zero);

      check(Fn.ln(x).limit('x', Constant.infinity)).equals(Constant.infinity);
      check(
        Fn.ln(
          x,
        ).limit('x', IntegerNumber.zero, direction: LimitDirection.fromAbove),
      ).equals(-Constant.infinity);
      check(
        () => Fn.ln(
          x,
        ).limit('x', IntegerNumber.zero, direction: LimitDirection.fromBelow),
      ).throws<UnsupportedError>();
      check(() => Fn.ln(x).limit('x', IntegerNumber.zero))
          .throws<UnsupportedError>();
      check(Fn.ln(Pow.of(x, IntegerNumber.two)).limit('x', IntegerNumber.zero))
          .equals(-Constant.infinity);
      check(Fn.ln(x).limit('x', IntegerNumber.one)).equals(IntegerNumber.zero);

      // Unevaluated Limit fall-through in Pow / exp
      final pwExp = Pow.of(
        Constant.e,
        Piecewise([
          (
            relation: Relational.lessThan(
              const Variable('y'),
              IntegerNumber.zero,
            ),
            expr: x,
          ),
        ]),
      );
      final limPw = pwExp.limit('x', Constant.infinity);
      check(limPw).isA<Limit>();
      check(
        limPw.anyNode(
          (n) => n is Pow && n.base == Constant.e && n.exponent is Limit,
        ),
      ).isFalse;
    });

    test('evaluates Sin, Cos, Atan, and Tanh limits', () {
      check(Fn.sin(x).limit('x', IntegerNumber.zero))
          .equals(IntegerNumber.zero);
      check(Fn.cos(x).limit('x', IntegerNumber.zero)).equals(IntegerNumber.one);
      check(Fn.atan(x).limit('x', IntegerNumber.zero))
          .equals(IntegerNumber.zero);
      check(Fn.tanh(x).limit('x', IntegerNumber.zero))
          .equals(IntegerNumber.zero);
      check(Fn.sin(const RealNumber(0.5) * x).limit('x', IntegerNumber.two))
          .equals(Fn.sin(const RealNumber(1.0)).simplify());
      check(Fn.sin(Constant.pi * x).limit('x', IntegerNumber.one))
          .equals(Fn.sin(Constant.pi).simplify());
      check(Fn.atan(Fn.ln(IntegerNumber.two) * x).limit('x', IntegerNumber.one))
          .equals(Fn.atan(Fn.ln(IntegerNumber.two)).simplify());

      check(Fn.atan(x).limit('x', Constant.infinity))
          .equals((Constant.pi / IntegerNumber.two).simplify());
      check(Fn.atan(x).limit('x', -Constant.infinity))
          .equals((-(Constant.pi / IntegerNumber.two)).simplify());
      check(Fn.tanh(x).limit('x', Constant.infinity)).equals(IntegerNumber.one);
      check(Fn.tanh(x).limit('x', -Constant.infinity))
          .equals(IntegerNumber.negativeOne);
      check(Fn.sinh(x).limit('x', Constant.infinity)).equals(Constant.infinity);
      check(Fn.sinh(x).limit('x', -Constant.infinity))
          .equals(-Constant.infinity);
      check(Fn.cosh(x).limit('x', Constant.infinity)).equals(Constant.infinity);
      check(Fn.cosh(x).limit('x', -Constant.infinity))
          .equals(Constant.infinity);
      check(Fn.asinh(x).limit('x', Constant.infinity))
          .equals(Constant.infinity);
      check(Fn.asinh(x).limit('x', -Constant.infinity))
          .equals(-Constant.infinity);
      check(Fn.acosh(x).limit('x', Constant.infinity))
          .equals(Constant.infinity);
      check(Fn.acosh(x).limit('x', -Constant.infinity))
          .equals(Constant.undefined);

      check(() => Fn.sin(x).limit('x', Constant.infinity))
          .throws<UnsupportedError>();
      check(() => Fn.cos(x).limit('x', Constant.infinity))
          .throws<UnsupportedError>();
    });
  });

  group('Asymptotic limits at infinity (rational, Gruntz MRV, and Squeeze)', () {
    test('evaluates rational functions at plus and minus infinity', () {
      check(Expr.parse('(x + 1) / (x^2 + 1)').limit('x', Constant.infinity))
          .equals(IntegerNumber.zero);
      check(Expr.parse('(3*x^2 + 1) / (x^2 - 5)').limit('x', Constant.infinity))
          .equals(IntegerNumber.of(3));
      check(Expr.parse('(x^3 + 1) / (x^2 + 1)').limit('x', Constant.infinity))
          .equals(Constant.infinity);
      check(Expr.parse('(-x^3 + 1) / (x^2 + 1)').limit('x', Constant.infinity))
          .equals(-Constant.infinity);
      check(Expr.parse('(x^3 + 1) / (x^2 + 1)').limit('x', -Constant.infinity))
          .equals(-Constant.infinity);
      check(
        (IntegerNumber.one / x).limit(
          'x',
          Mul.of([Constant.infinity, IntegerNumber.negativeOne]),
        ),
      ).equals(IntegerNumber.zero);
      check(Expr.parse('(3*x^2 + 1) / (x^2 - 5)').limit('x', Constant.infinity))
          .equals(IntegerNumber.of(3));
    });

    test('resolves Abs and Piecewise asymptotically at infinity', () {
      check((Fn.abs(x) / x).limit('x', Constant.infinity))
          .equals(IntegerNumber.one);
      check((Fn.abs(x) / x).limit('x', -Constant.infinity))
          .equals(IntegerNumber.negativeOne);
      check((Fn.abs(-x) / x).limit('x', Constant.infinity))
          .equals(IntegerNumber.one);

      final pw1 = Piecewise([
        (
          relation: Relational.greaterThan(x, IntegerNumber.zero),
          expr: IntegerNumber.of(7),
        ),
      ], otherwise: IntegerNumber.of(-7));
      check(pw1.limit('x', Constant.infinity)).equals(IntegerNumber.of(7));
      check(pw1.limit('x', -Constant.infinity)).equals(IntegerNumber.of(-7));
    });

    test('evaluates algebraic radicals and logarithmic limits at infinity', () {
      check(Expr.parse('sqrt(x^2 + x) - x').limit('x', Constant.infinity))
          .equals(FractionNumber.half);
      check(Expr.parse('sqrt(x^2 + 1) - x').limit('x', Constant.infinity))
          .equals(IntegerNumber.zero);
      check(Expr.parse('sqrt(x^4 + 1) - x').limit('x', Constant.infinity))
          .equals(Constant.infinity);
      check(Expr.parse('x - sqrt(x^4 + 1)').limit('x', Constant.infinity))
          .equals(-Constant.infinity);
      check(Expr.parse('sqrt(x^3 + 1) - x').limit('x', Constant.infinity))
          .equals(Constant.infinity);
      final undetAlg = Expr.parse('f(x)').limit('x', Constant.infinity);
      check(undetAlg).isA<Limit>();
      check(Expr.parse(undetAlg.toString())).equals(undetAlg);

      check((Fn.ln(x) / x).limit('x', Constant.infinity))
          .equals(IntegerNumber.zero);
      check(
        (Fn.ln(IntegerNumber.one + Pow.of(Constant.e, x)) / x).limit(
          'x',
          Constant.infinity,
        ),
      ).equals(IntegerNumber.one);
      check(
        (Fn.ln(Pow.of(Constant.e, x) + x) / x).limit('x', Constant.infinity),
      ).equals(IntegerNumber.one);
      check(
        (Fn.ln(Pow.of(Constant.e, x) + Fn.ln(x)) / x).limit(
          'x',
          Constant.infinity,
        ),
      ).equals(IntegerNumber.one);

      check(Expr.parse('abs(ln(x) - 5)/ln(x)').limit('x', Constant.infinity))
          .equals(IntegerNumber.one);
      check(Expr.parse('1/(ln(x) - 5)').limit('x', Constant.infinity))
          .equals(IntegerNumber.zero);
      check(Expr.parse('5 - ln(x)').limit('x', Constant.infinity))
          .equals(-Constant.infinity);
      check(() => Expr.parse('(-1 + 1/x)^x').limit('x', Constant.infinity))
          .throws<UnsupportedError>();
      check(Expr.parse('atan(x) + erf(x)').limit('x', 1))
          .equals(Expr.parse('pi/4 + erf(1)').simplify());
    });

    test('evaluates exponential hierarchy (Gruntz MRV) and Squeeze theorem', () {
      check(
        (Pow.of(x, IntegerNumber.of(5)) / Pow.of(Constant.e, x)).limit(
          'x',
          Constant.infinity,
        ),
      ).equals(IntegerNumber.zero);
      check(
        (Pow.of(Constant.e, x) / Pow.of(x, IntegerNumber.of(5))).limit(
          'x',
          Constant.infinity,
        ),
      ).equals(Constant.infinity);
      check(
        (-Pow.of(Constant.e, x) / Pow.of(x, IntegerNumber.of(5))).limit(
          'x',
          Constant.infinity,
        ),
      ).equals(-Constant.infinity);
      check(
        ((-IntegerNumber.two * Constant.pi * Pow.of(Constant.e, x)) /
                Pow.of(x, IntegerNumber.of(5)))
            .limit('x', Constant.infinity),
      ).equals(-Constant.infinity);
      check(
        (Pow.of(x - IntegerNumber.of(100), FractionNumber.half) *
                Pow.of(Constant.e, x))
            .limit('x', Constant.infinity),
      ).equals(Constant.infinity);

      final multiExp = Expr.parse(
        '(3 * exp(2 * x + 1) + exp(x)) / (exp(2 * x) - exp(x))',
      );
      check(multiExp.limit('x', Constant.infinity))
          .equals((IntegerNumber.of(3) * Constant.e).simplify());

      final mixedDegExp =
          (Pow.of(Constant.e, Pow.of(x, IntegerNumber.two) + x) +
              Pow.of(Constant.e, x)) /
          Pow.of(Constant.e, Pow.of(x, IntegerNumber.two) + x);
      check(mixedDegExp.limit('x', Constant.infinity))
          .equals(IntegerNumber.one);

      check(Expr.parse('exp(x - exp(x))').limit('x', Constant.infinity))
          .equals(IntegerNumber.zero);
      check(
        Expr.parse(
          'exp(x) * (exp(1/x + exp(-x) + exp(-x^2)) - exp(1/x - exp(-exp(x))))',
        ).limit('x', Constant.infinity),
      ).equals(IntegerNumber.one);
      check(
        Expr.parse('exp(exp(x - exp(-x)) / (1 - 1/x)) - exp(exp(x))')
            .limit('x', Constant.infinity),
      ).equals(Constant.infinity);

      final realExp =
          (Pow.of(Constant.e, const RealNumber(0.5) * x) + IntegerNumber.one) /
          Pow.of(Constant.e, x);
      check(realExp.limit('x', Constant.infinity)).equals(IntegerNumber.zero);

      check(
        (Pow.of(IntegerNumber.two, x) / Pow.of(IntegerNumber.of(3), x)).limit(
          'x',
          Constant.infinity,
        ),
      ).equals(IntegerNumber.zero);
      check(
        (Pow.of(IntegerNumber.of(3), x) / Pow.of(IntegerNumber.two, x)).limit(
          'x',
          Constant.infinity,
        ),
      ).equals(Constant.infinity);
      check(
        (Pow.of(IntegerNumber.two, x + IntegerNumber.one) /
                Pow.of(IntegerNumber.two, x))
            .limit('x', Constant.infinity),
      ).equals(IntegerNumber.two);
      check(
        ((x + IntegerNumber.one) * Pow.of(IntegerNumber.two, -x)).limit(
          'x',
          Constant.infinity,
        ),
      ).equals(IntegerNumber.zero);
      check(
        ((Pow.of(x, IntegerNumber.two) + x) * Pow.of(FractionNumber.half, x))
            .limit('x', Constant.infinity),
      ).equals(IntegerNumber.zero);
      check((Fn.sinh(x) / Fn.cosh(x)).limit('x', Constant.infinity))
          .equals(IntegerNumber.one);
      check((Fn.sinh(x) - Fn.cosh(x)).limit('x', Constant.infinity))
          .equals(IntegerNumber.zero);

      check((Fn.sin(x) / x).limit('x', Constant.infinity))
          .equals(IntegerNumber.zero);
      check((Fn.sin(x) / (x * Fn.ln(x))).limit('x', Constant.infinity))
          .equals(IntegerNumber.zero);
      check(
        (Pow.of(Fn.cos(x), IntegerNumber.two) / x).limit(
          'x',
          Constant.infinity,
        ),
      ).equals(IntegerNumber.zero);

      // Unexpanded polynomial exponents and terms in Gruntz and rational limits
      check(
        Expr.parse('exp((x + 1)^2) / exp(x^2 + 2 * x)')
            .limit('x', Constant.infinity),
      ).equals(Constant.e);
      check(Expr.parse('exp(x * (x + 1) - x^2)').limit('x', Constant.infinity))
          .equals(Constant.infinity);
      check(
        Expr.parse('((x + 1)^2 - x^2) / (2 * x + 5)')
            .limit('x', Constant.infinity),
      ).equals(IntegerNumber.one);
      check(() => (x * Fn.sin(x)).limit('x', Constant.infinity))
          .throws<UnsupportedError>();

      final unsupportedMrv =
          Piecewise([
            (
              relation: Relational.lessThan(
                const Variable('y'),
                IntegerNumber.zero,
              ),
              expr: Pow.of(Constant.e, x),
            ),
          ]) +
          Integral(
            Pow.of(Constant.e, x),
            't',
            lower: IntegerNumber.zero,
            upper: IntegerNumber.one,
          );
      final limNode = unsupportedMrv.limit('x', Constant.infinity);
      check(limNode).isA<Limit>();
      check(Expr.parse(limNode.toString())).equals(limNode);
      check(limNode.toLatex()).contains(r'\lim_{x \to \infty}');
      check(limNode.toMathMl(root: false))
          .contains('<munder><mo movablelimits="false">lim</mo>');

      final limAbove = Expr.parse('limit(f(x), x, 0, 1)');
      check(limAbove).equals(
        Limit(
          Expr.parse('f(x)'),
          'x',
          IntegerNumber.zero,
          direction: LimitDirection.fromAbove,
        ),
      );
      check(Expr.parse(limAbove.toString())).equals(limAbove);
      check(limAbove.toLatex()).equals(r'\lim_{x \to 0^+} f(x)');
      check(limAbove.toMathMl(root: false)).equals(
        '<mrow><munder><mo movablelimits="false">lim</mo><mrow><mi>x</mi><mo>&#x2192;</mo><msup><mn>0</mn><mo>+</mo></msup></mrow></munder><mrow><mi>f</mi><mo>(</mo><mi>x</mi><mo>)</mo></mrow></mrow>',
      );

      final limBelow = Expr.parse('limit(f(x), x, 0, -1)');
      check(Expr.parse(limBelow.toString())).equals(limBelow);
      check(limBelow.toLatex()).equals(r'\lim_{x \to 0^-} f(x)');

      check((Fn.sin(x) / x).limit('x', 0)).equals(IntegerNumber.one);
      check((x + IntegerNumber.one).limit('x', BigInt.two))
          .equals(IntegerNumber.of(3));
      check((x + IntegerNumber.one).limit('x', 1.5))
          .equals(const RealNumber(2.5));
      check((IntegerNumber.one / x).limit('x', double.infinity))
          .equals(IntegerNumber.zero);
      check((IntegerNumber.one / x).limit('x', double.negativeInfinity))
          .equals(IntegerNumber.zero);
      check(Fn.sin(x).limit('x', Constant.pi / IntegerNumber.two))
          .equals(IntegerNumber.one);
      check(() => x.limit('x', '??? invalid')).throws<ArgumentError>();

      // Exponential limits at infinity
      check(Pow.of(IntegerNumber.two, x).limit('x', Constant.infinity))
          .equals(Constant.infinity);
      check(Pow.of(FractionNumber.half, x).limit('x', -Constant.infinity))
          .equals(Constant.infinity);

      // Bounded oscillation with multiple non-oscillating factors
      final multiFactorOsc =
          (Mul.of([IntegerNumber.two, x, Fn.sin(x)])) /
          (Pow.of(x, IntegerNumber.two) + IntegerNumber.one);
      check(multiFactorOsc.limit('x', Constant.infinity))
          .equals(IntegerNumber.zero);

      // Asymptotic degree analysis scanning composite AST nodes
      final compositeExpr = Add.of([
        Derivative(x, 'x'),
        Limit(x, 't', IntegerNumber.zero),
        Sum(x, 'k', IntegerNumber.one, IntegerNumber.of(5)),
        Product(x, 'k', IntegerNumber.one, IntegerNumber.of(5)),
        Call.symbolic('f', [x]),
      ]);
      check(compositeExpr.limit('x', Constant.infinity)).isNotNull();

      // Assumptions propagation in limit
      check(
        Expr.parse('sqrt(x^2) / x')
            .limit('x', IntegerNumber.zero, assumptions: Assumptions.positive),
      ).equals(IntegerNumber.one);

      // Erfc at +infinity and -infinity, fresh limit variable collision, and power bounded factor
      check(Fn.erfc(x).limit('x', Constant.infinity))
          .equals(IntegerNumber.zero);
      check(Fn.erfc(x).limit('x', -Constant.infinity))
          .equals(IntegerNumber.two);
      const hVar = Variable('_h');
      const h1Var = Variable('_h_1');
      check((x + hVar + h1Var).limit('x', IntegerNumber.one))
          .equals((IntegerNumber.one + hVar + h1Var).simplify());
      final expComposite = Add.of([
        Pow.of(Constant.e, x),
        Limit(Pow.of(Constant.e, x), 't', IntegerNumber.zero),
        Sum(Pow.of(Constant.e, x), 'k', IntegerNumber.one, IntegerNumber.two),
      ]);
      check(expComposite.limit('x', Constant.infinity))
          .equals(Constant.infinity);

      // LambertW limits
      check(
        Fn.lambertW(
          x,
          IntegerNumber.negativeOne,
        ).limit('x', IntegerNumber.zero, direction: LimitDirection.fromBelow),
      ).equals(-Constant.infinity);
      check(
        () => Fn.lambertW(
          x,
          IntegerNumber.negativeOne,
        ).limit('x', IntegerNumber.zero, direction: LimitDirection.fromAbove),
      ).throws<UnsupportedError>();
      check(Fn.lambertW(x).limit('x', Constant.infinity))
          .equals(Constant.infinity);
    });

    test('limits involving special integral functions', () {
      const x = Variable('x');
      check(
        ((Fn.si(x) - x) / x.pow(IntegerNumber.of(3))).limit(
          'x',
          IntegerNumber.zero,
        ),
      ).equals(Expr.parse('-1/18').simplify());
      check((Fn.erfi(x) / x).limit('x', IntegerNumber.zero))
          .equals(Expr.parse('2/sqrt(pi)').simplify());
      check(
        (Fn.fresnelS(x) / x.pow(IntegerNumber.of(3))).limit(
          'x',
          IntegerNumber.zero,
        ),
      ).equals(Expr.parse('pi/6').simplify());
    });

    test('soundness for cancelling poles, unknown parameter signs, and oscillating bases', () {
      const x = Variable('x');
      const a = Variable('a');
      check(
        (IntegerNumber.one / x - IntegerNumber.one / Fn.sin(x)).limit('x', 0),
      ).equals(IntegerNumber.zero);

      check((a / Pow.of(x, IntegerNumber.two)).limit('x', 0)).isA<Limit>();
      check(
        (a / Pow.of(x, IntegerNumber.two)).limit(
          'x',
          0,
          assumptions: const Assumptions(
            domains: {'a': VariableDomain.positive},
          ),
        ),
      ).equals(Constant.infinity);
      check(
        ((-a) / Pow.of(x, IntegerNumber.two)).limit(
          'x',
          0,
          assumptions: const Assumptions(
            domains: {'a': VariableDomain.positive},
          ),
        ),
      ).equals(-Constant.infinity);
      check(
        () =>
            (Pow.of(IntegerNumber.of(-2), x) * x).limit('x', Constant.infinity),
      ).throws<UnsupportedError>();
    });

    test('evaluates hyperbolic and inverse hyperbolic limits at infinity', () {
      check(
        Expr.parse('(1 - tanh(x)) * exp(2 * x)').limit('x', Constant.infinity),
      ).equals(IntegerNumber.two);
      check(Expr.parse('asinh(x) - ln(2 * x)').limit('x', Constant.infinity))
          .equals(IntegerNumber.zero);
      check(Expr.parse('x * atanh(1 / x)').limit('x', Constant.infinity))
          .equals(IntegerNumber.one);
    });

    test('evaluates Stirling asymptotic limits for Factorial and Gamma', () {
      check(
        Expr.parse('x! / (sqrt(2*pi*x) * (x / e)^x)')
            .limit('x', Constant.infinity),
      ).equals(IntegerNumber.one);
      check(
        Expr.parse('gamma(x) / (sqrt(2*pi/x) * (x / e)^x)')
            .limit('x', Constant.infinity),
      ).equals(IntegerNumber.one);
      check(
        Expr.parse('(2*x)! / (x!^2 * 4^x / sqrt(pi*x))')
            .limit('x', Constant.infinity),
      ).equals(IntegerNumber.one);
    });

    test('combines logarithmic terms in infinity - infinity forms', () {
      check(
        Expr.parse(
          '-2 * ln(abs(x)) + 2 * ln(abs(2 * sqrt(4 + x) - 4) / abs(2 * sqrt(4 + x) + 4))',
        ).limit('x', IntegerNumber.zero, direction: LimitDirection.fromAbove),
      ).equals(Expr.parse('-8 * ln(2)').simplify());

      check(
        Expr.parse(
          '-1/2 * ln(abs(2 * x - 2) / abs(2 * x + 2)) + 1/2 * ln(x^2 - 1)',
        ).limit('x', IntegerNumber.one, direction: LimitDirection.fromAbove),
      ).equals(Expr.parse('ln(2)').simplify());

      check(
        Expr.parse('sqrt(75) * x^2 - sqrt(12) * x^2 + sqrt(27) * x')
            .limit('x', -Constant.infinity),
      ).equals(Constant.infinity);

      check(Expr.parse('x * x!').limit('x', Constant.infinity))
          .equals(Constant.infinity);

      // Log-vs-power dominance and GCD-factored logarithmic combination
      const radicalAntideriv =
          '-2 * ln(abs(x)) + 2 * ln(abs(-4 + 2 * sqrt(4 + x)) / abs(4 + 2 * sqrt(4 + x))) + 2 * sqrt(4 + x)';
      check(
        Expr.parse(
          radicalAntideriv,
        ).limit('x', IntegerNumber.zero, direction: LimitDirection.fromAbove),
      ).equals(Expr.parse('4 - 8 * ln(2)').simplify());
      check(Expr.parse(radicalAntideriv).limit('x', Constant.infinity))
          .equals(Constant.infinity);

      // Abs composition at ±infinity propagates real-domain errors immediately
      check(
        Expr.parse('-4 * ln(abs(2 + sqrt(4 + x))) + 2 * sqrt(4 + x)')
            .limit('x', Constant.infinity),
      ).equals(Constant.infinity);
      check(
        () =>
            Expr.parse('-4 * ln(abs(2 + sqrt(4 + x))) + 2 * sqrt(4 + x)')
                .limit('x', -Constant.infinity),
      ).throws<UnsupportedError>();
    });

    test('guards negative base powers, 0^(-infinity), and complex bounded trig limits', () {
      const x = Variable('x');
      check(
        () =>
            Pow.of(IntegerNumber.negativeOne, x).limit('x', Constant.infinity),
      ).throws<UnsupportedError>();
      check(() => Pow.of(IntegerNumber.zero, x).limit('x', -Constant.infinity))
          .throws<UnsupportedError>();
      check(
        () => Pow.of(
          x,
          FractionNumber.half,
        ).limit('x', 0, direction: LimitDirection.fromBelow),
      ).throws<UnsupportedError>();
      check((Fn.sin(x * ComplexNumber.i) / x).limit('x', Constant.infinity))
          .isA<Limit>();
      check(
        Piecewise([
          (
            relation: Relational.greaterEqual(x, IntegerNumber.of(5)),
            expr: IntegerNumber.of(9),
          ),
        ], otherwise: IntegerNumber.zero).limit('x', Constant.infinity),
      ).equals(IntegerNumber.of(9));
    });

    test('handles oscillating, LambertW, unknown-sign, Factorial/Gamma, bounded product, and Piecewise limits', () {
      const x = Variable('x');
      check(() => Pow.of(IntegerNumber.of(-2), x).limit('x', Constant.infinity))
          .throws<UnsupportedError>();
      check(() => Fn.sin(x).limit('x', Constant.infinity))
          .throws<UnsupportedError>();
      check(Fn.lambertW(x).limit('x', IntegerNumber.zero))
          .equals(IntegerNumber.zero);
      check(
        Fn.lambertW(
          x,
          IntegerNumber.negativeOne,
        ).limit('x', RationalNumber(-1, 4)).evaluate(),
      ).isCloseTo(
        Fn.lambertW(
          RationalNumber(-1, 4),
          IntegerNumber.negativeOne,
        ).evaluate(),
        1e-12,
      );

      check((const Variable('a') * x).limit('x', Constant.infinity))
          .isA<Limit>();
      check(
        (Fn.factorial(x + IntegerNumber.one) / Fn.factorial(x)).limit(
          'x',
          Constant.infinity,
        ),
      ).equals(Constant.infinity);
      check(
        (Fn.gamma(x + IntegerNumber.one) / (x * Fn.gamma(x))).limit(
          'x',
          Constant.infinity,
        ),
      ).equals(IntegerNumber.one);

      check((Fn.sin(x) * Pow.of(Constant.e, -x)).limit('x', Constant.infinity))
          .equals(IntegerNumber.zero);
      check((Fn.cos(x) / x).limit('x', Constant.infinity))
          .equals(IntegerNumber.zero);

      check(
        Piecewise([
          (
            relation: Relational.lessThan(x, IntegerNumber.zero),
            expr: IntegerNumber.one,
          ),
          (
            relation: Relational.lessEqual(x, IntegerNumber.two),
            expr: IntegerNumber.two,
          ),
          (
            relation: Relational.equal(x, IntegerNumber.of(3)),
            expr: IntegerNumber.of(3),
          ),
          (
            relation: Relational.greaterThan(x * x, IntegerNumber.of(10)),
            expr: IntegerNumber.of(7),
          ),
        ], otherwise: IntegerNumber.zero).limit('x', Constant.infinity),
      ).equals(IntegerNumber.of(7));
      check(
        Piecewise([
          (
            relation: Relational.notEqual(x, IntegerNumber.zero),
            expr: IntegerNumber.of(4),
          ),
        ], otherwise: IntegerNumber.zero).limit('x', Constant.infinity),
      ).equals(IntegerNumber.of(4));

      const a = Variable('a');
      final symFinite =
          (a +
              Fn.sin(a) +
              Fn.cos(a) +
              Fn.sinh(a) +
              Fn.cosh(a) +
              Fn.atan(a) +
              Fn.tanh(a) +
              Fn.asinh(a) +
              Fn.erf(a) +
              Fn.erfc(a) +
              Fn.abs(a) +
              Pow.of(Constant.e, a) +
              Pow.of(a, IntegerNumber.two)) /
          x;
      check(symFinite.limit('x', Constant.infinity)).equals(IntegerNumber.zero);
      check((Fn.tan(a) / x).limit('x', Constant.infinity))
          .equals(IntegerNumber.zero);

      // Bounded factors (sin(x), base^exponent) multiplied by 0 at infinity
      check(
        (Fn.sin(x) * Pow.of(IntegerNumber.two, -x)).limit(
          'x',
          Constant.infinity,
        ),
      ).equals(IntegerNumber.zero);
      check(
        (Fn.cos(x) * Pow.of(FractionNumber.half, x)).limit(
          'x',
          Constant.infinity,
        ),
      ).equals(IntegerNumber.zero);
      check(
        Piecewise([
          (relation: Relational.greaterEqual(x, x), expr: IntegerNumber.of(5)),
        ], otherwise: IntegerNumber.zero).limit('x', Constant.infinity),
      ).equals(IntegerNumber.of(5));
      check(
        Piecewise([
          (relation: Relational.greaterThan(x, x), expr: IntegerNumber.of(5)),
        ], otherwise: IntegerNumber.of(9)).limit('x', Constant.infinity),
      ).equals(IntegerNumber.of(9));
    });
  });
}
