import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/type.dart';
import 'package:test/scaffolding.dart';

T store<T>(DataType<T> type, T value) =>
    type.newList(1, fillValue: value).first;

void checkListOperations<T>(DataType<T> type, List<List<T>> lists) {
  if (<DataType<dynamic>>[
    DataType.boolean,
    DataType.string,
    DataType.bigInt,
    DataType.fraction,
    DataType.complex,
    DataType.quaternion,
  ].contains(type)) {
    test('fromType', () {
      check(DataType.fromType<T>()).equals(type);
    });
    test('fromInstance', () {
      for (final value in lists.expand((value) => value)) {
        check(
          because: 'DataType.fromInstance<$T>($value)',
          DataType.fromInstance<T>(value),
        ).equals(type);
      }
    });
  }

  if (<DataType<dynamic>>[
    DataType.float64,
    DataType.int32,
    DataType.boolean,
    DataType.string,
  ].contains(type)) {
    for (final list in lists) {
      test('fromIterable([${list.join(', ')}])', () {
        check(DataType.fromIterable<T>(list)).equals(type);
      });
    }
  }

  if ((type as DataType<dynamic>) != DataType.float32) {
    for (final list in lists) {
      test('castList([${list.join(', ')}])', () {
        final result = type.castList(list);
        check(result.length).equals(list.length);
        for (var i = 0; i < list.length; i++) {
          check(type.equality.isEqual(result[i], list[i])).isTrue();
        }
      });
    }
  }

  final exampleList = lists.reduce((a, b) => a.length >= b.length ? a : b);
  final exampleValue = lists
      .expand((value) => value)
      .firstWhere(
        (value) => value != type.defaultValue,
        orElse: () => type.defaultValue,
      );

  group('newList', () {
    test('empty', () {
      final list = type.newList(0);
      check(list).isEmpty();
    });

    test('length', () {
      final list = type.newList(42);
      check(list.length).equals(42);
    });

    test('defaultValue', () {
      final list = type.newList(1);
      check(type.equality.isEqual(list[0], type.defaultValue)).isTrue();
    });

    test('readonly', () {
      final list = type.newList(10, readonly: true);
      check(() => list[0] = exampleValue).throws<UnsupportedError>();
      check(list.length).equals(10);
    });

    test('filled', () {
      final list = type.newList(10, fillValue: exampleValue);
      check(list.length).equals(10);
      for (var i = 0; i < 10; i++) {
        check(type.equality.isEqual(list[i], exampleValue)).isTrue();
      }
    });

    test('filled, readonly', () {
      final list = type.newList(10, fillValue: exampleValue, readonly: true);
      check(() => list[0] = type.defaultValue).throws<UnsupportedError>();
      check(list.length).equals(10);
      for (var i = 0; i < 10; i++) {
        check(type.equality.isEqual(list[i], exampleValue)).isTrue();
      }
    });

    test('generated', () {
      final values = lists.expand((value) => value).toList();
      final list = type.newList(values.length, generate: (i) => values[i]);
      check(list.length).equals(values.length);
      for (var i = 0; i < values.length; i++) {
        check(type.equality.isEqual(list[i], values[i])).isTrue();
      }
    });

    test('generated, readonly', () {
      final values = lists.expand((value) => value).toList();
      final list = type.newList(
        values.length,
        generate: (i) => values[i],
        readonly: true,
      );
      if (values.isNotEmpty) {
        check(() => list[0] = values.last).throws<UnsupportedError>();
      }
      check(list.length).equals(values.length);
    });
  });

  group('copyList', () {
    test('basic', () {
      final copy = type.copyList(exampleList);
      check(copy.length).equals(exampleList.length);
      for (var i = 0; i < exampleList.length; i++) {
        check(type.equality.isEqual(copy[i], exampleList[i])).isTrue();
      }
    });

    test('smaller', () {
      final targetLength = math.max(0, exampleList.length - 1);
      final copy = type.copyList(exampleList, length: targetLength);
      check(copy.length).equals(targetLength);
      for (var i = 0; i < targetLength; i++) {
        check(type.equality.isEqual(copy[i], exampleList[i])).isTrue();
      }
    });

    test('larger', () {
      final copy = type.copyList(exampleList, length: exampleList.length + 5);
      check(copy.length).equals(exampleList.length + 5);
      for (var i = 0; i < exampleList.length; i++) {
        check(type.equality.isEqual(copy[i], exampleList[i])).isTrue();
      }
      for (var i = exampleList.length; i < copy.length; i++) {
        check(type.equality.isEqual(copy[i], type.defaultValue)).isTrue();
      }
    });

    test('larger, with custom fill', () {
      final copy = type.copyList(
        exampleList,
        length: exampleList.length + 5,
        fillValue: exampleValue,
      );
      check(copy.length).equals(exampleList.length + 5);
      for (var i = 0; i < exampleList.length; i++) {
        check(type.equality.isEqual(copy[i], exampleList[i])).isTrue();
      }
      for (var i = exampleList.length; i < copy.length; i++) {
        check(type.equality.isEqual(copy[i], exampleValue)).isTrue();
      }
    });

    test('readonly', () {
      final copyReadonly = type.copyList(exampleList, readonly: true);
      if (exampleList.isNotEmpty) {
        check(() => copyReadonly[0] = exampleValue).throws<UnsupportedError>();
      }
      final copyWritable = type.copyList(exampleList, readonly: false);
      if (exampleList.isNotEmpty) {
        copyWritable[0] = exampleValue;
        check(type.equality.isEqual(copyWritable[0], exampleValue)).isTrue();
      }
    });
  });

  test('printer', () {
    final printer = type.printer;
    final examples = lists.expand((list) => list).toList();
    for (final example in examples) {
      final printed = printer(example);
      check(printed.isNotEmpty).isTrue();
    }
  });
}

void checkFieldOperations<T>(
  DataType<T> type,
  List<T> values, {
  double epsilon = 0.01,
}) {
  final equality = type.equality;
  final field = type.field;

  final addId = field.additiveIdentity;
  final mulId = field.multiplicativeIdentity;

  group('equality', () {
    test('isEqual', () {
      check(equality.isEqual(addId, mulId)).isFalse();
      for (final value in values) {
        check(equality.isEqual(value, value)).isTrue();
        check(equality.isEqual(value, addId)).isFalse();
      }
    });

    test('isClose', () {
      check(equality.isClose(addId, mulId, epsilon)).isFalse();
      for (final value in values) {
        check(equality.isClose(value, value, epsilon)).isTrue();
        check(equality.isClose(value, addId, epsilon)).isFalse();
      }
    });

    test('hash', () {
      for (final value in values) {
        check(equality.hash(value)).equals(equality.hash(value));
      }
    });
  });

  if ((type as DataType<dynamic>) == DataType.complex ||
      (type as DataType<dynamic>) == DataType.quaternion) {
    test('comparator throws', () {
      check(() => type.comparator(values.first, values.last))
          .throws<UnsupportedError>();
    });
  } else {
    group('comparator', () {
      final comparator = type.comparator;
      test('increasing and decreasing', () {
        for (var i = 0; i < values.length - 1; i++) {
          check(comparator(values[i], values[i + 1])).isLessThan(0);
          check(comparator(values[i + 1], values[i])).isGreaterThan(0);
        }
      });

      test('equal', () {
        for (var i = 0; i < values.length; i++) {
          check(comparator(values[i], values[i])).equals(0);
        }
      });
    });
  }

  group('field arithmetic', () {
    test('neg, add, sub', () {
      for (final value in values) {
        check(equality.isEqual(field.neg(field.neg(value)), value)).isTrue();
        check(equality.isEqual(field.add(value, addId), value)).isTrue();
        check(equality.isEqual(field.add(addId, value), value)).isTrue();
        check(
          equality.isClose(field.add(value, field.neg(value)), addId, epsilon),
        ).isTrue();
        check(equality.isEqual(field.sub(value, addId), value)).isTrue();
      }
    });
  });
}
