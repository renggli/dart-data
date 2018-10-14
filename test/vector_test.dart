library data.test.vector;

import 'dart:math';

import 'package:data/matrix.dart' as matrix;
import 'package:data/type.dart';
import 'package:data/vector.dart';
import 'package:test/test.dart';

void vectorTest(String name, Builder builder) {
  group(name, () {
    group('builder', () {
      test('call', () {
        final vector = builder.withType(DataType.int8)(4);
        expect(vector.dataType, DataType.int8);
        expect(vector.count, 4);
        expect(vector.shape, [vector.count]);
        expect(vector.base, vector);
        for (var i = 0; i < vector.count; i++) {
          expect(vector[i], 0);
        }
      });
      test('constant', () {
        final vector = builder.withType(DataType.int8).constant(5, 123);
        expect(vector.dataType, DataType.int8);
        expect(vector.count, 5);
        expect(vector.shape, [vector.count]);
        expect(vector.base, vector);
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
        expect(vector.base, vector);
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
        expect(vector.base, vector);
        for (var i = 0; i < vector.count; i++) {
          expect(vector[i], '$i');
        }
      });
      test('transform', () {
        final source =
            builder.withType(DataType.int8).generate(9, (i) => 2 * i);
        final vector = builder
            .withType(DataType.string)
            .transform(source, (index, value) => '$index: $value');
        expect(vector.dataType, DataType.string);
        expect(vector.count, 9);
        expect(vector.shape, [vector.count]);
        expect(vector.base, vector);
        for (var i = 0; i < vector.count; i++) {
          expect(vector[i], '$i: ${2 * i}');
        }
      });
      test('fromVector', () {
        final source =
            builder.withType(DataType.string).generate(6, (i) => '$i');
        final vector = builder.withType(DataType.string).fromVector(source);
        expect(vector.dataType, DataType.string);
        expect(vector.count, 6);
        expect(vector.shape, [vector.count]);
        expect(vector.base, vector);
        for (var i = 0; i < vector.count; i++) {
          expect(vector[i], '$i');
        }
      });
      test('fromList', () {
        final vector = builder.withType(DataType.int8).fromList([2, 1, 3]);
        expect(vector.dataType, DataType.int8);
        expect(vector.count, 3);
        expect(vector.shape, [vector.count]);
        expect(vector.base, vector);
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
        for (var value in values) {
          vector[value] = value;
        }
        for (var i = 0; i < vector.count; i++) {
          expect(vector[i], i);
        }
        // update values
        values.shuffle();
        for (var value in values) {
          vector[value] = value + 1;
        }
        for (var i = 0; i < vector.count; i++) {
          expect(vector[i], i + 1);
        }
        // remove values
        values.shuffle();
        for (var value in values) {
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
        expect(copy.base, copy);
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
        expect(range.base, source);
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
        expect(range.base, source);
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
        expect(index.base, source);
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
        expect(index.base, source);
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
      group('map', () {
        final source = builder.generate(4, (index) => index);
        test('to string', () {
          final mapped =
              source.map((index, value) => '$index', DataType.string);
          expect(mapped.dataType, DataType.string);
          expect(mapped.count, source.count);
          expect(mapped.base, source);
          for (var i = 0; i < mapped.count; i++) {
            expect(mapped[i], '$i');
          }
        });
        test('to int', () {
          final mapped = source.map((index, value) => index, DataType.int32);
          expect(mapped.dataType, DataType.int32);
          expect(mapped.count, source.count);
          expect(mapped.base, source);
          for (var i = 0; i < mapped.count; i++) {
            expect(mapped[i], i);
          }
        });
        test('to float', () {
          final mapped =
              source.map((index, value) => index.toDouble(), DataType.float64);
          expect(mapped.dataType, DataType.float64);
          expect(mapped.count, source.count);
          expect(mapped.base, source);
          for (var i = 0; i < mapped.count; i++) {
            expect(mapped[i], i.toDouble());
          }
        });
        test('copy', () {
          final mapped = source.map((index, value) => index, DataType.int32);
          expect(compare(mapped.copy(), mapped), isTrue);
        });
        test('readonly', () {
          final mapped = source.map((index, value) => index, DataType.int32);
          expect(() => mapped.setUnchecked(0, 1), throwsUnsupportedError);
        });
      });
      test('unmodifiable', () {
        final source = builder.withType(DataType.int8).fromList([1, 2]);
        final readonly = source.unmodifiable;
        expect(readonly.dataType, source.dataType);
        expect(readonly.count, source.count);
        expect(readonly.base, source);
        expect(compare(readonly.copy(), readonly), isTrue);
        for (var i = 0; i < source.count; i++) {
          expect(source[i], readonly[i]);
          expect(() => readonly[i] = 0, throwsUnsupportedError);
        }
        source[1] = 3;
        expect(readonly[1], 3);
        expect(readonly.unmodifiable, readonly);
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
    group('operators', () {
      final random = Random();
      final sourceA = builder
          .withType(DataType.int32)
          .generate(100, (i) => random.nextInt(100));
      final sourceB = builder
          .withType(DataType.int32)
          .generate(100, (i) => random.nextInt(100));
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
        final target = scale(2, sourceA);
        expect(target.dataType, sourceA.dataType);
        expect(target.count, sourceA.count);
        for (var i = 0; i < target.count; i++) {
          expect(target[i], 2 * sourceA[i]);
        }
      });
      group('lerp', () {
        final v0 = builder.withType(DataType.int8).fromList([1, 6, 9]);
        final v1 = builder.withType(DataType.int8).fromList([9, -2, 9]);
        test('at start', () {
          final v = lerp(v0, v1, 0.0);
          expect(v.dataType, DataType.float64);
          expect(v.count, 3);
          expect(v[0], 1.0);
          expect(v[1], 6.0);
          expect(v[2], 9.0);
        });
        test('at middle', () {
          final v = lerp(v0, v1, 0.5);
          expect(v.dataType, DataType.float64);
          expect(v.count, 3);
          expect(v[0], 5.0);
          expect(v[1], 2.0);
          expect(v[2], 9.0);
        });
        test('at end', () {
          final v = lerp(v0, v1, 1.0);
          expect(v.dataType, DataType.float64);
          expect(v.count, 3);
          expect(v[0], 9.0);
          expect(v[1], -2.0);
          expect(v[2], 9.0);
        });
        test('at outside', () {
          final v = lerp(v0, v1, 2.0);
          expect(v.dataType, DataType.float64);
          expect(v.count, 3);
          expect(v[0], 17.0);
          expect(v[1], -10.0);
          expect(v[2], 9.0);
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
          expect(compare<int, int>(sourceA, negated, equals: (a, b) => a == -b),
              isTrue);
        });
      });
      test('mul', () {
        final a = matrix.Matrix.builder
            .withType(DataType.int32)
            .generate(37, 42, (r, c) => random.nextInt(100));
        final b = builder
            .withType(DataType.int8)
            .generate(a.colCount, (i) => random.nextInt(100));
        final v = mul(a, b);
        for (var i = 0; i < v.count; i++) {
          expect(v[i], dot(a.row(i), b));
        }
      });
      test('mul (dimension missmatch)', () {
        final a = matrix.Matrix.builder.withType(DataType.int32)(37, 42);
        final b = builder.withType(DataType.int8)(a.rowCount);
        expect(() => mul(a, b), throwsArgumentError);
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
