import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:more/number.dart' show Fraction;
import 'package:test/scaffolding.dart';

void main() {
  group('Structural Ordering & Comparator', () {
    const x = Variable('x');
    const y = Variable('y');

    test('compareStructural reflexivity and antisymmetry', () {
      final expressions = <Expr>[
        RationalNumber.zero,
        RationalNumber.one,
        const RationalNumber(3, 4),
        const RealNumber(2.5),
        ConstantNumber.pi,
        ConstantNumber.e,
        x,
        y,
        const Neg(x),
        const Sin(x),
        const Cos(x),
        const Exp(x),
        const Ln(x),
        const Add(x, RationalNumber.one),
        const Sub(x, RationalNumber.one),
        const Mul(RationalNumber(2), x),
        const Div(x, RationalNumber(2)),
        const Pow(x, RationalNumber(2)),
      ];

      for (var i = 0; i < expressions.length; i++) {
        final a = expressions[i];
        // Reflexivity
        check(compareStructural(a, a)).equals(0);

        for (var j = i + 1; j < expressions.length; j++) {
          final b = expressions[j];
          final cmpAB = compareStructural(a, b);
          final cmpBA = compareStructural(b, a);
          check(cmpAB != 0).isTrue();
          check(cmpAB).equals(-cmpBA);
        }
      }
    });

    test('compareStructural transitivity', () {
      final expressions = <Expr>[
        RationalNumber.zero,
        const RealNumber(1.0),
        ConstantNumber.pi,
        x,
        const Neg(x),
        const Sin(x),
        const Pow(x, RationalNumber(2)),
        const Mul(RationalNumber(2), x),
        const Add(x, RationalNumber.one),
      ];

      for (var i = 0; i < expressions.length; i++) {
        for (var j = 0; j < expressions.length; j++) {
          for (var k = 0; k < expressions.length; k++) {
            final a = expressions[i];
            final b = expressions[j];
            final c = expressions[k];
            if (compareStructural(a, b) < 0 && compareStructural(b, c) < 0) {
              check(compareStructural(a, c) < 0).isTrue();
            }
          }
        }
      }
    });

    test('compareRational orders fractions correctly', () {
      const half = RationalNumber(1, 2);
      const half2 = RationalNumber(1, 2);
      const twoFourths = RationalNumber(2, 4);
      const threeFourths = RationalNumber(3, 4);
      const negativeHalf = RationalNumber(-1, 2);

      check(compareRational(half, half2)).equals(0);
      check(compareRational(half, twoFourths)).isLessThan(0);
      check(compareRational(half, threeFourths)).isLessThan(0);
      check(compareRational(threeFourths, half)).isGreaterThan(0);
      check(compareRational(negativeHalf, half)).isLessThan(0);
    });

    test('nodeTag covers AST nodes deterministically', () {
      check(nodeTag(RationalNumber.zero)).equals(0);
      check(nodeTag(const RealNumber(1.0))).equals(1);
      check(nodeTag(ConstantNumber.pi)).equals(2);
      check(nodeTag(x)).equals(3);
      check(nodeTag(const Neg(x))).equals(4);
      check(nodeTag(const Cos(x))).equals(5);
      check(nodeTag(const Exp(x))).equals(6);
      check(nodeTag(const Ln(x))).equals(7);
      check(nodeTag(const Sin(x))).equals(8);
      check(nodeTag(const Tan(x))).equals(9);
      check(nodeTag(const Asin(x))).equals(10);
      check(nodeTag(const Acos(x))).equals(11);
      check(nodeTag(const Atan(x))).equals(12);
      check(nodeTag(const Sinh(x))).equals(13);
      check(nodeTag(const Cosh(x))).equals(14);
      check(nodeTag(const Tanh(x))).equals(15);
      check(nodeTag(const Abs(x))).equals(16);
      check(nodeTag(const Log(RationalNumber(10), x))).equals(18);
      check(nodeTag(const Pow(x, RationalNumber(2)))).equals(20);
      check(nodeTag(const Mul(x, y))).equals(21);
      check(nodeTag(const Div(x, y))).equals(22);
      check(nodeTag(const Add(x, y))).equals(23);
      check(nodeTag(const Sub(x, y))).equals(24);
    });

    test('termDegree calculates polynomial powers accurately', () {
      check(termDegree(RationalNumber.one)).equals(0.0);
      check(termDegree(ConstantNumber.pi)).equals(0.0);
      check(termDegree(x)).equals(1.0);
      check(termDegree(const Pow(x, RationalNumber(3)))).equals(3.0);
      check(termDegree(const Mul(x, x))).equals(2.0);
      check(termDegree(const Mul(Pow(x, RationalNumber(2)), y))).equals(3.0);
      check(termDegree(const Neg(Pow(x, RationalNumber(4))))).equals(4.0);
    });

    test('primarySymbol extracts symbol names', () {
      check(primarySymbol(x)).equals('x');
      check(primarySymbol(ConstantNumber.pi)).equals('pi');
      check(primarySymbol(const Pow(x, RationalNumber(2)))).equals('x');
      check(primarySymbol(const Neg(x))).equals('x');
      check(primarySymbol(const Mul(x, y))).equals('x');
      check(primarySymbol(const Sin(x))).equals('x');
    });

    test('compareTerms sorts polynomial descending degree and positive first', () {
      const termX3 = Pow(x, RationalNumber(3));
      const termX2 = Pow(x, RationalNumber(2));
      const termX = x;

      // Degree 3 comes before degree 2
      check(compareTerms(termX3, Fraction.one, termX2, Fraction.one))
          .isLessThan(0);
      check(compareTerms(termX2, Fraction.one, termX3, Fraction.one))
          .isGreaterThan(0);

      // Positive coefficient comes before negative coefficient with same degree
      check(compareTerms(termX, Fraction.one, termX, -Fraction.one))
          .isLessThan(0);
      check(compareTerms(termX, -Fraction.one, termX, Fraction.one))
          .isGreaterThan(0);
    });
  });
}
