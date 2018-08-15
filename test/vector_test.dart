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
      test('from', () {
        final source =
            builder.withType(DataType.string).generate(6, (i) => '$i');
        final vector = builder.withType(DataType.string).from(source);
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
      // custom initialization
      test('random order', () {
        final vector = builder(100);
        final values = <int>[];
        for (var i = 0; i < vector.count; i++) {
          values.add(i);
        }
        // add values in random order
        values.shuffle();
        for (var value in values) {
          vector[value] = value;
        }
        for (var i = 0; i < vector.count; i++) {
          expect(vector[i], i);
        }
        // remove values in random order
        values.shuffle();
        for (var value in values) {
          vector[value] = vector.dataType.nullValue;
        }
        for (var i = 0; i < vector.count; i++) {
          expect(vector[i], vector.dataType.nullValue);
        }
      });
    });
    group('operators', () {
      final random = Random();
      test('add', () {
        final sourceA = builder
            .withType(DataType.uint8)
            .generate(100, (i) => random.nextInt(DataType.uint8.max));
        final sourceB = builder
            .withType(DataType.uint8)
            .generate(100, (i) => random.nextInt(DataType.uint8.max));
        final target =
            add(sourceA, sourceB, builder: builder.withType(DataType.int16));
        expect(target.dataType, DataType.int16);
        expect(target.count, 100);
        for (var i = 0; i < target.count; i++) {
          expect(target[i], sourceA[i] + sourceB[i]);
        }
      });
      test('sub', () {
        final sourceA = builder
            .withType(DataType.uint8)
            .generate(100, (i) => random.nextInt(DataType.uint8.max));
        final sourceB = builder
            .withType(DataType.uint8)
            .generate(100, (i) => random.nextInt(DataType.uint8.max));
        final target =
            sub(sourceA, sourceB, builder: builder.withType(DataType.int16));
        expect(target.dataType, DataType.int16);
        expect(target.count, 100);
        for (var i = 0; i < target.count; i++) {
          expect(target[i], sourceA[i] - sourceB[i]);
        }
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
    });
  });
}

void main() {
  vectorTest('standard', Vector.builder.standard);
  vectorTest('keyed', Vector.builder.keyed);
  vectorTest('list', Vector.builder.list);
}
