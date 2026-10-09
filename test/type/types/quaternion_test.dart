import 'package:checks/checks.dart';
import 'package:data/type.dart';
import 'package:test/scaffolding.dart';

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
  });
}
