library data.test.matrix;

import 'dart:math';

import 'package:data/matrix.dart';
import 'package:data/type.dart';
import 'package:test/test.dart';

void matrixTest(String name, MatrixConstructor constructor) {
  group(name, () {
    group('constructors', () {
      test('Matrix.default', () {
        final matrix = constructor(DataType.int8, 3, 4);
        expect(matrix.dataType, DataType.int8);
        expect(matrix.rowCount, 3);
        expect(matrix.colCount, 4);
        for (var row = 0; row < matrix.rowCount; row++) {
          for (var col = 0; col < matrix.colCount; col++) {
            expect(matrix.get(row, col), 0);
          }
        }
      });

      test('Matrix.zero', () {
        final matrix = Matrix.zero(constructor, DataType.uint8, 4, 5);
        expect(matrix.dataType, DataType.uint8);
        expect(matrix.rowCount, 4);
        expect(matrix.colCount, 5);
        for (var row = 0; row < matrix.rowCount; row++) {
          for (var col = 0; col < matrix.colCount; col++) {
            expect(matrix.get(row, col), 0);
          }
        }
      });
      test('Matrix.constant', () {
        final matrix = Matrix.constant(constructor, DataType.int8, 5, 6, 123);
        expect(matrix.dataType, DataType.int8);
        expect(matrix.rowCount, 5);
        expect(matrix.colCount, 6);
        for (var row = 0; row < matrix.rowCount; row++) {
          for (var col = 0; col < matrix.colCount; col++) {
            expect(matrix.get(row, col), 123);
          }
        }
      });
      test('Matrix.identity', () {
        final matrix = Matrix.identity(constructor, DataType.int8, 6, -1);
        expect(matrix.dataType, DataType.int8);
        expect(matrix.rowCount, 6);
        expect(matrix.colCount, 6);
        for (var row = 0; row < matrix.rowCount; row++) {
          for (var col = 0; col < matrix.colCount; col++) {
            expect(matrix.get(row, col), row == col ? -1 : 0);
          }
        }
      });
      test('Matrix.generate', () {
        final matrix = Matrix.generate(
            constructor, DataType.string, 6, 7, (row, col) => '($row, $col)');
        expect(matrix.dataType, DataType.string);
        expect(matrix.rowCount, 6);
        expect(matrix.colCount, 7);
        for (var row = 0; row < matrix.rowCount; row++) {
          for (var col = 0; col < matrix.colCount; col++) {
            expect(matrix.get(row, col), '($row, $col)');
          }
        }
      });
      // custom initialization
      test('rows first', () {
        final matrix = constructor(DataType.object, 3, 4);
        for (var row = 0; row < matrix.rowCount; row++) {
          for (var col = 0; col < matrix.colCount; col++) {
            matrix.set(row, col, '($row, $col)');
          }
        }
        for (var row = 0; row < matrix.rowCount; row++) {
          for (var col = 0; col < matrix.colCount; col++) {
            expect(matrix.get(row, col), '($row, $col)');
          }
        }
      });
      test('columns first', () {
        final matrix = constructor(DataType.string, 4, 5);
        for (var col = 0; col < matrix.colCount; col++) {
          for (var row = 0; row < matrix.rowCount; row++) {
            matrix.set(row, col, '($row, $col)');
          }
        }
        for (var row = 0; row < matrix.rowCount; row++) {
          for (var col = 0; col < matrix.colCount; col++) {
            expect(matrix.get(row, col), '($row, $col)');
          }
        }
      });
      test('random order', () {
        final matrix = constructor(DataType.object, 5, 6);
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
        final matrix = Matrix.generate(
            constructor, DataType.string, 4, 5, (row, col) => '($row, $col)');
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
        final matrix = Matrix.generate(
            constructor, DataType.string, 4, 5, (row, col) => '($row, $col)');
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
      test('sub', () {
        final matrix = Matrix.generate(
            constructor, DataType.string, 5, 6, (row, col) => '($row, $col)');
        final view = matrix.subMatrix(1, 3, 1, 4);
        expect(view.dataType, matrix.dataType);
        expect(view.rowCount, 3);
        expect(view.colCount, 4);
        for (var row = 0; row < view.rowCount; row++) {
          for (var col = 0; col < view.colCount; col++) {
            expect(view.get(row, col), '(${row + 1}, ${col + 1})');
          }
        }
        expect(() => view.get(-1, 0), throwsRangeError);
        expect(() => view.get(0, -1), throwsRangeError);
        expect(() => view.get(3, 3), throwsRangeError);
        expect(() => view.get(2, 4), throwsRangeError);
      });
      test('transpose', () {
        final matrix = Matrix.generate(
            constructor, DataType.string, 7, 6, (row, col) => '($row, $col)');
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
        final source = Matrix.generate(constructor, DataType.uint8, 5, 4,
            (row, col) => random.nextInt(DataType.uint8.max));
        final target = constructor(DataType.int16, 5, 4);
        Matrix.copy(source, target: target);
        for (var row = 0; row < target.rowCount; row++) {
          for (var col = 0; col < target.colCount; col++) {
            expect(target.get(row, col), source.get(row, col));
          }
        }
      });
      test('add', () {
        final sourceA = Matrix.generate(constructor, DataType.uint8, 4, 5,
            (row, col) => random.nextInt(DataType.uint8.max));
        final sourceB = Matrix.generate(constructor, DataType.uint8, 4, 5,
            (row, col) => random.nextInt(DataType.uint8.max));
        final target = constructor(DataType.uint16, 4, 5);
        Matrix.add<int>(sourceA, sourceB, target: target);
        for (var row = 0; row < target.rowCount; row++) {
          for (var col = 0; col < target.colCount; col++) {
            expect(target.get(row, col),
                sourceA.get(row, col) + sourceB.get(row, col));
          }
        }
      });
      test('sub', () {
        final sourceA = Matrix.generate(constructor, DataType.uint8, 4, 5,
            (row, col) => random.nextInt(DataType.uint8.max));
        final sourceB = Matrix.generate(constructor, DataType.uint8, 4, 5,
            (row, col) => random.nextInt(DataType.uint8.max));
        final target = constructor(DataType.int16, 4, 5);
        Matrix.sub<int>(sourceA, sourceB, target: target);
        for (var row = 0; row < target.rowCount; row++) {
          for (var col = 0; col < target.colCount; col++) {
            expect(target.get(row, col),
                sourceA.get(row, col) - sourceB.get(row, col));
          }
        }
      });
      test('mul', () {
        final sourceA = Matrix.generate(constructor, DataType.uint8, 4, 5,
            (row, col) => random.nextInt(DataType.int8.max));
        final sourceB = Matrix.generate(constructor, DataType.uint8, 5, 6,
            (row, col) => random.nextInt(DataType.int8.max));
        final target = constructor(DataType.int32, 4, 6);
        Matrix.mul<int>(sourceA, sourceB, target: target);
        for (var row = 0; row < target.rowCount; row++) {
          for (var col = 0; col < target.colCount; col++) {
            expect(target.get(row, col),
                sourceA.get(row, col) * sourceB.get(row, col));
          }
        }
      });
    });

    test('get - bounds', () {
      final matrix = constructor(DataType.boolean, 2, 3);
      expect(() => matrix.get(-1, 0), throwsRangeError);
      expect(() => matrix.get(0, -1), throwsRangeError);
      expect(() => matrix.get(matrix.rowCount, 0), throwsRangeError);
      expect(() => matrix.get(0, matrix.colCount), throwsRangeError);
    });
  });
}

void main() {
  matrixTest('row major', Matrix.rowMajor);
  matrixTest('column major', Matrix.columnMajor);
  matrixTest('sparse-coo', Matrix.coordinateList);
  matrixTest('sparse-csr', Matrix.compressedRow);
  matrixTest('sparse-csc', Matrix.compressedColumn);
  matrixTest('sparse-dia', Matrix.diagonal);
  matrixTest('sparse-dok', Matrix.keyed);
}
