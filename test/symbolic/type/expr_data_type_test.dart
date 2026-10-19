import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:more/number.dart' show Complex;
import 'package:test/test.dart';

void main() {
  group('ExprDataType properties, casting, and ordering', () {
    test('metadata, comparator, printer, and cast conversions', () {
      const dt = ExprDataType.instance;
      check(dt).equals(exprDataType);
      check(dt.name).equals('expr');
      check(dt.defaultValue).equals(IntegerNumber.zero);
      check(dt.isNullable).isFalse();
      check(dt.toString()).equals('DataType.expr');
      check(dt.printer(IntegerNumber.of(42))).equals('42');

      const x = Variable('x');
      check(dt.equality.isEqual(x, x)).isTrue();
      check(dt.comparator(IntegerNumber.one, IntegerNumber.two)).isLessThan(0);
      check(dt.comparator(x, x)).equals(0);

      check(dt.cast(x)).equals(x);
      check(dt.cast(5)).equals(IntegerNumber.of(5));
      check(dt.cast(BigInt.from(12))).equals(IntegerNumber.of(12));
      check(dt.cast(const Complex(5, 0))).equals(IntegerNumber.of(5));
      check(dt.cast(const Complex(2, 3)))
          .equals(ComplexNumber(IntegerNumber.two, IntegerNumber.of(3)));
      check(dt.cast(const Complex(double.infinity, 2)))
          .equals(Expr.wrap(const Complex(double.infinity, 2)));
      check(dt.cast(2.5)).equals(const RealNumber(2.5));
      check(dt.cast('x + 1')).equals(Expr.parse('x + 1'));

      check(() => dt.cast('??? invalid')).throws<ArgumentError>();
      check(() => dt.cast(Object())).throws<ArgumentError>();
    });
  });

  group('ExprEquality', () {
    test('isEqual, isClose, and hash across numeric, constant, and symbolic expressions', () {
      final eq = exprDataType.equality;
      final a = Expr.parse('(x + 1)^2');
      final b = Expr.parse('x^2 + 2*x + 1');

      check(eq.isEqual(a, a)).isTrue();
      check(eq.isEqual(a, b)).isFalse();
      check(eq.hash(a)).equals(a.hashCode);

      check(eq.isClose(a, a, 1e-9)).isTrue();
      check(eq.isClose(a, b, 1e-9)).isTrue();
      check(eq.isClose(const RealNumber(1.0), const RealNumber(1.0001), 1e-3))
          .isTrue();
      check(eq.isClose(const RealNumber(1.0), const RealNumber(1.01), 1e-3))
          .isFalse();
      check(
        eq.isClose(
          const ComplexNumber(IntegerNumber.one, RealNumber(1e-5)),
          IntegerNumber.one,
          1e-3,
        ),
      ).isTrue();
      check(eq.isClose(Constant.pi, const RealNumber(math.pi), 1e-12)).isTrue();
      // Closed expression throwing on evaluateComplex returns false
      check(eq.isClose(Gamma(ComplexNumber.i), IntegerNumber.zero, 1e-3))
          .isFalse();
      // Distinct symbolic expressions with free variables return false
      check(eq.isClose(const Variable('x'), const Variable('y'), 1e-3))
          .isFalse();
    });
  });

  group('ExprField', () {
    test('field arithmetic, scaling, transcendental functions, norm, and conjugate', () {
      final f = exprDataType.field as ExprField;
      const x = Variable('x');
      final a = Expr.parse('x + 1');
      final b = Expr.parse('x - 1');

      check(f.additiveIdentity).equals(IntegerNumber.zero);
      check(f.multiplicativeIdentity).equals(IntegerNumber.one);
      check(f.infinity).equals(Constant.infinity);
      check(f.negativeInfinity).equals(-Constant.infinity);
      check(f.nan).equals(Constant.undefined);

      check(f.add(a, b).toString()).equals('2 * x');
      check(f.sub(a, b)).equals(IntegerNumber.two);
      check(f.mul(a, b).expand().toString()).equals('-1 + x ^ 2');
      check(f.div(a, a)).equals(IntegerNumber.one);
      check(f.neg(x)).equals(-x);
      check(f.inv(IntegerNumber.two)).equals(FractionNumber.half);

      // scale with int, integer double, rationalizable double, and general double
      check(f.scale(x, 3)).equals((x * 3).simplify());
      check(f.scale(x, 3.0)).equals((x * 3).simplify());
      check(f.scale(x, 0.25)).equals((x * FractionNumber.quarter).simplify());
      check(f.scale(x, math.pi))
          .equals((x * const RealNumber(math.pi)).simplify());

      check(f.pow(IntegerNumber.of(3), IntegerNumber.two))
          .equals(IntegerNumber.of(9));
      check(f.abs(IntegerNumber.of(-5))).equals(IntegerNumber.of(5));
      check(f.sqrt(IntegerNumber.of(9))).equals(IntegerNumber.of(3));
      check(f.exp(IntegerNumber.zero)).equals(IntegerNumber.one);
      check(f.log(Constant.e)).equals(IntegerNumber.one);

      // norm on real, complex, and symbolic
      check(f.norm(IntegerNumber.of(-5))).equals(5.0);
      check(f.norm(ComplexNumber(IntegerNumber.of(3), IntegerNumber.of(4))))
          .isCloseTo(5.0, 1e-12);
      check(() => f.norm(x)).throws<UnsupportedError>();

      // conjugate
      check(
        f.conjugate(
          x +
              ComplexNumber(IntegerNumber.two, IntegerNumber.of(3)) +
              const OrderTerm('x', 2),
        ),
      ).equals(
        (x +
                ComplexNumber(IntegerNumber.two, IntegerNumber.of(-3)) +
                const OrderTerm('x', 2))
            .simplify(),
      );

      // isZero
      check(f.isZero(IntegerNumber.zero)).isTrue();
      check(f.isZero(RealNumber.zero)).isTrue();
      check(f.isZero(x - x)).isTrue();
      check(f.isZero(x)).isFalse();

      // Euclidean / modular operations throw UnsupportedError
      check(() => f.mod(a, b)).throws<UnsupportedError>();
      check(() => f.division(a, b)).throws<UnsupportedError>();
      check(() => f.remainder(a, b)).throws<UnsupportedError>();
      check(() => f.modPow(a, b, x)).throws<UnsupportedError>();
      check(() => f.modInverse(a, b)).throws<UnsupportedError>();
      check(() => f.gcd(a, b)).throws<UnsupportedError>();
    });
  });
}
