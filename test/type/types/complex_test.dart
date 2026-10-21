import 'dart:typed_data';

import 'package:checks/checks.dart';
import 'package:data/src/type/utils/memory.dart';
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
      check(type.isNative).isTrue();
      check(type.bits).equals(128);
      check(type.bytesPerElement).equals(16);
      check(type.toString()).equals('DataType.complex');
      check(() => type.min).throws<UnsupportedError>();
      check(() => type.max).throws<UnsupportedError>();
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

  group('Float64ComplexList', () {
    test('construction and basic access', () {
      final list = Float64ComplexList(3);
      check(list.length).equals(3);
      check(list[0]).equals(Complex.zero);
      check(list[1]).equals(Complex.zero);
      check(list[2]).equals(Complex.zero);

      list[0] = const Complex(1.5, -2.5);
      list[1] = const Complex(3, 4);
      check(list[0]).equals(const Complex(1.5, -2.5));
      check(list[1]).equals(const Complex(3.0, 4.0));
      check(list.data[0]).equals(1.5);
      check(list.data[1]).equals(-2.5);
      check(list.data[2]).equals(3.0);
      check(list.data[3]).equals(4.0);
    });

    test('fixed-length restriction', () {
      final list = Float64ComplexList(2);
      check(() => list.length = 5).throws<UnsupportedError>();
    });

    test('fromData constructor', () {
      final data = Float64List.fromList([1.0, 3.0, 2.0, 4.0]);
      final list = Float64ComplexList.fromData(data);
      check(list.length).equals(2);
      check(list[0]).equals(const Complex(1.0, 3.0));
      check(list[1]).equals(const Complex(2.0, 4.0));
    });

    test('fromBuffers constructor', () {
      final real = Float64List.fromList([1.0, 2.0]);
      final imag = Float64List.fromList([3.0, 4.0]);
      final list = Float64ComplexList.fromBuffers(real, imag);
      check(list[0]).equals(const Complex(1.0, 3.0));
      check(list[1]).equals(const Complex(2.0, 4.0));
    });

    test('setRange from Float64ComplexList', () {
      final source = Float64ComplexList.fromBuffers(
        Float64List.fromList([1.0, 2.0, 3.0]),
        Float64List.fromList([4.0, 5.0, 6.0]),
      );
      final dest = Float64ComplexList(3);
      dest.setRange(1, 3, source, 1);
      check(dest[0]).equals(Complex.zero);
      check(dest[1]).equals(const Complex(2.0, 5.0));
      check(dest[2]).equals(const Complex(3.0, 6.0));
    });

    test('setRange from generic iterable', () {
      final dest = Float64ComplexList(3);
      dest.setRange(0, 2, [const Complex(7, 8), const Complex(9, 10)]);
      check(dest[0]).equals(const Complex(7.0, 8.0));
      check(dest[1]).equals(const Complex(9.0, 10.0));
      check(dest[2]).equals(Complex.zero);
    });

    test('fillRange', () {
      final list = Float64ComplexList(4);
      list.fillRange(1, 3, const Complex(2.5, -1.5));
      check(list[0]).equals(Complex.zero);
      check(list[1]).equals(const Complex(2.5, -1.5));
      check(list[2]).equals(const Complex(2.5, -1.5));
      check(list[3]).equals(Complex.zero);
    });

    test('sublist', () {
      final list = Float64ComplexList.fromBuffers(
        Float64List.fromList([1.0, 2.0, 3.0, 4.0]),
        Float64List.fromList([5.0, 6.0, 7.0, 8.0]),
      );
      final sub = list.sublist(1, 3);
      check(sub.length).equals(2);
      check(sub[0]).equals(const Complex(2.0, 6.0));
      check(sub[1]).equals(const Complex(3.0, 7.0));

      // Verify sublist creates a copy
      sub[0] = const Complex(99, 99);
      check(list[1]).equals(const Complex(2.0, 6.0));
    });

    test('sublistView', () {
      final list = Float64ComplexList(4);
      list[1] = const Complex(2.0, 6.0);
      list[2] = const Complex(3.0, 7.0);

      final view = list.sublistView(1, 3);
      check(view.length).equals(2);
      check(view[0]).equals(const Complex(2.0, 6.0));
      check(view[1]).equals(const Complex(3.0, 7.0));

      // Modifying view mutates underlying list
      view[0] = const Complex(99, 99);
      check(list[1]).equals(const Complex(99.0, 99.0));
    });

    test('buffer and byte properties', () {
      final list = Float64ComplexList(3);
      check(list.elementSizeInBytes).equals(16);
      check(list.lengthInBytes).equals(48);
      check(list.offsetInBytes).equals(0);
      check(list.buffer.lengthInBytes).isGreaterOrEqual(48);

      final unmod = list.asUnmodifiableView();
      check(unmod.elementSizeInBytes).equals(16);
      check(unmod.lengthInBytes).equals(48);
      check(unmod.offsetInBytes).equals(0);
      check(unmod.buffer.lengthInBytes).isGreaterOrEqual(48);
    });

    test('unmodifiable view', () {
      final list = Float64ComplexList(2);
      list[0] = const Complex(1, 2);
      final view = list.asUnmodifiableView();
      check(view.length).equals(2);
      check(view[0]).equals(const Complex(1.0, 2.0));
      check(() => view[0] = const Complex(3, 4)).throws<UnsupportedError>();
      check(() => view.setRange(0, 1, [Complex.zero]))
          .throws<UnsupportedError>();
      check(() => view.fillRange(0, 1, Complex.zero))
          .throws<UnsupportedError>();
      check(() => view.setAll(0, [Complex.zero])).throws<UnsupportedError>();
      check(view.asUnmodifiableView()).identicalTo(view);
    });

    test('sharesMemory and hasOverlap', () {
      final a = Float64ComplexList(4);
      final b = Float64ComplexList(4);
      final view = a.asUnmodifiableView();

      check(sharesMemory(a, a)).isTrue();
      check(sharesMemory(a, view)).isTrue();
      check(sharesMemory(a, b)).isFalse();
      check(hasOverlap(a, 0, a, 1, 2)).isTrue();
      check(hasOverlap(a, 0, b, 0, 2)).isFalse();
    });
  });
}
