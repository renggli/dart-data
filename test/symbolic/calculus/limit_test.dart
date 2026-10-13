import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:test/scaffolding.dart';

void main() {
  const x = Variable('x');

  group('LimitExtension - Direct substitution & continuous points', () {
    test('Polynomial limit at finite point', () {
      final expr =
          (const RationalNumber(3) * x * x -
                  const RationalNumber(4) * x +
                  const RationalNumber(5))
              .simplify();
      check(expr.limit('x', const RationalNumber(2)))
          .equals(const RationalNumber(9));
    });

    test('Trigonometric continuous limits', () {
      check(const Sin(x).limit('x', RationalNumber.zero))
          .equals(RationalNumber.zero);
      check(const Cos(x).limit('x', RationalNumber.zero))
          .equals(RationalNumber.one);
    });

    test('Exponential continuous limit', () {
      check(const Exp(x).limit('x', RationalNumber.zero))
          .equals(RationalNumber.one);
    });

    test('Rational function with non-zero denominator', () {
      final expr = (x + 1) / (x - 1);
      check(expr.limit('x', const RationalNumber(3)))
          .equals(const RationalNumber(2));
    });
  });

  group('LimitExtension - Indeterminate forms (0/0) via Laurent series', () {
    test('Rational cancelable linear root: (x^2 - 1) / (x - 1) as x -> 1', () {
      final expr = (x * x - 1) / (x - 1);
      check(expr.limit('x', RationalNumber.one))
          .equals(const RationalNumber(2));
    });

    test('Rational cancelable cubic root: (x^3 - 8) / (x - 2) as x -> 2', () {
      final expr = (x * x * x - 8) / (x - 2);
      check(expr.limit('x', const RationalNumber(2)))
          .equals(const RationalNumber(12));
    });

    test('Rational cancelable cubic root: (x^3 - 1) / (x - 1) as x -> 1', () {
      final expr = (x * x * x - 1) / (x - 1);
      check(expr.limit('x', RationalNumber.one))
          .equals(const RationalNumber(3));
    });

    test('Trigonometric cardinal sine: sin(x) / x as x -> 0', () {
      final expr = const Sin(x) / x;
      check(expr.limit('x', RationalNumber.zero)).equals(RationalNumber.one);
    });

    test('Trigonometric cosine difference: (1 - cos(x)) / x^2 as x -> 0', () {
      final expr = (RationalNumber.one - const Cos(x)) / (x * x);
      check(expr.limit('x', RationalNumber.zero))
          .equals(const RationalNumber(1, 2));
    });

    test('Tangent cardinal: tan(x) / x as x -> 0', () {
      final expr = const Tan(x) / x;
      check(expr.limit('x', RationalNumber.zero)).equals(RationalNumber.one);
    });

    test('Exponential: (e^x - 1) / x as x -> 0', () {
      final expr = (const Exp(x) - 1) / x;
      check(expr.limit('x', RationalNumber.zero)).equals(RationalNumber.one);
    });

    test('Logarithmic: ln(1 + x) / x as x -> 0', () {
      final expr = Ln(RationalNumber.one + x) / x;
      check(expr.limit('x', RationalNumber.zero)).equals(RationalNumber.one);
    });
  });

  group('LimitExtension - Finite poles and directional limits', () {
    test('Odd pole 1/x: fromAbove (+oo), fromBelow (-oo), both (fails)', () {
      final expr = RationalNumber.one / x;
      check(
        expr.limit(
          'x',
          RationalNumber.zero,
          direction: LimitDirection.fromAbove,
        ),
      ).equals(ConstantNumber.infinity);
      check(
        expr.limit(
          'x',
          RationalNumber.zero,
          direction: LimitDirection.fromBelow,
        ),
      ).equals(const Neg(ConstantNumber.infinity).simplify());
      check(
        () => expr.limit(
          'x',
          RationalNumber.zero,
          direction: LimitDirection.both,
        ),
      ).throws<UnsupportedError>();
    });

    test('Even pole 1/x^2: both (+oo)', () {
      final expr = RationalNumber.one / (x * x);
      check(
        expr.limit('x', RationalNumber.zero, direction: LimitDirection.both),
      ).equals(ConstantNumber.infinity);
    });

    test('Shifted pole 1/(x - 2)^3', () {
      final expr = RationalNumber.one / Pow(x - 2, const RationalNumber(3));
      check(
        expr.limit(
          'x',
          const RationalNumber(2),
          direction: LimitDirection.fromAbove,
        ),
      ).equals(ConstantNumber.infinity);
      check(
        expr.limit(
          'x',
          const RationalNumber(2),
          direction: LimitDirection.fromBelow,
        ),
      ).equals(const Neg(ConstantNumber.infinity).simplify());
    });

    test('Logarithmic pole ln(x) as x -> 0+', () {
      const expr = Ln(x);
      check(
        expr.limit(
          'x',
          RationalNumber.zero,
          direction: LimitDirection.fromAbove,
        ),
      ).equals(const Neg(ConstantNumber.infinity).simplify());
    });
  });

  group('LimitExtension - Rational functions at +/- infinity', () {
    test(
      'Equal degree: (2x^3 - 5x + 1) / (7x^3 + 4x^2 - 2) as x -> +oo and -oo',
      () {
        final num =
            const RationalNumber(2) * x * x * x -
            const RationalNumber(5) * x +
            1;
        final den =
            const RationalNumber(7) * x * x * x +
            const RationalNumber(4) * x * x -
            2;
        final expr = num / den;
        check(expr.limit('x', ConstantNumber.infinity))
            .equals(const RationalNumber(2, 7));
        check(expr.limit('x', const Neg(ConstantNumber.infinity)))
            .equals(const RationalNumber(2, 7));
      },
    );

    test('Equal degree quadratic: (x^2 + 3) / (2x^2 - 1) -> 1/2', () {
      final expr = (x * x + 3) / (const RationalNumber(2) * x * x - 1);
      check(expr.limit('x', ConstantNumber.infinity))
          .equals(const RationalNumber(1, 2));
      check(expr.limit('x', const Neg(ConstantNumber.infinity)))
          .equals(const RationalNumber(1, 2));
    });

    test('Numerator lower degree: (x + 5) / (x^2 + 1) -> 0', () {
      final expr = (x + 5) / (x * x + 1);
      check(expr.limit('x', ConstantNumber.infinity))
          .equals(RationalNumber.zero);
      check(expr.limit('x', const Neg(ConstantNumber.infinity)))
          .equals(RationalNumber.zero);
    });

    test('Numerator higher degree (odd difference): x^3 / (x^2 + 1)', () {
      final expr = (x * x * x) / (x * x + 1);
      check(expr.limit('x', ConstantNumber.infinity))
          .equals(ConstantNumber.infinity);
      check(expr.limit('x', const Neg(ConstantNumber.infinity)))
          .equals(const Neg(ConstantNumber.infinity).simplify());
    });
  });

  group('LimitExtension - Exponential and logarithmic limits at infinity (Gruntz MRV)', () {
    test('Exponential dominates polynomial: e^x / x^5 -> +oo', () {
      final expr = const Exp(x) / const Pow(x, RationalNumber(5));
      check(expr.limit('x', ConstantNumber.infinity))
          .equals(ConstantNumber.infinity);
    });

    test('Polynomial dominates logarithm: ln(x) / x -> 0', () {
      final expr = const Ln(x) / x;
      check(expr.limit('x', ConstantNumber.infinity))
          .equals(RationalNumber.zero);
    });

    test('Negative exponential decay: x^3 * e^(-x) -> 0', () {
      final expr = const Pow(x, RationalNumber(3)) * Exp(-x);
      check(expr.limit('x', ConstantNumber.infinity))
          .equals(RationalNumber.zero);
    });

    test('Exponential decay at negative infinity: e^x as x -> -oo', () {
      check(const Exp(x).limit('x', const Neg(ConstantNumber.infinity)))
          .equals(RationalNumber.zero);
    });

    test('Logarithmic difference: ln(x + 1) - ln(x) -> 0', () {
      final expr = Ln(x + 1) - const Ln(x);
      check(expr.limit('x', ConstantNumber.infinity))
          .equals(RationalNumber.zero);
    });

    test('Ratio of logs: ln(x + e^x) / x -> 1', () {
      final expr = Ln(x + const Exp(x)) / x;
      check(expr.limit('x', ConstantNumber.infinity))
          .equals(RationalNumber.one);
    });
  });

  group(
    'LimitExtension - Gruntz essential singularities & benchmark suite',
    () {
      test('Gruntz problem 1: e^x * (e^(1/x - e^(-x)) - e^(1/x)) -> -1', () {
        final expr =
            const Exp(x) *
            (Exp(RationalNumber.one / x - Exp(-x)) -
                Exp(RationalNumber.one / x));
        check(expr.limit('x', ConstantNumber.infinity))
            .equals(RationalNumber.negativeOne);
      });

      test('Scale cancellation: e^(x + e^(-x)) - e^x -> 1', () {
        final expr = Exp(x + Exp(-x)) - const Exp(x);
        check(expr.limit('x', ConstantNumber.infinity))
            .equals(RationalNumber.one);
      });

      test('Essential singularity at origin: x * ln(x) as x -> 0+', () {
        final expr = x * const Ln(x);
        check(
          expr.limit(
            'x',
            RationalNumber.zero,
            direction: LimitDirection.fromAbove,
          ),
        ).equals(RationalNumber.zero);
      });

      test('Essential power singularity at origin: x^x as x -> 0+', () {
        const expr = Pow(x, x);
        check(
          expr.limit(
            'x',
            RationalNumber.zero,
            direction: LimitDirection.fromAbove,
          ),
        ).equals(RationalNumber.one);
      });
    },
  );

  group('LimitExtension - Adversarial stress tests', () {
    test('Higher-order Taylor cancellation: (x - sin(x)) / x^3 -> 1/6', () {
      final expr = (x - const Sin(x)) / (x * x * x);
      check(expr.limit('x', RationalNumber.zero))
          .equals(const RationalNumber(1, 6));
    });

    test(
      'Higher-order Taylor cancellation: (tan(x) - sin(x)) / x^3 -> 1/2',
      () {
        final expr = (const Tan(x) - const Sin(x)) / (x * x * x);
        check(expr.limit('x', RationalNumber.zero))
            .equals(const RationalNumber(1, 2));
      },
    );

    test('Higher-order Taylor cancellation: (arcsin(x) - x) / x^3 -> 1/6', () {
      final expr = (const Asin(x) - x) / (x * x * x);
      check(expr.limit('x', RationalNumber.zero))
          .equals(const RationalNumber(1, 6));
    });

    test('Higher-order Taylor cancellation: (arctan(x) - x) / x^3 -> -1/3', () {
      final expr = (const Atan(x) - x) / (x * x * x);
      check(expr.limit('x', RationalNumber.zero))
          .equals(const RationalNumber(-1, 3));
    });

    test('Second-order exponential: (e^x - 1 - x) / x^2 -> 1/2', () {
      final expr = (const Exp(x) - 1 - x) / (x * x);
      check(expr.limit('x', RationalNumber.zero))
          .equals(const RationalNumber(1, 2));
    });

    test('Second-order logarithm: (ln(1 + x) - x) / x^2 -> -1/2', () {
      final expr = (Ln(RationalNumber.one + x) - x) / (x * x);
      check(expr.limit('x', RationalNumber.zero))
          .equals(const RationalNumber(-1, 2));
    });

    test('Negative even pole: -1 / x^2 -> -oo', () {
      final expr = -RationalNumber.one / (x * x);
      check(
        expr.limit('x', RationalNumber.zero, direction: LimitDirection.both),
      ).equals(const Neg(ConstantNumber.infinity).simplify());
    });

    test('Negative odd pole: -1 / x -> -oo fromAbove, +oo fromBelow', () {
      final expr = -RationalNumber.one / x;
      check(
        expr.limit(
          'x',
          RationalNumber.zero,
          direction: LimitDirection.fromAbove,
        ),
      ).equals(const Neg(ConstantNumber.infinity).simplify());
      check(
        expr.limit(
          'x',
          RationalNumber.zero,
          direction: LimitDirection.fromBelow,
        ),
      ).equals(ConstantNumber.infinity);
    });
  });
}
