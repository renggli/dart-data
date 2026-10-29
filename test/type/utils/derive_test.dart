import 'package:checks/checks.dart';
import 'package:data/src/type/utils/derive.dart';
import 'package:data/type.dart';
import 'package:test/test.dart';

void main() {
  group('fromType', () {
    test('standard types', () {
      check(fromType<int>()).equals(DataType.integer);
      check(fromType<double>()).equals(DataType.float);
      check(fromType<num>()).equals(DataType.numeric);
      check(fromType<bool>()).equals(DataType.boolean);
      check(fromType<String>()).equals(DataType.string);
      check(fromType<Complex>()).equals(DataType.complex);
      check(fromType<Fraction>()).equals(DataType.fraction);
      check(fromType<BigInt>()).equals(DataType.bigInt);
      check(fromType<Quaternion>()).equals(DataType.quaternion);
      check(fromType<dynamic>()).equals(DataType.dynamicType);
    });

    test('custom object fallback', () {
      final customType = fromType<Object?>();
      check(customType).isA<DataType<Object?>>();
      check(customType.name).equals('object');
    });
  });

  group('fromInstance', () {
    test('known runtime instances', () {
      check(fromInstance(42)).equals(DataType.integer);
      check(fromInstance(3.14)).equals(DataType.float);
      check(fromInstance('hello')).equals(DataType.string);
      check(fromInstance(true)).equals(DataType.boolean);
      check(fromInstance(Complex.i)).equals(DataType.complex);
    });

    test('custom instances fallback', () {
      final now = DateTime.now();
      check(fromInstance(now)).isA<DataType<DateTime>>();
    });
  });

  group('fromIterable', () {
    test('typed iterables', () {
      check(fromIterable(<int>[1, 2, 3])).equals(DataType.integer);
      check(fromIterable(<double>[1.0, 2.0])).equals(DataType.float);
    });

    test('inferred from first element', () {
      check(fromIterable(['a', 'b', 'c'])).equals(DataType.string);
      check(fromIterable([true, false])).equals(DataType.boolean);
    });

    test('heterogeneous Object/Object? elements fall back to object type', () {
      final heterogeneous = <Object?>[1.0, 'a'];
      check(fromIterable(heterogeneous))
          .equals(DataType.nullableObject<Object?>());
    });

    test('empty iterable uses type parameter', () {
      check(fromIterable(<String>[])).equals(DataType.string);
      check(fromIterable(<bool>[])).equals(DataType.boolean);
    });
  });
}
