import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:test/test.dart';

void main() {
  const x = Variable('x');

  group('Finite and directional limits', () {
    test('evaluates continuous and classic indeterminate limits', () {
      check(IntegerNumber.of(5).limit('x', IntegerNumber.zero))
          .equals(IntegerNumber.of(5));
      check(
        (Pow(x, IntegerNumber.two) + Sinh(x) + Cosh(x) + Pow(Constant.e, x))
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

      final veryHigh = Pow(x, IntegerNumber.of(20)) * Tan(x);
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
        (IntegerNumber.one / Pow(x, IntegerNumber.two)).limit(
          'x',
          IntegerNumber.zero,
        ),
      ).equals(Constant.infinity);
      check(
        (-Constant.pi / Pow(x, IntegerNumber.two)).limit(
          'x',
          IntegerNumber.zero,
        ),
      ).equals(-Constant.infinity);
      check(
        ((-IntegerNumber.two * Constant.pi * Constant.e) /
                Pow(x, IntegerNumber.two))
            .limit('x', IntegerNumber.zero),
      ).equals(-Constant.infinity);
      check(
        (Constant.pi / Pow(x, IntegerNumber.two)).limit(
          'x',
          IntegerNumber.zero,
        ),
      ).equals(Constant.infinity);
    });

    test(
      'evaluates non-analytic finite limits via reciprocal transformation',
      () {
        check(
          (x * Ln(x)).limit(
            'x',
            IntegerNumber.zero,
            direction: LimitDirection.fromAbove,
          ),
        ).equals(IntegerNumber.zero);
        check(
          (x * Ln(-x)).limit(
            'x',
            IntegerNumber.zero,
            direction: LimitDirection.fromBelow,
          ),
        ).equals(IntegerNumber.zero);
        check(Abs(x).limit('x', IntegerNumber.zero)).equals(IntegerNumber.zero);
        check(() => (Abs(x) / x).limit('x', IntegerNumber.zero))
            .throws<UnsupportedError>();
        check(
          () => Pow(
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
      check(Pow(x, x).limit('x', Constant.infinity)).equals(Constant.infinity);
      check(Pow(x, -x).limit('x', Constant.infinity))
          .equals(IntegerNumber.zero);

      check(Pow(Constant.e, x).limit('x', IntegerNumber.one))
          .equals(Constant.e);
      check(Pow(Constant.e, x).limit('x', Constant.infinity))
          .equals(Constant.infinity);
      check(Pow(Constant.e, -x).limit('x', Constant.infinity))
          .equals(IntegerNumber.zero);

      check(Ln(x).limit('x', Constant.infinity)).equals(Constant.infinity);
      check(
        Ln(
          x,
        ).limit('x', IntegerNumber.zero, direction: LimitDirection.fromAbove),
      ).equals(-Constant.infinity);
      check(Ln(x).limit('x', IntegerNumber.one)).equals(IntegerNumber.zero);
    });

    test('evaluates Sin, Cos, Atan, and Tanh limits', () {
      check(Sin(x).limit('x', IntegerNumber.zero)).equals(IntegerNumber.zero);
      check(Cos(x).limit('x', IntegerNumber.zero)).equals(IntegerNumber.one);
      check(Atan(x).limit('x', IntegerNumber.zero)).equals(IntegerNumber.zero);
      check(Tanh(x).limit('x', IntegerNumber.zero)).equals(IntegerNumber.zero);
      check(Sin(const RealNumber(0.5) * x).limit('x', IntegerNumber.two))
          .equals(Sin(const RealNumber(1.0)).simplify());
      check(Sin(Constant.pi * x).limit('x', IntegerNumber.one))
          .equals(Sin(Constant.pi).simplify());
      check(Atan(Ln(IntegerNumber.two) * x).limit('x', IntegerNumber.one))
          .equals(Atan(Ln(IntegerNumber.two)).simplify());

      check(Atan(x).limit('x', Constant.infinity))
          .equals((Constant.pi / IntegerNumber.two).simplify());
      check(Atan(x).limit('x', -Constant.infinity))
          .equals((-(Constant.pi / IntegerNumber.two)).simplify());
      check(Tanh(x).limit('x', Constant.infinity)).equals(IntegerNumber.one);
      check(Tanh(x).limit('x', -Constant.infinity))
          .equals(IntegerNumber.negativeOne);

      check(() => Sin(x).limit('x', Constant.infinity))
          .throws<UnsupportedError>();
      check(() => Cos(x).limit('x', Constant.infinity))
          .throws<UnsupportedError>();
    });
  });

  group(
    'Asymptotic limits at infinity (rational, Gruntz MRV, and Squeeze)',
    () {
      test('evaluates rational functions at plus and minus infinity', () {
        check(Expr.parse('(x + 1) / (x^2 + 1)').limit('x', Constant.infinity))
            .equals(IntegerNumber.zero);
        check(
          Expr.parse('(3*x^2 + 1) / (x^2 - 5)').limit('x', Constant.infinity),
        ).equals(IntegerNumber.of(3));
        check(Expr.parse('(x^3 + 1) / (x^2 + 1)').limit('x', Constant.infinity))
            .equals(Constant.infinity);
        check(
          Expr.parse('(-x^3 + 1) / (x^2 + 1)').limit('x', Constant.infinity),
        ).equals(-Constant.infinity);
        check(
          Expr.parse('(x^3 + 1) / (x^2 + 1)').limit('x', -Constant.infinity),
        ).equals(-Constant.infinity);
        check(
          (IntegerNumber.one / x).limit(
            'x',
            Mul(const [
              Constant.infinity,
              IntegerNumber.negativeOne,
            ], isSimplified: true),
          ),
        ).equals(IntegerNumber.zero);
        check(
          Expr.parse('(3*x^2 + 1) / (x^2 - 5)')
              .limit('x', const Variable('infinity')),
        ).equals(IntegerNumber.of(3));
      });

      test('resolves Abs and Piecewise asymptotically at infinity', () {
        check((Abs(x) / x).limit('x', Constant.infinity))
            .equals(IntegerNumber.one);
        check((Abs(x) / x).limit('x', -Constant.infinity))
            .equals(IntegerNumber.negativeOne);
        check((Abs(-x) / x).limit('x', Constant.infinity))
            .equals(IntegerNumber.one);

        final pw1 = Piecewise([
          (
            relation: GreaterThan(x, IntegerNumber.zero),
            expr: IntegerNumber.of(7),
          ),
        ], otherwise: IntegerNumber.of(-7));
        check(pw1.limit('x', Constant.infinity)).equals(IntegerNumber.of(7));
        check(pw1.limit('x', -Constant.infinity)).equals(IntegerNumber.of(-7));
      });

      test(
        'evaluates algebraic radicals and logarithmic limits at infinity',
        () {
          check(Expr.parse('sqrt(x^2 + x) - x').limit('x', Constant.infinity))
              .equals(FractionNumber.half);
          check(Expr.parse('sqrt(x^2 + 1) - x').limit('x', Constant.infinity))
              .equals(IntegerNumber.zero);
          check(Expr.parse('sqrt(x^4 + 1) - x').limit('x', Constant.infinity))
              .equals(Constant.infinity);
          check(Expr.parse('x - sqrt(x^4 + 1)').limit('x', Constant.infinity))
              .equals(-Constant.infinity);
          final undetAlg = Expr.parse('sqrt(x^3 + 1) - x')
              .limit('x', Constant.infinity);
          check(undetAlg).isA<Limit>();
          check(Expr.parse(undetAlg.toString())).equals(undetAlg);

          check((Ln(x) / x).limit('x', Constant.infinity))
              .equals(IntegerNumber.zero);
          check(
            (Ln(IntegerNumber.one + Pow(Constant.e, x)) / x).limit(
              'x',
              Constant.infinity,
            ),
          ).equals(IntegerNumber.one);
          check((Ln(Pow(Constant.e, x) + x) / x).limit('x', Constant.infinity))
              .equals(IntegerNumber.one);
          check(
            (Ln(Pow(Constant.e, x) + Ln(x)) / x).limit('x', Constant.infinity),
          ).equals(IntegerNumber.one);
        },
      );

      test(
        'evaluates exponential hierarchy (Gruntz MRV) and Squeeze theorem',
        () {
          check(
            (Pow(x, IntegerNumber.of(5)) / Pow(Constant.e, x)).limit(
              'x',
              Constant.infinity,
            ),
          ).equals(IntegerNumber.zero);
          check(
            (Pow(Constant.e, x) / Pow(x, IntegerNumber.of(5))).limit(
              'x',
              Constant.infinity,
            ),
          ).equals(Constant.infinity);
          check(
            (-Pow(Constant.e, x) / Pow(x, IntegerNumber.of(5))).limit(
              'x',
              Constant.infinity,
            ),
          ).equals(-Constant.infinity);
          check(
            ((-IntegerNumber.two * Constant.pi * Pow(Constant.e, x)) /
                    Pow(x, IntegerNumber.of(5)))
                .limit('x', Constant.infinity),
          ).equals(-Constant.infinity);
          check(
            (Pow(x - IntegerNumber.of(100), FractionNumber.half) *
                    Pow(Constant.e, x))
                .limit('x', Constant.infinity),
          ).equals(Constant.infinity);

          final multiExp = Expr.parse(
            '(3 * exp(2 * x + 1) + exp(x)) / (exp(2 * x) - exp(x))',
          );
          check(multiExp.limit('x', Constant.infinity))
              .equals((IntegerNumber.of(3) * Constant.e).simplify());

          final mixedDegExp =
              (Pow(Constant.e, Pow(x, IntegerNumber.two) + x) +
                  Pow(Constant.e, x)) /
              Pow(Constant.e, Pow(x, IntegerNumber.two) + x);
          check(mixedDegExp.limit('x', Constant.infinity))
              .equals(IntegerNumber.one);

          final realExp =
              (Pow(Constant.e, const RealNumber(0.5) * x) + IntegerNumber.one) /
              Pow(Constant.e, x);
          check(realExp.limit('x', Constant.infinity))
              .equals(IntegerNumber.zero);

          check((Sin(x) / x).limit('x', Constant.infinity))
              .equals(IntegerNumber.zero);
          check((Sin(x) / (x * Ln(x))).limit('x', Constant.infinity))
              .equals(IntegerNumber.zero);
          check(
            (Pow(Cos(x), IntegerNumber.two) / x).limit('x', Constant.infinity),
          ).equals(IntegerNumber.zero);
          check(() => (x * Sin(x)).limit('x', Constant.infinity))
              .throws<UnsupportedError>();

          final unsupportedMrv =
              Piecewise([
                (
                  relation: LessThan(const Variable('y'), IntegerNumber.zero),
                  expr: Pow(Constant.e, x),
                ),
              ]) +
              Integral(
                Pow(Constant.e, x),
                't',
                lower: IntegerNumber.zero,
                upper: IntegerNumber.one,
              );
          final limNode = unsupportedMrv.limit('x', Constant.infinity);
          check(limNode).isA<Limit>();
          check(Expr.parse(limNode.toString())).equals(limNode);
          check(limNode.toLatex()).contains(r'\lim_{x \to \infty}');
          check(limNode.toMathMl(root: false)).contains('<munder><mo>lim</mo>');

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
            '<mrow><munder><mo>lim</mo><mrow><mi>x</mi><mo>&#x2192;</mo><msup><mn>0</mn><mo>+</mo></msup></mrow></munder><mrow><mi>f</mi><mo>(</mo><mi>x</mi><mo>)</mo></mrow></mrow>',
          );

          final limBelow = Expr.parse('limit(f(x), x, 0, -1)');
          check(Expr.parse(limBelow.toString())).equals(limBelow);
          check(limBelow.toLatex()).equals(r'\lim_{x \to 0^-} f(x)');

          check((Sin(x) / x).limit('x', 0)).equals(IntegerNumber.one);
          check((x + IntegerNumber.one).limit('x', BigInt.two))
              .equals(IntegerNumber.of(3));
          check((x + IntegerNumber.one).limit('x', 1.5))
              .equals(const RealNumber(2.5));
          check((IntegerNumber.one / x).limit('x', double.infinity))
              .equals(IntegerNumber.zero);
          check((IntegerNumber.one / x).limit('x', double.negativeInfinity))
              .equals(IntegerNumber.zero);
          check(Sin(x).limit('x', Constant.pi / IntegerNumber.two))
              .equals(IntegerNumber.one);
          check(() => x.limit('x', '??? invalid')).throws<ArgumentError>();
        },
      );
    },
  );
}
