library data.test.vector;

import 'dart:math';

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
        for (var i = 0; i < vector.count; i++) {
          expect(vector[i], 0);
        }
      });
      test('constant', () {
        final vector = builder.withType(DataType.int8).constant(5, 123);
        expect(vector.dataType, DataType.int8);
        expect(vector.count, 5);
        for (var i = 0; i < vector.count; i++) {
          expect(vector[i], 123);
        }
      });
      test('generate', () {
        final vector =
            builder.withType(DataType.string).generate(7, (i) => '$i');
        expect(vector.dataType, DataType.string);
        expect(vector.count, 7);
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
        for (var i = 0; i < vector.count; i++) {
          expect(vector[i], '$i');
        }
      });
      test('fromList', () {
        final vector = builder.withType(DataType.int8).fromList([2, 1, 3]);
        expect(vector.dataType, DataType.int8);
        expect(vector.count, 3);
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
      test('range', () {
        final source =
            builder.withType(DataType.string).generate(6, (i) => '$i');
        final vector = source.range(1, 4);
        expect(vector.dataType, DataType.string);
        expect(vector.count, 3);
        expect(vector[0], '1');
        expect(vector[1], '2');
        expect(vector[2], '3');
        vector[1] += '*';
        expect(vector[1], '2*');
        expect(source[2], '2*');
      });
      test('range (full range)', () {
        final vector = builder.withType(DataType.int8).fromList([1, 2]);
        expect(vector.range(0, vector.count), vector);
      });
      test('range (sub range)', () {
        final source =
            builder.withType(DataType.string).generate(6, (i) => '$i');
        final vector = source.range(1, 4).range(1, 2);
        expect(vector.dataType, DataType.string);
        expect(vector.count, 1);
        expect(vector[0], '2');
        vector[0] += '*';
        expect(vector[0], '2*');
        expect(source[2], '2*');
      });
      test('range (range error)', () {
        final vector = builder.withType(DataType.int8).fromList([1, 2]);
        expect(vector.range(0, vector.count), vector);
        expect(() => vector.range(-1, vector.count), throwsRangeError);
        expect(() => vector.range(0, vector.count + 1), throwsRangeError);
      });
      test('index', () {
        final source =
            builder.withType(DataType.string).generate(6, (i) => '$i');
        final vector = source.index([3, 2, 2]);
        expect(vector.dataType, DataType.string);
        expect(vector.count, 3);
        expect(vector[0], '3');
        expect(vector[1], '2');
        expect(vector[2], '2');
        vector[1] += '*';
        expect(vector[1], '2*');
        expect(source[2], '2*');
      });
      test('index (sub index)', () {
        final source =
            builder.withType(DataType.string).generate(6, (i) => '$i');
        final vector = source.index([3, 2, 2]).index([1]);
        expect(vector.dataType, DataType.string);
        expect(vector.count, 1);
        expect(vector[0], '2');
        vector[0] += '*';
        expect(vector[0], '2*');
        expect(source[2], '2*');
      });
      test('index (range error)', () {
        final vector = builder.withType(DataType.int8).fromList([1, 2]);
        expect(() => vector.index([0, 1]), isNot(throwsRangeError));
        expect(() => vector.index([-1, vector.count - 1]), throwsRangeError);
        expect(() => vector.index([0, vector.count]), throwsRangeError);
      });
      test('unmodifiable', () {
        final source = builder.withType(DataType.int8).fromList([1, 2]);
        final vector = source.unmodifiable;
        expect(vector.dataType, source.dataType);
        expect(vector.count, source.count);
        for (var i = 0; i < source.count; i++) {
          expect(source[i], vector[i]);
          expect(() => vector[i] = 0, throwsUnsupportedError);
        }
        source[1] = 3;
        expect(vector[1], 3);
        expect(vector.unmodifiable, vector);
      });
      test('toString', () {
        final vector = builder.withType(DataType.int8).fromList([3, 2, 1]);
        expect(vector.toString(), '${vector.runtimeType}[3]: 3, 2, 1');
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
