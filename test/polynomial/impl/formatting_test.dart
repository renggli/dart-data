import 'package:checks/checks.dart';
import 'package:data/src/polynomial/impl/formatting.dart';
import 'package:data/symbolic.dart';
import 'package:data/type.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('Polynomial formatting', () {
    test('empty terms formats to 0', () {
      final s = formatPolynomialTerms<int>(DataType.int32, []);
      check(s).equals('0');
    });

    test('positive terms in descending degrees', () {
      final s = formatPolynomialTerms<int>(DataType.int32, [
        (exponent: 3, coefficient: 2),
        (exponent: 1, coefficient: 1),
        (exponent: 0, coefficient: 5),
      ]);
      check(s).equals('2x^3 + x + 5');
    });

    test('negative leading and interior terms', () {
      final s = formatPolynomialTerms<double>(DataType.float64, [
        (exponent: 2, coefficient: -1.0),
        (exponent: 1, coefficient: -3.5),
        (exponent: 0, coefficient: 4.25),
      ]);
      check(s).equals('-x^2 - 3.5x + 4.25');
    });

    test('BigInt and Fraction terms with negative coefficients', () {
      final sBig = formatPolynomialTerms<BigInt>(DataType.bigInt, [
        (exponent: 2, coefficient: BigInt.from(5)),
        (exponent: 0, coefficient: BigInt.from(-7)),
      ]);
      check(sBig).equals('5x^2 - 7');

      final sFrac = formatPolynomialTerms<Fraction>(DataType.fraction, [
        (exponent: 1, coefficient: Fraction(-3, 2)),
        (exponent: 0, coefficient: Fraction(1, 4)),
      ]);
      check(sFrac).equals('-Fraction(3, 2)x + Fraction(1, 4)');
    });

    test(
      'Complex real, pure imaginary, negative, and multi-term formatting',
      () {
        final s = formatPolynomialTerms<Complex>(DataType.complex, [
          (exponent: 3, coefficient: const Complex(0.0, 2.0)),
          (exponent: 2, coefficient: const Complex(1.0, 2.0)),
          (exponent: 1, coefficient: const Complex(3.0, -4.0)),
          (exponent: 0, coefficient: const Complex(5.0, 0.0)),
        ]);
        check(s).matchesPattern(
          RegExp(
            r'^2(\.0)?ix\^3 \+ \(1(\.0)? \+ 2(\.0)?i\)x\^2 \+ \(3(\.0)? - 4(\.0)?i\)x \+ 5(\.0)?$',
          ),
        );

        final sNegImag = formatPolynomialTerms<Complex>(DataType.complex, [
          (exponent: 1, coefficient: const Complex(-0.0, -2.0)),
          (exponent: 0, coefficient: const Complex(-0.0, -0.0)),
        ]);
        check(sNegImag).matchesPattern(RegExp(r'^-2(\.0)?ix \+ 0(\.0)?$'));
      },
    );

    test(
      'non-comparable Expr coefficients format cleanly without throwing',
      () {
        final s = formatPolynomialTerms<Expr>(exprDataType, [
          (exponent: 1, coefficient: const Variable('b')),
          (exponent: 0, coefficient: const Variable('a')),
        ]);
        check(s).equals('bx + a');
      },
    );
  });

  group('Coefficient helpers', () {
    test('coeffToDouble converts numeric and real Complex values', () {
      check(coeffToDouble(3)).equals(3.0);
      check(coeffToDouble(BigInt.from(5))).equals(5.0);
      check(coeffToDouble(Fraction(3, 2))).equals(1.5);
      check(coeffToDouble(const Complex(3.5, 0.0))).equals(3.5);
    });

    test('coeffToDouble throws on non-real Complex or unsupported values', () {
      check(() => coeffToDouble(const Complex(3.5, 1.0)))
          .throws<UnsupportedError>();
      check(() => coeffToDouble('not a number')).throws<UnsupportedError>();
    });

    test(
      'coeffToComplex converts numeric values and throws on unsupported',
      () {
        check(coeffToComplex(const Complex(1.0, -2.0)))
            .equals(const Complex(1.0, -2.0));
        check(coeffToComplex(4)).equals(const Complex(4.0));
        check(coeffToComplex(BigInt.from(7))).equals(const Complex(7.0));
        check(coeffToComplex(Fraction(1, 2))).equals(const Complex(0.5));
        check(() => coeffToComplex('bad')).throws<UnsupportedError>();
      },
    );

    test('normalizeCoefficient and checkSamePolynomialType', () {
      check(normalizeCoefficient(-0.0, 0.0)).equals(0.0);
      check(normalizeCoefficient(const Complex(-0.0, -0.0), Complex.zero))
          .equals(Complex.zero);
      check(normalizeCoefficient(const Complex(-0.0, 2.0), Complex.zero))
          .equals(const Complex(0.0, 2.0));
      check(
        () => checkSamePolynomialType<num>(DataType.int32, DataType.float64),
      ).throws<ArgumentError>();
      check(isFloatPolynomialType(DataType.float32)).isTrue;
      check(isFloatPolynomialType(DataType.float64)).isTrue;
      check(isFloatPolynomialType(DataType.int32)).isFalse;
    });
  });
}
