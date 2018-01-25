library pandas.test.pandas_test;

import 'package:pandas/pandas.dart';
import 'package:pandas/src/type/integer.dart' show IntegerDataType;

import 'package:test/test.dart';

import 'dart:math' as Math;

void main() {
//  group('index', () {
//    group('range', () {
//      test('range', () {
//        var index = new RangeIndex(name: 'foo', start: 5, stop: 10);
//        print('Labels: ${index.labels.toList()}');
//        print('Indexes: ${index.indexes.toList()}');
//      });
//      test('range -1', () {
//        var index = new RangeIndex(name: 'foo', start: 10, stop: 5, step: -1);
//        print('Labels: ${index.labels.toList()}');
//        print('Indexes: ${index.indexes.toList()}');
//      });
//    });
//  });
  group('Series', () {
    test('new Series.empty', () {
      var series = new Series.empty();
      expect(series.name, '');
      expect(series.values, isEmpty);
      expect(series.type, DataType.OBJECT);
    });
    test('new Series.fromIterable()', () {
      var series = new Series.fromIterable([5, 4, 0, 3, 4]);
      expect(series.name, '');
      expect(series.values, [5, 4, 0, 3, 4]);
      expect(series.type, DataType.UINT_8);
    });
//    test('from iterable with index', () {
//      var series = new Series.fromIterable([5, 4, 0, 3, 4], index: ['a', 'b', 'c', 'd', 'e']);
//      print(series);
//    });
//    test('from map', () {
//      var series = new Series.fromMap({'a': 0, 'b': 1, 'c': 2});
//      print(series);
//    });
//    test('from map with index', () {
//      var series = new Series.fromMap({'a': 0, 'b': 1, 'c': 2}, index: ['b', 'c', 'd', 'a']);
//      print(series);
//    });
  });
  group('DataType', () {
    convertListTest(DataType type, List<List> lists) {
      for (List list in lists) {
        test('convertList: $list', () {
          if (type != DataType.FLOAT_32) {
            expect(new DataType.fromIterable(list), type,
                reason: 'new DataType.fromIterable($list)');
          }
          expect(type.convertList(list), list, reason: '$type.convertList($list)');
        });
      }
    }

    group('OBJECT', () {
      var type = DataType.OBJECT;
      test('name', () {
        expect(type.name, 'OBJECT');
        expect(type.toString(), 'DataType.OBJECT');
      });
      test('nullable', () {
        expect(type.isNullable, isTrue);
        expect(type.nullable, type);
      });
      test('convert', () {
        expect(type.convert(null), isNull);
        expect(type.convert(123), 123);
        expect(type.convert('foo'), 'foo');
        expect(type.convert(true), true);
      });
      convertListTest(type, [
        [],
        [type],
        [1, true],
        ['abc', 123],
      ]);
    });
    group('STRING', () {
      var type = DataType.STRING;
      test('name', () {
        expect(type.name, 'STRING');
        expect(type.toString(), 'DataType.STRING');
      });
      test('nullable', () {
        expect(type.isNullable, isTrue);
        expect(type.nullable, type);
      });
      test('convert', () {
        expect(type.convert(null), isNull);
        expect(type.convert(123), '123');
        expect(type.convert('foo'), 'foo');
        expect(type.convert(true), 'true');
      });
      convertListTest(type, [
        ['abc'],
        ['abc', null],
        ['abc', 'def'],
      ]);
    });
    group('NUMERIC', () {
      var type = DataType.NUMERIC;
      test('name', () {
        expect(type.name, 'NUMERIC');
        expect(type.toString(), 'DataType.NUMERIC');
      });
      test('nullable', () {
        expect(type.isNullable, isTrue);
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
      convertListTest(type, [
        [1, 2.3],
        [1, 2.3, null],
      ]);
    });
    group('BOOLEAN', () {
      var type = DataType.BOOLEAN;
      test('name', () {
        expect(type.name, 'BOOLEAN');
        expect(type.toString(), 'DataType.BOOLEAN');
      });
      test('nullable', () {
        expect(type.isNullable, isFalse);
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
      convertListTest(type, [
        [true],
        [true, false],
      ]);
    });
    group('BOOLEAN.nullable', () {
      var type = DataType.BOOLEAN.nullable;
      test('name', () {
        expect(type.name, 'BOOLEAN.nullable');
        expect(type.toString(), 'DataType.BOOLEAN.nullable');
      });
      test('nullable', () {
        expect(type.isNullable, isTrue);
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
      convertListTest(type, [
        [true, null],
        [true, false, null],
      ]);
    });
    integerGroup(IntegerDataType type, bool isSigned, int bits) {
      var name = '${isSigned ? '' : 'U'}INT_${bits}';
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
            expect(type.min, -Math.pow(2, bits - 1));
            expect(type.max, Math.pow(2, bits - 1) - 1);
          } else {
            expect(type.min, 0);
            expect(type.max, Math.pow(2, bits) - 1);
          }
        });
        test('nullable', () {
          expect(type.isNullable, isFalse);
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
        convertListTest(type, [
          [type.min, 0, type.max],
          [type.min + 123, type.max - 45, type.max - 67],
        ]);
      });
      group('$name.nullable', () {
        var nullableType = type.nullable;
        test('name', () {
          expect(nullableType.name, '$name.nullable');
          expect(nullableType.toString(), 'DataType.$name.nullable');
        });
        test('nullable', () {
          expect(nullableType.isNullable, isTrue);
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
        convertListTest(nullableType, [
          [type.min, 0, null, type.max, null],
          [type.min + 123, type.max - 45, null, type.max - 67],
        ]);
      });
    }

    integerGroup(DataType.INT_8, true, 8);
    integerGroup(DataType.UINT_8, false, 8);
    integerGroup(DataType.INT_16, true, 16);
    integerGroup(DataType.UINT_16, false, 16);
    integerGroup(DataType.INT_32, true, 32);
    integerGroup(DataType.UINT_32, false, 32);
    integerGroup(DataType.INT_64, true, 64);
    integerGroup(DataType.UINT_64, false, 64);

    floatGroup(DataType type, int bits) {
      var name = 'FLOAT_$bits';
      group('$name', () {
        test('name', () {
          expect(type.name, name);
          expect(type.toString(), 'DataType.$name');
        });
        test('nullable', () {
          expect(type.isNullable, isFalse);
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
          convertListTest(type, [
            <double>[Math.PI, Math.E],
            <double>[-1.0, 0.0, 1.1],
          ]);
        }
      });
      group('$name.nullable', () {
        var nullableType = type.nullable;
        test('name', () {
          expect(nullableType.name, '$name.nullable');
          expect(nullableType.toString(), 'DataType.$name.nullable');
        });
        test('nullable', () {
          expect(nullableType.isNullable, isTrue);
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
          convertListTest(nullableType, [
            [Math.PI, null, Math.E],
            [-1.0, 0.0, 1.1, null],
          ]);
        }
      });
    }

    floatGroup(DataType.FLOAT_32, 32);
    floatGroup(DataType.FLOAT_64, 64);
  });
}
