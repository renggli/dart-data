library data.test.vector;

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
            builder.withType(DataType.string).generate(7, (index) => '$index');
        expect(vector.dataType, DataType.string);
        expect(vector.count, 7);
        for (var i = 0; i < vector.count; i++) {
          expect(vector[i], '$i');
        }
      });
      test('from', () {
        final source =
            builder.withType(DataType.string).generate(6, (index) => '$index');
        final vector = builder.withType(DataType.string).from(source);
        expect(vector.dataType, DataType.string);
        expect(vector.count, 6);
        for (var i = 0; i < vector.count; i++) {
          expect(vector[i], '$i');
        }
      });
      test('fromRange', () {
        final source =
            builder.withType(DataType.string).generate(6, (index) => '$index');
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
            builder.withType(DataType.string).generate(6, (index) => '$index');
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
  });
}

void main() {
  vectorTest('standard', Vector.builder.standard);
  vectorTest('keyed', Vector.builder.keyed);
  vectorTest('list', Vector.builder.list);
}
