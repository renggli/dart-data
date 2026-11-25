import 'package:checks/checks.dart';
import 'package:data/polynomial.dart';
import 'package:data/type.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('RationalFunction construction and queries', () {
    test('construction, fromPolynomial, isZero, and isPolynomial', () {
      final num = Polynomial<double>.fromCoefficients([1.0, 2.0]);
      final den = Polynomial<double>.fromCoefficients([3.0, 0.0, 1.0]);
      final rf = RationalFunction(num, den);
      check(rf.numerator).equals(num);
      check(rf.denominator).equals(den);
      check(rf.isZero).isFalse;
      check(rf.isPolynomial).isFalse;
      check(rf.toString()).contains('/');

      final fromP = RationalFunction.fromPolynomial(num);
      check(fromP.isPolynomial).isTrue;
      check(fromP.evaluate(2.0)).equals(5.0);

      final sparseFromP = RationalFunction.fromPolynomial(
        Polynomial<double>.compressed([0, 50], [1.0, 2.0]),
      );
      check(sparseFromP.denominator).isA<CompressedPolynomial<double>>();

      final zero = Polynomial<double>.zero();
      check(RationalFunction.fromPolynomial(zero).isZero).isTrue;
      check(() => RationalFunction(num, zero)).throws<UnsupportedError>();
    });

    test('mismatched DataType throws ArgumentError', () {
      check(
        () => RationalFunction<num>(
          Polynomial<num>.fromCoefficients([1.0], type: DataType.float64),
          Polynomial<num>.fromCoefficients([1], type: DataType.int32),
        ),
      ).throws<ArgumentError>();
    });
  });

  group('RationalFunction evaluation', () {
    test('real, double, and complex evaluation with pole handling', () {
      // R(x) = (x + 2) / (x - 1)
      final num = Polynomial<double>.fromCoefficients([2.0, 1.0]);
      final den = Polynomial<double>.fromCoefficients([-1.0, 1.0]);
      final rf = RationalFunction(num, den);

      check(rf.evaluate(2.0)).equals(4.0);
      check(rf.evaluateDouble(0.0)).equals(-2.0);
      check(() => rf.evaluate(1.0)).throws<UnsupportedError>();
      check(() => rf.evaluateDouble(1.0)).throws<UnsupportedError>();

      final complexRf = RationalFunction(
        Polynomial<double>.fromCoefficients([1.0, 1.0]),
        den,
      );
      final val = complexRf.evaluateComplex(const Complex(1.0, 1.0));
      check(val.a).isCloseTo(1.0, 1e-9);
      check(val.b).isCloseTo(-2.0, 1e-9);
      check(() => complexRf.evaluateComplex(const Complex(1.0, 0.0)))
          .throws<UnsupportedError>();
    });
  });

  group('RationalFunction simplification and equality', () {
    test('automatic and explicit GCD simplification preserves sparse type', () {
      final num = Polynomial<double>.fromCoefficients([-1.0, 0.0, 1.0]);
      final den = Polynomial<double>.fromCoefficients([-1.0, 1.0]);
      final simplified = RationalFunction.simplified(num, den);
      check(simplified.isPolynomial).isTrue;
      check(simplified.numerator.degree).equals(1);
      check(simplified.evaluate(3.0)).equals(4.0);
      check(identical(simplified.simplify(), simplified)).isTrue;

      final unsimplified = RationalFunction(num, den);
      check(unsimplified == simplified).isTrue;
      check(unsimplified.hashCode).equals(simplified.hashCode);

      final sparseNum = Polynomial<double>.compressed([0, 100], [2.0, 4.0]);
      final sparseDen = Polynomial<double>.compressed([0], [2.0]);
      final sparseRf = RationalFunction(sparseNum, sparseDen).simplify();
      check(sparseRf.numerator).isA<CompressedPolynomial<double>>();
      check(sparseRf.denominator).isA<CompressedPolynomial<double>>();
      check(sparseRf.numerator[100]).equals(2.0);
      check(sparseRf.denominator[0]).equals(1.0);
    });

    test('zero numerator and non-dyadic denominator canonicalization', () {
      // Integer ring zero numerators canonicalize to 0 / 1
      final zInt1 = RationalFunction(
        Polynomial<int>.zero(type: DataType.int32),
        Polynomial<int>.fromCoefficients([5, 3], type: DataType.int32),
      );
      final zInt2 = RationalFunction(
        Polynomial<int>.zero(type: DataType.int32),
        Polynomial<int>.fromCoefficients([7], type: DataType.int32),
      );
      check(zInt1 == zInt2).isTrue;
      check(zInt1.hashCode).equals(zInt2.hashCode);
      check(zInt1.simplify().denominator.coefficients).deepEquals([1]);

      // Exact monic normalization even for non-power-of-two float denominators
      final r49a = RationalFunction(
        Polynomial<double>.fromCoefficients([49.0]),
        Polynomial<double>.fromCoefficients([49.0]),
      ).simplify();
      final r49b = RationalFunction.fromPolynomial(
        Polynomial<double>.fromCoefficients([1.0]),
      );
      check(r49a == r49b).isTrue;
      check(r49a.denominator[0]).equals(1.0);
    });
  });

  group('RationalFunction algebra, powers, and calculus', () {
    test(
      'addition, subtraction, negation, scaling, multiplication, division',
      () {
        final p1 = Polynomial<double>.fromCoefficients([1.0]);
        final px = Polynomial<double>.fromCoefficients([0.0, 1.0]);
        final pxPlus1 = Polynomial<double>.fromCoefficients([1.0, 1.0]);
        final pxMinus1 = Polynomial<double>.fromCoefficients([-1.0, 1.0]);

        final r1 = RationalFunction(p1, px);
        final r2 = RationalFunction(p1, pxPlus1);

        check((r1 + r2).evaluate(2.0)).isCloseTo(0.5 + 1.0 / 3.0, 1e-9);
        check((r1 - r2).evaluate(2.0)).isCloseTo(0.5 - 1.0 / 3.0, 1e-9);
        check((-r1).evaluate(2.0)).equals(-0.5);

        final scaled = RationalFunction(
          pxPlus1,
          Polynomial<double>.fromCoefficients([2.0, 1.0]),
        ).scale(3.0);
        check(scaled.evaluate(0.0)).isCloseTo(1.5, 1e-9);
        check(r1.scale(0.0).isZero).isTrue;
        final sparseScaledZero = RationalFunction.fromPolynomial(
          Polynomial<double>.compressed([10], [2.0]),
        ).scale(0.0);
        check(sparseScaledZero.numerator).isA<CompressedPolynomial<double>>();

        final prod =
            RationalFunction(px, pxPlus1) *
            RationalFunction(
              pxPlus1,
              Polynomial<double>.fromCoefficients([0.0, 0.0, 1.0]),
            );
        check(prod.evaluate(4.0)).isCloseTo(0.25, 1e-9);

        final quot =
            RationalFunction(px, pxPlus1) / RationalFunction(px, pxMinus1);
        check(quot.evaluate(3.0)).isCloseTo(0.5, 1e-9);
        check(
          () => r1 / RationalFunction.fromPolynomial(Polynomial<double>.zero()),
        ).throws<UnsupportedError>();
      },
    );

    test('type mismatches in binary operators throw ArgumentError', () {
      final rInt32 = RationalFunction(
        Polynomial<int>.fromCoefficients([1, 1], type: DataType.int32),
        Polynomial<int>.fromCoefficients([2, 1], type: DataType.int32),
      );
      final rInt64 = RationalFunction(
        Polynomial<int>.fromCoefficients([1, 1], type: DataType.int64),
        Polynomial<int>.fromCoefficients([2, 1], type: DataType.int64),
      );
      check(() => rInt32 + rInt64).throws<ArgumentError>();
      check(() => rInt32 - rInt64).throws<ArgumentError>();
      check(() => rInt32 * rInt64).throws<ArgumentError>();
      check(() => rInt32 / rInt64).throws<ArgumentError>();
    });

    test('reciprocal and integer powers', () {
      final rf = RationalFunction(
        Polynomial<double>.fromCoefficients([1.0, 1.0]), // x + 1
        Polynomial<double>.fromCoefficients([2.0, 1.0]), // x + 2
      );
      final rec = rf.reciprocal();
      check(rec.evaluate(3.0)).isCloseTo(5.0 / 4.0, 1e-9);

      check(rf.pow(0).evaluate(3.0)).equals(1.0);
      check(rf.pow(1)).equals(rf);
      check(rf.pow(2).evaluate(3.0)).isCloseTo(16.0 / 25.0, 1e-9);
      check(rf.pow(-2).evaluate(3.0)).isCloseTo(25.0 / 16.0, 1e-9);

      final zeroRf = RationalFunction.fromPolynomial(Polynomial<double>.zero());
      check(zeroRf.pow(0).evaluate(3.0)).equals(1.0);
      check(zeroRf.pow(3).isZero).isTrue;
      check(zeroRf.reciprocal).throws<UnsupportedError>();
      check(() => zeroRf.pow(-1)).throws<UnsupportedError>();
    });

    test('derivative with order parameter', () {
      final r = RationalFunction(
        Polynomial<double>.fromCoefficients([1.0]),
        Polynomial<double>.fromCoefficients([0.0, 1.0]),
      );
      check(r.derivative(order: 0)).equals(r);
      check(r.derivative().evaluate(2.0)).isCloseTo(-0.25, 1e-9);
      // d^2/dx^2 (1/x) = 2 / x^3 -> at x = 2: 0.25
      check(r.derivative(order: 2).evaluate(2.0)).isCloseTo(0.25, 1e-9);
      check(() => r.derivative(order: -1)).throws<RangeError>();

      final zeroRf = RationalFunction.fromPolynomial(Polynomial<double>.zero());
      check(zeroRf.derivative().isZero).isTrue;
      check(
        RationalFunction.fromPolynomial(
          Polynomial<double>.fromCoefficients([3.0]),
        ).derivative(order: 2).isZero,
      ).isTrue;
    });
  });
}
