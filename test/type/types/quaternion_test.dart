import 'package:checks/checks.dart';
import 'package:data/type.dart';
import 'package:test/test.dart';

import '../test_utils.dart';

void main() {
  group('QuaternionDataType', () {
    const type = DataType.quaternion;

    test('attributes', () {
      check(type.name).equals('quaternion');
      check(type.defaultValue).equals(Quaternion.zero);
      check(type.isNullable).isFalse();
      check(type.isNative).isFalse();
      check(type.toString()).equals('DataType.quaternion');
    });

    test('comparator throws', () {
      check(() => type.comparator(const Quaternion(1), const Quaternion(2)))
          .throws<UnsupportedError>();
    });

    test('cast', () {
      check(type.cast(const Quaternion(1, 2, 3, 4)))
          .equals(const Quaternion(1, 2, 3, 4));
      check(type.cast(5)).equals(const Quaternion(5));
      check(type.cast(2.5)).equals(const Quaternion(2.5));
      check(type.cast(BigInt.from(7))).equals(const Quaternion(7));
      check(type.cast(Fraction(3, 2))).equals(const Quaternion(1.5));
    });

    test('cast error', () {
      check(() => type.cast('abc')).throws<ArgumentError>();
      check(() => type.cast(null)).throws<ArgumentError>();
    });

    checkListOperations(type, <List<Quaternion>>[
      [const Quaternion(1, 2, 3, 4), const Quaternion(5, 6, 7, 8)],
      [const Quaternion(-1), Quaternion.zero, const Quaternion(0, 0, 1)],
    ]);

    checkFieldOperations(type, <Quaternion>[
      const Quaternion(-1, 2, 0, 1),
      const Quaternion(3, -4, 1, 0),
      const Quaternion(2, 5, -1, 2),
    ]);

    test('QuaternionField extended operations', () {
      final field = type.field;
      check(field.inv(const Quaternion(2))).equals(const Quaternion(0.5));
      check(field.scale(const Quaternion(2, 3, 4, 5), 2))
          .equals(const Quaternion(4, 6, 8, 10));
      check(field.div(const Quaternion(4, 6, 8, 10), const Quaternion(2)))
          .equals(const Quaternion(4, 6, 8, 10) / const Quaternion(2));
      check(
        field
            .pow(const Quaternion(2), const Quaternion(3))
            .closeTo(const Quaternion(8), 1e-10),
      ).isTrue();
      check(field.abs(const Quaternion(1, 2, 2, 4)))
          .equals(const Quaternion(5));
      check(field.norm(const Quaternion(1, 2, 2, 4))).equals(5.0);
      check(field.conjugate(const Quaternion(1, 2, 3, 4)))
          .equals(const Quaternion(1, -2, -3, -4));
      check(() => field.sqrt(const Quaternion(4))).throws<UnsupportedError>();
      check(() => field.exp(Quaternion.zero)).throws<UnsupportedError>();
      check(() => field.log(const Quaternion(1))).throws<UnsupportedError>();
      check(() => field.nan).throws<UnsupportedError>();
      check(() => field.infinity).throws<UnsupportedError>();
      check(() => field.negativeInfinity).throws<UnsupportedError>();

      check(() => field.mod(Quaternion.zero, Quaternion.zero))
          .throws<UnsupportedError>();
      check(() => field.division(Quaternion.zero, Quaternion.zero))
          .throws<UnsupportedError>();
      check(() => field.remainder(Quaternion.zero, Quaternion.zero))
          .throws<UnsupportedError>();
      check(
        () => field.modPow(Quaternion.zero, Quaternion.zero, Quaternion.zero),
      ).throws<UnsupportedError>();
      check(() => field.modInverse(Quaternion.zero, Quaternion.zero))
          .throws<UnsupportedError>();
      check(() => field.gcd(Quaternion.zero, Quaternion.zero))
          .throws<UnsupportedError>();
    });
  });
}
