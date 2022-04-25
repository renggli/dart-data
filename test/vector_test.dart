import 'dart:math';

import 'package:data/data.dart';
import 'package:data/src/shared/config.dart' as config;
import 'package:test/test.dart';

void vectorTest(String name, VectorFormat format) {
  group(name, () {
    group('constructor', () {
      test('empty', () {
        final vector = Vector(DataType.int8, 0, format: format);
        expect(vector.dataType, DataType.int8);
        expect(vector.count, 0);
        expect(vector.storage, [vector]);
        expect(vector.shape, [vector.count]);
      });
      test('default', () {
        final vector = Vector(DataType.int8, 4, format: format);
        expect(vector.dataType, DataType.int8);
        expect(vector.count, 4);
        expect(vector.shape, [vector.count]);
        expect(vector.storage, [vector]);
        for (var i = 0; i < vector.count; i++) {
          expect(vector[i], 0);
        }
      });
      test('default with error', () {
        expect(
            () => Vector(DataType.int8, -4, format: format), throwsRangeError);
      });
      group('concat', () {
        final a = Vector.fromList(DataType.int8, [0, 1, 2], format: format);
        final b = Vector.fromList(DataType.int8, [3, 4], format: format);
        final expected = Vector.generate(DataType.int8, 5, (i) => i);
        test('default', () {
          final result = Vector.concat(DataType.int8, [a, b]);
          expect(result.dataType, DataType.int8);
          expect(result.count, 5);
          expect(result.storage, {a, b});
          expect(result.copy().compare(result), isTrue);
          expect(result.compare(expected), isTrue);
        });
        test('write', () {
          final first = a.copy(), second = b.copy();
          final result = Vector.concat(DataType.int8, [first, second]);
          for (var i = 0; i < result.count; i++) {
            result[i] = -1;
          }
          expect(first.iterable, everyElement(-1));
          expect(second.iterable, everyElement(-1));
        });
        test('with format', () {
          final result = Vector.concat(DataType.int8, [a, b], format: format);
          expect(result.dataType, DataType.int8);
          expect(result.count, 5);
          expect(result.storage, [result]);
          expect(result.copy().compare(result), isTrue);
          expect(result.compare(expected), isTrue);
        });
        test('single', () {
          expect(Vector.concat(DataType.int8, [a]), a);
        });
        test('error', () {
          expect(() => Vector.concat(DataType.int8, []), throwsArgumentError);
        });
      });
      test('constant', () {
        final vector = Vector.constant(DataType.int8, 5);
        expect(vector.dataType, DataType.int8);
        expect(vector.count, 5);
        expect(vector.shape, [vector.count]);
        expect(vector.storage, [vector]);
        expect(vector.copy(), vector);
        for (var i = 0; i < vector.count; i++) {
          expect(vector[i], 0);
        }
        expect(() => vector[3] = 1, throwsUnsupportedError);
      });
      test('constant with value', () {
        final vector = Vector.constant(DataType.int8, 5, value: 1);
        expect(vector.dataType, DataType.int8);
        expect(vector.count, 5);
        expect(vector.shape, [vector.count]);
        expect(vector.storage, [vector]);
        expect(vector.copy(), vector);
        for (var i = 0; i < vector.count; i++) {
          expect(vector[i], 1);
        }
        expect(() => vector[3] = 1, throwsUnsupportedError);
      });
      test('constant with format', () {
        final vector = Vector.constant(DataType.int8, 5, format: format);
        expect(vector.dataType, DataType.int8);
        expect(vector.count, 5);
        expect(vector.shape, [vector.count]);
        expect(vector.storage, [vector]);
        for (var i = 0; i < vector.count; i++) {
          expect(vector[i], 0);
        }
        vector[3] = 1;
        expect(vector[3], 1);
      });
      test('generate', () {
        final vector = Vector.generate(DataType.string, 7, (i) => '$i');
        expect(vector.dataType, DataType.string);
        expect(vector.count, 7);
        expect(vector.shape, [vector.count]);
        expect(vector.storage, [vector]);
        expect(vector.copy(), vector);
        for (var i = 0; i < vector.count; i++) {
          expect(vector[i], '$i');
        }
        expect(() => vector[3] = '*', throwsUnsupportedError);
      });
      test('generate with format', () {
        final vector =
            Vector.generate(DataType.string, 7, (i) => '$i', format: format);
        expect(vector.dataType, DataType.string);
        expect(vector.count, 7);
        expect(vector.shape, [vector.count]);
        expect(vector.storage, [vector]);
        expect(vector.copy().compare(vector), isTrue);
        for (var i = 0; i < vector.count; i++) {
          expect(vector[i], '$i');
        }
        vector[3] = '*';
        expect(vector[3], '*');
      });
      test('fromList', () {
        final vector =
            Vector.fromList(DataType.int8, [2, 1, 3], format: format);
        expect(vector.dataType, DataType.int8);
        expect(vector.count, 3);
        expect(vector.shape, [vector.count]);
        expect(vector.storage, [vector]);
        expect(vector[0], 2);
        expect(vector[1], 1);
        expect(vector[2], 3);
      });
    });
    group('accessing', () {
      final vector = Vector.fromList(DataType.int8, [2, 4, 6], format: format);
      test('random', () {
        final vector = Vector(DataType.int8, 100, format: format);
        final values = <int>[];
        for (var i = 0; i < vector.count; i++) {
          values.add(i);
        }
        // add values
        values.shuffle();
        for (final value in values) {
          vector[value] = value;
        }
        for (var i = 0; i < vector.count; i++) {
          expect(vector[i], i);
        }
        // update values
        values.shuffle();
        for (final value in values) {
          vector[value] = value + 1;
        }
        for (var i = 0; i < vector.count; i++) {
          expect(vector[i], i + 1);
        }
        // remove values
        values.shuffle();
        for (final value in values) {
          vector[value] = vector.dataType.defaultValue;
        }
        for (var i = 0; i < vector.count; i++) {
          expect(vector[i], vector.dataType.defaultValue);
        }
      });
      test('read operator', () {
        expect(vector[0], 2);
        expect(vector[1], 4);
        expect(vector[2], 6);
      });
      test('write operator', () {
        final copy = Vector(vector.dataType, vector.count, format: format);
        for (var i = 0; i < vector.count; i++) {
          copy[i] = vector[i];
        }
        expect(copy.compare(vector), isTrue);
      });
      test('read with range error', () {
        final vector = Vector.fromList(DataType.int8, [1, 2], format: format);
        expect(() => vector[-1], throwsRangeError);
        expect(() => vector[vector.count], throwsRangeError);
      });
      test('write with range error', () {
        final vector = Vector.fromList(DataType.int8, [1, 2], format: format);
        expect(() => vector[-1] = 1, throwsRangeError);
        expect(() => vector[vector.count] = 1, throwsRangeError);
      });
      test('format', () {
        final vector =
            Vector.generate(DataType.int8, 100, (i) => i, format: format);
        expect(vector.format(), '0 1 2 … 97 98 99');
      });
      test('toString', () {
        final vector =
            Vector.fromList(DataType.int8, [3, 2, 1], format: format);
        expect(
            vector.toString(),
            '${vector.runtimeType}'
            '(dataType: int8, count: 3):\n'
            '3 2 1');
      });
    });
    group('view', () {
      test('copy', () {
        final source =
            Vector.generate(DataType.int32, 30, (i) => i, format: format);
        final copy = source.copy();
        expect(copy.dataType, source.dataType);
        expect(copy.count, source.count);
        expect(copy.storage, [copy]);
        for (var i = 0; i < source.count; i++) {
          source[i] = i.isEven ? 0 : -i;
          copy[i] = i.isEven ? -i : 0;
        }
        for (var i = 0; i < source.count; i++) {
          expect(source[i], i.isEven ? 0 : -i);
          expect(copy[i], i.isEven ? -i : 0);
        }
      });
      group('range', () {
        test('default', () {
          final source =
              Vector.generate(DataType.string, 6, (i) => '$i', format: format);
          final range = source.range(1, 4);
          expect(range.dataType, DataType.string);
          expect(range.count, 3);
          expect(range.storage, [source]);
          expect(range.copy().compare(range), isTrue);
          expect(range[0], '1');
          expect(range[1], '2');
          expect(range[2], '3');
          range[1] += '*';
          expect(range[1], '2*');
          expect(source[2], '2*');
        });
        test('full range', () {
          final source = Vector.fromList(DataType.int8, [1, 2], format: format);
          expect(source.range(0, source.count), source);
        });
        test('sub range', () {
          final source =
              Vector.generate(DataType.string, 6, (i) => '$i', format: format);
          final range = source.range(1, 4).range(1, 2);
          expect(range.dataType, DataType.string);
          expect(range.count, 1);
          expect(range.storage, [source]);
          expect(range[0], '2');
          range[0] += '*';
          expect(range[0], '2*');
          expect(source[2], '2*');
        });
        test('error', () {
          final source = Vector.fromList(DataType.int8, [1, 2], format: format);
          expect(source.range(0, source.count), source);
          expect(() => source.range(-1, source.count), throwsRangeError);
          expect(() => source.range(0, source.count + 1), throwsRangeError);
        });
      });
      group('index', () {
        test('default', () {
          final source =
              Vector.generate(DataType.string, 6, (i) => '$i', format: format);
          final index = source.index([3, 2, 2]);
          expect(index.dataType, DataType.string);
          expect(index.count, 3);
          expect(index.storage, [source]);
          expect(index.copy().compare(index), isTrue);
          expect(index[0], '3');
          expect(index[1], '2');
          expect(index[2], '2');
          index[1] += '*';
          expect(index[1], '2*');
          expect(source[2], '2*');
        });
        test('sub index', () {
          final source =
              Vector.generate(DataType.string, 6, (i) => '$i', format: format);
          final index = source.index([3, 2, 2]).index([1]);
          expect(index.dataType, DataType.string);
          expect(index.count, 1);
          expect(index.storage, [source]);
          expect(index[0], '2');
          index[0] += '*';
          expect(index[0], '2*');
          expect(source[2], '2*');
        });
        test('error', () {
          final source = Vector.fromList(DataType.int8, [1, 2], format: format);
          expect(() => source.index([0, 1]), isNot(throwsRangeError));
          expect(() => source.index([-1, source.count - 1]), throwsRangeError);
          expect(() => source.index([0, source.count]), throwsRangeError);
        });
      });
      group('list', () {
        test('view', () {
          final list = [1, 2, 3];
          final vector = list.toVector();
          expect(vector.dataType, config.intDataType);
          expect(vector.count, 3);
          expect(vector[0], 1);
          expect(vector[1], 2);
          expect(vector[2], 3);
          list
            ..add(4)
            ..removeAt(0)
            ..removeAt(0);
          expect(vector.count, 2);
          expect(vector[0], 3);
          expect(vector[1], 4);
          vector[1] = -4;
          expect(list, [3, -4]);
        });
        test('copy', () {
          final list = [1, 2, 3];
          final vector = list.toVector(format: format);
          expect(vector.dataType, config.intDataType);
          expect(vector.count, 3);
          expect(vector[0], 1);
          expect(vector[1], 2);
          expect(vector[2], 3);
          list
            ..add(4)
            ..removeAt(0)
            ..removeAt(0);
          expect(vector.count, 3);
          expect(vector[0], 1);
          expect(vector[1], 2);
          expect(vector[2], 3);
          vector[1] = -4;
          expect(list, [3, 4]);
        });
      });
      group('overlay', () {
        final base = Vector.generate(DataType.string, 8, (index) => '($index)',
            format: format);
        test('offset', () {
          final top = Vector.generate(DataType.string, 2, (index) => '[$index]',
              format: format);
          final composite = top.overlay(base, offset: 4);
          expect(composite.dataType, top.dataType);
          expect(composite.count, base.count);
          expect(composite.storage, unorderedMatches(<Vector>[base, top]));
          final copy = composite.copy();
          expect(copy.compare(composite), isTrue);
          for (var i = 0; i < composite.count; i++) {
            expect(composite[i], 4 <= i && i <= 5 ? '[${i - 4}]' : '($i)');
            copy[i] = '${copy[i]}*';
          }
        });
        test('mask', () {
          final top = Vector.generate(
              DataType.string, base.count, (index) => '[$index]',
              format: format);
          final mask = Vector.generate(
              DataType.boolean, base.count, (index) => index.isEven,
              format: format);
          final composite = top.overlay(base, mask: mask);
          expect(composite.dataType, top.dataType);
          expect(composite.count, base.count);
          expect(
              composite.storage, unorderedMatches(<Vector>[base, top, mask]));
          final copy = composite.copy();
          expect(copy.compare(composite), isTrue);
          for (var i = 0; i < composite.count; i++) {
            expect(composite[i], i.isEven ? '[$i]' : '($i)');
            copy[i] = '${copy[i]}*';
          }
        });
        test('errors', () {
          expect(() => base.overlay(base), throwsArgumentError);
          expect(
              () => base.overlay(
                  Vector.constant(DataType.string, base.count + 1,
                      value: '', format: format),
                  mask: Vector.constant(DataType.boolean, base.count,
                      value: true, format: format)),
              throwsArgumentError);
          expect(
              () => base.overlay(
                  Vector.constant(DataType.string, base.count,
                      value: '', format: format),
                  mask: Vector.constant(DataType.boolean, base.count + 1,
                      value: true, format: format)),
              throwsArgumentError);
        });
      });
      group('transform', () {
        final source =
            Vector.generate(DataType.int8, 4, (index) => index, format: format);
        test('to string', () {
          final mapped =
              source.map((index, value) => '$index', DataType.string);
          expect(mapped.dataType, DataType.string);
          expect(mapped.count, source.count);
          expect(mapped.storage, [source]);
          for (var i = 0; i < mapped.count; i++) {
            expect(mapped[i], '$i');
          }
        });
        test('to int', () {
          final mapped = source.map((index, value) => index, DataType.int32);
          expect(mapped.dataType, DataType.int32);
          expect(mapped.count, source.count);
          expect(mapped.storage, [source]);
          for (var i = 0; i < mapped.count; i++) {
            expect(mapped[i], i);
          }
        });
        test('to float', () {
          final mapped =
              source.map((index, value) => index.toDouble(), DataType.float64);
          expect(mapped.dataType, DataType.float64);
          expect(mapped.count, source.count);
          expect(mapped.storage, [source]);
          for (var i = 0; i < mapped.count; i++) {
            expect(mapped[i], i.toDouble());
          }
        });
        test('readonly', () {
          final mapped = source.map((index, value) => index, DataType.int32);
          expect(() => mapped.setUnchecked(0, 1), throwsUnsupportedError);
        });
        test('mutable', () {
          final source = Vector.generate(
              DataType.uint8, 6, (index) => index + 97,
              format: format);
          final transform = source.transform<String>(
            (index, value) => String.fromCharCode(value),
            write: (index, value) => value.codeUnitAt(0),
            dataType: DataType.string,
          );
          expect(transform.dataType, DataType.string);
          expect(transform.count, source.count);
          expect(transform.storage, [source]);
          for (var i = 0; i < transform.count; i++) {
            expect(transform[i], 'abcdef'[i]);
          }
          transform[2] = '*';
          expect(transform[2], '*');
          expect(source[2], 42);
        });
        test('copy', () {
          final mapped = source.map((index, value) => index, DataType.int32);
          expect(mapped.copy().compare(mapped), isTrue);
        });
      });
      group('cast', () {
        final source = Vector.generate(DataType.int32, 256, (index) => index,
            format: format);
        test('to string', () {
          final cast = source.cast(DataType.string);
          expect(cast.dataType, DataType.string);
          expect(cast.count, source.count);
          expect(cast.storage, [source]);
          for (var i = 0; i < cast.count; i++) {
            expect(cast[i], '$i');
            cast[i] = '-$i';
            expect(source[i], -i);
          }
        });
        test('copy', () {
          final cast = source.cast(DataType.int32);
          expect(cast.copy().compare(cast), isTrue);
        });
      });
      test('reversed', () {
        final source =
            Vector.fromList(DataType.int8, [1, 2, 3], format: format);
        final reversed = source.reversed;
        expect(reversed.dataType, source.dataType);
        expect(reversed.count, source.count);
        expect(reversed.storage, [source]);
        expect(reversed.reversed, same(source));
        expect(reversed.copy().compare(reversed), isTrue);
        for (var i = 0; i < source.count; i++) {
          expect(reversed[i], source[source.count - i - 1]);
        }
        reversed[1] = 42;
        expect(reversed[1], 42);
        expect(source[1], 42);
      });
      test('unmodifiable', () {
        final source = Vector.fromList(DataType.int8, [1, 2], format: format);
        final readonly = source.unmodifiable;
        expect(readonly.dataType, source.dataType);
        expect(readonly.count, source.count);
        expect(readonly.storage, [source]);
        expect(readonly.copy().compare(readonly), isTrue);
        for (var i = 0; i < source.count; i++) {
          expect(source[i], readonly[i]);
          expect(() => readonly[i] = 0, throwsUnsupportedError);
        }
        source[1] = 3;
        expect(readonly[1], 3);
        expect(readonly.unmodifiable, readonly);
      });
      group('matrix ', () {
        test('diagonal', () {
          final vector =
              Vector.generate(DataType.string, 10, (i) => '$i', format: format);
          final matrix = vector.diagonalMatrix;
          expect(matrix.dataType, vector.dataType);
          expect(matrix.rowCount, vector.count);
          expect(matrix.columnCount, vector.count);
          expect(matrix.storage, [vector]);
          expect(matrix.copy().compare(matrix), isTrue);
          for (var r = 0; r < matrix.rowCount; r++) {
            for (var c = 0; c < matrix.columnCount; c++) {
              if (r == c) {
                expect(matrix.get(r, c), '$r');
                matrix.set(r, c, '$r*');
              } else {
                expect(matrix.get(r, c), isEmpty);
                expect(() => matrix.set(r, c, '*'), throwsArgumentError);
              }
            }
          }
        });
        test('row', () {
          final vector =
              Vector.generate(DataType.string, 10, (i) => '$i', format: format);
          final matrix = vector.rowMatrix;
          expect(matrix.dataType, vector.dataType);
          expect(matrix.rowCount, 1);
          expect(matrix.columnCount, vector.count);
          expect(matrix.storage, [vector]);
          expect(matrix.copy().compare(matrix), isTrue);
          for (var c = 0; c < matrix.columnCount; c++) {
            expect(matrix.get(0, c), '$c');
            matrix.set(0, c, '$c*');
            expect(vector[c], '$c*');
          }
        });
        test('column', () {
          final vector =
              Vector.generate(DataType.string, 10, (i) => '$i', format: format);
          final matrix = vector.columnMatrix;
          expect(matrix.dataType, vector.dataType);
          expect(matrix.rowCount, vector.count);
          expect(matrix.columnCount, 1);
          expect(matrix.storage, [vector]);
          expect(matrix.copy().compare(matrix), isTrue);
          for (var r = 0; r < matrix.rowCount; r++) {
            expect(matrix.get(r, 0), '$r');
            matrix.set(r, 0, '$r*');
            expect(vector[r], '$r*');
          }
        });
      });
      group('toList', () {
        test('default', () {
          final vector =
              Vector.generate(DataType.string, 10, (i) => '$i', format: format);
          final list = vector.toList();
          expect(list.length, vector.count);
          for (var i = 0; i < list.length; i++) {
            expect(list[i], '$i');
            list[i] = '$i*';
            expect(vector[i], '$i*');
          }
          expect(() => list.add('*'), throwsUnsupportedError);
        });
        test('growable', () {
          final vector =
              Vector.generate(DataType.string, 3, (i) => '$i', format: format);
          final list = vector.toList(growable: true);
          expect(list.length, vector.count);
          for (var i = 0; i < list.length; i++) {
            expect(list[i], '$i');
            list[i] = '$i*';
            expect(vector[i], '$i');
          }
          list.add('*');
          expect(list, ['0*', '1*', '2*', '*']);
        });
      });
    });
    group('iterables', () {
      group('forEach', () {
        test('empty', () {
          final source = Vector(DataType.string, 0, format: format);
          source.forEach((index, value) => fail('Should not be called'));
        });
        test('default', () {
          final source = Vector(DataType.string, 5, format: format);
          source.forEach((index, value) => fail('Should not be called'));
        });
        test('complete', () {
          final defined = <String>{};
          final source = Vector.generate(DataType.string, 13, (index) {
            final value = index.toString();
            defined.add(value);
            return value;
          }, format: format);
          source.forEach((index, value) {
            expect(value, index.toString());
            expect(defined.remove(value), isTrue);
          });
          expect(defined, isEmpty);
        });
        test('sparse', () {
          final defined = <String>{};
          final random = Random(634234);
          final source = Vector.generate(DataType.string, 63, (index) {
            if (random.nextDouble() < 0.2) {
              final value = index.toString();
              defined.add(value);
              return value;
            } else {
              return DataType.string.defaultValue;
            }
          }, format: format);
          source.forEach((index, value) {
            expect(value, index.toString());
            expect(defined.remove(value), isTrue);
          });
          expect(defined, isEmpty);
        });
      });
      test('basic', () {
        final source =
            Vector.generate(DataType.string, 5, (i) => '$i', format: format);
        final list = source.iterable;
        expect(list, ['0', '1', '2', '3', '4']);
        expect(list.length, source.count);
        expect(() => list.length = 0, throwsUnsupportedError);
        list[2] = '*';
        expect(list, ['0', '1', '*', '3', '4']);
        source[2] = '!';
        expect(list, ['0', '1', '!', '3', '4']);
      });
    });
    group('operators', () {
      final random = Random(648208272);
      final sourceA = Vector.generate(
          DataType.int32, 100, (i) => 1 + random.nextInt(100),
          format: format);
      final sourceB = Vector.generate(
          DataType.int32, 100, (i) => 1 + random.nextInt(100),
          format: format);
      group('add', () {
        test('default', () {
          final target = sourceA.add(sourceB);
          expect(target.dataType, sourceA.dataType);
          expect(target.count, sourceA.count);
          for (var i = 0; i < target.count; i++) {
            expect(target[i], sourceA[i] + sourceB[i]);
          }
        });
        test('operator', () {
          final target = sourceA + sourceB;
          expect(target.dataType, sourceA.dataType);
          expect(target.count, sourceA.count);
          for (var i = 0; i < target.count; i++) {
            expect(target[i], sourceA[i] + sourceB[i]);
          }
        });
        test('target', () {
          final target = Vector(DataType.int16, sourceA.count, format: format);
          final result = sourceA.add(sourceB, target: target);
          expect(target.dataType, DataType.int16);
          expect(target.count, sourceA.count);
          for (var i = 0; i < target.count; i++) {
            expect(target[i], sourceA[i] + sourceB[i]);
          }
          expect(result, target);
        });
        test('format', () {
          final target =
              sourceA.add(sourceB, dataType: DataType.int16, format: format);
          expect(target.dataType, DataType.int16);
          expect(target.count, sourceA.count);
          for (var i = 0; i < target.count; i++) {
            expect(target[i], sourceA[i] + sourceB[i]);
          }
        });
        test('operand dimension mismatch', () {
          final sourceA =
              Vector.fromList(DataType.int8, [1, 2], format: format);
          expect(() => sourceA.add(sourceB), throwsArgumentError);
        });
        test('target dimension mismatch', () {
          final target =
              Vector(DataType.int16, sourceA.count - 1, format: format);
          expect(
              () => sourceA.add(sourceB, target: target), throwsArgumentError);
        });
      });
      group('sub', () {
        test('default', () {
          final target = sourceA.sub(sourceB);
          expect(target.dataType, sourceA.dataType);
          expect(target.count, sourceA.count);
          for (var i = 0; i < target.count; i++) {
            expect(target[i], sourceA[i] - sourceB[i]);
          }
        });
        test('operator', () {
          final target = sourceA - sourceB;
          expect(target.dataType, sourceA.dataType);
          expect(target.count, sourceA.count);
          for (var i = 0; i < target.count; i++) {
            expect(target[i], sourceA[i] - sourceB[i]);
          }
        });
      });
      group('neg', () {
        test('default', () {
          final target = sourceA.neg();
          expect(target.dataType, sourceA.dataType);
          expect(target.count, sourceA.count);
          for (var i = 0; i < target.count; i++) {
            expect(target[i], -sourceA[i]);
          }
        });
        test('operator', () {
          final target = -sourceA;
          expect(target.dataType, sourceA.dataType);
          expect(target.count, sourceA.count);
          for (var i = 0; i < target.count; i++) {
            expect(target[i], -sourceA[i]);
          }
        });
      });
      group('mul', () {
        test('default', () {
          final target = sourceA.mul(sourceB);
          expect(target.dataType, sourceA.dataType);
          expect(target.count, sourceA.count);
          for (var i = 0; i < target.count; i++) {
            expect(target[i], sourceA[i] * sourceB[i]);
          }
        });
        test('operator', () {
          final target = sourceA * sourceB;
          expect(target.dataType, sourceA.dataType);
          expect(target.count, sourceA.count);
          for (var i = 0; i < target.count; i++) {
            expect(target[i], sourceA[i] * sourceB[i]);
          }
        });
        test('scalar', () {
          final target = sourceA.mul(2);
          expect(target.dataType, sourceA.dataType);
          expect(target.count, sourceA.count);
          for (var i = 0; i < target.count; i++) {
            expect(target[i], sourceA[i] * 2);
          }
        });
      });
      group('div', () {
        test('default', () {
          final target = sourceA.div(sourceB);
          expect(target.dataType, sourceA.dataType);
          expect(target.count, sourceA.count);
          for (var i = 0; i < target.count; i++) {
            expect(target[i], sourceA[i] ~/ sourceB[i]);
          }
        });
        test('operator', () {
          final target = sourceA / sourceB;
          expect(target.dataType, sourceA.dataType);
          expect(target.count, sourceA.count);
          for (var i = 0; i < target.count; i++) {
            expect(target[i], sourceA[i] ~/ sourceB[i]);
          }
        });
        test('scalar', () {
          final target = sourceA.div(2);
          expect(target.dataType, sourceA.dataType);
          expect(target.count, sourceA.count);
          for (var i = 0; i < target.count; i++) {
            expect(target[i], sourceA[i] ~/ 2);
          }
        });
      });
      group('lerp', () {
        final v0 = Vector<double>.fromList(DataType.float32, [1, 6, 9],
            format: format);
        final v1 = Vector<double>.fromList(DataType.float32, [9, -2, 9],
            format: format);
        test('at start', () {
          final v = v0.lerp(v1, 0.0);
          expect(v.dataType, v1.dataType);
          expect(v.count, v1.count);
          expect(v[0], v0[0]);
          expect(v[1], v0[1]);
          expect(v[2], v0[2]);
        });
        test('at middle', () {
          final v = v0.lerp(v1, 0.5);
          expect(v.dataType, v1.dataType);
          expect(v.count, v1.count);
          expect(v[0], 5.0);
          expect(v[1], 2.0);
          expect(v[2], 9.0);
        });
        test('at end', () {
          final v = v0.lerp(v1, 1.0);
          expect(v.dataType, v1.dataType);
          expect(v.count, v1.count);
          expect(v[0], v1[0]);
          expect(v[1], v1[1]);
          expect(v[2], v1[2]);
        });
        test('at outside', () {
          final v = v0.lerp(v1, 2.0);
          expect(v.dataType, v1.dataType);
          expect(v.count, v1.count);
          expect(v[0], 17.0);
          expect(v[1], -10.0);
          expect(v[2], 9.0);
        });
        test('error', () {
          final other = Vector(DataType.float32, 2, format: format);
          expect(() => v0.lerp(other, 2.0), throwsArgumentError);
        });
      });
      group('compare', () {
        test('identity', () {
          expect(sourceA.compare(sourceA), isTrue);
          expect(sourceB.compare(sourceB), isTrue);
          expect(sourceA.compare(sourceB), isFalse);
          expect(sourceB.compare(sourceA), isFalse);
        });
        test('views', () {
          expect(sourceA.range(0, 3).compare(sourceA.index([0, 1, 2])), isTrue);
          expect(sourceA.range(0, 3).compare(sourceA.index([3, 1, 0])), isFalse,
              reason: 'order mismatch');
          expect(sourceA.range(0, 3).compare(sourceA.index([0, 1])), isFalse,
              reason: 'count mismatch');
        });
        test('custom', () {
          final negated = sourceA.neg();
          expect(sourceA.compare(negated), isFalse);
          expect(sourceA.compare(negated, equals: (a, b) => a == -b), isTrue);
        });
      });
      group('dot', () {
        test('default', () {
          var expected = 0;
          for (var i = 0; i < sourceA.count; i++) {
            expected += sourceA[i] * sourceB[i];
          }
          expect(sourceA.dot(sourceB), expected);
        });
        test('dimension mismatch', () {
          final sourceB =
              Vector(DataType.uint8, sourceA.count - 1, format: format);
          expect(() => sourceA.dot(sourceB), throwsArgumentError);
        });
      });
      test('sum', () {
        final source =
            Vector.fromList(DataType.uint8, [1, 2, 3, 4], format: format);
        expect(source.sum, 10);
      });
      test('magnitude', () {
        final source =
            Vector.fromList(DataType.float32, [3, 4], format: format);
        expect(source.magnitude, 5.0);
      });
      test('magnitude2', () {
        final source = Vector.fromList(DataType.int32, [4, 3], format: format);
        expect(source.magnitude2, 25);
      });
    });
  });
}

void main() {
  vectorTest('standard', VectorFormat.standard);
  vectorTest('keyed', VectorFormat.keyed);
  vectorTest('list', VectorFormat.list);
}
