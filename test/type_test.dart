library data.test.type;

import 'dart:math' as math;

import 'package:data/src/shared/config.dart' as config;
import 'package:data/type.dart';
import 'package:test/test.dart';

void listTest<T>(DataType<T> type, List<List<T>> lists) {
  if ([
    config.floatDataType,
    config.intDataType,
    DataType.boolean,
    DataType.string,
    DataType.bigInt,
    DataType.fraction,
    DataType.complex,
    DataType.quaternion,
    DataType.object,
  ].contains(type)) {
    // Inference based on single example.dart or runtime type.
    final exampleInstance = lists.expand((list) => list).first;
    final exampleType = exampleInstance.runtimeType;
    test('fromInstance: $exampleInstance', () {
      expect(DataType.fromInstance(exampleInstance), type,
          reason: 'DataType.fromInstance($exampleInstance)');
    });
    test('fromType: $exampleType', () {
      expect(DataType.fromType(exampleType), type,
          reason: 'DataType.fromType($exampleType)');
    });
  }
  if ([
    DataType.float64,
    DataType.int64,
    DataType.int32,
    DataType.int16,
    DataType.int8,
    DataType.uint64,
    DataType.uint32,
    DataType.uint16,
    DataType.uint8,
    DataType.boolean,
    DataType.string,
    DataType.object,
  ].contains(type)) {
    // Inference based on iterable of examples.
    for (final list in lists) {
      test('fromIterable: $list', () {
        expect(DataType.fromIterable(list), type,
            reason: 'DataType.fromIterable($list)');
      });
    }
  }
  if (![DataType.float32].contains(type)) {
    for (final list in lists) {
      test('castList: $list', () {
        final result = type.castList(list);
        expect(result.length, list.length);
        expect(type.castList(list),
            pairwiseCompare(list, type.equality.isEqual, 'isEqual'),
            reason: '$type.castList($list)');
      });
    }
  }
  final exampleList = lists.last;
  final exampleValue =
      exampleList.firstWhere((value) => value != type.nullValue);
  group('newList', () {
    test('empty', () {
      final list = type.newList(0);
      expect(list, isEmpty);
    });
    test('length', () {
      final list = type.newList(42);
      expect(list.length, 42);
    });
    test('null', () {
      final list = type.newList(1);
      expect(list[0], type.nullValue);
    });
    test('filled', () {
      final list = type.newListFilled(10, exampleValue);
      expect(list, List.filled(10, exampleValue));
    });
  });
  group('copy', () {
    test('basic', () {
      final copy = type.copyList(exampleList);
      expect(
          copy, pairwiseCompare(exampleList, type.equality.isEqual, 'isEqual'));
    });
    test('smaller', () {
      final copy = type.copyList(exampleList, length: exampleList.length - 1);
      expect(copy.length, exampleList.length - 1);
      expect(
          copy,
          pairwiseCompare(exampleList.getRange(0, exampleList.length - 1),
              type.equality.isEqual, 'isEqual'));
    });
    test('larger', () {
      final copy = type.copyList(exampleList, length: exampleList.length + 5);
      expect(copy.length, exampleList.length + 5);
      expect(copy.getRange(0, exampleList.length),
          pairwiseCompare(exampleList, type.equality.isEqual, 'isEqual'));
      expect(
          copy.getRange(exampleList.length, copy.length),
          pairwiseCompare(List.filled(5, type.nullValue), type.equality.isEqual,
              'isEqual'));
    });
    test('larger, with custom fill', () {
      final copy = type.copyList(exampleList,
          length: exampleList.length + 5, fillValue: exampleValue);
      expect(copy.length, exampleList.length + 5);
      expect(copy.getRange(0, exampleList.length),
          pairwiseCompare(exampleList, type.equality.isEqual, 'isEqual'));
      expect(
          copy.getRange(exampleList.length, copy.length),
          pairwiseCompare(
              List.filled(5, exampleValue), type.equality.isEqual, 'isEqual'));
    });
  });
  test('printer', () {
    final printer = type.printer;
    final examples = lists.expand((list) => list).toList();
    for (final example in examples) {
      final printed = printer(example);
      expect(printed, contains(example.toString().substring(0, 1)));
    }
  });
}

void floatGroup(DataType type, int bits) {
  final name = 'float$bits';
  group('$name', () {
    test('name', () {
      expect(type.name, name);
      expect(type.toString(), 'DataType.$name');
    });
    test('nullable', () {
      expect(type.isNullable, isFalse);
      expect(type.nullValue, 0.0);
    });
    test('cast', () {
      expect(() => type.cast(null), throwsArgumentError);
      expect(type.cast(0), 0.0);
      expect(type.cast(1), 1.0);
      expect(type.cast(12.34), 12.34);
      expect(type.cast('123.45'), 123.45);
      expect(type.cast(BigInt.from(42)), 42.0);
      expect(type.cast(Fraction(1, 2)), 0.5);
      expect(() => type.cast('abc'), throwsArgumentError);
    });
    listTest(type, <List<double>>[
      [math.pi, math.e],
      [-0.750, 1.5, 0.375],
    ]);
    fieldTest(type, <double>[-0.75, 0.375, 1.5]);
  });
  group('$name.nullable', () {
    final nullableType = type.nullable;
    test('name', () {
      expect(nullableType.name, '$name.nullable');
      expect(nullableType.toString(), 'DataType.$name.nullable');
    });
    test('equality', () {
      final sameNullableType = type.nullable;
      expect(nullableType, sameNullableType);
      expect(nullableType.hashCode, sameNullableType.hashCode);
    });
    test('nullable', () {
      expect(nullableType.isNullable, isTrue);
      expect(nullableType.nullValue, isNull);
      expect(nullableType.nullable, nullableType);
    });
    test('cast', () {
      expect(nullableType.cast(null), isNull);
      expect(nullableType.cast(0), 0.0);
      expect(nullableType.cast(1), 1.0);
      expect(nullableType.cast(12.34), 12.34);
      expect(nullableType.cast('123.45'), 123.45);
      expect(nullableType.cast(BigInt.from(42)), 42.0);
      expect(nullableType.cast(Fraction(1, 2)), 0.5);
      expect(() => nullableType.cast('abc'), throwsArgumentError);
    });
    if (DataType.float64 == type) {
      listTest(nullableType, <List<double>>[
        [math.pi, null, math.e],
        [-1.1, 0.1, 1.1, null],
      ]);
    }
  });
}

void integerGroup(IntegerDataType type, bool isSigned, int bits) {
  final name = '${isSigned ? '' : 'u'}int$bits';
  group('$name', () {
    test('name', () {
      expect(type.name, name);
      expect(type.toString(), 'DataType.$name');
    });
    test('metadata', () {
      expect(type.isSigned, isSigned);
      expect(type.bits, bits);
    });
    test('min/max', () {
      if (type.isSigned) {
        expect(type.min, -math.pow(2, bits - 1));
        expect(type.max, math.pow(2, bits - 1) - 1);
      } else {
        expect(type.min, 0);
        expect(type.max, math.pow(2, bits) - 1);
      }
    });
    test('safe', () {
      if (type.bits <= 32) {
        expect(type.safeBits, type.bits);
        expect(type.safeMin, type.min);
        expect(type.safeMax, type.max);
      } else {
        expect(type.safeBits <= type.bits, isTrue);
        if (type.isSigned) {
          expect(type.safeMin, -math.pow(2, type.safeBits - 1));
          expect(type.safeMax, math.pow(2, type.safeBits - 1) - 1);
        } else {
          expect(type.safeMin, 0);
          expect(type.safeMax, math.pow(2, type.safeBits) - 1);
        }
      }
    });
    test('nullable', () {
      expect(type.isNullable, isFalse);
      expect(type.nullValue, 0);
    });
    test('cast', () {
      expect(() => type.cast(null), throwsArgumentError);
      expect(type.cast(0), 0);
      expect(type.cast(1), 1);
      expect(type.cast(12.34), 12);
      expect(type.cast('123'), 123);
      expect(type.cast(BigInt.from(123)), 123);
      expect(type.cast(Fraction(2, 1)), 2);
      if (isSigned) {
        expect(type.cast(-12.34), -12);
        expect(type.cast('-123'), -123);
        expect(type.cast(BigInt.from(-123)), -123);
        expect(type.cast(Fraction(-2, 1)), -2);
      }
      expect(() => type.cast('abc'), throwsArgumentError);
    });
    listTest(type, <List<int>>[
      [type.safeMin, 0, type.safeMax],
      [type.safeMin + 123, type.safeMax - 45, type.safeMax - 67],
    ]);
    fieldTest(type, <int>[-2, 5]);
  });
  group('$name.nullable', () {
    final nullableType = type.nullable;
    test('name', () {
      expect(nullableType.name, '$name.nullable');
      expect(nullableType.toString(), 'DataType.$name.nullable');
    });
    test('nullable', () {
      expect(nullableType.isNullable, isTrue);
      expect(nullableType.nullValue, isNull);
      expect(nullableType.nullable, nullableType);
    });
    test('cast', () {
      expect(nullableType.cast(null), isNull);
      expect(nullableType.cast(0), 0);
      expect(nullableType.cast(1), 1);
      expect(nullableType.cast(12.34), 12);
      expect(type.cast(BigInt.from(123)), 123);
      expect(type.cast(Fraction(2, 1)), 2);
      if (isSigned) {
        expect(type.cast(-12.34), -12);
        expect(type.cast('-123'), -123);
        expect(type.cast(BigInt.from(-123)), -123);
        expect(type.cast(Fraction(-2, 1)), -2);
      }
      expect(() => nullableType.cast('abc'), throwsArgumentError);
    });
    listTest(nullableType, <List<int>>[
      [type.safeMin, 0, null, type.safeMax, null],
      [type.safeMin + 123, type.safeMax - 45, null, type.safeMax - 67],
    ]);
  });
}

void fieldTest<T>(DataType<T> type, List<T> values) {
  const epsilon = 0.01;

  // equality functions
  final equality = type.equality;
  final isEqual = equality.isEqual;
  final isClose = equality.isClose;
  final hash = equality.hash;

  // field functions
  final field = type.field;
  final addId = field.additiveIdentity;
  final neg = field.neg;
  final add = field.add;
  final sub = field.sub;
  final mulId = field.multiplicativeIdentity;
  final mul = field.mul;
  final inv = field.inv;
  final scale = field.scale;
  final div = field.div;
  final mod = field.mod;
  final pow = field.pow;

  group('equality', () {
    test('isEqual', () {
      expect(isEqual(addId, mulId), isFalse);
      for (final value in values) {
        expect(isEqual(value, value), isTrue);
        expect(isEqual(value, addId), isFalse);
        expect(isEqual(value, mulId), isFalse);
      }
    });
    test('isClose', () {
      expect(isClose(addId, mulId, epsilon), isFalse);
      for (final value in values) {
        expect(isClose(value, value, epsilon), isTrue);
        expect(isClose(value, addId, epsilon), isFalse);
        expect(isClose(value, mulId, epsilon), isFalse);
      }
    });
    test('hash', () {
      expect(hash(addId), isNot(hash(mulId)));
      for (final value in values) {
        expect(hash(value), hash(value));
        expect(hash(value), isNot(hash(addId)));
        expect(hash(value), isNot(hash(mulId)));
      }
    });
  });
  if ([DataType.complex, DataType.quaternion, DataType.object].contains(type)) {
    test('no order', () {
      expect(() => type.order, throwsUnsupportedError);
    });
  } else {
    group('order', () {
      final order = type.order;
      final compare = order.compare;
      test('increasing', () {
        for (var i = 0; i < values.length - 1; i++) {
          expect(compare(values[i], values[i + 1]), lessThan(0),
              reason: 'Expected ${values[i]} < ${values[i + 1]}.');
        }
      });
      test('decreasing', () {
        for (var i = 0; i < values.length - 1; i++) {
          expect(compare(values[i + 1], values[i]), greaterThan(0),
              reason: 'Expected ${values[i]} > ${values[i + 1]}.');
        }
      });
      test('equal', () {
        for (var i = 0; i < values.length; i++) {
          expect(compare(values[i], values[i]), 0);
        }
      });
    });
  }
  group('field', () {
    test('neg', () {
      for (final value in values) {
        expect(isEqual(neg(neg(value)), value), isTrue);
        expect(isEqual(sub(addId, value), neg(value)), isTrue);
      }
    });
    test('add', () {
      for (final value in values) {
        expect(isEqual(add(value, addId), value), isTrue);
        expect(isEqual(add(addId, value), value), isTrue);
        expect(isEqual(add(value, neg(value)), addId), isTrue);
      }
    });
    test('sub', () {
      for (final value in values) {
        expect(isEqual(sub(value, addId), value), isTrue);
        expect(isEqual(sub(addId, value), neg(value)), isTrue);
        expect(isEqual(sub(addId, neg(value)), value), isTrue);
      }
    });
    if ([
      DataType.numeric,
      DataType.float32,
      DataType.float64,
      DataType.complex,
      DataType.quaternion,
      DataType.fraction,
    ].contains(type)) {
      test('inv', () {
        expect(isClose(inv(mulId), mulId, epsilon), isTrue);
        for (final value in values) {
          expect(isClose(inv(inv(value)), value, epsilon), isTrue);
        }
      });
      test('mul', () {
        expect(isClose(mul(mulId, mulId), mulId, epsilon), isTrue);
        for (final value in values) {
          expect(isClose(mul(value, inv(value)), mulId, epsilon), isTrue);
        }
      });
      test('div', () {
        for (final value in values) {
          expect(isClose(div(value, value), mulId, epsilon), isTrue);
        }
      });
    }
    test('scale', () {
      for (final value in values) {
        expect(isClose(scale(value, 2), add(value, value), epsilon), isTrue);
      }
    });
    if ([
      DataType.int8,
      DataType.int16,
      DataType.int32,
      DataType.int64,
      DataType.uint8,
      DataType.uint16,
      DataType.uint32,
      DataType.uint64,
      DataType.bigInt,
    ].contains(type)) {
      test('inv', () {
        expect(inv(mulId), mulId);
        for (final value in values) {
          expect(inv(value), addId);
        }
      });
      test('mul', () {
        expect(mul(mulId, mulId), mulId);
        for (final value in values) {
          expect(mul(value, mulId), value);
          expect(mul(mulId, value), value);
        }
      });
      test('div', () {
        for (final value in values) {
          expect(div(value, value), mulId);
          expect(div(value, mulId), value);
        }
      });
    }
    test('mod', () {
      for (final value in values) {
        if ([
          DataType.int8,
          DataType.int16,
          DataType.int32,
          DataType.int64,
          DataType.uint8,
          DataType.uint16,
          DataType.uint32,
          DataType.uint64,
          DataType.bigInt,
        ].contains(type)) {
          expect(isClose(mod(value, mulId), addId, epsilon), isTrue);
          expect(isClose(mod(value, value), addId, epsilon), isTrue);
        } else if ([
          DataType.numeric,
          DataType.float32,
          DataType.float64,
        ].contains(type)) {
          expect(isClose(mod(value, mulId), addId, 1), isTrue);
          expect(isClose(mod(value, value), addId, 1), isTrue);
        } else {
          expect(() => mod(value, mulId), throwsUnsupportedError);
        }
      }
    });
    test('pow', () {
      for (final value in values) {
        if (![DataType.quaternion].contains(type)) {
          expect(isClose(pow(value, addId), mulId, epsilon), isTrue);
        }
        expect(isClose(pow(value, mulId), value, epsilon), isTrue);
      }
    });
  });
}

void main() {
  group('object', () {
    const type = DataType.object;
    test('name', () {
      expect(type.name, 'object');
      expect(type.toString(), 'DataType.object');
    });
    test('nullable', () {
      expect(type.isNullable, isTrue);
      expect(type.nullValue, isNull);
      expect(type.nullable, type);
    });
    test('cast', () {
      expect(type.cast(null), isNull);
      expect(type.cast(123), 123);
      expect(type.cast('foo'), 'foo');
      expect(type.cast(true), true);
    });
    test('equality', () {
      final equality = type.equality;
      expect(equality.isEqual('foo', 'foo'), isTrue);
      expect(equality.isEqual('foo', 'bar'), isFalse);
      expect(equality.hash('foo'), 'foo'.hashCode);
      expect(equality.isClose('foo', 'foo', 0), isTrue);
      expect(equality.isClose('foo', 'bar', 0), isFalse);
    });
    test('field', () {
      expect(() => type.field, throwsUnsupportedError);
    });
    test('order', () {
      expect(() => type.order, throwsUnsupportedError);
    });
    listTest(type, <List<Object>>[
      [],
      [Uri.parse('https://lukas-renggli.ch/')],
      [1, true],
      ['abc', 123],
    ]);
  });
  group('string', () {
    const type = DataType.string;
    test('name', () {
      expect(type.name, 'string');
      expect(type.toString(), 'DataType.string');
    });
    test('nullable', () {
      expect(type.isNullable, isTrue);
      expect(type.nullValue, isNull);
      expect(type.nullable, type);
    });
    test('cast', () {
      expect(type.cast(null), isNull);
      expect(type.cast(123), '123');
      expect(type.cast(BigInt.from(123)), '123');
      expect(type.cast('foo'), 'foo');
      expect(type.cast(true), 'true');
    });
    test('equality', () {
      final equality = type.equality;
      expect(equality.isEqual('bar', 'bar'), isTrue);
      expect(equality.isEqual('bar', 'baz'), isFalse);
      expect(equality.hash('bar'), 'bar'.hashCode);
      expect(equality.isClose('bar', 'bar', 1), isTrue);
      expect(equality.isClose('bar', 'ba', 2), isTrue);
      expect(equality.isClose('ba', 'bar', 2), isTrue);
      expect(equality.isClose('bar', 'barr', 2), isTrue);
      expect(equality.isClose('barr', 'bar', 2), isTrue);
      expect(equality.isClose('bar', 'baz', 2), isTrue);
      expect(equality.isClose('foo', 'fuz', 2), isFalse);
    });
    test('field', () {
      expect(() => type.field, throwsUnsupportedError);
    });
    test('order', () {
      expect(type.order.compare('foo', 'bar'), greaterThan(0));
      expect(type.order.compare('bar', 'foo'), lessThan(0));
      expect(type.order.compare('foo', 'foo'), 0);
    });
    listTest(type, <List<String>>[
      ['abc'],
      ['abc', null],
      ['abc', 'def'],
    ]);
  });
  group('numeric', () {
    const type = DataType.numeric;
    test('name', () {
      expect(type.name, 'numeric');
      expect(type.toString(), 'DataType.numeric');
    });
    test('nullable', () {
      expect(type.isNullable, isTrue);
      expect(type.nullValue, isNull);
      expect(type.nullable, type);
    });
    test('cast', () {
      expect(type.cast(null), isNull);
      expect(type.cast(123), 123);
      expect(type.cast(12.3), 12.3);
      expect(type.cast('123'), 123);
      expect(type.cast('123.4'), 123.4);
      expect(type.cast(BigInt.from(123)), 123);
      expect(type.cast(Fraction(1, 2)), 0.5);
      expect(() => type.cast('abc'), throwsArgumentError);
      expect(() => type.cast(const Symbol('bad')), throwsArgumentError);
    });
    listTest(type, <List<num>>[
      [1, 2.3],
      [1, 2.3, null],
    ]);
    fieldTest(type, [-2, 2.3]);
  });
  group('boolean', () {
    const type = DataType.boolean;
    test('name', () {
      expect(type.name, 'boolean');
      expect(type.toString(), 'DataType.boolean');
    });
    test('nullable', () {
      expect(type.isNullable, isFalse);
      expect(type.nullValue, false);
    });
    test('cast', () {
      expect(() => type.cast(null), throwsArgumentError);
      expect(type.cast(true), isTrue);
      expect(type.cast(false), isFalse);
      expect(type.cast('true'), isTrue);
      expect(type.cast('false'), isFalse);
      expect(type.cast(1), isTrue);
      expect(type.cast(2), isTrue);
      expect(type.cast(0), isFalse);
      expect(() => type.cast('abc'), throwsArgumentError);
    });
    listTest(type, <List<bool>>[
      [true],
      [true, false],
    ]);
  });
  group('boolean.nullable', () {
    final type = DataType.boolean.nullable;
    test('name', () {
      expect(type.name, 'boolean.nullable');
      expect(type.toString(), 'DataType.boolean.nullable');
    });
    test('nullable', () {
      expect(type.isNullable, isTrue);
      expect(type.nullValue, isNull);
      expect(type.nullable, type);
    });
    test('cast', () {
      expect(type.cast(null), isNull);
      expect(type.cast(true), isTrue);
      expect(type.cast(false), isFalse);
      expect(type.cast('true'), isTrue);
      expect(type.cast('false'), isFalse);
      expect(type.cast(1), isTrue);
      expect(type.cast(2), isTrue);
      expect(type.cast(0), isFalse);
      expect(() => type.cast('abc'), throwsArgumentError);
    });
    listTest(type, <List<bool>>[
      [true, null],
      [true, false, null],
    ]);
  });
  integerGroup(DataType.int8, true, 8);
  integerGroup(DataType.uint8, false, 8);
  integerGroup(DataType.int16, true, 16);
  integerGroup(DataType.uint16, false, 16);
  integerGroup(DataType.int32, true, 32);
  integerGroup(DataType.uint32, false, 32);
  if (!config.isJavaScript) {
    /// int64 and uint64 are only supported in VM
    integerGroup(DataType.int64, true, 64);
    integerGroup(DataType.uint64, false, 64);
  }
  floatGroup(DataType.float32, 32);
  floatGroup(DataType.float64, 64);

  group('bigInt', () {
    const type = DataType.bigInt;
    test('name', () {
      expect(type.name, 'bigInt');
      expect(type.toString(), 'DataType.bigInt');
    });
    test('nullable', () {
      expect(type.isNullable, isTrue);
      expect(type.nullValue, null);
    });
    test('cast', () {
      expect(type.cast(null), isNull);
      expect(type.cast(BigInt.from(11)), BigInt.from(11));
      expect(type.cast(42), BigInt.from(42));
      expect(type.cast(3.14), BigInt.from(3));
      expect(type.cast('-123456789'), BigInt.from(-123456789));
      expect(() => type.cast(''), throwsArgumentError);
      expect(() => type.cast(const Symbol('bad')), throwsArgumentError);
    });
    fieldTest(type, [
      BigInt.from(-42),
      BigInt.from(35),
    ]);
  });
  group('fraction', () {
    const type = DataType.fraction;
    test('name', () {
      expect(type.name, 'fraction');
      expect(type.toString(), 'DataType.fraction');
    });
    test('nullable', () {
      expect(type.isNullable, isTrue);
      expect(type.nullValue, null);
    });
    test('cast', () {
      expect(type.cast(null), isNull);
      expect(type.cast(Fraction(1, 2)), Fraction(1, 2));
      expect(type.cast(BigInt.from(123)), Fraction(123, 1));
      expect(type.cast(2), Fraction(2));
      expect(type.cast(0.5), Fraction(1, 2));
      expect(type.cast('1/2'), Fraction(1, 2));
      expect(() => type.cast(''), throwsArgumentError);
      expect(() => type.cast(const Symbol('bad')), throwsArgumentError);
    });
    fieldTest(type, [
      Fraction(5, -6),
      Fraction(-3, 4),
      Fraction(1, 2),
    ]);
  });
  group('complex', () {
    const type = DataType.complex;
    test('name', () {
      expect(type.name, 'complex');
      expect(type.toString(), 'DataType.complex');
    });
    test('nullable', () {
      expect(type.isNullable, isTrue);
      expect(type.nullValue, null);
    });
    test('cast', () {
      expect(type.cast(null), isNull);
      expect(type.cast(const Complex(1, 2)), const Complex(1, 2));
      expect(type.cast(2), const Complex(2));
      expect(type.cast(0.5), const Complex(0.5));
      expect(type.cast(BigInt.from(123)), const Complex(123));
      expect(type.cast(Fraction(1, 2)), const Complex(0.5));
      expect(type.cast('1+2i'), const Complex(1, 2));
      expect(() => type.cast(''), throwsArgumentError);
      expect(() => type.cast(const Symbol('bad')), throwsArgumentError);
    });
    fieldTest(type, [
      const Complex(1, 2),
      const Complex(-3, 4),
      const Complex(5, -6),
    ]);
  });
  group('quaternion', () {
    const type = DataType.quaternion;
    test('name', () {
      expect(type.name, 'quaternion');
      expect(type.toString(), 'DataType.quaternion');
    });
    test('nullable', () {
      expect(type.isNullable, isTrue);
      expect(type.nullValue, null);
    });
    test('cast', () {
      expect(type.cast(null), isNull);
      expect(type.cast(const Quaternion(1, 2, 3, 4)),
          const Quaternion(1, 2, 3, 4));
      expect(type.cast(2), const Quaternion(2));
      expect(type.cast(0.5), const Quaternion(0.5));
      expect(type.cast(BigInt.from(123)), const Quaternion(123));
      expect(type.cast(Fraction(1, 2)), const Quaternion(0.5));
      expect(type.cast(const Complex(1, 2)), const Quaternion(1, 2));
      expect(type.cast('1+2i+3j+4k'), const Quaternion(1, 2, 3, 4));
      expect(() => type.cast(''), throwsArgumentError);
      expect(() => type.cast(const Symbol('bad')), throwsArgumentError);
    });
    fieldTest(type, [
      const Quaternion(1, 2, 3, 4),
      const Quaternion(-3, 5, -7, 9),
    ]);
  });
}
