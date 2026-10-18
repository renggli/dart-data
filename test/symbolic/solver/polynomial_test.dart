import 'package:checks/checks.dart';
import 'package:data/src/symbolic/algebra/term_accumulator.dart';
import 'package:data/src/symbolic/solver/polynomial.dart';
import 'package:data/symbolic.dart';
import 'package:test/test.dart';

void main() {
  group('Quadratic matching and solving', () {
    test(
      'matchQuadratic identifies degree-2 polynomials and rejects others',
      () {
        check(matchQuadratic(Expr.parse('sin(x)'), 'x')).isNull();
        check(matchQuadratic(Expr.parse('x^3 + x^2 - 1'), 'x')).isNull();
        check(matchQuadratic(Expr.parse('2*x + 1'), 'x')).isNull();

        final m = matchQuadratic(Expr.parse('3*x^2 - 4*x + 5'), 'x');
        check(m).isNotNull();
        check(m!.a).equals(IntegerNumber.of(3));
        check(m.b).equals(IntegerNumber.of(-4));
        check(m.c).equals(IntegerNumber.of(5));
      },
    );

    test('solveQuadratic handles rational, real, complex, and symbolic discriminants', () {
      // Rational discriminant < 0 with zero and non-zero real parts
      final pureImag = solveQuadratic(
        IntegerNumber.one,
        IntegerNumber.zero,
        IntegerNumber.of(4),
      );
      check(pureImag).unorderedEquals([
        const ComplexNumber(IntegerNumber.zero, IntegerNumber.two),
        const ComplexNumber(IntegerNumber.zero, IntegerNumber(Integer(-2))),
      ]);

      final complexRational = solveQuadratic(
        IntegerNumber.one,
        IntegerNumber.two,
        IntegerNumber.of(5),
      );
      check(complexRational).unorderedEquals([
        const ComplexNumber(IntegerNumber.negativeOne, IntegerNumber.two),
        const ComplexNumber(
          IntegerNumber.negativeOne,
          IntegerNumber(Integer(-2)),
        ),
      ]);

      // Rational discriminant == 0 (repeated root)
      final repeated = solveQuadratic(
        IntegerNumber.one,
        IntegerNumber.of(-6),
        IntegerNumber.of(9),
      );
      check(repeated).deepEquals([IntegerNumber.of(3)]);

      // Rational discriminant > 0 (exact and radical)
      final exact = solveQuadratic(
        IntegerNumber.one,
        IntegerNumber.of(-5),
        IntegerNumber.of(6),
      );
      check(exact).unorderedEquals([IntegerNumber.two, IntegerNumber.of(3)]);

      final radical = solveQuadratic(
        IntegerNumber.one,
        IntegerNumber.zero,
        IntegerNumber.of(-2),
      );
      check(radical.length).equals(2);

      // RealNumber discriminant < 0 with zero and non-zero real parts
      final realPureImag = solveQuadratic(
        IntegerNumber.one,
        IntegerNumber.zero,
        const RealNumber(2.25),
      );
      check(realPureImag.length).equals(2);

      final realComplex = solveQuadratic(
        IntegerNumber.one,
        const RealNumber(2.0),
        const RealNumber(2.25),
      );
      check(realComplex.length).equals(2);

      // Symbolic discriminant
      final symRoots = solveQuadratic(
        const Variable('a'),
        const Variable('b'),
        const Variable('c'),
      );
      check(symRoots.length).equals(2);
    });
  });

  group('Biquadratic matching, coefficient extraction, and root helpers', () {
    test(
      'matchBiquadratic and solveBiquadratic handle variable collisions',
      () {
        check(matchBiquadratic(Expr.parse('sin(x)'), 'x')).isNull();
        check(matchBiquadratic(Expr.parse('x^4 + x^3 - 1'), 'x')).isNull();
        check(matchBiquadratic(Expr.parse('x^2 - 1'), 'x')).isNull();

        final bq = matchBiquadratic(Expr.parse('2*x^4 - 10*x^2 + 8'), 'x');
        check(bq).isNotNull();

        // Variable named '_u' to exercise internal variable renaming
        final rootsU = solveBiquadratic(
          IntegerNumber.one,
          IntegerNumber.of(-5),
          IntegerNumber.of(4),
          '_u',
        );
        check(rootsU).unorderedEquals([
          IntegerNumber.of(-2),
          IntegerNumber.negativeOne,
          IntegerNumber.one,
          IntegerNumber.two,
        ]);
      },
    );

    test('extractPolynomialCoefficients handles constants and polynomials', () {
      check(extractPolynomialCoefficients(IntegerNumber.zero, 'x'))
          .isNotNull()
          .deepEquals({0: IntegerNumber.zero});
      check(extractPolynomialCoefficients(IntegerNumber.of(7), 'x'))
          .isNotNull()
          .deepEquals({0: IntegerNumber.of(7)});
      check(extractPolynomialCoefficients(Expr.parse('1 / x'), 'x')).isNull();
    });

    test('sqrtConstant, integerNthRoot, and rootConstant cover all cases', () {
      check(sqrtConstant(RationalNumber(4, 9))).equals(RationalNumber(2, 3));
      check(sqrtConstant(RationalNumber(2, 3)))
          .equals(Pow(RationalNumber(2, 3), FractionNumber.half).simplify());

      check(integerNthRoot(-8, 3)).isNull();
      check(integerNthRoot(0, 3)).equals(0);
      check(integerNthRoot(1, 3)).equals(1);
      check(integerNthRoot(27, 3)).equals(3);
      check(integerNthRoot(26, 3)).isNull();
      check(integerNthRoot(28, 3)).isNull();

      check(rootConstant(RationalNumber(-8, 27), 3))
          .equals(RationalNumber(-2, 3));
      check(rootConstant(RationalNumber(8, 27), 3))
          .equals(RationalNumber(2, 3));
      check(rootConstant(IntegerNumber.of(5), 3))
          .equals(Pow(IntegerNumber.of(5), FractionNumber.third).simplify());
      check(rootConstant(const RealNumber(-8.0), 3))
          .equals(const RealNumber(-2.0));
      check(rootConstant(const Variable('a'), 3))
          .equals(Pow(const Variable('a'), FractionNumber.third));
    });
  });
}
