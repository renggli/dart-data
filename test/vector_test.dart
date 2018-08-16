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
      test('fromRange', () {
        final source =
            builder.withType(DataType.string).generate(6, (i) => '$i');
        final vector =
            builder.withType(DataType.string).fromRange(source, 1, 4);
        expect(vector.dataType, DataType.string);
        expect(vector.count, 3);
        expect(vector[0], '1');
        expect(vector[1], '2');
        expect(vector[2], '3');
      });
      test('fromIndices', () {
        final source =
            builder.withType(DataType.string).generate(6, (i) => '$i');
        final vector =
            builder.withType(DataType.string).fromIndices(source, [5, 0, 0]);
        expect(vector.dataType, DataType.string);
        expect(vector.count, 3);
        expect(vector[0], '5');
        expect(vector[1], '0');
        expect(vector[2], '0');
      });
      test('fromList', () {
        final vector = builder.withType(DataType.int8).fromList([2, 1, 3]);
        expect(vector.dataType, DataType.int8);
        expect(vector.count, 3);
        expect(vector[0], 2);
        expect(vector[1], 1);
        expect(vector[2], 3);
      });
      test('fromList (empty)', () {
        expect(() => builder.fromList([]), throwsArgumentError);
      });
    });
    group('accesssing', () {
      final vector = builder.withType(DataType.int8).fromList([1, 2, 3, 5]);
      test('random order', () {
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
      test('read (out of bounds)', () {
        expect(() => vector[-1], throwsRangeError);
        expect(() => vector[4], throwsRangeError);
      });
      test('write (out of bounds)', () {
        expect(() => vector[-1] = 1, throwsRangeError);
        expect(() => vector[4] = 1, throwsRangeError);
      });
      test('toString', () {
        expect(vector.toString(), '${vector.runtimeType}[4]: 1, 2, 3, 5');
      });
    });
    group('operators', () {
      final random = Random();
      group('add', () {
        final sourceA = builder
            .withType(DataType.uint8)
            .generate(100, (i) => random.nextInt(100));
        final sourceB = builder
            .withType(DataType.uint8)
            .generate(100, (i) => random.nextInt(100));
        test('default', () {
          final target = add(sourceA, sourceB);
          expect(target.dataType, DataType.uint8);
          expect(target.count, sourceA.count);
          for (var i = 0; i < target.count; i++) {
            expect(target[i], sourceA[i] + sourceB[i]);
          }
        });
        test('default, bad count', () {
          final sourceA = builder.withType(DataType.uint8).fromList([1, 2]);
          expect(() => add(sourceA, sourceB), throwsArgumentError);
        });
        test('target', () {
          final target = builder.withType(DataType.uint16)(sourceA.count);
          final result = add(sourceA, sourceB, target: target);
          expect(target.dataType, DataType.uint16);
          expect(target.count, sourceA.count);
          for (var i = 0; i < target.count; i++) {
            expect(target[i], sourceA[i] + sourceB[i]);
          }
          expect(result, target);
        });
        test('target, bad count', () {
          final target = builder.withType(DataType.uint16)(sourceA.count - 1);
          expect(
              () => add(sourceA, sourceB, target: target), throwsArgumentError);
        });
        test('builder', () {
          final target =
              add(sourceA, sourceB, builder: builder.withType(DataType.uint16));
          expect(target.dataType, DataType.uint16);
          expect(target.count, sourceA.count);
          for (var i = 0; i < target.count; i++) {
            expect(target[i], sourceA[i] + sourceB[i]);
          }
        });
      });
      test('sub', () {
        final sourceA = builder
            .withType(DataType.int16)
            .generate(100, (i) => random.nextInt(100) - 50);
        final sourceB = builder
            .withType(DataType.int16)
            .generate(100, (i) => random.nextInt(100) - 50);
        final target = sub(sourceA, sourceB);
        expect(target.dataType, DataType.int16);
        expect(target.count, 100);
        for (var i = 0; i < target.count; i++) {
          expect(target[i], sourceA[i] - sourceB[i]);
        }
      });
      test('sub (dimension missmatch)', () {
        final sourceA = builder.withType(DataType.uint8).fromList([1, 2]);
        final sourceB = builder.withType(DataType.uint8).fromList([1, 2, 3]);
        expect(() => sub(sourceA, sourceB), throwsArgumentError);
      });
      test('mul', () {
        final source = builder
            .withType(DataType.uint32)
            .generate(100, (i) => random.nextInt(1000));
        final target = mul(2, source);
        expect(target.dataType, DataType.uint32);
        expect(target.count, 100);
        for (var i = 0; i < target.count; i++) {
          expect(target[i], 2 * source[i]);
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
        final sourceA = builder
            .withType(DataType.uint8)
            .generate(100, (i) => random.nextInt(DataType.uint8.max));
        final sourceB = builder
            .withType(DataType.uint8)
            .generate(100, (i) => random.nextInt(DataType.uint8.max));
        var expected = 0;
        for (var i = 0; i < sourceA.count; i++) {
          expected += sourceA[i] * sourceB[i];
        }
        expect(dot(sourceA, sourceB), expected);
      });
      test('dot (dimension missmatch)', () {
        final sourceA = builder.withType(DataType.uint8).fromList([1, 2]);
        final sourceB = builder.withType(DataType.uint8).fromList([1, 2, 3]);
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
