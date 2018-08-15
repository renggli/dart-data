library data.test.matrix;

import 'dart:math';

import 'package:data/matrix.dart';
import 'package:data/type.dart';
import 'package:test/test.dart';

void matrixTest(String name, Builder builder) {
  group(name, () {
    group('builder', () {
      test('call', () {
        final matrix = builder.withType(DataType.int8)(4, 5);
        expect(matrix.dataType, DataType.int8);
        expect(matrix.rowCount, 4);
        expect(matrix.colCount, 5);
        for (var row = 0; row < matrix.rowCount; row++) {
          for (var col = 0; col < matrix.colCount; col++) {
            expect(matrix.get(row, col), 0);
          }
        }
      });
      test('constant', () {
        final matrix = builder.withType(DataType.int8).constant(5, 6, 123);
        expect(matrix.dataType, DataType.int8);
        expect(matrix.rowCount, 5);
        expect(matrix.colCount, 6);
        for (var row = 0; row < matrix.rowCount; row++) {
          for (var col = 0; col < matrix.colCount; col++) {
            expect(matrix.get(row, col), 123);
          }
        }
      });
      test('identity', () {
        final matrix = builder.withType(DataType.int8).identity(6, -1);
        expect(matrix.dataType, DataType.int8);
        expect(matrix.rowCount, 6);
        expect(matrix.colCount, 6);
        for (var row = 0; row < matrix.rowCount; row++) {
          for (var col = 0; col < matrix.colCount; col++) {
            expect(matrix.get(row, col), row == col ? -1 : 0);
          }
        }
      });
      test('generate', () {
        final matrix = builder
            .withType(DataType.string)
            .generate(7, 8, (row, col) => '($row, $col)');
        expect(matrix.dataType, DataType.string);
        expect(matrix.rowCount, 7);
        expect(matrix.colCount, 8);
        for (var row = 0; row < matrix.rowCount; row++) {
          for (var col = 0; col < matrix.colCount; col++) {
            expect(matrix.get(row, col), '($row, $col)');
          }
        }
      });
      test('from', () {
        final source = builder
            .withType(DataType.string)
            .generate(5, 6, (row, col) => '($row, $col)');
        final matrix = builder.withType(DataType.string).from(source);
        expect(matrix.dataType, DataType.string);
        expect(matrix.rowCount, 5);
        expect(matrix.colCount, 6);
        for (var row = 0; row < source.rowCount; row++) {
          for (var col = 0; col < source.colCount; col++) {
            expect(matrix.get(row, col), '($row, $col)');
          }
        }
      });
      test('fromRanges', () {
        final source = builder
            .withType(DataType.string)
            .generate(5, 6, (row, col) => '($row, $col)');
        final matrix =
            builder.withType(DataType.string).fromRanges(source, 1, 4, 3, 5);
        expect(matrix.dataType, DataType.string);
        expect(matrix.rowCount, 3);
        expect(matrix.colCount, 2);
        expect(matrix.get(0, 0), '(1, 3)');
        expect(matrix.get(0, 1), '(1, 4)');
        expect(matrix.get(1, 0), '(2, 3)');
        expect(matrix.get(1, 1), '(2, 4)');
        expect(matrix.get(2, 0), '(3, 3)');
        expect(matrix.get(2, 1), '(3, 4)');
      });
      test('fromRangeAndIndices', () {
        final source = builder
            .withType(DataType.string)
            .generate(5, 6, (row, col) => '($row, $col)');
        final matrix = builder
            .withType(DataType.string)
            .fromRangeAndIndices(source, 1, 3, [0, 0, 5]);
        expect(matrix.dataType, DataType.string);
        expect(matrix.rowCount, 2);
        expect(matrix.colCount, 3);
        expect(matrix.get(0, 0), '(1, 0)');
        expect(matrix.get(0, 1), '(1, 0)');
        expect(matrix.get(0, 2), '(1, 5)');
        expect(matrix.get(1, 0), '(2, 0)');
        expect(matrix.get(1, 1), '(2, 0)');
        expect(matrix.get(1, 2), '(2, 5)');
      });
      test('fromIndicesAndRanges', () {
        final source = builder
            .withType(DataType.string)
            .generate(5, 6, (row, col) => '($row, $col)');
        final matrix = builder
            .withType(DataType.string)
            .fromIndicesAndRange(source, [0, 4, 0], 1, 3);
        expect(matrix.dataType, DataType.string);
        expect(matrix.rowCount, 3);
        expect(matrix.colCount, 2);
        expect(matrix.get(0, 0), '(0, 1)');
        expect(matrix.get(0, 1), '(0, 2)');
        expect(matrix.get(1, 0), '(4, 1)');
        expect(matrix.get(1, 1), '(4, 2)');
        expect(matrix.get(2, 0), '(0, 1)');
        expect(matrix.get(2, 1), '(0, 2)');
      });
      test('fromIndices', () {
        final source = builder
            .withType(DataType.string)
            .generate(5, 6, (row, col) => '($row, $col)');
        final matrix = builder
            .withType(DataType.string)
            .fromIndices(source, [3, 2, 2], [1, 0]);
        expect(matrix.dataType, DataType.string);
        expect(matrix.rowCount, 3);
        expect(matrix.colCount, 2);
        expect(matrix.get(0, 0), '(3, 1)');
        expect(matrix.get(0, 1), '(3, 0)');
        expect(matrix.get(1, 0), '(2, 1)');
        expect(matrix.get(1, 1), '(2, 0)');
        expect(matrix.get(2, 0), '(2, 1)');
        expect(matrix.get(2, 1), '(2, 0)');
      });
      test('fromRows', () {
        final matrix = builder.withType(DataType.int8).fromRows([
          [1, 2, 3],
          [4, 5, 6],
        ]);
        expect(matrix.dataType, DataType.int8);
        expect(matrix.rowCount, 2);
        expect(matrix.colCount, 3);
        expect(matrix.get(0, 0), 1);
        expect(matrix.get(1, 0), 4);
        expect(matrix.get(0, 1), 2);
        expect(matrix.get(1, 1), 5);
        expect(matrix.get(0, 2), 3);
        expect(matrix.get(1, 2), 6);
      });
      test('fromCols', () {
        final matrix = builder.withType(DataType.int8).fromCols([
          [1, 2, 3],
          [4, 5, 6],
        ]);
        expect(matrix.dataType, DataType.int8);
        expect(matrix.rowCount, 3);
        expect(matrix.colCount, 2);
        expect(matrix.get(0, 0), 1);
        expect(matrix.get(1, 0), 2);
        expect(matrix.get(2, 0), 3);
        expect(matrix.get(0, 1), 4);
        expect(matrix.get(1, 1), 5);
        expect(matrix.get(2, 1), 6);
      });
      // custom initialization
      test('random order', () {
        final matrix = builder(5, 6);
        final points = <Point>[];
        for (var row = 0; row < matrix.rowCount; row++) {
          for (var col = 0; col < matrix.colCount; col++) {
            points.add(Point(row, col));
          }
        }
        // add values in random order
        points.shuffle();
        for (var point in points) {
          matrix.set(point.x, point.y, point);
        }
        for (var row = 0; row < matrix.rowCount; row++) {
          for (var col = 0; col < matrix.colCount; col++) {
            expect(matrix.get(row, col), Point(row, col));
          }
        }
        // remove values in random order
        points.shuffle();
        for (var point in points) {
          matrix.set(point.x, point.y, matrix.dataType.nullValue);
        }
        for (var row = 0; row < matrix.rowCount; row++) {
          for (var col = 0; col < matrix.colCount; col++) {
            expect(matrix.get(row, col), matrix.dataType.nullValue);
          }
        }
      });
    });
    group('views', () {
      test('row', () {
        final matrix = builder
            .withType(DataType.string)
            .generate(4, 5, (row, col) => '($row, $col)');
        for (var row = 0; row < matrix.rowCount; row++) {
          final view = matrix.row(row);
          expect(view.dataType, matrix.dataType);
          for (var col = 0; col < matrix.colCount; col++) {
            expect(view[col], '($row, $col)');
          }
          expect(() => view[-1], throwsRangeError);
          expect(() => view[matrix.colCount], throwsRangeError);
        }
      });
      test('col', () {
        final matrix = builder
            .withType(DataType.string)
            .generate(5, 4, (row, col) => '($row, $col)');
        for (var col = 0; col < matrix.colCount; col++) {
          final view = matrix.col(col);
          expect(view.dataType, matrix.dataType);
          for (var row = 0; row < matrix.rowCount; row++) {
            expect(view[row], '($row, $col)');
          }
          expect(() => view[-1], throwsRangeError);
          expect(() => view[matrix.rowCount], throwsRangeError);
        }
      });
      test('transpose', () {
        final matrix = builder
            .withType(DataType.string)
            .generate(7, 6, (row, col) => '($row, $col)');
        final view = matrix.transpose;
        expect(view.dataType, matrix.dataType);
        expect(view.rowCount, 6);
        expect(view.colCount, 7);
        for (var row = 0; row < view.rowCount; row++) {
          for (var col = 0; col < view.colCount; col++) {
            expect(view.get(row, col), '($col, $row)');
          }
        }
        expect(view.transpose, matrix);
      });
    });
    group('operators', () {
      final random = Random();
      test('add', () {
        final sourceA = builder
            .withType(DataType.uint8)
            .generate(4, 5, (row, col) => random.nextInt(DataType.uint8.max));
        final sourceB = builder
            .withType(DataType.uint8)
            .generate(4, 5, (row, col) => random.nextInt(DataType.uint8.max));
        final target =
            add(sourceA, sourceB, builder: builder.withType(DataType.int16));
        expect(target.dataType, DataType.int16);
        expect(target.rowCount, 4);
        expect(target.colCount, 5);
        for (var row = 0; row < target.rowCount; row++) {
          for (var col = 0; col < target.colCount; col++) {
            expect(target.get(row, col),
                sourceA.get(row, col) + sourceB.get(row, col));
          }
        }
      });
      test('sub', () {
        final sourceA = builder
            .withType(DataType.uint8)
            .generate(5, 4, (row, col) => random.nextInt(DataType.uint8.max));
        final sourceB = builder
            .withType(DataType.uint8)
            .generate(5, 4, (row, col) => random.nextInt(DataType.uint8.max));
        final target =
            sub(sourceA, sourceB, builder: builder.withType(DataType.int16));
        expect(target.dataType, DataType.int16);
        expect(target.rowCount, 5);
        expect(target.colCount, 4);
        for (var row = 0; row < target.rowCount; row++) {
          for (var col = 0; col < target.colCount; col++) {
            expect(target.get(row, col),
                sourceA.get(row, col) - sourceB.get(row, col));
          }
        }
      });
      test('mul', () {
        final sourceA = builder
            .withType(DataType.uint8)
            .generate(4, 5, (row, col) => random.nextInt(DataType.uint8.max));
        final sourceB = builder
            .withType(DataType.uint8)
            .generate(5, 6, (row, col) => random.nextInt(DataType.uint8.max));
        final target =
            mul(sourceA, sourceB, builder: builder.withType(DataType.int32));
        expect(target.dataType, DataType.int32);
        expect(target.rowCount, 4);
        expect(target.colCount, 6);
        for (var row = 0; row < target.rowCount; row++) {
          for (var col = 0; col < target.colCount; col++) {
            // TODO(renggli): verify the multiplication
            //expect(target.get(row, col),
            //    sourceA.get(row, col) * sourceB.get(row, col));
          }
        }
      });
    });
    test('get - bounds', () {
      final matrix = builder.withType(DataType.boolean)(2, 3);
      expect(() => matrix.get(-1, 0), throwsRangeError);
      expect(() => matrix.get(0, -1), throwsRangeError);
      expect(() => matrix.get(matrix.rowCount, 0), throwsRangeError);
      expect(() => matrix.get(0, matrix.colCount), throwsRangeError);
    });
  });
}

void main() {
  matrixTest('row major', Matrix.builder.rowMajor);
  matrixTest('col major', Matrix.builder.columnMajor);
  matrixTest('sparse-coo', Matrix.builder.coordinateList);
  matrixTest('sparse-csr', Matrix.builder.compressedRow);
  matrixTest('sparse-csc', Matrix.builder.compressedColumn);
  matrixTest('sparse-dia', Matrix.builder.diagonal);
  matrixTest('sparse-dok', Matrix.builder.keyed);
}
