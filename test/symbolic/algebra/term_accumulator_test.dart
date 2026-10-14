import 'package:checks/checks.dart';
import 'package:data/src/symbolic/algebra/term_accumulator.dart';
import 'package:data/symbolic.dart';
import 'package:more/number.dart' show Fraction;
import 'package:test/scaffolding.dart';

void main() {
  const x = Variable('x');
  const y = Variable('y');

  group('MonomialAccumulator - constant folding', () {
    test('rational constants accumulate without floating-point pollution', () {
      final acc = MonomialAccumulator();
      acc.add(const RationalNumber(3));
      acc.add(const RationalNumber(5));
      acc.add(const RationalNumber(-2));

      check(acc.hasReal).isFalse();
      check(acc.constantRational).equals(Fraction(6));
      check(acc.constantReal).equals(0.0);

      final built = acc.build();
      check(built).equals(const RationalNumber(6));
    });

    test('real constants set hasReal and accumulate in constantReal', () {
      final acc = MonomialAccumulator();
      acc.add(const RealNumber(2.5));
      acc.add(const RealNumber(1.5));

      check(acc.hasReal).isTrue();
      check(acc.constantReal).equals(4.0);
      check(acc.constantRational).equals(Fraction.zero);

      final built = acc.build();
      check(built).equals(const RealNumber(4.0));
    });

    test('mixed rational and real constants keep channels separate', () {
      final acc = MonomialAccumulator();
      acc.add(const RationalNumber(2));
      acc.add(const RealNumber(0.5));

      check(acc.hasReal).isTrue();
      check(acc.constantRational).equals(Fraction(2));
      check(acc.constantReal).equals(0.5);

      final built = acc.build();
      check(built).equals(const RealNumber(2.5));
    });
  });

  group('MonomialAccumulator - monomial and like-term combination', () {
    test('combines rational like-terms', () {
      final acc = MonomialAccumulator();
      acc.add(const RationalNumber(2) * x);
      acc.add(const RationalNumber(3) * x);

      check(acc.rationalTerms[x]).equals(Fraction(5));
      check(acc.hasReal).isFalse();

      final built = acc.build();
      check(built).equals(const RationalNumber(5) * x);
    });

    test('combines real like-terms', () {
      final acc = MonomialAccumulator();
      acc.add(const RealNumber(1.5) * x);
      acc.add(const RealNumber(2.5) * x);

      check(acc.realTerms[x]).equals(4.0);
      check(acc.hasReal).isTrue();

      final built = acc.build();
      check(built).equals(const RealNumber(4.0) * x);
    });

    test('cancels terms to zero and builds zero expression', () {
      final acc = MonomialAccumulator();
      acc.add(x);
      acc.add(-x);

      check(acc.build()).equals(RationalNumber.zero);
    });

    test('cancels pure imaginary units', () {
      final acc = MonomialAccumulator();
      acc.add(ConstantNumber.i);
      acc.add(const Neg(ConstantNumber.i));

      check(acc.build()).equals(RationalNumber.zero);
    });
  });

  group('MonomialAccumulator - transcendental detection', () {
    test('hasTranscendental is false for pure polynomials', () {
      final acc1 = MonomialAccumulator();
      acc1.add(
        x.pow(const RationalNumber(2)) +
            const RationalNumber(3) * x +
            const RationalNumber(1),
      );
      check(acc1.hasTranscendental).isFalse();

      final acc2 = MonomialAccumulator();
      acc2.add((const RationalNumber(4) * x) * y - const RationalNumber(7));
      check(acc2.hasTranscendental).isFalse();
    });

    test(
      'hasTranscendental is true when transcendental functions are present',
      () {
        final transcendentals = <Expr>[
          const Sin(x),
          const Cos(x),
          const Tan(x),
          const Sinh(x),
          const Cosh(x),
          const Tanh(x),
          const Exp(x),
          const Ln(x),
        ];

        for (final expr in transcendentals) {
          final acc = MonomialAccumulator();
          acc.add(expr);
          check(acc.hasTranscendental).isTrue();
        }
      },
    );
  });

  group('MonomialAccumulator - extractPolynomialCoefficients', () {
    test('extracts single-variable polynomial coefficients', () {
      final acc = MonomialAccumulator();
      acc.add(
        const RationalNumber(3) * x.pow(const RationalNumber(2)) +
            const RationalNumber(5) * x +
            const RationalNumber(7),
      );

      final coeffs = acc.extractPolynomialCoefficients('x');
      check(coeffs).isNotNull();
      check(coeffs![2]).equals(const RationalNumber(3));
      check(coeffs[1]).equals(const RationalNumber(5));
      check(coeffs[0]).equals(const RationalNumber(7));
    });

    test(
      'extracts multivariate polynomial coefficients with symbolic expressions',
      () {
        final acc = MonomialAccumulator();
        acc.add(
          (const RationalNumber(2) * y) * x.pow(const RationalNumber(2)) +
              (y + const RationalNumber(1)) * x +
              const RationalNumber(3),
        );

        final coeffs = acc.extractPolynomialCoefficients('x');
        check(coeffs).isNotNull();
        check(coeffs![2]).equals(const RationalNumber(2) * y);
        check(coeffs[1]).equals(y + const RationalNumber(1));
        check(coeffs[0]).equals(const RationalNumber(3));
      },
    );

    test('returns null for non-polynomial forms in target variable', () {
      final nonPolyForms = <Expr>[
        const RationalNumber(1) / x,
        x.pow(const RationalNumber(1, 2)),
        x.pow(const RationalNumber(-1)),
        const Sin(x),
        const Exp(x),
      ];

      for (final expr in nonPolyForms) {
        final acc = MonomialAccumulator();
        acc.add(expr);
        check(acc.extractPolynomialCoefficients('x')).isNull();
      }
    });
  });

  group('MonomialAccumulator - static utilities', () {
    test('collectTerms flattens expressions preserving signs', () {
      final expr =
          (x + const RationalNumber(2)) - (y - const RationalNumber(3));
      final terms = <Expr>[];
      MonomialAccumulator.collectTerms(expr, terms);

      check(terms.length).equals(4);
      check(terms[0]).equals(x);
      check(terms[1]).equals(const RationalNumber(2));
      check(terms[2]).equals(-y);
      check(terms[3]).equals(const RationalNumber(3));
    });

    test('negateMonomial negates constants and wraps terms cleanly', () {
      check(MonomialAccumulator.negateMonomial(const RationalNumber(3)))
          .equals(const RationalNumber(-3));
      check(MonomialAccumulator.negateMonomial(const RealNumber(2.5)))
          .equals(const RealNumber(-2.5));
      check(MonomialAccumulator.negateMonomial(const RationalNumber(2) * x))
          .equals(Neg(const RationalNumber(2) * x));
      check(MonomialAccumulator.negateMonomial(-x)).equals(x);
    });
  });

  group('MonomialAccumulator - adversarial stress testing', () {
    test('deeply nested addition and subtraction trees fold cleanly', () {
      // 1. Deep left-leaning addition tree: (...((x + 1) + 1)... + 1) - 50 = x
      Expr leftTree = x;
      for (var i = 0; i < 50; i++) {
        leftTree = leftTree + const RationalNumber(1);
      }
      leftTree = leftTree - const RationalNumber(50);

      final acc1 = MonomialAccumulator();
      acc1.add(leftTree);
      check(acc1.build()).equals(x);

      // 2. Deep right-leaning subtraction tree: 50 - (1 + (1 + ... + (1 + x)...)) = -x
      Expr rightTree = x;
      for (var i = 0; i < 50; i++) {
        rightTree = const RationalNumber(1) + rightTree;
      }
      final tree2 = const RationalNumber(50) - rightTree;

      final acc2 = MonomialAccumulator();
      acc2.add(tree2);
      check(acc2.build()).equals(-x);

      // 3. Deeply nested alternating telescoping chain:
      // (x_0 - x_1) + (x_1 - x_2) + ... + (x_49 - x_50) + x_50 - x_0 = 0
      Expr telescope = RationalNumber.zero;
      for (var i = 0; i < 50; i++) {
        final xi = Variable('v$i');
        final xNext = Variable('v${i + 1}');
        telescope = telescope + (xi - xNext);
      }
      telescope = telescope + const Variable('v50') - const Variable('v0');

      final acc3 = MonomialAccumulator();
      acc3.add(telescope);
      check(acc3.build()).equals(RationalNumber.zero);
    });

    test('cancellation of like terms and mixed rational-real terms', () {
      // x - x = 0
      final accZero = MonomialAccumulator();
      accZero.add(x);
      accZero.add(-x);
      check(accZero.rationalTerms[x]).equals(Fraction.zero);
      check(accZero.build()).equals(RationalNumber.zero);
      check(accZero.rationalTerms).isEmpty();

      // 2.5*x - 1.5*x = 1.0*x -> folds to x (or 1.0*x)
      final accReal = MonomialAccumulator();
      accReal.add(const RealNumber(2.5) * x);
      accReal.add(Neg(const RealNumber(1.5) * x));
      check(accReal.realTerms[x]).equals(1.0);
      check(accReal.hasReal).isTrue();
      check(accReal.build()).equals(x);

      // End-to-end simplification: 2.5*x - 1.5*x = x
      final simplifiedReal =
          (const RealNumber(2.5) * x - const RealNumber(1.5) * x).simplify();
      check(simplifiedReal).equals(x);

      // Mixed rational and real like-term cancellation:
      // (1/2)*x + (-0.5)*x = 0.0 (hasReal yields RealNumber(0.0))
      final accMixedCancel = MonomialAccumulator();
      accMixedCancel.add(const RationalNumber(1, 2) * x);
      accMixedCancel.add(const RealNumber(-0.5) * x);
      check(accMixedCancel.hasReal).isTrue();
      check(accMixedCancel.build()).equals(const RealNumber(0.0));

      // Mixed rational and real like-term aggregation:
      // (3/4)*x - 0.25*x = 0.5*x
      final accMixedAdd = MonomialAccumulator();
      accMixedAdd.add(const RationalNumber(3, 4) * x);
      accMixedAdd.add(const RealNumber(-0.25) * x);
      check(accMixedAdd.hasReal).isTrue();
      check(accMixedAdd.build()).equals(const RealNumber(0.5) * x);
    });

    test('dual rational and real constant mixing keeps precision and folds properly', () {
      final acc = MonomialAccumulator();
      acc.add(const RationalNumber(7, 2)); // 3.5
      acc.add(const RealNumber(1.5)); // 1.5

      check(acc.hasReal).isTrue();
      check(acc.constantRational).equals(Fraction(7, 2));
      check(acc.constantReal).equals(1.5);

      final built = acc.build();
      check(built).equals(const RealNumber(5.0));

      // Real constant cancels exact rational constant to 0.0
      final accZero = MonomialAccumulator();
      accZero.add(const RationalNumber(4));
      accZero.add(const RealNumber(-4.0));
      check(accZero.hasReal).isTrue();
      check(accZero.build()).equals(const RealNumber(0.0));
    });
  });
}
