library data.test.matrix;

import 'dart:math';

import 'package:data/matrix.dart';
import 'package:data/type.dart';
import 'package:test/test.dart';

void matrixTest(String name, MatrixBuilder builder) {
  group(name, () {
    group('builder', () {
      test('default', () {
        final matrix =
            builder.withDataType(DataType.int8).withSize(4, 5).build();
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
        final matrix = builder
            .withDataType(DataType.int8)
            .withSize(5, 6)
            .buildConstant(123);
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
        final matrix = builder
            .withDataType(DataType.int8)
            .withSize(6, 7)
            .buildIdentity(-1);
        expect(matrix.dataType, DataType.int8);
        expect(matrix.rowCount, 6);
        expect(matrix.colCount, 7);
        for (var row = 0; row < matrix.rowCount; row++) {
          for (var col = 0; col < matrix.colCount; col++) {
            expect(matrix.get(row, col), row == col ? -1 : 0);
          }
        }
      });
      test('generate', () {
        final matrix = builder
            .withDataType(DataType.string)
            .withSize(7, 8)
            .buildGenerate((row, col) => '($row, $col)');
        expect(matrix.dataType, DataType.string);
        expect(matrix.rowCount, 7);
        expect(matrix.colCount, 8);
        for (var row = 0; row < matrix.rowCount; row++) {
          for (var col = 0; col < matrix.colCount; col++) {
            expect(matrix.get(row, col), '($row, $col)');
          }
        }
      });
      test('fromRows', () {
        final matrix =
            builder.withDataType(DataType.int8).withSize(3, 2).buildFromRows([
          [1, 2],
          [3, 4],
        ]);
        expect(matrix.dataType, DataType.int8);
        expect(matrix.rowCount, 3);
        expect(matrix.colCount, 2);
        expect(matrix.get(0, 0), 1);
        expect(matrix.get(1, 0), 3);
        expect(matrix.get(2, 0), 0);
        expect(matrix.get(0, 1), 2);
        expect(matrix.get(1, 1), 4);
        expect(matrix.get(2, 1), 0);
      });
      test('fromCols', () {
        final matrix =
            builder.withDataType(DataType.int8).withSize(2, 3).buildFromCols([
          [1, 2],
          [3, 4],
        ]);
        expect(matrix.dataType, DataType.int8);
        expect(matrix.rowCount, 2);
        expect(matrix.colCount, 3);
        expect(matrix.get(0, 0), 1);
        expect(matrix.get(1, 0), 2);
        expect(matrix.get(0, 1), 3);
        expect(matrix.get(1, 1), 4);
        expect(matrix.get(0, 2), 0);
        expect(matrix.get(1, 2), 0);
      });
      // custom initialization
      test('random order', () {
        final matrix = builder.withSize(5, 6).build();
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
            .withDataType(DataType.string)
            .withSize(4, 5)
            .buildGenerate((row, col) => '($row, $col)');
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
            .withDataType(DataType.string)
            .withSize(5, 4)
            .buildGenerate((row, col) => '($row, $col)');
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
            .withDataType(DataType.string)
            .withSize(7, 6)
            .buildGenerate((row, col) => '($row, $col)');
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
      test('copy', () {
        final source = builder
            .withDataType(DataType.uint8)
            .withSize(5, 4)
            .buildGenerate((row, col) => random.nextInt(DataType.uint8.max));
        final target =
            builder.withDataType(DataType.uint8).withSize(5, 4).build();
        Matrix.copy(source, target: target);
        for (var row = 0; row < target.rowCount; row++) {
          for (var col = 0; col < target.colCount; col++) {
            expect(target.get(row, col), source.get(row, col));
          }
        }
      });
      test('add', () {
        final sourceA = builder
            .withDataType(DataType.uint8)
            .withSize(4, 5)
            .buildGenerate((row, col) => random.nextInt(DataType.uint8.max));
        final sourceB = builder
            .withDataType(DataType.uint8)
            .withSize(4, 5)
            .buildGenerate((row, col) => random.nextInt(DataType.uint8.max));
        final target =
            builder.withDataType(DataType.uint16).withSize(4, 5).build();
        Matrix.add<int>(sourceA, sourceB, target: target);
        for (var row = 0; row < target.rowCount; row++) {
          for (var col = 0; col < target.colCount; col++) {
            expect(target.get(row, col),
                sourceA.get(row, col) + sourceB.get(row, col));
          }
        }
      });
      test('sub', () {
        final sourceA = builder
            .withDataType(DataType.uint8)
            .withSize(5, 4)
            .buildGenerate((row, col) => random.nextInt(DataType.uint8.max));
        final sourceB = builder
            .withDataType(DataType.uint8)
            .withSize(5, 4)
            .buildGenerate((row, col) => random.nextInt(DataType.uint8.max));
        final target =
            builder.withDataType(DataType.int16).withSize(5, 4).build();
        Matrix.sub<int>(sourceA, sourceB, target: target);
        for (var row = 0; row < target.rowCount; row++) {
          for (var col = 0; col < target.colCount; col++) {
            expect(target.get(row, col),
                sourceA.get(row, col) - sourceB.get(row, col));
          }
        }
      });
      test('mul', () {
        final sourceA = builder
            .withDataType(DataType.uint8)
            .withSize(4, 5)
            .buildGenerate((row, col) => random.nextInt(DataType.uint8.max));
        final sourceB = builder
            .withDataType(DataType.uint8)
            .withSize(5, 6)
            .buildGenerate((row, col) => random.nextInt(DataType.uint8.max));
        final target =
            builder.withDataType(DataType.int32).withSize(4, 6).build();
        Matrix.mul<int>(sourceA, sourceB, target: target);
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
      final matrix =
          builder.withDataType(DataType.boolean).withSize(2, 3).build();
      expect(() => matrix.get(-1, 0), throwsRangeError);
      expect(() => matrix.get(0, -1), throwsRangeError);
      expect(() => matrix.get(matrix.rowCount, 0), throwsRangeError);
      expect(() => matrix.get(0, matrix.colCount), throwsRangeError);
    });
  });
}

void main() {
  matrixTest('row major', Matrix.builder.withMatrixType(MatrixType.rowMajor));
  matrixTest(
      'column major', Matrix.builder.withMatrixType(MatrixType.columnMajor));
  matrixTest(
      'sparse-coo', Matrix.builder.withMatrixType(MatrixType.coordinateList));
  matrixTest(
      'sparse-csr', Matrix.builder.withMatrixType(MatrixType.compressedRow));
  matrixTest(
      'sparse-csc', Matrix.builder.withMatrixType(MatrixType.compressedColumn));
  matrixTest('sparse-dia', Matrix.builder.withMatrixType(MatrixType.diagonal));
  matrixTest('sparse-dok', Matrix.builder.withMatrixType(MatrixType.keyed));
}
