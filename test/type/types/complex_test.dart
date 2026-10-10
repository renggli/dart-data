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
  });
}
