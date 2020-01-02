library data.test.vector;

import 'dart:math';

import 'package:data/matrix.dart' as matrix;
import 'package:data/type.dart';
import 'package:data/vector.dart';
import 'package:test/test.dart';
import 'package:test/test.dart' as prefix0;

void vectorTest(String name, Builder builder) {
  group(name, () {
    group('builder', () {
      test('call', () {
        final vector = builder.withType(DataType.int8)(4);
        expect(vector.dataType, DataType.int8);
        expect(vector.count, 4);
        expect(vector.shape, [vector.count]);
        expect(vector.storage, [vector]);
        for (var i = 0; i < vector.count; i++) {
          expect(vector[i], 0);
        }
      });
      test('call, error', () {
        expect(() => builder(-4), throwsRangeError);
        expect(() => builder.withType(null)(4), throwsArgumentError);
        expect(() => builder.withFormat(null)(4), throwsArgumentError);
      });
      test('constant', () {
        final vector = builder.withType(DataType.int8).constant(5, 123);
        expect(vector.dataType, DataType.int8);
        expect(vector.count, 5);
        expect(vector.shape, [vector.count]);
        expect(vector.storage, [vector]);
        expect(vector.copy(), vector);
        for (var i = 0; i < vector.count; i++) {
          expect(vector[i], 123);
        }
        expect(() => vector[3] = 1, throwsUnsupportedError);
      });
      test('constant, mutable', () {
        final vector =
            builder.withType(DataType.int8).constant(5, 123, mutable: true);
        expect(vector.dataType, DataType.int8);
        expect(vector.count, 5);
        expect(vector.shape, [vector.count]);
        expect(vector.storage, [vector]);
        for (var i = 0; i < vector.count; i++) {
          expect(vector[i], 123);
        }
        vector[3] = 1;
        expect(vector[3], 1);
      });
      test('generate', () {
        final vector =
            builder.withType(DataType.string).generate(7, (i) => '$i');
        expect(vector.dataType, DataType.string);
        expect(vector.count, 7);
        expect(vector.shape, [vector.count]);
        expect(vector.storage, [vector]);
        for (var i = 0; i < vector.count; i++) {
          expect(vector[i], '$i');
        }
        vector[3] = '*';
        expect(vector[3], '*');
      });
      test('generate, lazy', () {
        final vector = builder
            .withType(DataType.string)
            .generate(7, (i) => '$i', lazy: true);
        expect(vector.dataType, DataType.string);
        expect(vector.count, 7);
        expect(vector.shape, [vector.count]);
        expect(vector.storage, [vector]);
        for (var i = 0; i < vector.count; i++) {
          expect(vector[i], '$i');
        }
        expect(() => vector[3] = '*', throwsUnsupportedError);
        final copy = vector.copy();
        expect(copy, same(vector));
      });
      test('transform', () {
        final source =
            builder.withType(DataType.int8).generate(9, (i) => 2 * i);
        final vector = builder
            .withType(DataType.string)
            .transform(source, (index, value) => '$index: $value');
        expect(vector.dataType, DataType.string);
        expect(vector.count, source.count);
        expect(vector.shape, [source.count]);
        expect(vector.storage, [vector]);
        for (var i = 0; i < vector.count; i++) {
          expect(vector[i], '$i: ${2 * i}');
        }
        vector[3] = '*';
        expect(vector[3], '*');
      });
      test('transform, lazy', () {
        final source =
            builder.withType(DataType.int8).generate(9, (i) => 2 * i);
        final vector = builder
            .withType(DataType.string)
            .transform(source, (index, value) => '$index: $value', lazy: true);
        expect(vector.dataType, DataType.string);
        expect(vector.count, source.count);
        expect(vector.shape, [source.count]);
        expect(vector.storage, [source]);
        for (var i = 0; i < vector.count; i++) {
          expect(vector[i], '$i: ${2 * i}');
        }
        expect(() => vector[3] = '*', throwsUnsupportedError);
      });
      test('cast', () {
        final source =
            builder.withType(DataType.int8).generate(10, (i) => i * i);
        final vector = builder.withType(DataType.string).cast(source);
        expect(vector.dataType, DataType.string);
        expect(vector.count, source.count);
        expect(vector.shape, [source.count]);
        expect(vector.storage, [vector]);
        for (var i = 0; i < vector.count; i++) {
          expect(vector[i], '${i * i}');
        }
        vector[3] = '42';
        expect(vector[3], '42');
        expect(source[3], 9);
      });
      test('cast, lazy', () {
        final source =
            builder.withType(DataType.int8).generate(10, (i) => i * i);
        final vector =
            builder.withType(DataType.string).cast(source, lazy: true);
        expect(vector.dataType, DataType.string);
        expect(vector.count, source.count);
        expect(vector.shape, [source.count]);
        expect(vector.storage, [source]);
        for (var i = 0; i < vector.count; i++) {
          expect(vector[i], '${i * i}');
        }
        vector[3] = '42';
        expect(vector[3], '42');
        expect(source[3], 42);
      });
      test('concat', () {
        final source1 = builder.withType(DataType.string).fromList(['a']);
        final source2 = builder.withType(DataType.string).fromList(['b', 'c']);
        final source3 = builder.withType(DataType.string).fromList(['d', 'e']);
        final vector = builder
            .withType(DataType.string)
            .concat([source1, source2, source3, source1]);
        expect(vector.dataType, DataType.string);
        expect(vector.count, 6);
        expect(vector.shape, [vector.count]);
        expect(vector.storage, [vector]);
        for (var i = 0; i < vector.count; i++) {
          expect(vector[i], 'abcdea'[i]);
        }
        vector[0] = '*';
        vector[4] = '!';
        for (var i = 0; i < vector.count; i++) {
          expect(vector[i], '*bcd!a'[i]);
        }
      });
      test('concat, lazy', () {
        final source1 = builder.withType(DataType.string).fromList(['a']);
        final source2 = builder.withType(DataType.string).fromList(['b', 'c']);
        final source3 = builder.withType(DataType.string).fromList(['d', 'e']);
        final vector = builder
            .withType(DataType.string)
            .concat([source1, source2, source3, source1], lazy: true);
        expect(vector.dataType, DataType.string);
        expect(vector.count, 6);
        expect(vector.shape, [vector.count]);
        expect(vector.storage, unorderedMatches([source1, source2, source3]));
        for (var i = 0; i < vector.count; i++) {
          expect(vector[i], 'abcdea'[i]);
        }
        vector[0] = '*';
        vector[4] = '!';
        for (var i = 0; i < vector.count; i++) {
          expect(vector[i], '*bcd!*'[i]);
        }
        final copy = vector.copy();
        expect(copy, isNot(same(vector)));
      });
      test('fromVector', () {
        final source =
            builder.withType(DataType.string).generate(6, (i) => '$i');
        final vector = builder.withType(DataType.string).fromVector(source);
        expect(vector.dataType, DataType.string);
        expect(vector.count, 6);
        expect(vector.shape, [vector.count]);
        expect(vector.storage, [vector]);
        for (var i = 0; i < vector.count; i++) {
          expect(vector[i], '$i');
        }
      });
      test('fromList', () {
        final vector = builder.withType(DataType.int8).fromList([2, 1, 3]);
        expect(vector.dataType, DataType.int8);
        expect(vector.count, 3);
        expect(vector.shape, [vector.count]);
        expect(vector.storage, [vector]);
        expect(vector[0], 2);
        expect(vector[1], 1);
        expect(vector[2], 3);
      });
    });
    group('accesssing', () {
      test('random', () {
        final vector = builder(100);
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
          vector[value] = vector.dataType.nullValue;
        }
        for (var i = 0; i < vector.count; i++) {
          expect(vector[i], vector.dataType.nullValue);
        }
      });
      test('read (range error)', () {
        final vector = builder.withType(DataType.int8).fromList([1, 2]);
        expect(() => vector[-1], throwsRangeError);
        expect(() => vector[vector.count], throwsRangeError);
      });
      test('write (range error)', () {
        final vector = builder.withType(DataType.int8).fromList([1, 2]);
        expect(() => vector[-1] = 1, throwsRangeError);
        expect(() => vector[vector.count] = 1, throwsRangeError);
      });
    });
    group('view', () {
      test('copy', () {
        final source = builder.generate(30, (i) => i);
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
      test('range', () {
        final source =
            builder.withType(DataType.string).generate(6, (i) => '$i');
        final range = source.range(1, 4);
        expect(range.dataType, DataType.string);
        expect(range.count, 3);
        expect(range.storage, [source]);
        expect(compare(range.copy(), range), isTrue);
        expect(range[0], '1');
        expect(range[1], '2');
        expect(range[2], '3');
        range[1] += '*';
        expect(range[1], '2*');
        expect(source[2], '2*');
      });
      test('range (full range)', () {
        final source = builder.withType(DataType.int8).fromList([1, 2]);
        expect(source.range(0, source.count), source);
      });
      test('range (sub range)', () {
        final source =
            builder.withType(DataType.string).generate(6, (i) => '$i');
        final range = source.range(1, 4).range(1, 2);
        expect(range.dataType, DataType.string);
        expect(range.count, 1);
        expect(range.storage, [source]);
        expect(range[0], '2');
        range[0] += '*';
        expect(range[0], '2*');
        expect(source[2], '2*');
      });
      test('range (range error)', () {
        final source = builder.withType(DataType.int8).fromList([1, 2]);
        expect(source.range(0, source.count), source);
        expect(() => source.range(-1, source.count), throwsRangeError);
        expect(() => source.range(0, source.count + 1), throwsRangeError);
      });
      test('index', () {
        final source =
            builder.withType(DataType.string).generate(6, (i) => '$i');
        final index = source.index([3, 2, 2]);
        expect(index.dataType, DataType.string);
        expect(index.count, 3);
        expect(index.storage, [source]);
        expect(compare(index.copy(), index), isTrue);
        expect(index[0], '3');
        expect(index[1], '2');
        expect(index[2], '2');
        index[1] += '*';
        expect(index[1], '2*');
        expect(source[2], '2*');
      });
      test('index (sub index)', () {
        final source =
            builder.withType(DataType.string).generate(6, (i) => '$i');
        final index = source.index([3, 2, 2]).index([1]);
        expect(index.dataType, DataType.string);
        expect(index.count, 1);
        expect(index.storage, [source]);
        expect(index[0], '2');
        index[0] += '*';
        expect(index[0], '2*');
        expect(source[2], '2*');
      });
      test('index (range error)', () {
        final source = builder.withType(DataType.int8).fromList([1, 2]);
        expect(() => source.index([0, 1]), isNot(throwsRangeError));
        expect(() => source.index([-1, source.count - 1]), throwsRangeError);
        expect(() => source.index([0, source.count]), throwsRangeError);
      });
      group('overlay', () {
        final base = builder
            .withType(DataType.string)
            .generate(8, (index) => '($index)');
        test('offset', () {
          final top = builder
              .withType(DataType.string)
              .generate(2, (index) => '[$index]');
          final composite = top.overlay(base, offset: 4);
          expect(composite.dataType, top.dataType);
          expect(composite.count, base.count);
          expect(composite.storage, unorderedMatches([base, top]));
          final copy = composite.copy();
          expect(compare(copy, composite), isTrue);
          for (var i = 0; i < composite.count; i++) {
            expect(composite[i], 4 <= i && i <= 5 ? '[${i - 4}]' : '($i)');
            copy[i] = '${copy[i]}*';
          }
        });
        test('mask', () {
          final top = builder
              .withType(DataType.string)
              .generate(base.count, (index) => '[$index]');
          final mask = builder
              .withType(DataType.boolean)
              .generate(base.count, (index) => index.isEven, lazy: true);
          final composite = top.overlay(base, mask: mask);
          expect(composite.dataType, top.dataType);
          expect(composite.count, base.count);
          expect(composite.storage, unorderedMatches([base, top, mask]));
          final copy = composite.copy();
          expect(compare(copy, composite), isTrue);
          for (var i = 0; i < composite.count; i++) {
            expect(composite[i], i.isEven ? '[$i]' : '($i)');
            copy[i] = '${copy[i]}*';
          }
        });
        test('errors', () {
          expect(() => base.overlay(base), throwsArgumentError);
          expect(
              () => base.overlay(
                  builder
                      .withType(DataType.string)
                      .constant(base.count + 1, ''),
                  mask: builder
                      .withType(DataType.boolean)
                      .constant(base.count, true)),
              throwsArgumentError);
          expect(
              () => base.overlay(
                  builder.withType(DataType.string).constant(base.count, ''),
                  mask: builder
                      .withType(DataType.boolean)
                      .constant(base.count + 1, true)),
              throwsArgumentError);
        });
      });
      group('transform', () {
        final source = builder.generate(4, (index) => index);
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
          final source = builder
              .withType(DataType.uint8)
              .generate(6, (index) => index + 97);
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
          expect(compare(mapped.copy(), mapped), isTrue);
        });
      });
      group('cast', () {
        final source = builder.generate(256, (index) => index);
        test('to string', () {
          final cast = source.cast(DataType.string);
          expect(cast.dataType, DataType.string);
          expect(cast.count, source.count);
          expect(cast.storage, [source]);
          for (var i = 0; i < cast.count; i++) {
            expect(cast[i], '$i');
          }
        });
        test('copy', () {
          final cast = source.cast(DataType.int32);
          expect(compare(cast.copy(), cast), isTrue);
        });
      });
      test('reversed', () {
        final source = builder.withType(DataType.int8).fromList([1, 2, 3]);
        final reversed = source.reversed;
        expect(reversed.dataType, source.dataType);
        expect(reversed.count, source.count);
        expect(reversed.storage, [source]);
        expect(reversed.reversed, same(source));
        expect(compare(reversed.copy(), reversed), isTrue);
        for (var i = 0; i < source.count; i++) {
          expect(reversed[i], source[source.count - i - 1]);
        }
        reversed[1] = 42;
        expect(reversed[1], 42);
        expect(source[1], 42);
      });
      test('unmodifiable', () {
        final source = builder.withType(DataType.int8).fromList([1, 2]);
        final readonly = source.unmodifiable;
        expect(readonly.dataType, source.dataType);
        expect(readonly.count, source.count);
        expect(readonly.storage, [source]);
        expect(compare(readonly.copy(), readonly), isTrue);
        for (var i = 0; i < source.count; i++) {
          expect(source[i], readonly[i]);
          expect(() => readonly[i] = 0, throwsUnsupportedError);
        }
        source[1] = 3;
        expect(readonly[1], 3);
        expect(readonly.unmodifiable, readonly);
      });
      test('format', () {
        final vector = builder.withType(DataType.int8).generate(100, (i) => i);
        expect(vector.format(), '0 1 2 … 97 98 99');
      });
      test('toString', () {
        final vector = builder.withType(DataType.int8).fromList([3, 2, 1]);
        expect(
            vector.toString(),
            '${vector.runtimeType}'
            '[3, ${vector.dataType.name}]:\n'
            '3 2 1');
      });
    });
    group('iterables', () {
      test('basic', () {
        final source =
            builder.withType(DataType.string).generate(5, (i) => '$i');
        final list = source.iterable;
        expect(list, ['0', '1', '2', '3', '4']);
        expect(list.length, source.count);
        expect(() => list.length = 0, prefix0.throwsUnsupportedError);
        list[2] = '*';
        expect(list, ['0', '1', '*', '3', '4']);
        source[2] = '!';
        expect(list, ['0', '1', '!', '3', '4']);
      });
    });
    group('operators', () {
      final random = Random();
      final sourceA = builder
          .withType(DataType.int32)
          .generate(100, (i) => random.nextInt(100));
      final sourceB = builder
          .withType(DataType.int32)
          .generate(100, (i) => random.nextInt(100));
      test('unary', () {
        final result = unaryOperator(sourceA, (a) => a * a);
        expect(result.dataType, sourceA.dataType);
        expect(result.count, sourceA.count);
        for (var i = 0; i < result.count; i++) {
          final a = sourceA[i];
          expect(result[i], a * a);
        }
      });
      test('binary', () {
        final result =
            binaryOperator(sourceA, sourceB, (a, b) => a * a + b * b);
        expect(result.dataType, sourceA.dataType);
        expect(result.count, sourceA.count);
        for (var i = 0; i < result.count; i++) {
          final a = sourceA[i];
          final b = sourceB[i];
          expect(result[i], a * a + b * b);
        }
      });
      group('add', () {
        test('default', () {
          final target = add(sourceA, sourceB);
          expect(target.dataType, sourceA.dataType);
          expect(target.count, sourceA.count);
          for (var i = 0; i < target.count; i++) {
            expect(target[i], sourceA[i] + sourceB[i]);
          }
        });
        test('default, bad count', () {
          final sourceA = builder.withType(DataType.int8).fromList([1, 2]);
          expect(() => add(sourceA, sourceB), throwsArgumentError);
        });
        test('target', () {
          final target = builder.withType(DataType.int16)(sourceA.count);
          final result = add(sourceA, sourceB, target: target);
          expect(target.dataType, DataType.int16);
          expect(target.count, sourceA.count);
          for (var i = 0; i < target.count; i++) {
            expect(target[i], sourceA[i] + sourceB[i]);
          }
          expect(result, target);
        });
        test('target, bad count', () {
          final target = builder.withType(DataType.int16)(sourceA.count - 1);
          expect(
              () => add(sourceA, sourceB, target: target), throwsArgumentError);
        });
        test('builder', () {
          final target =
              add(sourceA, sourceB, builder: builder.withType(DataType.int16));
          expect(target.dataType, DataType.int16);
          expect(target.count, sourceA.count);
          for (var i = 0; i < target.count; i++) {
            expect(target[i], sourceA[i] + sourceB[i]);
          }
        });
      });
      test('sub', () {
        final target = sub(sourceA, sourceB);
        expect(target.dataType, sourceA.dataType);
        expect(target.count, sourceA.count);
        for (var i = 0; i < target.count; i++) {
          expect(target[i], sourceA[i] - sourceB[i]);
        }
      });
      test('sub (dimension missmatch)', () {
        final sourceB = builder.withType(DataType.uint8)(sourceA.count + 1);
        expect(() => sub(sourceA, sourceB), throwsArgumentError);
      });
      test('neg', () {
        final target = neg(sourceA);
        expect(target.dataType, sourceA.dataType);
        expect(target.count, sourceA.count);
        for (var i = 0; i < target.count; i++) {
          expect(target[i], -sourceA[i]);
        }
      });
      test('scale', () {
        final target = scale(sourceA, 2);
        expect(target.dataType, sourceA.dataType);
        expect(target.count, sourceA.count);
        for (var i = 0; i < target.count; i++) {
          expect(target[i], 2 * sourceA[i]);
        }
      });
      group('lerp', () {
        final v0 = builder.withType(DataType.float32).fromList([1, 6, 9]);
        final v1 = builder.withType(DataType.float32).fromList([9, -2, 9]);
        test('at start', () {
          final v = lerp(v0, v1, 0.0);
          expect(v.dataType, v1.dataType);
          expect(v.count, v1.count);
          expect(v[0], v0[0]);
          expect(v[1], v0[1]);
          expect(v[2], v0[2]);
        });
        test('at middle', () {
          final v = lerp(v0, v1, 0.5);
          expect(v.dataType, v1.dataType);
          expect(v.count, v1.count);
          expect(v[0], 5.0);
          expect(v[1], 2.0);
          expect(v[2], 9.0);
        });
        test('at end', () {
          final v = lerp(v0, v1, 1.0);
          expect(v.dataType, v1.dataType);
          expect(v.count, v1.count);
          expect(v[0], v1[0]);
          expect(v[1], v1[1]);
          expect(v[2], v1[2]);
        });
        test('at outside', () {
          final v = lerp(v0, v1, 2.0);
          expect(v.dataType, v1.dataType);
          expect(v.count, v1.count);
          expect(v[0], 17.0);
          expect(v[1], -10.0);
          expect(v[2], 9.0);
        });
        test('error', () {
          final other = builder.withType(DataType.float32).fromList([0, 1]);
          expect(() => lerp(v0, other, 2.0), throwsArgumentError);
        });
      });
      test('lerp (dimension missmatch)', () {
        final v0 = builder.withType(DataType.int8).fromList([1, 6]);
        final v1 = builder.withType(DataType.int8).fromList([9, -2, 9]);
        expect(() => lerp(v0, v1, -1.0), throwsArgumentError);
      });
      group('compare', () {
        test('identity', () {
          expect(compare(sourceA, sourceA), isTrue);
          expect(compare(sourceB, sourceB), isTrue);
          expect(compare(sourceA, sourceB), isFalse);
          expect(compare(sourceB, sourceA), isFalse);
        });
        test('views', () {
          expect(
              compare(sourceA.range(0, 3), sourceA.index([0, 1, 2])), isTrue);
          expect(
              compare(sourceA.range(0, 3), sourceA.index([3, 1, 0])), isFalse,
              reason: 'order missmatch');
          expect(compare(sourceA.range(0, 3), sourceA.index([0, 1])), isFalse,
              reason: 'count missmatch');
        });
        test('custom', () {
          final negated = neg(sourceA);
          expect(compare(sourceA, negated), isFalse);
          expect(compare(sourceA, negated, equals: (a, b) => a == -b), isTrue);
        });
      });
      group('mul', () {
        final sourceA = matrix.Matrix.builder
            .withType(DataType.int32)
            .generate(37, 42, (r, c) => random.nextInt(100));
        final sourceB = builder
            .withType(DataType.int8)
            .generate(sourceA.colCount, (i) => random.nextInt(100));
        test('default', () {
          final v = mul(sourceA, sourceB);
          for (var i = 0; i < v.count; i++) {
            expect(v[i], dot(sourceA.row(i), sourceB));
          }
        });
        test('error in-place', () {
          final derivedA = sourceA.range(0, 8, 0, 8);
          final derivedB = sourceB.range(0, 8);
          expect(() => mul(derivedA, derivedB, target: derivedB),
              throwsArgumentError);
          expect(() => mul(derivedA, derivedB, target: derivedA.row(0)),
              throwsArgumentError);
          expect(() => mul(derivedA, derivedB, target: derivedA.column(0)),
              throwsArgumentError);
        });
        test('error dimensions', () {
          expect(() => mul(sourceA.colRange(1), sourceB), throwsArgumentError);
          expect(() => mul(sourceA, sourceB.range(1)), throwsArgumentError);
        });
      });
      test('dot', () {
        var expected = 0;
        for (var i = 0; i < sourceA.count; i++) {
          expected += sourceA[i] * sourceB[i];
        }
        expect(dot(sourceA, sourceB), expected);
      });
      test('dot (dimension missmatch)', () {
        final sourceB = builder.withType(DataType.uint8)(sourceA.count - 1);
        expect(() => dot(sourceA, sourceB), throwsArgumentError);
      });
      test('sum', () {
        final source = builder.withType(DataType.uint8).fromList([1, 2, 3, 4]);
        expect(sum(source), 10);
      });
      test('length', () {
        final source = builder.withType(DataType.uint8).fromList([3, 4]);
        expect(length(source), 5.0);
      });
      test('length2', () {
        final source = builder.withType(DataType.uint8).fromList([4, 3]);
        expect(length2(source), 25);
      });
    });
  });
}

void main() {
  vectorTest('standard', Vector.builder.standard);
  vectorTest('keyed', Vector.builder.keyed);
  vectorTest('list', Vector.builder.list);
}
