library data.test.type;

import 'dart:math' as math;

import 'package:data/type.dart';
import 'package:test/test.dart';

void convertListTest(DataType type, List<List> lists) {
  for (var list in lists) {
    test('convertList: $list', () {
      if (type != DataType.FLOAT_32) {
        expect(DataType.fromIterable(list), type,
            reason: 'new DataType.fromIterable($list)');
      }
      expect(type.convertList(list), list, reason: '$type.convertList($list)');
    });
  }
}

void floatGroup(DataType type, int bits) {
  final name = 'FLOAT_$bits';
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
    if (DataType.FLOAT_64 == type) {
      convertListTest(type, <List<double>>[
        <double>[math.pi, math.e],
        <double>[-1.0, 0.0, 1.1],
      ]);
    }
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
      expect(nullableType.convert(0), 0.0);
      expect(nullableType.convert(1), 1.0);
      expect(nullableType.convert(12.34), 12.34);
      expect(nullableType.convert('123.45'), 123.45);
      expect(() => nullableType.convert('abc'), throwsArgumentError);
    });
    if (DataType.FLOAT_64 == type) {
      convertListTest(nullableType, <List<double>>[
        [math.pi, null, math.e],
        [-1.0, 0.0, 1.1, null],
      ]);
    }
  });
}

void integerGroup(IntegerDataType type, bool isSigned, int bits) {
  final name = '${isSigned ? '' : 'U'}INT_$bits';
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
        if (type != DataType.UINT_64) {
          expect(type.max, math.pow(2, bits) - 1);
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
    convertListTest(type, <List<int>>[
      [type.min, 0, type.max],
      [type.min + 123, type.max - 45, type.max - 67],
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
    convertListTest(nullableType, <List<int>>[
      [type.min, 0, null, type.max, null],
      [type.min + 123, type.max - 45, null, type.max - 67],
    ]);
  });
}

void main() {
  group('OBJECT', () {
    final type = DataType.OBJECT;
    test('name', () {
      expect(type.name, 'OBJECT');
      expect(type.toString(), 'DataType.OBJECT');
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
    convertListTest(type, <List<Object>>[
      [],
      [type],
      [1, true],
      ['abc', 123],
    ]);
  });
  group('STRING', () {
    final type = DataType.STRING;
    test('name', () {
      expect(type.name, 'STRING');
      expect(type.toString(), 'DataType.STRING');
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
    convertListTest(type, <List<String>>[
      ['abc'],
      ['abc', null],
      ['abc', 'def'],
    ]);
  });
  group('NUMERIC', () {
    final type = DataType.NUMERIC;
    test('name', () {
      expect(type.name, 'NUMERIC');
      expect(type.toString(), 'DataType.NUMERIC');
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
    convertListTest(type, <List<num>>[
      [1, 2.3],
      [1, 2.3, null],
    ]);
  });
  group('BOOLEAN', () {
    final type = DataType.BOOLEAN;
    test('name', () {
      expect(type.name, 'BOOLEAN');
      expect(type.toString(), 'DataType.BOOLEAN');
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
    convertListTest(type, <List<bool>>[
      [true],
      [true, false],
    ]);
  });
  group('BOOLEAN.nullable', () {
    final type = DataType.BOOLEAN.nullable;
    test('name', () {
      expect(type.name, 'BOOLEAN.nullable');
      expect(type.toString(), 'DataType.BOOLEAN.nullable');
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
    convertListTest(type, <List<bool>>[
      [true, null],
      [true, false, null],
    ]);
  });
  integerGroup(DataType.INT_8, true, 8);
  integerGroup(DataType.UINT_8, false, 8);
  integerGroup(DataType.INT_16, true, 16);
  integerGroup(DataType.UINT_16, false, 16);
  integerGroup(DataType.INT_32, true, 32);
  integerGroup(DataType.UINT_32, false, 32);
  integerGroup(DataType.INT_64, true, 64);
  integerGroup(DataType.UINT_64, false, 64);
  floatGroup(DataType.FLOAT_32, 32);
  floatGroup(DataType.FLOAT_64, 64);
}
