library data.test.type;

import 'dart:math' as math;

import 'package:data/src/shared/config.dart' as config;
import 'package:data/type.dart';
import 'package:test/test.dart';

void listTest(DataType type, List<List> lists) {
  if ([
    DataType.float64,
    DataType.int64,
    DataType.boolean,
    DataType.string,
    DataType.object,
  ].contains(type)) {
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
  if (type != DataType.float32) {
    for (var list in lists) {
      test('fromIterable: $list', () {
        expect(DataType.fromIterable(list), type,
            reason: 'DataType.fromIterable($list)');
      });
      test('convertList: $list', () {
        expect(type.convertList(list), list,
            reason: '$type.convertList($list)');
      });
    }
  }
  final example = lists.last;
  test('copyList', () {
    final copy = type.copyList(example);
    expect(copy, example);
  });
  test('copyList (smaller)', () {
    final copy = type.copyList(example, length: example.length - 1);
    expect(copy.length, example.length - 1);
    expect(copy, example.getRange(0, example.length - 1));
  });
  test('copyList (larger)', () {
    final copy = type.copyList(example, length: example.length + 5);
    expect(copy.length, example.length + 5);
    expect(copy.getRange(0, example.length), example);
    expect(copy.getRange(example.length, copy.length),
        List.filled(5, type.nullValue));
  });
  test('copyList (larger, with custom fill)', () {
    final copy = type.copyList(example,
        length: example.length + 5, fillValue: example[0]);
    expect(copy.length, example.length + 5);
    expect(copy.getRange(0, example.length), example);
    expect(
        copy.getRange(example.length, copy.length), List.filled(5, example[0]));
  });
  test('printer', () {
    final printer = type.printer;
    final examples = lists.expand((list) => list).toList();
    for (var example in examples) {
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
    test('convert', () {
      expect(() => type.convert(null), throwsArgumentError);
      expect(type.convert(0), 0.0);
      expect(type.convert(1), 1.0);
      expect(type.convert(12.34), 12.34);
      expect(type.convert('123.45'), 123.45);
      expect(() => type.convert('abc'), throwsArgumentError);
    });
    listTest(type, <List<double>>[
      [math.pi, math.e],
      [-0.750, 1.5, 0.375],
    ]);
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
    test('convert', () {
      expect(nullableType.convert(null), isNull);
      expect(nullableType.convert(0), 0.0);
      expect(nullableType.convert(1), 1.0);
      expect(nullableType.convert(12.34), 12.34);
      expect(nullableType.convert('123.45'), 123.45);
      expect(() => nullableType.convert('abc'), throwsArgumentError);
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
      expect(type.bits, bits);
      expect(type.isSigned, isSigned);
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
    test('convert', () {
      expect(() => type.convert(null), throwsArgumentError);
      expect(type.convert(0), 0);
      expect(type.convert(1), 1);
      expect(type.convert(12.34), 12);
      expect(type.convert('123'), 123);
      if (isSigned) {
        expect(type.convert(-12.34), -12);
        expect(type.convert('-123'), -123);
      }
      expect(() => type.convert('abc'), throwsArgumentError);
    });
    listTest(type, <List<int>>[
      [type.safeMin, 0, type.safeMax],
      [type.safeMin + 123, type.safeMax - 45, type.safeMax - 67],
    ]);
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
    test('convert', () {
      expect(nullableType.convert(null), isNull);
      expect(nullableType.convert(0), 0);
      expect(nullableType.convert(1), 1);
      expect(nullableType.convert(12.34), 12);
      if (isSigned) {
        expect(type.convert(-12.34), -12);
        expect(type.convert('-123'), -123);
      }
      expect(() => nullableType.convert('abc'), throwsArgumentError);
    });
    listTest(nullableType, <List<int>>[
      [type.safeMin, 0, null, type.safeMax, null],
      [type.safeMin + 123, type.safeMax - 45, null, type.safeMax - 67],
    ]);
  });
}

void main() {
  group('object', () {
    final type = DataType.object;
    test('name', () {
      expect(type.name, 'object');
      expect(type.toString(), 'DataType.object');
    });
    test('nullable', () {
      expect(type.isNullable, isTrue);
      expect(type.nullValue, isNull);
      expect(type.nullable, type);
    });
    test('convert', () {
      expect(type.convert(null), isNull);
      expect(type.convert(123), 123);
      expect(type.convert('foo'), 'foo');
      expect(type.convert(true), true);
    });
    listTest(type, <List<Object>>[
      [],
      [Uri.parse('https://lukas-renggli.ch/')],
      [1, true],
      ['abc', 123],
    ]);
  });
  group('string', () {
    final type = DataType.string;
    test('name', () {
      expect(type.name, 'string');
      expect(type.toString(), 'DataType.string');
    });
    test('nullable', () {
      expect(type.isNullable, isTrue);
      expect(type.nullValue, isNull);
      expect(type.nullable, type);
    });
    test('convert', () {
      expect(type.convert(null), isNull);
      expect(type.convert(123), '123');
      expect(type.convert('foo'), 'foo');
      expect(type.convert(true), 'true');
    });
    listTest(type, <List<String>>[
      ['abc'],
      ['abc', null],
      ['abc', 'def'],
    ]);
  });
  group('numeric', () {
    final type = DataType.numeric;
    test('name', () {
      expect(type.name, 'numeric');
      expect(type.toString(), 'DataType.numeric');
    });
    test('nullable', () {
      expect(type.isNullable, isTrue);
      expect(type.nullValue, isNull);
      expect(type.nullable, type);
    });
    test('convert', () {
      expect(type.convert(null), isNull);
      expect(type.convert(123), 123);
      expect(type.convert(12.3), 12.3);
      expect(type.convert('123'), 123);
      expect(type.convert('123.4'), 123.4);
      expect(() => type.convert('abc'), throwsArgumentError);
    });
    listTest(type, <List<num>>[
      [1, 2.3],
      [1, 2.3, null],
    ]);
  });
  group('boolean', () {
    final type = DataType.boolean;
    test('name', () {
      expect(type.name, 'boolean');
      expect(type.toString(), 'DataType.boolean');
    });
    test('nullable', () {
      expect(type.isNullable, isFalse);
      expect(type.nullValue, false);
    });
    test('convert', () {
      expect(() => type.convert(null), throwsArgumentError);
      expect(type.convert(true), isTrue);
      expect(type.convert(false), isFalse);
      expect(type.convert('true'), isTrue);
      expect(type.convert('false'), isFalse);
      expect(type.convert(1), isTrue);
      expect(type.convert(2), isTrue);
      expect(type.convert(0), isFalse);
      expect(() => type.convert('abc'), throwsArgumentError);
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
    test('convert', () {
      expect(type.convert(null), isNull);
      expect(type.convert(true), isTrue);
      expect(type.convert(false), isFalse);
      expect(type.convert('true'), isTrue);
      expect(type.convert('false'), isFalse);
      expect(type.convert(1), isTrue);
      expect(type.convert(2), isTrue);
      expect(type.convert(0), isFalse);
      expect(() => type.convert('abc'), throwsArgumentError);
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
}
