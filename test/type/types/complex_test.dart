import 'package:checks/checks.dart';
import 'package:data/type.dart';
import 'package:test/test.dart';

import '../test_utils.dart';

void main() {
  group('ComplexDataType', () {
    const type = DataType.complex;

    test('attributes', () {
      check(type.name).equals('complex');
      check(type.defaultValue).equals(Complex.zero);
      check(type.isNullable).isFalse();
      check(type.isNative).isFalse();
      check(type.toString()).equals('DataType.complex');
    });

    test('comparator throws', () {
      check(() => type.comparator(const Complex(1, 2), const Complex(3, 4)))
          .throws<UnsupportedError>();
    });

    test('cast', () {
      check(type.cast(const Complex(1, 2))).equals(const Complex(1, 2));
      check(type.cast(5)).equals(const Complex(5));
      check(type.cast(2.5)).equals(const Complex(2.5));
      check(type.cast(BigInt.from(7))).equals(const Complex(7));
      check(type.cast(Fraction(3, 2))).equals(const Complex(1.5));
    });

    test('cast error', () {
      check(() => type.cast('abc')).throws<ArgumentError>();
      check(() => type.cast(null)).throws<ArgumentError>();
    });

    checkListOperations(type, <List<Complex>>[
      [const Complex(1, 2), const Complex(3, 4)],
      [const Complex(-1, -1), Complex.zero, const Complex(0, 5)],
    ]);

    checkFieldOperations(type, <Complex>[
      const Complex(-1, 2),
      const Complex(3, -4),
      const Complex(2, 5),
    ]);

    test('ComplexField extended operations', () {
      final field = type.field;
      check(field.inv(const Complex(2, 0))).equals(const Complex(0.5));
      check(field.scale(const Complex(2, 3), 2)).equals(const Complex(4, 6));
      check(field.div(const Complex(4, 6), const Complex(2, 0)))
          .equals(const Complex(2, 3));
      check(field.pow(const Complex(2, 0), const Complex(2, 0)))
          .equals(const Complex(4, 0));
      check(field.abs(const Complex(3, 4))).equals(const Complex(5, 0));
      check(field.norm(const Complex(3, 4))).equals(5.0);
      check(field.conjugate(const Complex(2, 3))).equals(const Complex(2, -3));
      check(field.sqrt(const Complex(4, 0))).equals(const Complex(2, 0));
      check(field.exp(Complex.zero)).equals(const Complex(1, 0));
      check(field.log(const Complex(1, 0))).equals(Complex.zero);
      check(field.nan.isNaN).isTrue();
      check(field.infinity.isInfinite).isTrue();
      check(field.negativeInfinity.isInfinite).isTrue();

      check(() => field.mod(Complex.zero, Complex.zero))
          .throws<UnsupportedError>();
      check(() => field.division(Complex.zero, Complex.zero))
          .throws<UnsupportedError>();
      check(() => field.remainder(Complex.zero, Complex.zero))
          .throws<UnsupportedError>();
      check(() => field.modPow(Complex.zero, Complex.zero, Complex.zero))
          .throws<UnsupportedError>();
      check(() => field.modInverse(Complex.zero, Complex.zero))
          .throws<UnsupportedError>();
      check(() => field.gcd(Complex.zero, Complex.zero))
          .throws<UnsupportedError>();
    });
  });
}
